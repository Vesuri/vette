# Optimising a native twin for the 68000 (hard-won; apply when a function is hot)

> **⚑ INHERITED VERBATIM from the *Rescue on Fractalus!* (Atari) and *Revs* (BBC) ports.**  Every
> rule below was measured on a 7 MHz A500 with the same toolchain (m68k-amiga-elf-gcc + vasm) and
> the same vendored framework this port uses, so the **68000 and GCC rules apply unchanged**.  The
> worked examples name *those* projects' functions (`terrain_column_rasterize_core`, the SFX mixer,
> the band paint, …); read them as evidence, not as references to code in this tree.  Add this
> port's own measured cases as they arrive, and do not soften a rule without a measurement that
> contradicts it.
>
> ⚠⚠ **READ THE FRAMING DIFFERENTLY HERE.**  Both prior ports reached the 68000 through a `mem[]`-based
> 6502 transliteration, so this file is written as "how to make a NATIVE TWIN fast".  **Vette has no
> transliteration and no `mem[]`** — the original is already 68000 code.  That retires the
> transliteration-specific rules below (`bus_read` hoisting, ZP scratch round-trips, the
> little-endian `mem[]` aliasing hazard, "a twin can be slower than the transliteration") and leaves
> the rest — the GCC inlining rules, the pointer-walk/ivopts pathology, the `move.l` batching traps,
> the mul/div ban, `ROR` vs `X` — fully live.  Where a rule says "the transliteration", read "the C
> you write where the original had hand asm", which faces the same GCC.
> ⚠ And this port inherits a **third** case those two never had: the original's OWN 68000 code, which
> is hand-written and was tuned for a 68000.  Before optimising a routine you converted, check what
> the original instruction sequence did — it is a lower bound that actually existed.
>
> **Read this before optimising any hot function or writing an asm twin.** The two rules that
> must not be violated even without reading this file (RAM is uniformly slow; never emit a
> 32-bit software mul/div) are stated in `CLAUDE.md` §Hard rules.
> Companions: `docs/perf-method.md` (how to get a number you can trust),
> `docs/amiga-lessons.md`, `docs/method-lessons.md`.

The transliteration→native step gets you a *correct* twin; it is NOT fast. The transliterated
style (`mem[addr]` for every access, `bus_read`/`bus_write`, per-op temporaries) is memory-bound
on the 68000. **The dominant cost is the number of memory accesses, not arithmetic** — the
68000 has no cache, every load/store goes to RAM, and `mem[]` is `volatile` (shared with the
VBI/audio ISRs) so the compiler can't cache, batch, or reorder a single access.

⚠ **RAM is slow REGARDLESS of address — do NOT reason in terms of "FAST RAM vs CHIP RAM".** The
target is a bare **A500 with NO real fast RAM**. Any "fast RAM" an A500 has is almost always
"slow RAM" (trapdoor/ranger) on the SAME bus as chip RAM, and even genuine fast RAM is not much
faster. So treat **every** memory access — `mem[]`, chip bitmaps/sprites, the stack (hence every
subroutine call/return) — as uniformly expensive. The lever is **reducing the number of reads and
writes**, full stop; never justify one buffer being cheaper than another by which "kind" of RAM it
lives in, and never dismiss a copy as cheap because it's "fast RAM". (This has been a recurring
mistake — the old `&mem[0]`≈`0x264fe8` "it's fast RAM" note was wrong-headed and is retired.)
A zero-copy scheme that avoids moving data beats any scheme that moves it, independent of address.
Rewrite hot functions in idiomatic C:

- **Keep loop scratch / running pointers / loop-invariants in locals (registers), not `mem[]`.**
  The transliteration re-reads/-writes ZP scratch every iteration (e.g. `terrain_collision_and_silhouette` hit
  `$80/$81/$95/$96` ~13×/iter). Hoist them into locals; write back only the *final* value the
  6502 oracle leaves in `mem[]` (the harness only compares post-return state, so intermediate
  ZP writes that the next iteration overwrites are dead — skip them). Cache invariants
  (`$00A0-$00A3` etc.) into locals once before the loop.
- **Pointer-walk with autoincrement, never multiply+index in a loop.** Replace
  `M[base + i*stride + Y]` (a 68000 `mulu` + indexed load each step) with a pointer advanced by
  `p += stride` / `p -= stride` (`move (a0)+` / `-(a0)`). Reuse a walked pointer across phases
  where the geometry allows (collision's scan leaves the pointer at row k, so the waterfall
  steps it back down with no fresh multiply).
  ⚠ **This rule kills a `mulu`+index — it does NOT beat an UNROLLED absolute scan.** Over a
  short fixed-length array GCC often emits straight-line absolute code (`move.b (base+i).l,dn`
  16 cyc + `beq.s` 10 = 26/element), which is *cheaper* than a pointer loop (`tst.b (a0)+` 8 +
  `beq.s` 10 + `addq.l #1,a1` 8 + `dbra` 10 = 36/element): the 18 cycles of loop bookkeeping
  exceed the 8 that autoincrement saves on addressing. Measured on the SFX mixer's 12-slot
  scans, where a "clean" pointer-walked asm twin came out **5% slower than the C**; the fix was
  to unroll as well and keep `(a0)+` only for the per-element test. **So: disassemble what GCC
  emitted BEFORE designing the asm** — if it already inlined and unrolled, you must beat
  straight-line code, and the headroom is small. Watch the prologue too: a 10-register `movem`
  costs ~180 cycles against GCC's 3-register ~68, which can exceed the whole win.
  ⚠⚠ **GCC UNDOES this rule when a loop walks 3+ pointers — and the exit test is the one-line fix.**
  ivopts strength-reduces N pointer IVs into ONE index register plus N invariant bases, so every
  access becomes `(0,An,Dn.L)`: **14 cycles of EA for a long against `(An)+`'s 8**, on top of losing
  the free increment. The full recipe, all three parts measured (RoF log §14/§15):
  1. **Exit test = a POINTER COMPARE against a precomputed end** (`do { … } while (p != pEnd);`).
     `for (int n = count; n--; )` invites the strength-reduction; the pointer compare forces one IV
     to be a real pointer and GCC then keeps them all. Band paint **170 → 121 cyc/long**.
  2. **Post-increment EVERY pointer.** Leaving one as `*p` with a separate `addq` cost **16
     cyc/long** — GCC emitted `move.l (a0),d0` plus two `addq.l #4` instead of two `(a0)+`.
  3. **Constant trip count ⇒ `#pragma GCC unroll N`**, which deletes the loop bookkeeping outright
     (`(d16,An)` displacement compares, no counter at all). Change-detect scan **70 → 46**.
  Also **split a fused loop that carries pointers only its RARE path needs** — the band's scan was
  maintaining a decode-loop bound on every unchanged long. Four wins in this tree have now turned on
  this one pathology, so **read the disassembly of any hot multi-pointer loop before assuming its
  cost is the work it does.**
- **Batch bulk clears/copies with `move.l` through a NON-VOLATILE alias** of `mem[]`
  (`uint8_t* M = (uint8_t*)mem;`). Casting away `volatile` lets the compiler emit 4-byte stores
  and a tight loop. SAFE only for buffers the ISR doesn't touch concurrently — the main loop
  owns the `$1010+` terrain field (verified the flight VBI never writes it); ZP and ISR-shared
  regions must stay `volatile`. `move.l` needs an even/4-aligned address (odd → 68000 address
  fault) — align first (see `zero_run`). ⚠ The win is from **`move.l` batching of SEQUENTIAL
  bytes**, NOT from dropping `volatile` per se. For SCATTERED single-byte access (e.g. the terrain
  rasterizer's per-column PLOT + Y-walked interpolation arrays) a non-volatile alias is a measured
  **no-op** — GCC already keeps the base in a register, so there is nothing to batch. Don't chase
  volatile-vs-non-volatile for scattered access; that whole class of "cheaper mem access" is
  exhausted there — the cost is instruction count / algorithm, not the `volatile` barrier.
  ⚠ **Endianness when aliasing `mem[]` as `uint16_t*`/`uint32_t*`:** `mem[]` is little-endian
  (6502: `mem[a]`=lo). The Amiga 68000 is **big-endian**, so a word/long read through such an
  alias returns the **byte-swapped** value — and worse, the SDL validation host is little-endian,
  so `make validate` passes GREEN while the Amiga silently renders garbage. So do NOT alias for
  general 16/32-bit values; lift them into `uint16_t`/`int16_t` LOCALS and touch `mem[]` byte-wise
  at the boundaries (`mem[a] | (mem[a+1]<<8)`), as the rasterizer/`MIDPOINT` twins do. The ONE
  safe alias case is a **uniform-byte broadcast** store (e.g. fill 4 lanes with the same byte via
  `grp = b*0x01010101u`, walk a `uint32_t*`): all bytes equal ⇒ endianness-neutral (identical on
  host + Amiga). Used for `terrain_draw_frame_core`'s `$BD00` column-id fill (commit ac3a9a8) —
  46 long stores; still needs the 4-aligned + ISR-untouched + non-overflowing-lane conditions.
  ⚠⚠ **GCC CAN SILENTLY UNDO THE BATCHING — always re-read the disassembly.** A uniform fill written
  as a plain `uint32_t*` loop is recognised as a **memset** and becomes `jsr memset`, and this build's
  freestanding memset (`support/gcc8_c_support.c`) is a byte-at-a-time `move.b d0,(a0)+`/`cmpa.l`/
  `bne` loop at ~24 cycles a byte — i.e. it hands every byte write straight back and the "batching"
  is worth nothing. Keeping the pointer **`volatile`** is what pins the long stores (commit 688069d,
  `terrain_draw_frame_core`'s `$264E..$26D1` fill). ⚠ But volatile is not a free win either: over a
  SHORT trip count with two interleaved volatile long pointers GCC emitted a redundant volatile READ
  before every byte store — measured on the adjacent `$67` fill and reverted. So: batch, then LOOK at
  what was emitted; the source saying `move.l` guarantees nothing.
  ⚠ Also worth knowing: **"odd address" can mean odd OFFSET, not odd address.** The four `$6B` runs
  at `$264E/$266F/$2690/$26B1` carried a comment saying they could not be batched because
  `$266F`/`$26B1` are odd — they are odd only as offsets from `$260E`; every actual address is even,
  which is all `move.l` needs on a 68000 (it faults on ODD, 4-alignment is a 68020+ perf matter). And
  those four `$21`-byte runs ABUT, so they are really one contiguous 132-byte fill = 33 longs.
- **Skip redundant work the original wasted.** Avoid re-decoding/-scanning what hasn't changed
  (per-writer dirty flags; dirty row/cell ranges, cf. planet viewport `g_planetRowLo/Hi` and the
  cockpit plan the RoF cockpit render plan). Shadow-compare scans are themselves a full
  volatile scan — a 68000 no-go; prefer dirty flags.
- **A transliterated loop's 6502 shape can BLIND GCC's loop analysis — that costs far more than the
  instructions it emits.** Two habits do it, and both look harmless: a loop counter/index typed
  `uint8_t` because the 6502 held it in a register (every use then pays an `andi.l #255` + a
  `moveq`/`move.b` zero-extend, and the wrap semantics hide the stride), and a `mem[]` round trip
  the 6502 needed to save a register across a `JSR` (which, being `volatile`, is an opaque write GCC
  must assume changes the index). Remove both and GCC can suddenly see a constant stride and a fixed
  trip count. On `terrain_draw_objects` (RoF log §11) that turned an un-analysable loop into a ×3 unroll
  with ONE exit test — amortising the loop tail 22 → 6 cycles a pair, the largest single component
  of the win. **So when a hot loop's index is a byte or round-trips through `mem[]`, fix that
  first and re-read the disassembly before designing anything cleverer.**
- **When the idiomatic-C twin is still hot, ESCALATE to hand-written m68k asm** (vasm). GCC won't
  emit `(a0)+`, has no scaled index, and spills under the register pressure these loops create — so
  the C floor is GCC's floor, not the algorithm's. In asm you control the regs (pin the working set,
  walk a private stack with `(a3)±3`), force the addressing, and shave every redundant insn
  (`movea` copies, `and.w #$FF` after a `sub.b` into an already-zero-extended reg, `moveq#0;move.b`
  → `move.l` of a clean reg). This beat the C on `terrain_column_rasterize_core` (~27%) where four C
  restructurings had all regressed. Verify with the in-process differential (see `docs/perf-method.md`),
  NOT cross-run. See the RoF asm-migration plan + its `TerrainRasterizeAssembler.s`.
- **⚠ NEVER emit a 32-bit software multiply/divide (`__mulsi3`/`__divsi3`/`__udivsi3`/`__modsi3`/
  `__umodsi3`).** The 68000 has NO 32-bit mul/div — GCC lowers any `uint32_t`/`int32_t` `*` / `/` / `%`
  into those slow (~200-600 cyc) software routines. It has only `MULU.W`/`MULS.W` (16×16→32) and
  `DIVU.W`/`DIVS.W` (32÷16→16q+16r). Use the helpers in **`src/m68k_math.h`** — `vette_mulu16`,
  `vette_divu16`, `vette_modu16`, `vette_muls16`, `vette_divs16`, `vette_mods16` (inline asm on Amiga, plain-C
  on a host build) — wherever a product's factors fit 16 bits and a quotient fits 16 bits
  (verify the ranges!). Techniques when a value looks 32-bit: fold constant factors with the exact
  identity `⌊n/(a·b)⌋ = ⌊⌊n/a⌋/b⌋` so the runtime divide shrinks to 16-bit (see `pokey_period`);
  reduce with `(a·b)%m = ((a%m)·(b%m))%m` (see `build_poly_dist`); replace a small-modulus wrap in a
  loop with compare-subtract (`if (x>=m) x-=m`); clamp an input so `2·x` stays <2^16. **Audit after
  any perf/math change:** `m68k-amiga-elf-objdump -d out/Vette.elf | grep -E '__(u?div|u?mod|mul)si3'`
  must be empty (bodies unreferenced → not even linked). In this port `amiga/Makefile` runs that
  audit on EVERY link (the `muldiv-audit` target), so a regression is caught the moment it is
  introduced rather than months later.

## ⚠⚠ `ROR`/`ROL` DO NOT AFFECT X — and BCD arithmetic needs X

`ABCD` / `SBCD` / `ADDX` / `SUBX` / `NEGX` take their carry-in from **X**, not C.  Getting a C
variable into X is therefore not `ror.b #1,<reg>`: **ROR and ROL leave X untouched.**  Only the
shifts (`ASL`/`ASR`/`LSL`/`LSR`) and `ROXL`/`ROXR` write it — and ROXR/ROXL also *read* X, so
they are the wrong tool for seeding it.  **Use `lsr.b #1,<reg>`** on a 0/1 byte.

Getting X back out: `moveq #0,<d>` then `addx.b <d>,<d>` — MOVEQ writes N/Z/V/C but **not** X,
so it can sit anywhere before the ADDX.

⚠ This class of bug assembles cleanly and disassembles to exactly the instructions you intended,
so an objdump review cannot catch it.  `src/cpu/bcd.h` shipped it briefly and it was found only
by an on-target sweep (`make BCDSELFTEST=1 PROBES=1`, 4500 add / 10000 sub failures out of
40000).  **Inline asm for this target is unverified until it has RUN on the target.**

## ⭐⭐ THE 68000 HAS EIGHT ADDRESS REGISTERS AND A HOT LOOP CAN EXHAUST THEM — read the objdump

The framebuffer decode's per-cell scan cost ~140 cycles of which only ~50 were the four longword
reads it exists to do. The rest was register pressure, and the objdump names it in two tells:

- **`tst.l <n>(sp)` / any `<n>(sp)` operand on a value that cannot change inside the loop.** Two of
  those (`tst.l 48(sp)` + `tst.l 52(sp)`, re-reading `shadowRow` and `rowDirty`) were **32 cycles a
  cell**, 23% of the loop, spent re-deciding something settled before it started. GCC did not hoist
  them because it had nowhere to hoist them TO.
- **Pointers living in `d` registers**, copied into `a0`/`a1` at the top of each iteration, plus a
  spill/reload of an `a` register around an inner call site. An address in a data register is not a
  style choice the compiler made; it is the allocator telling you it ran out.

⭐ **The fix is usually to SPLIT the loop, not to hand-optimise it.** Fusing "find what changed"
with "act on what changed" is what creates the pressure: each half needs its own set of pointers and
they are live simultaneously. Two passes over a small stack array (`uint8_t changed[40]`) each fit
in registers, and the array never leaves cache. 128 → ~80 cycles on the common path, and the second
pass unrolls cleanly because it no longer carries the first pass's induction variables.

⭐ **Three companion tricks from the same rewrite:**
- **`#pragma GCC unroll N` works on this toolchain (GCC 15.1.0), and -O3 will NOT unroll a
  constant-trip-count 8-iteration loop unasked.** Do not assume a small fixed loop is already flat —
  check, then ask for it. Unrolling also turns indexed `(0,a4,a0.l)` addressing into constant
  displacements off one base.
- **`__builtin_expect` on the *condition*, spelled as the mismatch, not the match.** Written as
  `if (clean) continue;` GCC hoisted the second compare out of line and routed the COMMON case
  through two taken `beq.w`. Written `if (__builtin_expect(a != b || c != d, 0))` the common case
  falls straight through. Same semantics, ~8% of the loop.
- **A test that is invariant across the inner loop belongs in a specialisation, not in the loop.**
  Classifying a row once and dispatching a 3-arm switch into `always_inline` variants deletes a
  per-line `mode[]` test from ~17 of 19 rows — the general form of the `always_inline` rule already
  in this file, applied to a *predicate* rather than to a descriptor pointer.

⚠ Converting a cycle count into a predicted millisecond figure on this target needs a **contention
factor of ~1.6** (measured: 30 µs for a ~140-cycle cell at 7.09 MHz), and it applies to instruction
fetch as much as to data. With it the prediction here landed within 15% of the measurement.

## ⚠⚠ MAKING A FUNCTION SMALLER CAN MAKE IT SLOWER — GCC's inlining threshold is part of the change

Measured on the span rasteriser, 2026-09-13, and it is a **1.4-percentage-point swing from one
inlining decision**:

`span_entry_decode(const SpanArm *arm, ...)` searched three `static const uint8_t[8]` tables to
turn a patched entry offset into a column index. Replacing the two linear scans with `switch`
statements deleted ~300 cycles of `move.b <abs.l>` table reads per span — and **measured −0.6%**.
The cause was in the objdump: the smaller body dropped under GCC's inlining threshold, so the
routine that had been *inlined into all four arm specialisations* became **one shared out-of-line
copy** — and a shared copy has to take `arm` as a **pointer** again, which puts `arm->steep` back
in memory and adds a five-argument call per span. The same switch with
`inline __attribute__((always_inline))` measured **+0.8%**.

⭐⭐ **The rule: when a hot routine is fast BECAUSE it is specialised, its `always_inline` is part of
its correctness-for-speed, and any edit that changes its size can silently revoke it.** Pin it
explicitly rather than relying on the size heuristic, and **re-read the call list in the objdump
after the edit** (`jsr <name>` appearing where there were none is the whole tell).

⭐ And the sibling half of the descriptor rule, from the same pass: **`always_inline` on the LEAF
does not fold a descriptor — the SELECTION has to be specialised too.** `span_plot_core` was
`always_inline` exactly so `SPAN_PLOT_1`/`SPAN_PLOT_2`'s fields would become immediates, but its
caller picked `usePlot2 ? &SPAN_PLOT_2 : &SPAN_PLOT_1`, so the descriptor was a runtime value
*inside* the inlined leaf and the objdump read `lea SPAN_PLOT_2,a2` / `move.l (a2),d2` /
`move.l 8(a2),d3`. Two `noinline` twins, one per descriptor, is the fix — `noinline` deliberately,
because the leaf is ~370 instructions and there are twenty call sites.

### ⚠⚠ THE SIBLING CASE: INLINING A BODY **TWICE** EVICTS THE HOT LEAF'S OWN INLINE (2026-09-13)

Same threshold, opposite direction, and worth **4.3 ms/frame** on the dash-edge walk. Serving two
configurations from one source body — `VETTE_FLAG_OP void gap_walk_body(int reread, ...)` with
`reread` a compile-time constant at both call sites — inlined the whole loop *twice* into
`column_gap_walk_core`. That doubled the function, and the casualty was not the body: it pushed
`surface_colour_at_core`, the six-arm classifier **every empty cell calls**, back out of line.
Each call then cost four `move.l dN,-(sp)` argument pushes, a `lea 85(sp),a0` for the hidden
struct-return pointer, a `lea 16(sp),sp` cleanup and an `rts`, and GCC unrolled the walk ×4-×7
around it. Phase 18 went **17.13 → 21.46 ms/frame**.

The objdump is unambiguous and is the only thing that was: `jsr <surface_colour_at_core>` — **0**
at HEAD, **10** in the regressing build, **7** in the intermediate two-copy shapes.

⭐⭐ **The fix is structural, and all three parts are load-bearing:** one source body, the cold
instance in its own `static __attribute__((noinline))` wrapper so the hot function stays
HEAD-sized, and `always_inline` **pinned** on the leaf. Result: 0 `jsr`, and phase 18 at
**10.40 ms**.

⚠ **The diagnosis I reached first was wrong, and the shape of the error is worth more than the
fix.** "More hoisted values than there are registers" is the intuitive story, it is consistent with
a hoist regressing, and it is **retracted** — the hot loop's stack references had gone *down*, not
up. A plausible cycle-accounting story is not evidence. ⭐ **When a size-changing edit regresses,
count the `jsr`s to the hot leaves BEFORE reasoning about register pressure** — it is one grep, and
it is the same trap CLAUDE.md already documents as `jsr <sub_from>` with a different callee.

⚠⚠ **And the framing error that sent this pass at the wrong target: divide by the right
denominator.** "24 ms in the span walk / 49 DDA scan lines = ~3 500 cycles per scan line" made the
walk's inner loop look catastrophic. The honest denominator was **43 spans**, and the weight was in
per-span setup, not per-line work. **Before optimising a loop, check how many times it actually
runs** — `docs/perf-method.md` §the span kernel's call and search surface.

### ⭐ THE THIRD CASE: A BOUNDED LOOP OVER A SHORT LIST IS WHAT PUSHES A BODY OVER THE THRESHOLD (2026-09-13)

Worth **0.8 ms/frame** in the view sweep, and the diagnosis runs the opposite way round from the
two above: the inlining decision was the *symptom*, and a loop bound was the cause.

The sweep tracks which of the forty unit stores have had an `RTS` planted over them in
`g_viewStopList[41]` — a list that **normally holds one entry and is empty through all of phase
1**. `view_stop_from` already scanned it sentinel-style, with a comment explaining that spelling
the bound as `i < g_viewStopN` makes gcc peel the trip count and unroll the search eight ways.
Its two siblings, `view_stop_note` and `view_stop_forget`, still carried the bound — and gcc had
done exactly that to both, plus to both shift loops. Four unrolled loops over a one-entry list
made `view_plant` a **348-instruction** body, which put it over the inlining threshold, so every
one of the sweep's **25 plants** paid a **five-argument out-of-line call**.

Rewriting all three walks to terminate on the 40 the list already carries — the end becomes
POSITIONAL and the count is retired — took `view_plant` to **108** instructions and
`view_paint_lines_core` to 757 from 877. Phase 3's bracket 24.49 → 23.76 ms, the frame
179.33 → 178.49, with phase 1's bracket flat (15.83 → 15.81) as the built-in control: phase 1
plants nothing, so it must not move.

⭐⭐ **The rule: before reaching for an inlining attribute, ask what made the body big.** A short
list with an explicit count is the recurring answer on this target, because the trip-count peel
is unconditional and its cost scales with the list's *declared* bound, not its real length.

⚠⚠ **And then `always_inline` on the same routine measured WORSE — this is the exception to the
constant-parameter rule.** `view_plant`'s last two arguments are literals at every call site
(`page` 0x7C or 0x7E, `opcode` STA (zp),Y or RTS) and folding them does everything the rule
predicts: `view_low_page(page)` becomes true, `g_viewSlotOf`'s row a constant base, the
`opcode == OP_STA_IND_Y` test that picks note-vs-forget collapses to **one** list walk, and the
inlined body lands at ~30 instructions rather than 108. It still cost **+1.04 ms/frame** (phase 3
+1.18); with the two list walks additionally forced `noinline`, so the inlined body is ~20
instructions, **+1.01** (phase 3 +1.44). Phase 2's bracket gained both times (−0.26 / −0.20) and
phase 3's lost more, which is the whole story: the core grows 757 → **995** instructions and
`paint_lines_short`'s per-line loop is already at the register ceiling. **The constant-parameter
rule holds for a leaf in an inner loop; it does not hold for a caller that has run out of
registers.** Do not re-try it — the record is written at the code.

### ⚠⚠⚠ THE FOURTH CASE, AND THE WORST: GROWING A SHARED `always_inline` LEAF RE-DECIDES EVERY CALLER (2026-09-14)

The three cases above are all about **one** function's own size. This one is collateral, it hits
functions the edit never mentions, and it was misdiagnosed for a whole session as *"adding ~300
instructions to `the prior port's native TU` moved GCC's per-TU inline-growth budget and re-decided the whole
file"* — **a story that is now disproven in both of its parts.**

`view_mark_source` (`the prior port's native seam header`) is a `VETTE_FLAG_OP` — i.e. `always_inline` — and
it is called from `seam_write`, **the port's universal store choke point**, which is itself an
`always_inline` function in a header. So the leaf is inlined into every writer in the tree.
Defining `VETTE_VIEWEVT` adds one mask read-modify-write to it: two shifts, an `and`, a `lea` and a
byte `or` to memory. That is ~6 instructions in the source and **104 inlined copies across 14
functions** in the binary — and **13 of the 17 functions whose size changed are exactly those 14.**
The worst casualty was nowhere near the edit: `column_gap_walk_core` went 1176 → 1029 instructions
and **lost the 4× unroll** that §a fragile local optimum had already measured at 1.38 ms.

⚠ **Both of the plausible fixes are dead, and neither was ever going to work:**
- `--param inline-unit-growth=400` plus enormous `large-function-growth` / `large-function-insns`
  caps produced **byte-identical output**. It is not a budget effect; it is 104 real copies of real
  instructions, each of which legitimately changes its host's size and register pressure.
- **Splitting the translation unit cannot help either** — an `always_inline` leaf in a *header* is
  present in every TU that includes it, so the copies follow the callers wherever they are put.

⭐⭐⭐ **The rule: before growing an `always_inline` leaf, count its call sites — the edit is
multiplied by that number, and the cost lands in the callers, not in the leaf.** A universal
choke point (`seam_write` here) is the one place on this target where a six-instruction change is
a thousand-instruction change. ⭐ **The diagnostic, when an unrelated function slows down after an
edit:** dump per-function sizes from both objdumps, diff them, and intersect the movers with the
call sites of whatever leaf the edit touched. A 13-of-17 intersection settles it in one pass, and
it is the only way to tell this apart from a genuine whole-file budget effect — which looks
identical from the phase table.

⭐ **The design fix is to not use the choke point at all.** A catch-all hook on every store is
convenient and structurally wrong: mark at the handful of explicit producer sites (there are
seven) and the leaf stays empty for the other 104.

## ⭐⭐ HAND-UNROLL: `#pragma GCC unroll N` IS IGNORED, AND THE WIN IS THE ADDRESSING (2026-09-13)

m68k-amiga-elf-gcc 15.1.0 at `-O2` **ignores `#pragma GCC unroll 4`** — byte-identical output, 282
instructions either way. Unroll by hand (a file-scope macro taking the unit's byte offsets, so the
loop's own locals stay visible to it).

What the unroll actually buys, measured on `view_paint_lines`' unit loop — a byte load 128 apart,
a test, a byte store 8 apart:

| | cycles/unit |
|---|---|
| one unit a turn | 64 |
| …with the loop rotated store-first (gcc's own shape) | 72 |
| **4 units a turn** | **43** |
| remainder loop (recovers a conditional back edge) | 56 |

Two mechanisms, both about addressing rather than about the branch:
- three of the four units reach memory through a **`d16(An)` displacement (4 cycles)** instead of a
  pointer bump (`addq`/`lea`, 8);
- one back edge serves four units.

⭐ Choose the factor against the RUN-LENGTH DISTRIBUTION, not by taste: runs averaged ~17.7 units,
so a quad loop keeps four full turns and leaves a short remainder. An 8-way computes to ~41
cycles/unit — 2 better — and would spend more of the run in the one-at-a-time tail.

⭐⭐ **282 -> 785 instructions cost nothing: the 68000 has no instruction cache**, so cold arms of
the unrolled body are never fetched. The only real cost is branch distance — three `bne.s` (8
cycles not-taken) became `bne.w` (12).

## ⚠⚠ GCC'S LOOP ROTATION IS NOT REACHABLE FROM THE SOURCE — CHECK THE BACK-EDGE MNEMONIC

A plain `while`, a guarded `do`/`while` and an explicit down-counter all produced the **identical**
store-first shape, and the down-counter was strength-reduced back into a pointer compare. GCC
rotates such a loop so the store leads and closes it with an unconditional `bra`, which is ~8
cycles a unit of pure book-keeping. You cannot ask for the other shape; you can only unroll so the
book-keeping is amortised.

⭐ So the objdump check on a hot loop is **the back-edge mnemonic**, not only the absence of a
`jsr`: a conditional back edge (`bne.s`, 10 taken) is the good shape; a `bra` at the bottom plus a
`beq` out of the middle is the rotated one, and it is costing you the difference.
