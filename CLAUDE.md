# Vette! — Macintosh 68000 → Amiga port

Porting Spectrum HoloByte's 1989 Macintosh driving simulation *Vette!* to the Amiga from the Mac
application. ⭐ **The code is already 68000 and can stay 68000** — this is a port of the *seams*
(OS/Toolbox calls, display, input, sound), not a translation across processor families like the
three 6502 ports before it. **Faithful 1:1 port** — parity before improvements; validate against
the original under a Macintosh emulator, **NEVER** against the dev-host backend.

⚠⚠ **THIS FILE CARRIES STANDING RULES ONLY — IT IS NOT A LOG.** It is re-read in full on every turn
of every session, so nothing dated, no measurement history, no "X now works" achievement notes: a
*rule* or a *pointer*, or it belongs in `docs/`. When something is learned, write it in the matching
`docs/` file and, if it changes how to work, add or amend one line here. The same discipline governs
`docs/rename.md` and `docs/open-work.md` (queues, never logs).

⚠⚠ **NOTHING IN THIS REPO HAS BEEN BUILT OR RUN.** The structure, the vendored framework, the
inherited docs and the FS-UAE scripts are in place; there is no port code, no disassembly, and the
source archive has not been opened. **Do not read an inherited doc's confident present tense as a
description of this repo** — every ⚑ doc describes the prior ports.

> **This project is the third run at a process that worked twice, and the FIRST of a new kind.**
> *Rescue on Fractalus!* (`~/Documents/Rescue on Fractalus`, Atari 8-bit) and *Revs*
> (`~/Documents/Revs`, BBC Micro) both converted 6502 to C to 68000. **This one does not**, and
> `PROJECT.md` §Why this project exists says what that changes. It is a **pilot for a series of
> Mac 68k ports**.
>
> **Read `docs/postmortem.md` early** — it is RoF's retrospective, ordered by leverage, and its
> closing section maps each finding onto *this* kind of port (three survive, two are retired).
> One sentence: *build the discovery and validation infrastructure exhaustively up front instead of
> growing it reactively.*
>
> Everything in `docs/` marked ⚑ is inherited — measured on the same target with the same
> toolchain, so it applies unchanged. **Don't soften an inherited rule without a measurement that
> contradicts it, and don't re-derive one from scratch either.**

## ⭐ The four things that must happen in order

Doing these out of order is the known-expensive failure mode, so they gate each other.

| # | Gate | Doc |
|---|---|---|
| 1 | **The Macintosh reference loop is built and DRIVES** | `docs/mac-reference-loop.md` |
| 2 | **Exhaustive entry-point + trap sweep** before a line of port code is written against the binary | `docs/toolchain.md` |
| 3 | **The seam rule is written down** before the first routine is converted | `docs/faithfulness-seam.md` |
| 4 | **Profile an end-to-end skeleton on the real A500** before choosing what to optimise, and before setting any target | `docs/perf-method.md` |

## Getting from the archive to the segments

Three layers, two of them needing our own code because the host reads neither. `docs/toolchain.md`
has the detail; the commands are:

```
unar -o tmp/unpacked tmp/VETTE__1.02_and_extras.sit        # StuffIt 5  (brew install unar)
python3 tools/ndif2raw.py "tmp/unpacked/.../VETTE!.img" tmp/VETTE_1_02.raw
python3 tools/hfs_extract.py tmp/VETTE_1_02.raw list
python3 tools/hfs_extract.py tmp/VETTE_1_02.raw segments "<path>/VETTE!" tmp/seg_bw
```

⚠⚠ **`VETTE!.img` is an NDIF image and its block map is in the RESOURCE FORK** (`bcem` 128). A copy
of that file that lost its fork — moved through a non-HFS filesystem, a zip, an email — **cannot be
converted at all**, and the loss is invisible because the data fork alone still looks like a disk
image and its first 7 sectors even parse as a valid HFS volume header. Keep the fork.

⚠ **Do not gate anything on the checksum `bcem` records.** `vers` calls it a CRC, the algorithm is
unidentified, and the recorded value reproduces under none of the obvious candidates — so a
mismatch is **not** a corruption signal here. Validate structurally with `hfs_extract.py` instead;
`tools/ndif2raw.py`'s docstring says why that is the stronger proof.

⭐ **There are TWO applications on the volume, B&W and Color, and they are different builds** — not
one binary with a flag. ⭐⭐ **This port follows `Color VETTE!`** (decision locked, `PROJECT.md`).
Extract, import and name **that** build: an address is `(segment, offset)` *in one specific build*,
and the two builds' segments differ in size, so a B&W offset is simply wrong here.

⭐ **The copy protection is patched out, not reproduced** — the single deliberate, documented
departure from 1:1. ⚠ Find the check before defeating it (`COPY 1 "Protect"` is 1 991 B, more than
a password list needs, so it may gate more than the prompt). Rules:
`docs/faithfulness-seam.md` §The copy protection.

## The source material

⚠⚠ **`tmp/` IS LOCAL ONLY, ALWAYS** (user instruction). Never commit anything from it.

The game is copyrighted and is not ours to distribute, nor is anything derived from it byte for
byte. `.gitignore` is deliberately broad, because **a Mac application arrives in more shapes than a
disc image**: `.sit` → MacBinary/BinHex → a data fork **plus a resource fork**, and on a non-HFS
filesystem that resource fork is an **AppleDouble `._Vette` sidecar** — which looks like macOS noise
and *is the executable code*. That is the accident the rules exist to prevent.

## ⚠ Three things that make a Mac binary different, and they change what "an address" means

Read these before any disassembly work; `docs/toolchain.md` has the verified detail.

1. **The code is in numbered `CODE` resources, one per segment** — not one flat image. The flat
   memory image both prior ports disassembled **does not exist**, and an address is
   `(segment, offset)`. Every address in `symbols.csv` and in the docs must say which segment.
   ⭐ All 11 are **near model**, so there is **nothing to relocate** — internal references are
   PC-relative, globals A5-relative, inter-segment calls go through the jump table. Never write
   relocation code for these; if you think you need it, re-read the segment header.
2. **`CODE 0` is the jump table**, and every inter-segment call goes through it. ⭐ This makes the
   postmortem's highest-leverage item — the exhaustive dispatch sweep — **enumerable** rather than a
   search. Take the win.
3. **Application globals are A5-relative.** `-nnnn(a5)` is the game's own global; `$0000-$0BFF` is
   the system's low memory. ⚠ **The sweep must look for absolute low-memory references as well as
   for traps**, or a whole class of hardware access is invisible.

⭐⭐ **And the fourth: every OS/Toolbox call is an A-line (`$Axxx`) trap, and that surface IS the
project.** RoF replaced the Atari OS wholesale; Revs serviced a closed MOS surface of 4 entries at
17 sites. A Mac game reaches QuickDraw, the Event Manager, the Memory Manager, the Resource Manager,
the Segment Loader and the Sound Manager. **Inventory it from the binary before estimating
anything, and treat the inventory as a FLOOR** — Revs's looked closed after a static sweep and three
more calls were found by *running* it.

⚠ **Ghidra 12.1 has no classic-Mac resource-fork loader** (verified against this install: 68000
processor yes, HFS+ for iOS only). Extract the `CODE` resources with `tools/hfs_extract.py segments`
and import each as a raw binary, `68000:BE:32:default`. `docs/toolchain.md`.

⭐ **The segments carry their original names** (`Main`, `Initialize`, `Communication`, `load`,
`Score`, `Traffic`, `FRED`, `Intro`, `sound`, `%A5Init`) — free, authored structure of the kind
`docs/rename.md` exists to recover by hand. Treat a name as `[INFERRED]` evidence about a segment's
contents, not as proof.

## ⭐⭐ The port strategy is decided: **keep the original instructions** (option A)

The original `CODE` segments are placed, linked and executed as-is; the port supplies the *seams*.
Option B (port-authored reimplementation of a routine) is the **exception** and needs a stated
reason from `docs/faithfulness-seam.md` #2. Consequences that are rules, not notes:

- ⚠⚠ **The trap layer must honour DOCUMENTED Toolbox semantics, because A removes the freedom to
  reinterpret.** Memory Manager handles **move**; QuickDraw has a stateful current port; the
  Resource Manager is how the game reads all of its data. Implement what Inside Macintosh says, not
  what the call appears to want.
- ⚠ **`%A5Init` runs, or is replaced by exactly what it produces.** It initialises the game's
  31 272 B of A5-relative globals. Skipping it zeroes them — a silent wrong-value failure.
- **The A5 world is fixed and known:** 31 272 B of globals below `a5`; above it 32 B + a 4 072 B
  jump table of **509 entries** at A5+32, all shipped in unloaded form. Pre-patch them to
  `JMP abs.l` at startup and `_LoadSeg` never needs servicing.
- ⭐ **The 509 entries are a CLOSED set** (per-segment counts sum to exactly 509), so the dispatch
  sweep is an enumeration. `FRED` alone exports 242 of them.
- **Carried-over code is opaque** — unnameable, unprofilable at source level, unoptimisable. That is
  the accepted price; `disasm/symbols.csv` and the jump table are the whole map.

## Build / run / debug

⚠ None of this is verified in this repo yet. Phase 0 (`docs/phases.md`).

### Host — from repo root
```
make                       # build/vette — scope is an OPEN DECISION (PROJECT.md #5)
make todo                  # ⭐⭐ WHAT IS OPEN: docs/open-work.md's queue + a live marker sweep
```

### Amiga cross-build (m68k-amiga-elf-gcc) — from `amiga/`
```
. env.sh        # put the ~/.local Amiga toolchain on PATH (SOURCE it, in the SAME shell command)
make            # out/Vette.exe (+ Vette.elf; runs the muldiv + probe audits on every link)
./run.sh        # boot in FS-UAE (Kickstart 3.1; CTRL + left mouse button quits)
./debug.sh      # source-level debug via the FS-UAE GDB stub (prints its $DEBUG_PORT)
./diag_run.sh N # headless probe run for N seconds (needs a PROBES=1 build)
EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=x.gdb ./diag_run.sh 60   # ⭐⭐ ~4.9x faster, same numbers
```

⭐⭐ **Put `EXTRA_ARGS="--warp_mode=1"` on every probe run.** FS-UAE runs ~4.9× faster than real time
and it changes **no** measurement of the kind this project takes, because they are ratios of
*emulated* quantities.

### Macintosh reference (MAME) — from repo root
```
timeout -k 5 240 env SDL_VIDEODRIVER=dummy mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
  -hard ref/mame/hd/608_2GB_drive.hd -video none -sound none -window -skip_gameinfo \
  -nothrottle -seconds_to_run N -snapshot_directory ref/mame/snap -autoboot_script tools/mame_snap.lua
```
⚠⚠ **`/ref/` is LOCAL ONLY, like `tmp/`** — ROMs, System/game images, MAME state, captures. Never
commit it. ⭐ Put files on the Mac volume from the host with `hfsutils`
(`hmount …608_2GB_drive.hd 1`, `hcopy -m` to keep BOTH forks) — not with floppy images.

⚠⚠ **MAME must be run with the headless recipe in `docs/mac-reference-loop.md`, never bare.**
`-video none` alone still opens a **FULLSCREEN window** on macOS and hijacks the user's screen;
`SDL_VIDEODRIVER=dummy` + `-window` + `-skip_gameinfo` + an external `timeout` is the verified form.
⚠ Same pid-scoped-kill rule as FS-UAE below — kill only the pid you started.

⚠⚠ **Never `pkill fs-uae` / `pkill gdb`** — several Amiga projects run their own emulator at once.
The scripts source `~/.local/share/amiga/fsuae_common.sh` (shared, outside every repo;
`$FSUAE_COMMON` overrides), which kills only the pid in this directory's `.run/fsuae.pid` and gives
each project its own gdb-stub `$DEBUG_PORT`. Stop a stranger's emulator by pid, or not at all.
A killed run reads exactly like your build crashing — `docs/headless-fsuae.md`.

⚠ **`make clean` before any `PROBES=1` build and after editing a widely-included header.** The
Amiga Makefile tracks neither, so a partial rebuild links stale objects into a
**working-but-wrong** binary. Treat any unexplained regression right after a header edit or a
`PROBES` toggle as a stale build first.

⚠⚠ **Every global a committed `.gdb` script reads must be listed in `PROBE_SYMS`
(`amiga/Makefile`).** `--gc-sections` drops an unreferenced counter and gdb then prints
**instruction bytes as a value** — a fake measurement, not an obvious zero.
`make probe-audit` runs on every link. (`__attribute__((retain))` is ignored on this target.)

## Reference docs — READ ON DEMAND (this file stays small on purpose)

Hard-won detail lives in `docs/`, not here. **Read the relevant one BEFORE working in its area.**
⚑ = inherited from the prior ports.

| Doc | Read it when |
|---|---|
| **`docs/open-work.md`** ⭐⭐ | **"What is next?" — THE QUEUE.** Ranked open items with their gates, plus ⛔ one line per measured dead end |
| **`docs/postmortem.md`** ⚑ | **Early, once, in full.** The retrospective this pipeline is built on, and how it maps onto a Mac 68k port |
| `docs/phases.md` | The gating between phases, and what each phase owes |
| **`docs/faithfulness-seam.md`** ⭐ | **Before converting, rewriting or reimplementing ANY routine.** The three-way choice this port has and the prior ports did not |
| **`docs/source-inventory.md`** ⭐⭐ | **What is actually in the shipped game** — the 11 named `CODE` segments, the 23 data types, the 160 objects. Read it before estimating anything |
| **`docs/mac-reference-loop.md`** ⭐ | Anything about ground truth, or before trusting a claim about what the original does |
| **`docs/mac-hardware.md`** | Touching the trap layer, the display, input or sound. ⚠ Mostly `[ASSUMED]` — replace rows, don't build on them |
| `docs/toolchain.md` | Running the pipeline: resource/segment tools, Ghidra headless, the builds |
| `docs/perf-method.md` ⚑ | Quoting, sizing or judging ANY performance number |
| `docs/m68k-optimisation.md` ⚑ | Optimising a hot function or writing an asm twin (68000 rules) |
| `docs/amiga-lessons.md` ⚑ | Copper lists, sprites, the VBI, write-only registers |
| `docs/amiga-arch.md` ⚑ | The Amiga display/interrupt architecture decisions and why |
| `docs/headless-fsuae.md` ⚑ | Writing a probe, driving FS-UAE headlessly, or suspecting a stale build |
| `docs/method-lessons.md` ⚑ | How to work: measuring, bisecting, proving a change, recording findings |
| `docs/rename.md` | A name contradicts behaviour, or you need a name that does not exist yet |

## Hard rules (violating these costs a day)

- **Ground truth is the ORIGINAL under a Macintosh emulator.** Never the dev-host backend, never the
  Amiga build, never reasoning. `docs/mac-reference-loop.md`.
- ⭐⭐ **A SEAM MUST HAND OVER EVERY REGISTER THE ORIGINAL HAS LIVE THERE, and the set is derived
  from the SURROUNDING INSTRUCTIONS, never from what the callee happens to read.** On 68000 code that
  includes `d0-d7`/`a0-a6`, the condition codes, and the `a5`/`a7` invariants. ⚠ The recurring shape
  of this defect is a *stale* register: a routine that indexes off it does not fail, it addresses a
  neighbouring structure and computes something plausible.
- ⭐⭐ **When a translation cannot represent something, make the gap LOUD at the earliest point that
  can name it.** A silent no-op is the most expensive translation choice — it looks exactly like
  working code, and the failure surfaces far from its cause. An unknown trap gets reported with a
  name, never absorbed. (There is one such no-op in this tree already:
  `src/platform/amiga/framework/BitmapAssembler.s`'s two non-interleaved arms, inherited and
  retagged `[ASSUMED]`.)
- **Mark assumptions as assumptions** — `[ASSUMED]` / `[DERIVED]` / `[INFERRED]`, in `symbols.csv`
  notes and docs alike. The postmortem's failure mode is an assumption calcifying into a documented
  fact; a measurement replaces the tag. ⚠ **A hedge is not a control**: writing "this might be
  broken" next to a number does not license quoting the number.
- **NEVER emit a 32-bit software mul/div** (`__mulsi3`/`__divsi3`/`__udivsi3`/`__modsi3`/
  `__umodsi3`) — the 68000 has none. Use `src/m68k_math.h`'s 16-bit helpers. `amiga/Makefile` audits
  every link (`muldiv-audit`); keep it clean.
- **RAM is uniformly slow — there is no "fast RAM" on the target A500.** Optimise by reducing the
  NUMBER of accesses, never by moving data to a "cheaper" buffer, and never explain a measurement
  with fast-vs-chip RAM. It is a 68020-era distinction. (`docs/m68k-optimisation.md`)
- **Copper bitplane POINTER swaps happen in the VBI ISR, never mid-frame** — a torn pointer garbages
  the whole viewport for a frame. Colour-only pokes mid-frame are tolerable; `SPRxPT` operands are
  stricter still (the copper reads them at scanline 16).
  ⚠⚠ **"In the VBI ISR" ≠ "in the vblank":** anything after the handler's own work lands 100+
  scanlines into the display. **The copper work goes FIRST.** A rebuilt copper `WAIT` behind the
  beam blocks the copper for the whole field, and no frame-boundary dump can see it.
  (`docs/amiga-lessons.md`)
- **Work in the vblank ISR is capped at ONE FRAME.** Over that you silently drop a displayed frame,
  and the dropped frame is what the player reports — not the cost.
- ⭐ **If the original ran its periodic body once per DRAWN frame and the port draws far slower, the
  body must NOT run in the port's vblank ISR** — it will run many times per painted frame and the
  renderer will be drawing a scene that changes under it. Drive it from main-loop context where the
  game is provably not drawing. (`docs/amiga-arch.md` — Revs measured this one the hard way.)

## Working conventions

- ⭐⭐ **"What is next?" is answered by `docs/open-work.md` + `make todo`, never by a session
  summary** (which only remembers what that session touched). It is a QUEUE like `docs/rename.md`:
  an entry is **DELETED** in the commit that closes it, and what the work taught goes in the doc
  that was wrong. ⛔ Its CLOSED section is one line per measured dead end — read it before proposing
  a lever, so a negative result is not re-derived.
- **Commit directly to `main`** (no feature branches). Commit each fix as soon as it is confirmed to
  work — one logical change per commit.
- ⚠ **Git conventions for this repo** (user instruction): no commit signing, no `Co-Authored-By`
  lines, no git hooks, the `Vesuri` GitHub account and the `vesuri@jormas.com` identity. All set in
  `.git/config`; don't add a global-config behaviour back in.
- **Misnamed or unnamed things:** whenever a function, table or global contradicts its name — or has
  none and you are about to reason about it — append it to `docs/rename.md` immediately. Do not
  rename piecemeal; `disasm/symbols.csv` is the source of truth and `ApplyNames.java` applies it.
  **On a binary-only project the names are your map.** ⭐ Apply the queue as part of the work, not
  when asked — renaming is cheap right up to the moment hand-written code references the name, and
  never again.
- **Newly-found dispatch targets / trap-dispatched routines:** add them to
  `ghidra_scripts/entrypoints.csv` the moment you find one. Record it immediately; don't defer.
- **Keep this file small, and keep it a rulebook.** New hard-won detail goes in the matching `docs/`
  file (add a row to the index above if it is a new one). Nothing dated, nothing celebratory, no
  measurement history here.
- **No redundant waiter shells** — backgrounded tasks self-notify.
- Ask the user at genuine decision points (they're an experienced retro-porter and want to steer
  architecture and scope choices).
