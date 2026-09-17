# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — nothing else can start

*Nothing.* ⭐⭐ The A-trap log is **DONE and measured** → `docs/trap-log.md`: **38 traps** called by
the game's own segments, in first-use order, each caller resolved to `(segment, offset)`, with the
intro screen's share isolated to **18** of them. Stage C's order is no longer an estimate.

1. ⏸ **The copy-protection password is DEFERRED** (user decision: revisit when it becomes
   relevant). It has not blocked anything — the game reached the garage screen without ever asking,
   so either this copy is already registered or the check fires deeper in. ⚠ Do not record "there
   is no password" as a finding: `readme.txt` says there is one, and the two readings have not been
   separated. The answers are in `tmp/unpacked/…/scans/Manual.pdf` when it is time. ⚠ Ground truth
   runs the **unpatched** original; the patch item below is port-side only and does not retire this.

2. ⭐⭐ **Three measurements that GATE Stage C**, all cheap now that `tools/mac_traps.lua` exists —
   extend it to read the stack/registers at the call site instead of just the trap word:
   * ⚠⚠ **Which trap does the game patch?** `SetTrapAddress` at `load+00B8`, one call at frame 1617,
     *inside* Target 1. The trap number is in `d0`. Under option A the game installs that patch on
     the Amiga too, so our dispatcher has to route the patched trap to the game's handler. A layer
     that ignores it is wrong silently.
   * ⚠ **What does `%A5Init` call?** It was already purged when the app first became frontmost, even
     with the jump table polled every frame for 400 frames. Stage B *runs* `%A5Init`, so its trap
     set is a hole in the work list. Catch it by arming the tracer before `CurApName` flips.
   * ⭐ **The `QDExtensions` selectors** ($AB1D, 11 calls from `Initialize+0134`) — they carry
     `NewGWorld` / `LockPixels`, and they decide whether the offscreen surface exists before the
     intro or only for driving, which is the question `docs/amiga-arch.md`'s c2p section waits on.
     `ScriptUtil`, `SCSIDispatch` and the `Pack` traps are selector-dispatched too.

   And one that does not gate it:
   * The window ends at the **menu**: `FRED` (242 of the 509 jump-table entries) and
     `Communication` never ran, and `%A5Init` was purged before the first segment map. ⚠ The 38 are
     a **FLOOR**. Extend `tools/mame_mac_input.lua` past the garage screen and re-run.
   ⚠ The re-run for driving does not block Stage A or B; the three bullets above block **Stage C**.

## ⭐⭐ TARGET 1 — the intro screen, painted by the game's own code — the CURRENT GOAL

⭐⭐ **Scoped by measurement, not by ambition: 18 traps.** `docs/trap-log.md` shows the intro art is
fully painted at frame 1758 and that rows 1–18 of the trap table are the last new trap before it
exists. Rows 19–21 are the wait-for-click loop and rows 22–38 are the garage screen — **both out of
scope for Target 1.** ⚠ `GetNextEvent` is *not* needed: the intro polls `Button`.

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

3. ⭐ **Stage A — the display path, with a captured frame.** Amiga skeleton in the locked mode
   (4 bitplanes, hires **interlaced**), a copper list, VERTB, the frame pump, and a host-side
   converter that turns a `tools/mac_probe_fb.lua` dump into planar bitplanes + a palette derived
   from the **displayed** colour (the gamma table, `docs/mac-hardware.md`).
   **Proves:** the screen mode, geometry, plane order, nibble order and palette — and it builds the
   pixel differential that every later stage is judged by. **Does NOT prove:** anything about the
   game. ⭐ Also satisfies most of Phase 0's exit criteria, so it is not a detour.
4. ⭐⭐ **Stage B — the loader: the game's own code executes on the Amiga.** Place all 11 `CODE`
   segments resident, build the A5 world (31 272 B below `a5`; 32 B + the 4 072 B / 509-entry jump
   table above), pre-patch every entry from unloaded form to `JMP abs.l`, run `%A5Init`, install our
   own Line-A handler on vector `$28`, and jump to the entry point.
   **Pass criterion:** the game runs and **halts on its first unimplemented trap, naming it** —
   manager, routine, selector, and the `(segment, offset)` of the caller. ⚠⚠ That loud stop *is* the
   deliverable; a build that runs on past an unknown trap is the silent-no-op failure this project's
   hard rules exist to prevent.
   ⚠ The resources have to reach the Amiga too — the Resource Manager is how the game reads all of
   its data, so a host-side resource-fork → Amiga-readable converter is part of this stage.
5. **Stage C — the trap layer: the 18 traps of Target 1, in the MEASURED order**
   (`docs/trap-log.md`).
   Implement first-use-first, re-running after each one; progress is countable ("N traps deep,
   halted at *M*"). ⭐ Rows 1–18 are the whole cost of a painted intro screen, and the load-bearing
   ones are `SetPort`/`ClipRect`/`PenSize`/`TextMode` (stateful QuickDraw port), `GetResource` +
   `CurResFile`/`UseResFile`, `GetPicture`/`DrawPicture`/`CopyBits`, and `QDExtensions`.
   ⭐ **`GetNextEvent` is NOT needed for the intro** — it first appears at the menu; the intro runs
   on `Button` polling from `Intro+0224`.
   ⚠⚠ **Two measurements gate this stage, both cheap and both listed in #2 below — take them first:**
   (a) which trap `SetTrapAddress` patches at `load+00B8`, and (b) the `QDExtensions` selectors.
   Neither is optional: (a) decides whether our dispatcher must route a trap to the game's own
   handler, and a layer that ignores the patch fails silently.
   ⚠ **Honour documented Inside Macintosh semantics, not what the call appears to want** — handles
   move, QuickDraw has a stateful current port (`CLAUDE.md`).
6. ⚠ **Stage D — `DrawPicture`, and it is a PICT opcode interpreter, not a call to wire up.**
   ⭐ Now sized from measurement: the intro issues **16 `DrawPicture` calls and 47 `GetPicture`s**,
   not hundreds. Read which opcodes those specific `PICT`s use before writing any of it; a general
   QuickDraw picture parser is far more than this port needs.
   **Then:** the intro screen is rendered by the game's own code, and the Stage A differential says
   whether it is right.

## Small, cheap, and wrong if left

⚠ **The game's year is not settled.** The intro art reads **"© 1991 SPHERE, INC"**; `PROJECT.md`,
`CLAUDE.md` and `docs/source-inventory.md` all say 1989, and the archive is `VETTE! 1.02`. Read the
`vers` resource and fix whichever is wrong, in one pass, everywhere. It costs minutes and a wrong
date in a pilot project's docs propagates to every port after it.

## Phase 0 — scaffolding (see `docs/phases.md`)

7. **`src/platform/platform.h` + `Platform.cpp`** — the abstraction. ⚠ Deliberately NOT copied from
   either prior port: both interfaces are shaped around a 6502 memory bus and an OS-call marshalling
   ABI this port does not have. Write it from this port's own boundary, which the trap map defines.
8. **`PlatformAmiga` + the app skeleton** — `main()` + VERTB takeover + the frame pump, per
   `docs/amiga-arch.md`. Nothing here is implemented; the doc is the shape to build.
9. **Verify the inherited FS-UAE loop end to end.** `amiga/{env,run,debug,diag_run}.sh` came over and
   are renamed but **unrun**. A plain build reading `painted=0` and an `FPSCOUNT=1` build reading a
   real framerate with nothing to draw is the exit criterion. → `docs/headless-fsuae.md`.
10. **Port the standing checks.** `docs/amiga-lessons.md` prescribes counters that "must read 0"
   (`g_beamPresentsLate`) and probe scripts (`beam_watch.gdb`, `fill_catch.gdb`) that **do not exist
   in this repo**. A rule that names a counter is an instruction to build it.
11. **`PROBE_SYMS` + `make probe-audit` + `make muldiv-audit`** in `amiga/Makefile` from the first
   link. ⚠ A gc-dropped probe counter reads as *instruction bytes*, not zero
   (`docs/method-lessons.md`).
12. **Close the inherited silent no-op.** `BitmapAssembler.s`'s two non-interleaved arms are
   unimplemented and retagged `[ASSUMED]`; either assert at `Bitmap` construction that nothing builds
   a non-interleaved one, or implement them. → `src/platform/amiga/framework/UPSTREAM.md`.
13. **Two dormant link traps in the vendored framework**, verified by partial-linking it here. Both
    are invisible until the first caller: `AmigaHardware::isLongFrame()`'s ASSEMBLER bridge `jsr`s a
    symbol **no `.s` defines** (undefined-symbol error), and `Bitmap::patternWithMask()` pulls in
    `__mulsi3` (fails the mandatory `muldiv-audit`, with a message that names `__mulsi3` rather than
    the caller). Fix the one you need when you need it, not speculatively. →
    `src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.

## Phase 1+ — carried forward, not yet actionable

14. **Write `ghidra_scripts/DumpTraps.java`.** The trap map is the abstraction boundary and there is
    no inherited script for it (Revs's `DumpHwAccesses.java` hardcodes BBC I/O ranges and was not
    carried over). → `docs/toolchain.md`.
15. **Fill `ghidra_scripts/entrypoints.csv` from `CODE 0`.** The jump table makes the postmortem's
    §1.1 sweep *enumerable* rather than a search — take the win.
16. **Read the manual / the extras before the binary.** RoF's `docs/manual.md` earned its place.
    Present and unread: `scans/Manual.pdf` (5.2 MB), `Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`,
    `Package.pdf`, `web_docs/cheats.txt`. ⭐ `KeyChart.jpg` is the input map and `cheats.txt` may
    name states worth reaching in the reference loop.
17. **Decode the `VETTE!.Data` record formats.** The *inventory* is done
    (`docs/source-inventory.md`); the formats are not. ⭐ Start with **`PERF`** — eight records of
    exactly 110 bytes with meaningful names (`Stock`, `ZR1`, `F40`, …), which is the cheapest
    possible place to calibrate a decode. Then `OBJS` (160 models, recurring exact sizes, and
    `QUAD`'s `Quad Discripter Data` says the renderer is quad-based) and `MAPS`. ⚠ Do this against
    the `load` segment's disassembly, not by pattern-guessing — RoF's postmortem §1.2 is about
    exactly this.
18. **Confirm or kill the `OBJS` two-level-of-detail reading.** The `C`/`S` name pairs
    (`F40C`/`F40S1`, `GenericC`/`GenericS`, `Taxi`/`TaxiS`, …) `[INFERRED]` a near/far pair per
    object. It is load-bearing for the Amiga frame budget, so it should be confirmed early rather
    than discovered during optimisation. → `docs/source-inventory.md` §OBJS.
19. **Explain the `Communication` segment and `COMM` 0.** 9.1 KB of code in *both* builds plus a
    2 490 B resource, in a 1989 single-player driving game. Modem head-to-head is a guess. It matters
    because 9 KB of code that the port may not need at all is 10% of the whole job.
20. **Explain `FRED`** — 6.5 KB in both builds, name says nothing. ⭐ New evidence, and it is a
    strong hint: `FRED` exports **242 of the 509 jump-table entries** — 6 508 bytes across 242
    externally-callable routines is **~27 bytes each**, so `[INFERRED]` it is a library of small leaf
    routines (maths/trig/fixed-point being the obvious candidates, which would fit the table-driven
    trig already found in the data). Cheap to settle: disassemble a dozen of its entries.
21. ⭐ **The two display questions that are still open** — the mode itself is now locked
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

22. ⭐ **Locate the copy-protection check, then patch it out.** Decision locked — patched, not
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
