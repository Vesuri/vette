#!/usr/bin/env python3
"""⭐⭐ Does the game actually EXECUTE 68020-only instructions?

The Color build runs on a Mac II, which HAS a 68020 -- but that says nothing
about what the compiler emitted.  Option A (keep the original instructions)
makes this a gate: the bytes must *execute* on a 68000, not merely be
understood.

Method: recursive descent from every jump-table entry, following branches, with
a DUAL DECODE of each instruction -- once as 68040 (a superset, for correct
lengths and flow) and once as 68000.  An instruction the 68000 decoder rejects,
or decodes differently, is 68020-only.  Addressing modes are checked separately,
because a perfectly ordinary MOVE can carry a 020-only extension word.

⚠ This supersedes the earlier LINEAR screen (600 bytes per entry, no branch
following, whole-file sweeps producing callm/rtm/cmp2 false positives out of
data).  Two things make this one believable instead:

  1. It FOLLOWS FLOW, so it only ever decodes bytes that are reached, which is
     what removes the data-decoded-as-code false positives.
  2. It SELF-TESTS.  --selftest assembles known 68020-only encodings and known
     68000 ones and checks the classifier calls each correctly.  ⚑ A
     fixture-less pass runs zero comparisons and reports green; a sweep that
     cannot detect a 68020 instruction would report "clean" just as loudly.

And it reports COVERAGE, because "no 68020 instruction found" is only as strong
as the fraction of each segment the walk actually reached.  Unfollowable
computed jumps (switch tables) are counted and named, not silently dropped.

Usage:  python3 tools/m68k_sweep.py --selftest
        python3 tools/m68k_sweep.py tmp/seg_color [tmp/seg_bw ...]
"""
import os, re, struct, sys
from capstone import Cs, CS_ARCH_M68K, CS_MODE_M68K_000, CS_MODE_M68K_040, CsError
from capstone.m68k import (M68K_OP_BR_DISP, M68K_OP_MEM, M68K_AM_PCI_DISP,
                           M68K_AM_PCI_INDEX_8_BIT_DISP)

md40 = Cs(CS_ARCH_M68K, CS_MODE_M68K_040); md40.detail = True
md00 = Cs(CS_ARCH_M68K, CS_MODE_M68K_000); md00.detail = True

# Mnemonics that simply do not exist on a 68000 (68010+ / 68020+ / FPU).
NOT_68000 = {
    "bfchg","bfclr","bfexts","bfextu","bfffo","bfins","bfset","bftst",
    "callm","rtm","cas","cas2","chk2","cmp2","extb","pack","unpk",
    "trapcc","trapcs","trapeq","trapf","trapge","trapgt","traphi","traple",
    "traplt","trapmi","trapne","trappl","trapt","trapvc","trapvs","trapls",
    "bkpt","movec","moves","rtd","divsl","divul","muls.l","mulu.l",
    "pflush","pload","pmove","ptest","pvalid","cinv","cpush","move16",
}
FPU = re.compile(r"^f[a-z]")

# ⚠ MEASURED GAPS IN CAPSTONE, found by the self-test rather than assumed away:
#   * CALLM/RTM decode as `dc.w` in BOTH 68040 and 68000 mode, so the dual decode
#     cannot see them -- they need a raw-encoding check.
#   * CAS2 is wrongly ACCEPTED by capstone's 68000 decoder; the mnemonic table
#     catches it.
# Everything else 68020-only that was tried does decode on 040 and is correctly
# rejected on 000, which is what makes the dual decode worth having.
RAW_020 = [
    (0xFFC0, 0x06C0, "callm/rtm (68020-only, removed again in the 68030)"),
]

def is_020_only(insn):
    """Classify ONE instruction.  Returns a reason string, or None if 68000-legal."""
    w = int.from_bytes(insn.bytes[:2], "big") if len(insn.bytes) >= 2 else 0
    for mask, val, why in RAW_020:
        if (w & mask) == val:
            return why
    m = insn.mnemonic.lower()
    base = m.split(".")[0]
    if base in NOT_68000 or m in NOT_68000:
        return f"{m} is not a 68000 instruction"
    if FPU.match(base) and base not in ("for",):
        return f"{m} is an F-line coprocessor instruction (traps on a 68000)"
    # 32-bit multiply/divide: 68000 has only the 16-bit forms.
    if base in ("muls","mulu","divs","divu") and insn.mnemonic.endswith(".l"):
        return f"{m} — the 68000 has no 32-bit multiply/divide"
    # Long branch displacement (Bcc.L / BRA.L / BSR.L) is 68020+.
    if base.startswith(("b","bra","bsr")) and insn.mnemonic.endswith(".l") \
       and base not in ("bchg","bclr","bset","btst","bfins"):
        return f"{m} — 32-bit branch displacement is 68020+"
    # Addressing-mode extension words: scale factors and the full format.
    # ⚠ capstone raises on .operands for anything it decoded as data, so guard it.
    try:
        ops = insn.operands
    except CsError:
        ops = []
    for op in ops:
        mem = getattr(op, "mem", None)
        if mem is None: continue
        if getattr(mem, "scale", 1) not in (0, 1):
            return f"scaled index (*{mem.scale}) is 68020+"
        if getattr(mem, "bd_size", 0) or getattr(mem, "od_size", 0) \
           or getattr(mem, "in_disp", 0) or getattr(mem, "out_disp", 0):
            return "full-format extension word (memory indirect / base displacement) is 68020+"
    # Belt and braces: does the 68000 decoder agree this is an instruction at all?
    d00 = list(md00.disasm(insn.bytes, insn.address, count=1))
    if not d00:
        return f"{m} does not decode as a 68000 instruction"
    if d00[0].size != insn.size:
        return f"{m} decodes to a different length on a 68000 ({d00[0].size} vs {insn.size})"
    return None

# ------------------------------------------------------------------ flow ----

STOP   = {"rts","rte","rtr","bra","illegal","jmp"}
BRANCH = re.compile(r"^(b(ra|sr|hi|ls|cc|cs|ne|eq|vc|vs|pl|mi|ge|lt|gt|le)|db[a-z]{1,3}|jsr|jmp)$")

def target_of(insn):
    """The intra-segment address a control transfer goes to, or None if it cannot
    be computed statically.

    ⚠⚠ THE BUG THIS FUNCTION EXISTS TO NOT REPEAT: capstone hands a branch target
    back as an operand of type **M68K_OP_BR_DISP**, not M68K_OP_IMM, and as a
    DISPLACEMENT relative to `address + 2`, not as an absolute.  Looking for IMM
    found nothing, so the first version of this sweep followed NO branches at all
    and still produced a confident table of zeros -- at 17.6% coverage, which was
    the only visible symptom.  ⭐ That is why this tool reports coverage: it is
    the control that catches a walk which is not walking.
    """
    try:
        ops = insn.operands
    except CsError:
        return None
    for op in ops:
        if op.type == M68K_OP_BR_DISP:
            return insn.address + 2 + op.br_disp.disp
        if op.type == M68K_OP_MEM and op.address_mode in (M68K_AM_PCI_DISP,
                                                          M68K_AM_PCI_INDEX_8_BIT_DISP):
            # pc-relative jsr/jmp.  An INDEXED one is a switch table: the
            # displacement is the table base, and the real targets are unknown.
            if op.address_mode == M68K_AM_PCI_DISP:
                return insn.address + 2 + op.mem.disp
            return None
    return None

def walk(code, entries, name):
    """Recursive descent.  Returns (findings, seen_byte_set, unfollowable_jumps)."""
    seen, todo = set(), list(entries)
    findings, blind = [], 0
    while todo:
        pc = todo.pop()
        while 0 <= pc < len(code) and pc not in seen:
            word = struct.unpack_from(">H", code, pc)[0] if pc + 2 <= len(code) else 0
            # A-line traps are the Toolbox; they are 2 bytes and execution resumes after.
            if 0xA000 <= word <= 0xAFFF:
                seen.add(pc); seen.add(pc + 1); pc += 2; continue
            try:
                insn = next(iter(md40.disasm(code[pc:pc + 16], pc, count=1)), None)
            except CsError:
                insn = None
            if insn is None or insn.size == 0:
                break                                   # not code (or data): stop this path
            why = is_020_only(insn)
            # ⚠ `dc.w` is capstone saying "this is not an instruction".  It must
            # STOP the path, not be counted as 68000-legal -- but check it for a
            # raw 68020 encoding first, because callm/rtm look like this too.
            if insn.mnemonic.lower() == "dc.w":
                if why:
                    findings.append((name, pc, insn.mnemonic, insn.op_str, why,
                                     code[pc:pc + insn.size].hex()))
                break
            for off in range(insn.size): seen.add(pc + off)
            if why:
                findings.append((name, pc, insn.mnemonic, insn.op_str, why,
                                 code[pc:pc + insn.size].hex()))
            m = insn.mnemonic.lower().split(".")[0]
            if BRANCH.match(m):
                t = target_of(insn)
                if t is not None and 0 <= t < len(code):
                    if t not in seen: todo.append(t)
                else:
                    blind += 1
            if m in STOP:
                break
            pc += insn.size
    return findings, seen, blind

# ------------------------------------------------------------ jump table ----

def linear_scan(code, member, name, skew=0):
    """⭐⭐ THE CONTROL for the coverage the walk did not get.

    "No 68020 instruction on any reached path" is only half an answer while a
    third of the bytes were never reached.  So sweep the UNREACHED bytes too,
    linearly, and classify them the same way.  This is deliberately the weak,
    false-positive-prone method the earlier screen used -- that is the point:
    a linear sweep over data invents `callm`/`cmp2`/`cas2` readily, so a
    residue that comes back EMPTY is much stronger than the walk alone, and a
    residue that comes back non-empty is a short list to explain by hand
    rather than an unbounded unknown.

    Each run is decoded from its own start on an even boundary.  ⭐ Call it
    BOTH ways -- over the unreached bytes and over the reached ones -- because
    the reached bytes are known-code and give the method's own false-positive
    rate on this very binary.  A residue density far above that calibration is
    the measurement that says "those bytes are not code", and it needs no
    eyeballing of hex.
    """
    def ascii_frac(a, b):
        w = code[max(0, a):min(len(code), b)]
        if not w: return 0.0
        return sum(1 for c in w if 32 <= c < 127) / len(w)

    hits, gaps, gap_bytes = [], 0, 0
    i, n = 0, len(code)
    while i < n:
        if not member(i):
            i += 1; continue
        j = i
        while j < n and member(j): j += 1
        gaps += 1; gap_bytes += j - i
        pc = i + (i & 1) + skew                       # instructions are word-aligned
        while pc < j:
            insn = next(iter(md40.disasm(code[pc:min(j, pc + 16)], pc, count=1)), None)
            if insn is None or insn.size == 0:
                pc += 2; continue
            why = is_020_only(insn)
            if why:
                hits.append((name, pc, insn.mnemonic, insn.op_str, why,
                             code[pc:pc + insn.size].hex(),
                             ascii_frac(pc - 12, pc + 20), j - i))
            pc += insn.size
        i = j
    return hits, gaps, gap_bytes

def jump_table(code0):
    """CODE 0: 16-byte header, then 8-byte entries 'offset:w, MOVE.W #seg,-(SP), _LoadSeg'."""
    above, below, jtsize, jtoff = struct.unpack_from(">IIII", code0, 0)
    out = []
    for i in range(16, len(code0) - 7, 8):
        off, push, seg, trap = struct.unpack_from(">HHHH", code0, i)
        if push != 0x3F3C or trap != 0xA9F0:
            return out, (above, below, jtsize, jtoff), False
        out.append((seg, off))
    return out, (above, below, jtsize, jtoff), True

def sweep(dirname):
    segs = {}
    for f in sorted(os.listdir(dirname)):
        m = re.match(r"CODE_(\d+)", f)
        if m: segs[int(m.group(1))] = (f, open(os.path.join(dirname, f), "rb").read())
    entries, hdr, clean = jump_table(segs[0][1])
    print(f"\n=== {dirname}")
    print(f"    CODE 0: above-A5 {hdr[0]}  below-A5 {hdr[1]}  JT {hdr[2]} B "
          f"({hdr[2]//8} entries) at A5+{hdr[3]};  parsed {len(entries)} entries"
          f"{'' if clean else '  ⚠ NOT all in unloaded form'}")
    per_seg = {}
    for seg, off in entries: per_seg.setdefault(seg, set()).add(off)
    total_find, total_bytes, total_size, total_blind = [], 0, 0, 0
    residue, res_gaps, res_bytes = [], 0, 0
    control, ctl_bytes = [], 0
    skewed, skew_bytes = [], 0
    print(f"    {'seg':<22} {'entries':>7} {'bytes':>7} {'reached':>8} {'cov':>6}"
          f" {'blind':>6} {'68020':>6} {'residue':>7}")
    for n in sorted(segs):
        fname, data = segs[n]
        if n == 0: continue
        code = data[4:]                                  # skip the near-model header
        roots = sorted(per_seg.get(n, set()))
        f, seen, blind = walk(code, roots, fname)
        cov = len(seen)
        r, g, rb = linear_scan(code, lambda k: k not in seen, fname)
        c, _, cb = linear_scan(code, lambda k: k in seen, fname)
        k, _, kb_ = linear_scan(code, lambda q: q in seen, fname, skew=2)
        skewed += k; skew_bytes += kb_
        residue += r; res_gaps += g; res_bytes += rb
        control += c; ctl_bytes += cb
        total_find += f; total_bytes += cov; total_size += len(code); total_blind += blind
        print(f"    {fname:<22} {len(roots):>7} {len(code):>7} {cov:>8} "
              f"{100*cov/max(1,len(code)):>5.1f}% {blind:>6} {len(f):>6} {len(r):>7}")
    print(f"    {'TOTAL':<22} {len(entries):>7} {total_size:>7} {total_bytes:>8} "
          f"{100*total_bytes/max(1,total_size):>5.1f}% {total_blind:>6} {len(total_find):>6}"
          f" {len(residue):>7}")
    print(f"    residue control: {res_bytes} unreached bytes in {res_gaps} runs, "
          f"linearly swept, {len(residue)} 68020-only candidates")
    # ⭐ Objective triage of the residue instead of eyeballing it: a hit sitting
    # in a window that is mostly printable ASCII is a string table decoded as
    # code, which is the known false positive of a linear sweep.
    kb = lambda hits, byts: 1024 * len(hits) / max(1, byts)
    print(f"    ⭐ CALIBRATION, same linear method over the bytes the walk PROVED are code:")
    print(f"         known code : {ctl_bytes:>6} B  {len(control):>4} candidates  "
          f"{kb(control, ctl_bytes):.2f} per KB  (aligned -- partly circular,"
          f" it re-derives the walk's own boundaries)")
    print(f"         same, +2 B skew, so it DESYNCS: {skew_bytes:>6} B  {len(skewed):>4}"
          f"  {kb(skewed, skew_bytes):.2f} per KB"
          f"   <-- the method's real rate on code-shaped bytes")
    print(f"         unreached  : {res_bytes:>6} B  {len(residue):>4} candidates  "
          f"{kb(residue, res_bytes):.2f} per KB")
    texty = [h for h in residue if h[6] >= 0.5]
    print(f"         ({len(texty)} of the unreached hits sit in >=50% printable-ASCII windows)")
    for name, pc, mn, ops, why, hx, af, gl in residue[:12]:
        print(f"      ? {name}+0x{pc:04X}  {hx:<12} {mn:<10} {ops:<24} "
              f"ascii={af:.2f} gap={gl:<6} {why}")
    if total_find:
        print("    ⚠ 68020-only instructions on reachable paths:")
        for name, pc, mn, ops, why, hx in total_find[:40]:
            print(f"      {name}+0x{pc:04X}  {hx:<12} {mn:<10} {ops:<24} {why}")
    return total_find

# -------------------------------------------------------------- selftest ----

SELFTEST = [
    # (bytes, expect_020_only, what)
    ("4c00 1800", True,  "mulu.l d0,d1"),
    ("4c41 1000", True,  "divul.l"),
    ("49c0",      True,  "extb.l d0"),
    ("e9c0 0000", True,  "bftst"),
    ("06c0 0000", True,  "callm/rtm — capstone decodes it as dc.w in BOTH modes"),
    ("0cfc 0000 0000", True, "cas2 — capstone's 68000 decoder WRONGLY accepts it"),
    ("4808 0000 0000", True, "link.l"),
    ("60ff 0000 0000", True, "bra.l"),
    ("4848",      True,  "bkpt"),
    ("50fc",      True,  "trapt"),
    ("4e7a 0000", True,  "movec"),
    ("0e10 1000", True,  "moves"),
    ("4e74 0000", True,  "rtd"),
    ("8140 0000", True,  "pack"),
    ("1030 0a00", True,  "move.b (0,a0,d0.l*4),d0 — scaled index"),
    ("1030 0170", True,  "move.b with full-format extension word"),
    ("4e71",      False, "nop"),
    ("4e56 0000", False, "link a6,#0"),
    ("c0c1",      False, "mulu.w d1,d0"),
    ("81c1",      False, "divs.w d1,d0"),
    ("4e75",      False, "rts"),
    ("3f3c 0001", False, "move.w #1,-(sp)"),
    ("1030 0800", False, "move.b (0,a0,d0.w),d0 — brief ext, scale 1"),
    ("6000 0100", False, "bra.w"),
    ("48e7 fffe", False, "movem.l"),
]

def selftest():
    print("Self-test of the classifier (⚑ without this the sweep proves nothing):")
    bad = 0
    for hexs, expect, what in SELFTEST:
        b = bytes.fromhex(hexs.replace(" ", ""))
        insn = next(iter(md40.disasm(b, 0, count=1)), None)
        if insn is None:
            got, why = None, "did not decode at all"
        else:
            why = is_020_only(insn); got = why is not None
        ok = (got == expect)
        bad += not ok
        print(f"  {'ok ' if ok else 'FAIL'} {hexs:<12} {what:<42} "
              f"expected {'020-only' if expect else '68000  '}  got "
              f"{'020-only' if got else ('68000' if got is False else 'undecodable')}"
              + (f"   [{why}]" if why else ""))
    print(f"  -> {len(SELFTEST)-bad}/{len(SELFTEST)} correct")
    return bad

if __name__ == "__main__":
    args = sys.argv[1:]
    if "--selftest" in args:
        sys.exit(1 if selftest() else 0)
    for d in args or ["tmp/seg_color"]:
        sweep(d)
