# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — nothing else can start

1. ⭐⭐ **Finish the reference loop: get the game LAUNCHED and past the password, unattended.**
   No longer blocked on the user — the ROM, the System and the transfer are all done and verified:
   `mac2fdhd` + `-nb9 mdc48` boots `ref/mame/hd/608_2GB_drive.hd` (System 6.0.8) to the Finder, and
   `Color VETTE!` + `VETTE!.Data` are on that volume with both forks intact, written from the host
   with `hfsutils`. → `docs/mac-reference-loop.md`. What is left, in order:
   - **Drive the GUI headlessly** — MAME must double-click the app (or Finder's *Set Startup* must
     be set once) with no window open. Unsolved; Lua mouse/keyboard injection is the candidate.
   - **Answer the copy-protection password once**, then never again — the volume is persistent, so
     this is a one-time cost. ⭐ The answers are in `tmp/unpacked/…/scans/Manual.pdf`, which is
     already here, so nothing external is needed. ⚠ Ground truth runs the **unpatched** original;
     #17's patch is port-side only and does not retire this.
   - **Set the screen to 16 colours** in the Monitors control panel (the card is a 4/8 at 640×480;
     the captures so far are 1-bit). ⚠ It persists in MAME's `nvram`, so verify it survives a
     restart rather than assuming.
   - **Enter MacsBug and log A-traps.** ⭐ MacsBug 6.2.2 is installed and *verified* installed
     (`MacJmp` = `701E9A6E` on the hard disk vs `00000000` on the MacsBug-less floppy control), so
     what is left is an **input** problem — the programmer's-switch interrupt — shared with the
     GUI-driving item above. This is what capability 3 and the trap inventory run on.

## Phase 0 — scaffolding (see `docs/phases.md`)

2. **`src/platform/platform.h` + `Platform.cpp`** — the abstraction. ⚠ Deliberately NOT copied from
   either prior port: both interfaces are shaped around a 6502 memory bus and an OS-call marshalling
   ABI this port does not have. Write it from this port's own boundary, which the trap map defines.
3. **`PlatformAmiga` + the app skeleton** — `main()` + VERTB takeover + the frame pump, per
   `docs/amiga-arch.md`. Nothing here is implemented; the doc is the shape to build.
4. **Verify the inherited FS-UAE loop end to end.** `amiga/{env,run,debug,diag_run}.sh` came over and
   are renamed but **unrun**. A plain build reading `painted=0` and an `FPSCOUNT=1` build reading a
   real framerate with nothing to draw is the exit criterion. → `docs/headless-fsuae.md`.
5. **Port the standing checks.** `docs/amiga-lessons.md` prescribes counters that "must read 0"
   (`g_beamPresentsLate`) and probe scripts (`beam_watch.gdb`, `fill_catch.gdb`) that **do not exist
   in this repo**. A rule that names a counter is an instruction to build it.
6. **`PROBE_SYMS` + `make probe-audit` + `make muldiv-audit`** in `amiga/Makefile` from the first
   link. ⚠ A gc-dropped probe counter reads as *instruction bytes*, not zero
   (`docs/method-lessons.md`).
7. **Close the inherited silent no-op.** `BitmapAssembler.s`'s two non-interleaved arms are
   unimplemented and retagged `[ASSUMED]`; either assert at `Bitmap` construction that nothing builds
   a non-interleaved one, or implement them. → `src/platform/amiga/framework/UPSTREAM.md`.
8. **Two dormant link traps in the vendored framework**, verified by partial-linking it here. Both
    are invisible until the first caller: `AmigaHardware::isLongFrame()`'s ASSEMBLER bridge `jsr`s a
    symbol **no `.s` defines** (undefined-symbol error), and `Bitmap::patternWithMask()` pulls in
    `__mulsi3` (fails the mandatory `muldiv-audit`, with a message that names `__mulsi3` rather than
    the caller). Fix the one you need when you need it, not speculatively. →
    `src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.

## Phase 1+ — carried forward, not yet actionable

9. **Write `ghidra_scripts/DumpTraps.java`.** The trap map is the abstraction boundary and there is
    no inherited script for it (Revs's `DumpHwAccesses.java` hardcodes BBC I/O ranges and was not
    carried over). → `docs/toolchain.md`.
10. **Fill `ghidra_scripts/entrypoints.csv` from `CODE 0`.** The jump table makes the postmortem's
    §1.1 sweep *enumerable* rather than a search — take the win.
11. **Read the manual / the extras before the binary.** RoF's `docs/manual.md` earned its place.
    Present and unread: `scans/Manual.pdf` (5.2 MB), `Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`,
    `Package.pdf`, `web_docs/cheats.txt`. ⭐ `KeyChart.jpg` is the input map and `cheats.txt` may
    name states worth reaching in the reference loop.
12. **Decode the `VETTE!.Data` record formats.** The *inventory* is done
    (`docs/source-inventory.md`); the formats are not. ⭐ Start with **`PERF`** — eight records of
    exactly 110 bytes with meaningful names (`Stock`, `ZR1`, `F40`, …), which is the cheapest
    possible place to calibrate a decode. Then `OBJS` (160 models, recurring exact sizes, and
    `QUAD`'s `Quad Discripter Data` says the renderer is quad-based) and `MAPS`. ⚠ Do this against
    the `load` segment's disassembly, not by pattern-guessing — RoF's postmortem §1.2 is about
    exactly this.
13. **Confirm or kill the `OBJS` two-level-of-detail reading.** The `C`/`S` name pairs
    (`F40C`/`F40S1`, `GenericC`/`GenericS`, `Taxi`/`TaxiS`, …) `[INFERRED]` a near/far pair per
    object. It is load-bearing for the Amiga frame budget, so it should be confirmed early rather
    than discovered during optimisation. → `docs/source-inventory.md` §OBJS.
14. **Explain the `Communication` segment and `COMM` 0.** 9.1 KB of code in *both* builds plus a
    2 490 B resource, in a 1989 single-player driving game. Modem head-to-head is a guess. It matters
    because 9 KB of code that the port may not need at all is 10% of the whole job.
15. **Explain `FRED`** — 6.5 KB in both builds, name says nothing. ⭐ New evidence, and it is a
    strong hint: `FRED` exports **242 of the 509 jump-table entries** — 6 508 bytes across 242
    externally-callable routines is **~27 bytes each**, so `[INFERRED]` it is a library of small leaf
    routines (maths/trig/fixed-point being the obvious candidates, which would fit the table-driven
    trig already found in the data). Cheap to settle: disassemble a dozen of its entries.
16. **Decide the display architecture** — 512×342 against a PAL planar display, and 60 Hz against
    50 Hz. ⚠ **Re-read since the build choice:** the depth is no longer "1bpp, which is a free win";
    the Color build is `[DERIVED]` a 16-colour program, so 4 bitplanes, which is workable but costs
    real bitplane DMA and blit width. Blocked on #18 for the actual surface depth.
    → `PROJECT.md`, `docs/mac-hardware.md` question 5.

17. ⭐ **Locate the copy-protection check, then patch it out.** Decision locked — patched, not
    reproduced (`docs/faithfulness-seam.md` §The copy protection; required for a WHDLoad release).
    Targets: `VETTE!.Data`'s `COPY 1 "Protect"` (1 991 B) for the data side, and the check itself in
    the code — `Initialize` first, `Main` second. ⚠⚠ **Read the routine before defeating it.** 1 991
    bytes is far more than a password list, so it may gate more than the prompt; a protection check
    that also initialises state is a classic, and a stub would give a game that runs and is subtly
    wrong. The patch is a **named** port-side seam in `disasm/symbols.csv`, not a silent edit, and
    the reference loop keeps running the *unpatched* original.
18. ⭐ **Confirm the Color build's real offscreen depth from the binary.** `[DERIVED]` 16 colours →
    4 bitplanes comes from 8 `pltt` resources of 16 entries each, which is evidence about palettes,
    not about the drawing surface. The answer lives in `Initialize`'s Color QuickDraw calls
    (`NewGWorld`/`NewPixMap`/`GDevice` setup), not in `PICT` headers — a naive `PICT` opcode scan
    produced garbage (`49151 bpp`) and must not be re-trusted. It gates #16 and the whole blit
    budget. → `docs/source-inventory.md`, `docs/mac-hardware.md` question 5.

19. ⭐⭐ **Build the A5 world and the segment-loader stand-in.** The first port code that option A
    requires, and it is well-specified rather than exploratory: allocate the A5 world (**31 272 B**
    of globals below `a5`, **4 104 B** above = 32 B + the **4 072 B / 509-entry jump table** at
    A5+32), pre-patch all 509 entries from unloaded form (`MOVE.W #seg,-(SP)`, `_LoadSeg`) to
    `JMP abs.l`, and place all 11 segments resident so `_LoadSeg` never has to be serviced.
    ⚠⚠ **`%A5Init` must run or be replaced by what it produces** — 28 732 B whose job is to
    initialise those globals. Skip it and the globals are zero instead of initialised: a silent
    wrong-value failure, not a crash. → `docs/faithfulness-seam.md`.
20. **Close the 68020-legality question properly.** ⭐ Current status is a *screen*, not a proof:
    a 68000-vs-68020 differential from all 508 distinct jump-table entries (2 734 instructions,
    600 B per entry, no branch following) found **no 68020-only encoding on any reachable path**.
    The Ghidra sweep (#11/#12) closes it for real, since it follows flow. ⚠ It matters more under
    option A than it would under B: the original bytes must *execute* on a 68000, not merely be
    understood. ⚠ Do not re-run the whole-file linear sweep as evidence — mixed code and data
    yields `callm`/`rtm`/`cmp2` false positives by the dozen.

## ⛔ CLOSED — measured dead ends

*(empty — read this section before proposing a lever, so a negative result is not re-derived.
Each entry is ONE line: what was tried, what it measured, and the doc that has the detail.)*
