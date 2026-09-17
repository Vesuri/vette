# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — nothing else can start

1. ⭐⭐ **Log every A-line trap the game executes, launch → intro screen, in order.** Option A runs
   the original code, so *the set of traps the game executes IS the port's work list* — and it is a
   measurement, not an estimate. Nothing below #1 should be implemented before this exists, because
   it decides both the order and the size of the trap layer.

   ⭐ **Do it by tapping the 68000's Line-A exception vector, not with MacsBug.** Vector 10 (`$28`)
   is the Line 1010 emulator; every `$Axxx` trap goes through the ROM handler it points at. A MAME
   breakpoint there — Lua `cpu:debug():bpset()`, or the m68k gdb stub — yields the trap word, the
   caller's PC and the call order, which is strictly more than MacsBug's log and needs no input at
   all. ⚠⚠ **This supersedes the MacsBug route, which was blocked on a real problem** (synthesising
   the programmer's-switch NMI), and MacsBug's `atb`/`atheap` would have given a less precise
   answer for more work. MacsBug stays installed and harmless.
   ⚠ **The caller's PC must be resolved to `(segment, offset)`**, not printed raw: segments are
   relocated into the heap at load time, so a bare address names nothing. Read the jump table.
   → `docs/mac-reference-loop.md`.

   ⚠ **Capability check first, cheaply:** breakpoints + register reads have never been exercised on
   this driver (`docs/phases.md` Phase 1). Prove `bpset` fires once before building a tracer on it.

   ⏸ **The copy-protection password is DEFERRED** (user decision: revisit when it becomes
   relevant). It has not blocked anything — the game reached the garage screen without ever asking,
   so either this copy is already registered or the check fires deeper in. ⚠ Do not record "there
   is no password" as a finding: `readme.txt` says there is one, and the two readings have not been
   separated. The answers are in `tmp/unpacked/…/scans/Manual.pdf` when it is time. ⚠ Ground truth
   runs the **unpatched** original; the patch item below is port-side only and does not retire this.

## ⭐⭐ The road to the intro screen on the Amiga — the CURRENT GOAL

⚠⚠ **Read the honesty rule before starting any of these: each stage states what it PROVES, and a
stage that shows the right picture for the wrong reason is a failure, not a milestone.** Displaying
a converted Mac screenshot is a display-path proof and nothing more — it must never be reported as
"the intro screen works".

2. ⭐ **Stage A — the display path, with a captured frame.** Amiga skeleton in the locked mode
   (4 bitplanes, hires **interlaced**), a copper list, VERTB, the frame pump, and a host-side
   converter that turns a `tools/mac_probe_fb.lua` dump into planar bitplanes + a palette derived
   from the **displayed** colour (the gamma table, `docs/mac-hardware.md`).
   **Proves:** the screen mode, geometry, plane order, nibble order and palette — and it builds the
   pixel differential that every later stage is judged by. **Does NOT prove:** anything about the
   game. ⭐ Also satisfies most of Phase 0's exit criteria, so it is not a detour.
3. ⭐⭐ **Stage B — the loader: the game's own code executes on the Amiga.** Place all 11 `CODE`
   segments resident, build the A5 world (31 272 B below `a5`; 32 B + the 4 072 B / 509-entry jump
   table above), pre-patch every entry from unloaded form to `JMP abs.l`, run `%A5Init`, install our
   own Line-A handler on vector `$28`, and jump to the entry point.
   **Pass criterion:** the game runs and **halts on its first unimplemented trap, naming it** —
   manager, routine, selector, and the `(segment, offset)` of the caller. ⚠⚠ That loud stop *is* the
   deliverable; a build that runs on past an unknown trap is the silent-no-op failure this project's
   hard rules exist to prevent.
   ⚠ The resources have to reach the Amiga too — the Resource Manager is how the game reads all of
   its data, so a host-side resource-fork → Amiga-readable converter is part of this stage.
4. **Stage C — the trap layer, in the order #1 measured.** Implement first-use-first, re-running
   after each one; progress is countable ("N traps deep, halted at *M*"). Expect Memory Manager,
   Resource Manager, QuickDraw init/ports, `NewGWorld`/`LockPixels`, and the Event Manager.
   ⚠ **Honour documented Inside Macintosh semantics, not what the call appears to want** — handles
   move, QuickDraw has a stateful current port (`CLAUDE.md`).
5. ⚠ **Stage D — `DrawPicture`, and it is the one with an unknown floor.** The intro is
   PICT-driven, so this is a **PICT opcode interpreter**, not a call to wire up. Size it from #1's
   log (which opcodes the intro's `PICT`s actually use) before writing any of it; a general
   QuickDraw picture parser is far more than this port needs.
   **Then:** the intro screen is rendered by the game's own code, and the Stage A differential says
   whether it is right.

## Phase 0 — scaffolding (see `docs/phases.md`)

6. **`src/platform/platform.h` + `Platform.cpp`** — the abstraction. ⚠ Deliberately NOT copied from
   either prior port: both interfaces are shaped around a 6502 memory bus and an OS-call marshalling
   ABI this port does not have. Write it from this port's own boundary, which the trap map defines.
7. **`PlatformAmiga` + the app skeleton** — `main()` + VERTB takeover + the frame pump, per
   `docs/amiga-arch.md`. Nothing here is implemented; the doc is the shape to build.
8. **Verify the inherited FS-UAE loop end to end.** `amiga/{env,run,debug,diag_run}.sh` came over and
   are renamed but **unrun**. A plain build reading `painted=0` and an `FPSCOUNT=1` build reading a
   real framerate with nothing to draw is the exit criterion. → `docs/headless-fsuae.md`.
9. **Port the standing checks.** `docs/amiga-lessons.md` prescribes counters that "must read 0"
   (`g_beamPresentsLate`) and probe scripts (`beam_watch.gdb`, `fill_catch.gdb`) that **do not exist
   in this repo**. A rule that names a counter is an instruction to build it.
10. **`PROBE_SYMS` + `make probe-audit` + `make muldiv-audit`** in `amiga/Makefile` from the first
   link. ⚠ A gc-dropped probe counter reads as *instruction bytes*, not zero
   (`docs/method-lessons.md`).
11. **Close the inherited silent no-op.** `BitmapAssembler.s`'s two non-interleaved arms are
   unimplemented and retagged `[ASSUMED]`; either assert at `Bitmap` construction that nothing builds
   a non-interleaved one, or implement them. → `src/platform/amiga/framework/UPSTREAM.md`.
12. **Two dormant link traps in the vendored framework**, verified by partial-linking it here. Both
    are invisible until the first caller: `AmigaHardware::isLongFrame()`'s ASSEMBLER bridge `jsr`s a
    symbol **no `.s` defines** (undefined-symbol error), and `Bitmap::patternWithMask()` pulls in
    `__mulsi3` (fails the mandatory `muldiv-audit`, with a message that names `__mulsi3` rather than
    the caller). Fix the one you need when you need it, not speculatively. →
    `src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.

## Phase 1+ — carried forward, not yet actionable

13. **Write `ghidra_scripts/DumpTraps.java`.** The trap map is the abstraction boundary and there is
    no inherited script for it (Revs's `DumpHwAccesses.java` hardcodes BBC I/O ranges and was not
    carried over). → `docs/toolchain.md`.
14. **Fill `ghidra_scripts/entrypoints.csv` from `CODE 0`.** The jump table makes the postmortem's
    §1.1 sweep *enumerable* rather than a search — take the win.
15. **Read the manual / the extras before the binary.** RoF's `docs/manual.md` earned its place.
    Present and unread: `scans/Manual.pdf` (5.2 MB), `Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`,
    `Package.pdf`, `web_docs/cheats.txt`. ⭐ `KeyChart.jpg` is the input map and `cheats.txt` may
    name states worth reaching in the reference loop.
16. **Decode the `VETTE!.Data` record formats.** The *inventory* is done
    (`docs/source-inventory.md`); the formats are not. ⭐ Start with **`PERF`** — eight records of
    exactly 110 bytes with meaningful names (`Stock`, `ZR1`, `F40`, …), which is the cheapest
    possible place to calibrate a decode. Then `OBJS` (160 models, recurring exact sizes, and
    `QUAD`'s `Quad Discripter Data` says the renderer is quad-based) and `MAPS`. ⚠ Do this against
    the `load` segment's disassembly, not by pattern-guessing — RoF's postmortem §1.2 is about
    exactly this.
17. **Confirm or kill the `OBJS` two-level-of-detail reading.** The `C`/`S` name pairs
    (`F40C`/`F40S1`, `GenericC`/`GenericS`, `Taxi`/`TaxiS`, …) `[INFERRED]` a near/far pair per
    object. It is load-bearing for the Amiga frame budget, so it should be confirmed early rather
    than discovered during optimisation. → `docs/source-inventory.md` §OBJS.
18. **Explain the `Communication` segment and `COMM` 0.** 9.1 KB of code in *both* builds plus a
    2 490 B resource, in a 1989 single-player driving game. Modem head-to-head is a guess. It matters
    because 9 KB of code that the port may not need at all is 10% of the whole job.
19. **Explain `FRED`** — 6.5 KB in both builds, name says nothing. ⭐ New evidence, and it is a
    strong hint: `FRED` exports **242 of the 509 jump-table entries** — 6 508 bytes across 242
    externally-callable routines is **~27 bytes each**, so `[INFERRED]` it is a library of small leaf
    routines (maths/trig/fixed-point being the obvious candidates, which would fit the table-driven
    trig already found in the data). Cheap to settle: disassemble a dozen of its entries.
20. ⭐ **The two display questions that are still open** — the mode itself is now locked
    (4 bitplanes, hires interlaced; `PROJECT.md` §Decisions), so what remains is:
    **(a)** is the **in-game** surface 512 × 320 or **512 × 342**? One reference-loop probe of the
    front `WindowRecord`'s `portRect` past the garage screen. ⭐ Cheap, and do it on the next
    reference run rather than as its own trip.
    **(b)** is there an **OCS / 68000 fallback**, and which of crop / squeeze / none? ⚠ Gated on
    (a), because a 512 × 342 driving view makes every crop worse. → `PROJECT.md` §Open decisions.
    ⚠⚠ **Chunky → planar is a named, unbudgeted cost either way**, and whether it is even on the
    critical path is unknown: if the driving view is built from QuickDraw primitives, a
    planar-native trap layer skips it; if the game rasterises into the GWorld itself, it does not.
    ⛔ **Do not settle that from inference** — #1's trap log plus a write tap over the live GWorld's
    pixel range answers it by measurement. → `docs/mac-hardware.md` question 5.

21. ⭐ **Locate the copy-protection check, then patch it out.** Decision locked — patched, not
    reproduced (`docs/faithfulness-seam.md` §The copy protection; required for a WHDLoad release).
    Targets: `VETTE!.Data`'s `COPY 1 "Protect"` (1 991 B) for the data side, and the check itself in
    the code — `Initialize` first, `Main` second. ⚠⚠ **Read the routine before defeating it.** 1 991
    bytes is far more than a password list, so it may gate more than the prompt; a protection check
    that also initialises state is a classic, and a stub would give a game that runs and is subtly
    wrong. The patch is a **named** port-side seam in `disasm/symbols.csv`, not a silent edit, and
    the reference loop keeps running the *unpatched* original.
## ⛔ CLOSED — measured dead ends

*Read this section before proposing a lever, so a negative result is not re-derived.
Each entry is ONE line: what was tried, what it measured, and the doc that has the detail.*

- **68020-only instructions in the game** — none. Flow-following sweep of all 509/507 jump-table
  entries in both builds, 67.9 %/63.1 % of code bytes reached, **0** found; the unreached bytes are
  shown to be data by a self-calibrated linear control (18.4 vs 0.07 candidates/KB).
  `tools/m68k_sweep.py`, `docs/mac-hardware.md`.
- **Whole-file LINEAR 68020 sweep** — unusable as evidence: it decodes data as code and yields
  `callm`/`rtm`/`cmp2`/`pack` by the dozen. `docs/mac-hardware.md`.
