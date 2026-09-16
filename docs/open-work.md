# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — nothing else can start

1. **Pick the reference-loop emulator.** → `docs/mac-reference-loop.md` §Candidates. Gates Phase 1,
   which gates Phase 2. ⚠ New constraint from the archive: the build asks for a copy-protection
   password **once, on first run** (answers in `Manual.pdf`'s first pages), so the chosen emulator
   must be able to keep a *post-registration* volume — a throwaway image stops at the prompt every
   time, and that turns the reference loop into a manual chore exactly where it needs to be cheap.
2. **Decide the port strategy** (keep the original 68000 code vs reimplement, and the default at the
   seam). → `PROJECT.md` §Open decisions, `docs/faithfulness-seam.md`. Nothing should be converted
   before this is settled.
3. **Choose the build: B&W `VETTE!` or `Color VETTE!`.** They are two separate applications with the
   same 11 named segments and near-identical code size; the Color one carries ~1 MB more `PICT` plus
   `pltt`/`wctb`/8 `WIND`. ⚠ This decides which binary gets disassembled and named, so it wants
   settling *before* `symbols.csv` has anything in it — every address is `(segment, offset)` in one
   specific build. Weigh it against the Amiga display decision (#18): the Mac's 1-bit 512×342 and a
   planar Amiga bitmap are not the same trade-off as an 8-bit colour original. → `PROJECT.md`
   §The source material.

## Phase 0 — scaffolding (see `docs/phases.md`)

4. **`src/platform/platform.h` + `Platform.cpp`** — the abstraction. ⚠ Deliberately NOT copied from
   either prior port: both interfaces are shaped around a 6502 memory bus and an OS-call marshalling
   ABI this port does not have. Write it from this port's own boundary, which the trap map defines.
5. **`PlatformAmiga` + the app skeleton** — `main()` + VERTB takeover + the frame pump, per
   `docs/amiga-arch.md`. Nothing here is implemented; the doc is the shape to build.
6. **Verify the inherited FS-UAE loop end to end.** `amiga/{env,run,debug,diag_run}.sh` came over and
   are renamed but **unrun**. A plain build reading `painted=0` and an `FPSCOUNT=1` build reading a
   real framerate with nothing to draw is the exit criterion. → `docs/headless-fsuae.md`.
7. **Port the standing checks.** `docs/amiga-lessons.md` prescribes counters that "must read 0"
   (`g_beamPresentsLate`) and probe scripts (`beam_watch.gdb`, `fill_catch.gdb`) that **do not exist
   in this repo**. A rule that names a counter is an instruction to build it.
8. **`PROBE_SYMS` + `make probe-audit` + `make muldiv-audit`** in `amiga/Makefile` from the first
   link. ⚠ A gc-dropped probe counter reads as *instruction bytes*, not zero
   (`docs/method-lessons.md`).
9. **Close the inherited silent no-op.** `BitmapAssembler.s`'s two non-interleaved arms are
   unimplemented and retagged `[ASSUMED]`; either assert at `Bitmap` construction that nothing builds
   a non-interleaved one, or implement them. → `src/platform/amiga/framework/UPSTREAM.md`.
10. **Two dormant link traps in the vendored framework**, verified by partial-linking it here. Both
    are invisible until the first caller: `AmigaHardware::isLongFrame()`'s ASSEMBLER bridge `jsr`s a
    symbol **no `.s` defines** (undefined-symbol error), and `Bitmap::patternWithMask()` pulls in
    `__mulsi3` (fails the mandatory `muldiv-audit`, with a message that names `__mulsi3` rather than
    the caller). Fix the one you need when you need it, not speculatively. →
    `src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.

## Phase 1+ — carried forward, not yet actionable

11. **Write `ghidra_scripts/DumpTraps.java`.** The trap map is the abstraction boundary and there is
    no inherited script for it (Revs's `DumpHwAccesses.java` hardcodes BBC I/O ranges and was not
    carried over). → `docs/toolchain.md`.
12. **Fill `ghidra_scripts/entrypoints.csv` from `CODE 0`.** The jump table makes the postmortem's
    §1.1 sweep *enumerable* rather than a search — take the win.
13. **Read the manual / the extras before the binary.** RoF's `docs/manual.md` earned its place.
    Present and unread: `scans/Manual.pdf` (5.2 MB), `Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`,
    `Package.pdf`, `web_docs/cheats.txt`. ⭐ `KeyChart.jpg` is the input map and `cheats.txt` may
    name states worth reaching in the reference loop.
14. **Decode the `VETTE!.Data` record formats.** The *inventory* is done
    (`docs/source-inventory.md`); the formats are not. ⭐ Start with **`PERF`** — eight records of
    exactly 110 bytes with meaningful names (`Stock`, `ZR1`, `F40`, …), which is the cheapest
    possible place to calibrate a decode. Then `OBJS` (160 models, recurring exact sizes, and
    `QUAD`'s `Quad Discripter Data` says the renderer is quad-based) and `MAPS`. ⚠ Do this against
    the `load` segment's disassembly, not by pattern-guessing — RoF's postmortem §1.2 is about
    exactly this.
15. **Confirm or kill the `OBJS` two-level-of-detail reading.** The `C`/`S` name pairs
    (`F40C`/`F40S1`, `GenericC`/`GenericS`, `Taxi`/`TaxiS`, …) `[INFERRED]` a near/far pair per
    object. It is load-bearing for the Amiga frame budget, so it should be confirmed early rather
    than discovered during optimisation. → `docs/source-inventory.md` §OBJS.
16. **Explain the `Communication` segment and `COMM` 0.** 9.1 KB of code in *both* builds plus a
    2 490 B resource, in a 1989 single-player driving game. Modem head-to-head is a guess. It matters
    because 9 KB of code that the port may not need at all is 10% of the whole job.
17. **Explain `FRED`** — 6.5 KB in both builds, name says nothing.
18. **Decide the display architecture** — 512×342×1bpp against a PAL planar display, and 60 Hz
    against 50 Hz. → `PROJECT.md`, `docs/mac-hardware.md` question 5.

## ⛔ CLOSED — measured dead ends

*(empty — read this section before proposing a lever, so a negative result is not re-derived.
Each entry is ONE line: what was tried, what it measured, and the doc that has the detail.)*
