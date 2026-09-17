# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — nothing else can start

*Nothing.* ⭐⭐ The A-trap log is **DONE and measured** → `docs/trap-log.md`: **51 traps** called by
the game's own segments, in first-use order, each caller resolved to `(segment, offset)` **live at
the moment of the call**, with the intro screen's share isolated to the first **36**. Stage C's
order is no longer an estimate, and the three measurements that used to gate it are answered:
the game patches exactly one trap (`_ExitToShell`), `%A5Init` calls exactly one (`_BlockMove`), and
`QDExtensions` is dispatched by `D0` with Target 1 needing selectors 0 (`NewGWorld`) and
1 (`LockPixels`).

1. ⏸ **The copy-protection password is DEFERRED** (user decision: revisit when it becomes
   relevant). It has not blocked anything — the game reached the garage screen without ever asking,
   so either this copy is already registered or the check fires deeper in. ⚠ Do not record "there
   is no password" as a finding: `readme.txt` says there is one, and the two readings have not been
   separated. The answers are in `tmp/unpacked/…/scans/Manual.pdf` when it is time. ⚠ Ground truth
   runs the **unpatched** original; the patch item below is port-side only and does not retire this.

2. ⚠ **The trap log stops at the MENU, so re-run it for DRIVING.** `FRED` (242 of the 509
   jump-table entries) and `Communication` were never observed resident, so any trap they call is
   missing. ⚠⚠ The 51 are a **FLOOR**. Extend `tools/mame_mac_input.lua` past the garage screen and
   re-run `tools/mac_traps.lua`. ⛔ Does **not** gate Target 1 — the intro is fully measured.

3. ⚠ **`512×323` vs `512×320` is unreconciled.** The intro's first `DrawPicture` destination rect
   is 512 wide by **323** tall `[MEASURED]`; `docs/mac-hardware.md` records the game painting
   **320** rows at (64,92). Three rows are unexplained — clipped, or the recorded 320 is short.
   Settle it before the Stage A viewport geometry is fixed, by capturing the GWorld and the screen
   at frame 1758 and diffing the row extents. ⭐ Same reference run as #24(a) (`PROJECT.md` #2),
   which asks the same question about the **driving** surface — take both probes at once.

4. ⚠ **`QDExtensions` selector 12** (2 calls, `Initialize+031E`/`+0422`) is unidentified — a void
   procedure taking the GWorld's `PixMapHandle`. Outside Target 1. ⛔ Do not name it from a
   remembered `QDOffscreen` selector order; disassemble or measure it.

5. ⚠ **1989 vs "© 1991 SPHERE, INC".** `PROJECT.md`/`CLAUDE.md` call the game 1989; the intro art
   the port must match says 1991. One of them is wrong and neither is load-bearing yet — resolve it
   before either date is quoted as measured.

## ⭐⭐ TARGET 1 — the intro screen, painted by the game's own code — the CURRENT GOAL

⭐⭐ **Scoped by measurement, not by ambition: 36 traps.** `docs/trap-log.md` shows the intro art is
fully painted at frame 1758 and that rows 1–36 of the trap table are every trap first called before
it exists. Rows 37–38 are the animation + wait-for-click loop and rows 39–51 are the garage screen —
**both out of scope for Target 1.** ⚠ `GetNextEvent` is *not* needed: the intro polls `Button`.
⚠⚠ **This is DOUBLE the 18 previously documented**, and the 18 were not wrong so much as blind: the
earlier tracer cleared its accumulators when the app became frontmost and so discarded the game's
own first 230 frames — `%A5Init`, QuickDraw/Font/Window/Menu init, the `QUAD` + `OBJS` loads, the
GWorld creation. Nothing was removed; 18 more sit in front.

**Acceptance criterion, and it is a pixel diff, not a look:** the Amiga paints the Golden Gate /
San Francisco title art with "© 1991 SPHERE, INC", produced by the game's own `CODE` segments
calling our trap layer, and it matches the MAME reference capture of frame 1758 under the Stage A
differential.

⚠⚠ **Read the honesty rule before starting any of these: each stage states what it PROVES, and a
stage that shows the right picture for the wrong reason is a failure, not a milestone.** Displaying
a converted Mac screenshot is a display-path proof and nothing more — it must never be reported as
"the intro screen works".

⛔ **Deferred out of Target 1 by this scoping** — do not implement them early "while we are here":
the Event Manager (`GetNextEvent`, `SystemTask`), the Menu Manager (`NewMenu`, `AppendMenu`,
`GetRMenu`, `DrawMenuBar`, `DisableItem`), `MoveWindow`/`DisposeWindow`/`PaintBehind`,
`GetGDevice`/`GetMainDevice`/`GetCTSeed`, `PurgeMem`/`CompactMem`, `UnLoadSeg`.

6. ⭐ **Stage A — the ONE thing left is the eyeball check, and it needs a human at the screen.**
   The display path is built and measured headlessly: `out/Vette.exe` takes the machine over, brings
   up 512×320 in 4 bitplanes hires interlaced and shows Target 1's captured Macintosh frame from
   chip RAM. `EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=stage_a.gdb ./diag_run.sh 30` reads
   `screenReady=1`, `planeChecksum=0x597A969D` (identical to `python3 tools/planes_checksum.py
   amiga/assets/intro.planes`, so the whole asset path is proven byte for byte) and
   `long/lace=0.500` with VPOSR alternating.
   ⚠⚠ **What no probe here can cover:** whether the picture is centred and undistorted **on the
   glass**, and whether the two interlace fields are the right way round — the field polarity is
   `[ASSUMED]` in `VetteScreen::vbiUpdate()` and getting it backwards displaces every row by one
   scanline, which reads as a slightly soft image rather than as a fault. Run `cd amiga && ./run.sh`
   and compare against `amiga/assets/intro_amiga.png` (what it should look like) and
   `intro_mac.png` (what the Macintosh showed). **Then delete this item.**
   ⚠ **And it proves nothing about the game** — it displays a converted Macintosh screenshot. See
   the honesty rule above.
7. ⭐⭐ **Stage B — the loader: the game's own code executes on the Amiga.** Place all 11 `CODE`
   segments resident, build the A5 world (31 272 B below `a5`; 32 B + the 4 072 B / 509-entry jump
   table above), pre-patch every entry from unloaded form to `JMP abs.l`, run `%A5Init`, install our
   own Line-A handler on vector `$28`, and jump to the entry point.
   **Pass criterion:** the game runs and **halts on its first unimplemented trap, naming it** —
   manager, routine, selector, and the `(segment, offset)` of the caller. ⚠⚠ That loud stop *is* the
   deliverable; a build that runs on past an unknown trap is the silent-no-op failure this project's
   hard rules exist to prevent.
   ⚠ The resources have to reach the Amiga too — the Resource Manager is how the game reads all of
   its data, so a host-side resource-fork → Amiga-readable converter is part of this stage.
8. **Stage C — the trap layer: the 36 traps of Target 1, in the MEASURED order**
   (`docs/trap-log.md`). ⭐ **Nothing gates this stage any more.**
   Implement first-use-first, re-running after each one; progress is countable ("N traps deep,
   halted at *M*"). ⭐ Rows 1–36 are the whole cost of a painted intro screen, and the load-bearing
   ones are `SetPort`/`ClipRect`/`PenSize`/`TextMode` (stateful QuickDraw port), `GetResource` +
   `CurResFile`/`UseResFile`, `GetPicture`/`DrawPicture`/`CopyBits`, and `QDExtensions`
   (`NewGWorld` + `LockPixels`, selector in **`D0`**).
   ⭐ **`GetNextEvent` is NOT needed for the intro** — it first appears at the menu; the intro runs
   on `Button` polling from `Intro+0224`.
   ⚠⚠ **`SetTrapAddress` must be honoured, and it is exactly one trap:** the game patches `$A9F4
   ExitToShell` to its own handler from `load+00B8` at frame 1617, *inside* Target 1. Route it, or
   quitting fails in a way that looks like a crash. ⛔ No general trap-patching machinery is needed.
   ⚠ **Honour documented Inside Macintosh semantics, not what the call appears to want** — handles
   move, QuickDraw has a stateful current port (`CLAUDE.md`).
9. ⚠ **Stage D — `DrawPicture`, and it is a PICT opcode interpreter, not a call to wire up.**
   ⭐ Now sized from measurement: the intro issues **16 `DrawPicture` calls and 47 `GetPicture`s**,
   not hundreds. Read which opcodes those specific `PICT`s use before writing any of it; a general
   QuickDraw picture parser is far more than this port needs.
   **Then:** the intro screen is rendered by the game's own code, and the Stage A differential says
   whether it is right.

⚠ **Refer to an item by its TITLE, not its number.** The list is renumbered every time an entry is
closed and deleted, so a `#N` written in another doc goes quietly wrong — three of them already had.

## Small, cheap, and wrong if left

⚠ **The game's year is not settled.** The intro art reads **"© 1991 SPHERE, INC"**; `PROJECT.md`,
`CLAUDE.md` and `docs/source-inventory.md` all say 1989, and the archive is `VETTE! 1.02`. Read the
`vers` resource and fix whichever is wrong, in one pass, everywhere. It costs minutes and a wrong
date in a pilot project's docs propagates to every port after it.

## Phase 0 — scaffolding (see `docs/phases.md`)

10. **`src/platform/platform.h` + `Platform.cpp`** — the abstraction. ⚠ Deliberately NOT copied from
   either prior port: both interfaces are shaped around a 6502 memory bus and an OS-call marshalling
   ABI this port does not have. Write it from this port's own boundary, which the trap map defines.
11. **Port the standing checks.** `docs/amiga-lessons.md` prescribes counters that "must read 0"
   (`g_beamPresentsLate`) and probe scripts (`beam_watch.gdb`, `fill_catch.gdb`) that **do not exist
   in this repo**. A rule that names a counter is an instruction to build it.
12. **Close the inherited silent no-op.** `BitmapAssembler.s`'s two non-interleaved arms are
   unimplemented and retagged `[ASSUMED]`; either assert at `Bitmap` construction that nothing builds
   a non-interleaved one, or implement them. → `src/platform/amiga/framework/UPSTREAM.md`.
13. **One dormant link trap left in the vendored framework.** `Bitmap::patternWithMask()` pulls in
    `__mulsi3`, so it fails the mandatory `muldiv-audit` — with a message that names `__mulsi3`
    rather than the caller. Fix it when something needs it, not speculatively. →
    `src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.
    ✅ The other one is no longer dormant: `AmigaHardware::isLongFrame()`'s ASSEMBLER bridge `jsr`s
    `_isLongFrame__13AmigaHardwareFv`, which no `.s` defines, and the interlaced display was its
    first caller. **Not fixed — routed around**, because the whole function is one VPOSR read
    (`VetteScreen::vbiUpdate()`). Left here because a future caller will hit it again.

14. ⚠⚠ **⛔ Do not call the framework's `setPlayfield()` — it discards `interlace` silently.**
    Both `AmigaHardware::setPlayfield()` and `CopperList::setPlayfield()` accept the flag and
    `(void)` it, so neither ever writes BPLCON0's LACE bit; `CopperList`'s also drops `height` and
    `centerY`. It additionally hardcodes a 320-lores DIW window and uses the *lores* DDFSTRT
    formula for hires. Since `PROJECT.md` locks this port to **hires interlaced**, calling it would
    have produced a plausible half-resolution picture with nothing reporting a problem.
    `VetteScreen` owns those registers instead. **Decide once, for the series:** fix the vendored
    framework (and feed it upstream) or mark the two functions unusable so the next Mac 68k port
    does not rediscover this. → `docs/amiga-arch.md` §THE VENDORED `setPlayfield()`.

15. ⚠ **The quit chord is the BARE left mouse button, not `CTRL`+LMB.** `amiga/run.sh` documents
    the CTRL qualifier and explains why it exists: the Macintosh is a one-button machine, so the
    game **will** bind the bare button. Reading CTRL needs the keyboard layer, which Stage A does
    not have. ⚠⚠ **This must be fixed BEFORE the first trap that reads the mouse button**
    (`Button`, row 30 of `docs/trap-log.md`, which the intro polls) — after that, quitting and
    clicking are the same gesture. → `src/platform/amiga/PlatformAmiga.cpp`.

## Phase 1+ — carried forward, not yet actionable

16. **Write `ghidra_scripts/DumpTraps.java`.** The trap map is the abstraction boundary and there is
    no inherited script for it (Revs's `DumpHwAccesses.java` hardcodes BBC I/O ranges and was not
    carried over). → `docs/toolchain.md`.
17. **Fill `ghidra_scripts/entrypoints.csv` from `CODE 0`.** The jump table makes the postmortem's
    §1.1 sweep *enumerable* rather than a search — take the win.
18. **Read the manual / the extras before the binary.** RoF's `docs/manual.md` earned its place.
    Present and unread: `scans/Manual.pdf` (5.2 MB), `Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`,
    `Package.pdf`, `web_docs/cheats.txt`. ⭐ `KeyChart.jpg` is the input map and `cheats.txt` may
    name states worth reaching in the reference loop.
19. **Decode the `VETTE!.Data` record formats.** The *inventory* is done
    (`docs/source-inventory.md`); the formats are not. ⭐ Start with **`PERF`** — eight records of
    exactly 110 bytes with meaningful names (`Stock`, `ZR1`, `F40`, …), which is the cheapest
    possible place to calibrate a decode. Then `OBJS` (160 models, recurring exact sizes, and
    `QUAD`'s `Quad Discripter Data` says the renderer is quad-based) and `MAPS`. ⚠ Do this against
    the `load` segment's disassembly, not by pattern-guessing — RoF's postmortem §1.2 is about
    exactly this.
20. **Confirm or kill the `OBJS` two-level-of-detail reading.** The `C`/`S` name pairs
    (`F40C`/`F40S1`, `GenericC`/`GenericS`, `Taxi`/`TaxiS`, …) `[INFERRED]` a near/far pair per
    object. It is load-bearing for the Amiga frame budget, so it should be confirmed early rather
    than discovered during optimisation. → `docs/source-inventory.md` §OBJS.
21. **Explain the `Communication` segment and `COMM` 0.** 9.1 KB of code in *both* builds plus a
    2 490 B resource, in a 1989 single-player driving game. Modem head-to-head is a guess. It matters
    because 9 KB of code that the port may not need at all is 10% of the whole job.
22. **Explain `FRED`** — 6.5 KB in both builds, name says nothing. ⭐ New evidence, and it is a
    strong hint: `FRED` exports **242 of the 509 jump-table entries** — 6 508 bytes across 242
    externally-callable routines is **~27 bytes each**, so `[INFERRED]` it is a library of small leaf
    routines (maths/trig/fixed-point being the obvious candidates, which would fit the table-driven
    trig already found in the data). Cheap to settle: disassemble a dozen of its entries.
23. ⭐ **The two display questions that are still open** — the mode itself is now locked
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

24. ⭐ **Locate the copy-protection check, then patch it out.** Decision locked — patched, not
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
