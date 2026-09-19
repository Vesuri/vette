# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — current loud stop

⭐ **HEAD OF QUEUE: finish the first driving frame and identify its completion boundary.** The blank upper
viewport was an intermediate frame. The live VBL queue contained a one-tick sound task and a
three-tick driving task; returning after the first due record starved the latter forever. The
scheduler now ages every record and selects callbacks round-robin, and the three direct `$0174`
readers share a complete A5-relative KeyMap shadow. The first game-drawn road frame now contains
skyline, traffic, mirror and cockpit without another trap. Keypad 8 is held through the direct
KeyMap path at the Course One transition; consecutive driving-task captures differ and the original
throttle global advances from 3 to 21 over 30 ticks. Direct `_BlockMove` writes now mark bounded
dirty regions. Most raster pixels are direct 68k stores, but a three-tick full-surface comparison
was rejected: it presented partial construction and cut callback progress from 162 to 48. The
baseline 303-tick cadence queues no new completed frame. A spaced exception-PC sampler disproves
the earlier attribution to the game's 3D code: 10 of 16 samples are in the compatibility PICT
decoder and two are in chunky-to-planar conversion while the initial road artwork is still being
built. Packing pairs of mapped 8-bit pixels, expanding PackBits in words, and translating packed
4-bit pixels while decompressing raise measured callback progress from 0.535 to 0.606 per tick,
about 13 percent, but the first frame still does not complete in the bounded run. Continue
profiling the PICT path; do not poll the 81,920-byte surface again or present partially constructed
frames. The original completion signal is now identified: while driving, `Main+$29C6` branches
back to the loop entry at `Main+$1FD2`, so consecutive hits on the first trap at `Main+$1FEA`
delimit complete frames. `SystemTask` at `Main+$29E6` belongs to the exit/event-loop path and was
the wrong target. The bridge now marks the full 512x320 surface at that corrected boundary and
disarms the marker on the exit path; `driving_setup_boundary.gdb` measures consecutive frames.
The next bounded run must reach the second hit and validate the first complete presentation.
Per-row direct decode, identity-palette detection, literal-loop unrolling, and
single-entry palette caching are measured regressions; profile and optimize at the PICT-call or
resource level rather than retrying those local variants. `driving_pict_progress.gdb` now shows
the dominant workload: 38 large 8-bit, 512×24 PackBits strips build the 3,392-pixel wrapping
roadside panorama. An in-decoder 8→4-bit fusion was slower. Host-predecoded archive sidecars were
also rejected: caching all eligible rasters fell to 123/322, while a 215,040-byte packed cache of
only the 35 unique panorama strips fell to 108/315, versus the 183/302 control. Preserve the
decoder's fresh-working-memory locality. Copying the three already-rendered wrap duplicates also
lost at 177/395 because per-call validation outweighed the saved decodes. The next optimization
must amortize setup across the whole panorama rather than add another per-picture cache. Skipping
the packed-nibble map that 8-bit PICTs cannot use is retained but essentially neutral at 183/301.
The panorama's two shared source color tables do not provide a shortcut either: caching their
translated maps regressed to 153/373 and was removed. Reusing one 12,288-byte decode workspace
across the 38 panorama strips is retained: an A/B/A measurement repeated the allocator control at
171/304 on both sides and reached 183/312 with the workspace, about 4.3 percent more callbacks per
tick. Larger pictures still use fresh allocations.
`driving_frame_phases.gdb` now divides the wait at original-code boundaries: the first 33 pictures
finish after 177 ticks, all 38 after 384, and the dynamic-renderer gate at `Main+$286A` is reached
after 773 ticks without completing the frame. Do not keep treating PICT as the entire bottleneck;
the 389-tick gap after the initial pictures is mostly further compatibility drawing inside later
main-path routines, not the already-returned straight-line picture batch.
`driving_post_picture_samples.gdb` finds 16 of 19 samples back inside the indexed PICT decoder, two
in complete-frame conversion, and one in clearing. A repeat with explicit state shows all 19 have
`g_macVBLCallbackActive == 0`: these are later synchronous main-path PICTs, not callback work.
`driving_post_picture_picts.gdb` identifies the costly case as 512-pixel 4-bit strips whose
horizontal mapping is 1:1 while their enclosing frame scales vertically from 157 to 156 rows. A
retained horizontal packed-row path preserves the vertical mapping and improves the milestone
times from 177/384/773 to 155/346/503 ticks. The exact intro differential remains pixel-perfect.
The next bounded run should now profile the dynamic renderer and try to reach the second loop-entry
hit that presents the first complete frame.
`driving_dynamic_samples.gdb` initially found 14 of 24 samples in partial-frame C2P, nine in
`CopyBits`, and one in game code. Driving presentation is now suppressed during construction and
performed only at the proven next-loop boundary; milestone times improve again from 155/346/503 to
112/301/428 ticks. The repeat contains no C2P samples and is dominated by `CopyBits`, followed by
resident Main/Traffic code. Measure the dynamic `CopyBits` geometry next.
`driving_dynamic_copybits.gdb` finds repeated non-identity `srcCopy` operations between the same
two PixMaps over the complete `(0,0)-(342,512)` rectangle. Widening overlap-safe `blockMove` to
longwords and mapping equal-stride full rows as one contiguous span reduces the same twelve calls
from 138 to 126 ticks, about nine percent. Samples now land in the contiguous palette-map loop;
optimize that loop only with a bounded A/B measurement, then return to the genuine Main/Traffic
share and the still-unreached second frame-boundary hit.

The MAME A-trap log remains a measured reference-run inventory → `docs/trap-log.md`,
but Stage C has proved that it is **not an exact standalone-port first-use script**. The port has
already executed initialization calls absent from, or much later in, that 51-row ordering. Treat
51 and the intro's 36 as floors until the tracer omission is explained. Three earlier questions
are nevertheless answered:
the game patches exactly one trap (`_ExitToShell`), `%A5Init` calls exactly one (`_BlockMove`), and
`QDExtensions` is dispatched by `D0` with Target 1 needing selectors 0 (`NewGWorld`) and
1 (`LockPixels`).

1. ✅ **The copy-protection requester is removed in the port.** It first fired after Course One was
   accepted. `Main+$05FE` is now replaced only after verifying the exact shipped 12-byte prologue;
   the replacement sets `protection passed = -1`, clears the retry flag, and returns. This is the
   state left by the correct-answer path, without implementing `GetDItem`, text editing, modal
   events, or persistent writable resources. ⚠ Ground truth still runs the **unpatched** original.

2. ⚠ **The trap log stops at the MENU, so re-run it for DRIVING.** `FRED` (242 of the 509
   jump-table entries) and `Communication` were never observed resident, so any trap they call is
   missing. ⚠⚠ The 51 are a **FLOOR**. Extend `tools/mame_mac_input.lua` past the garage screen and
   re-run `tools/mac_traps.lua`. ⛔ Does **not** gate Target 1 — the intro is fully measured.

3. ⚠ **`512×323` vs `512×320` is unreconciled.** The intro's first `DrawPicture` destination rect
   is 512 wide by **323** tall `[MEASURED]`; `docs/mac-hardware.md` records the game painting
   **320** rows at (64,92). Three rows are unexplained — clipped, or the recorded 320 is short.
   Settle it before the Stage A viewport geometry is fixed, by capturing the GWorld and the screen
   at frame 1758 and diffing the row extents. ⭐ Same reference run as **The two display questions
   that are still open**, part (a) (`PROJECT.md` #2),
   which asks the same question about the **driving** surface — take both probes at once.

## ⭐⭐ TARGET 1 — the complete intro, run by the game's own code — COMPLETE

The MAME capture proves that its first 36 logged traps suffice to paint the reference intro at
frame 1758. Stage C's own loud-stop loop is now the implementation order and has already found
additional setup calls. The visual acceptance boundary is unchanged; the exact trap count is not.
⚠ `GetNextEvent` is still outside the intro path: the intro polls `Button`.

**Acceptance criterion, and it is a pixel diff, not a look:** the Amiga paints the Golden Gate /
San Francisco title art with "© 1991 SPHERE, INC", produced by the game's own `CODE` segments
calling our trap layer, and it matches the MAME reference capture of frame 1758 under the Stage A
differential.

⭐ **Passed:** at the first `Button` poll, all 163,840 displayed colors match the Macintosh
frame, the game-produced chunky surface converts into the centred 512×384 display (32 black rows,
81,920 bytes of image, 32 black rows), and the next VBI installs those exact bytes and all 16
game-derived colors into the copper display. No captured framebuffer is linked into the runtime.
Reproduce
with `amiga/stage_c_capture.gdb` followed by `tools/verify_stage_c_intro.py`. The matching source
crop is `(64,91,512,320)`; the one-row correction is recorded in `docs/stage-c.md` while the
separate 323-row destination-rectangle question remains queued.

⭐ **The complete animated intro also passes on the target A1200 configuration** (2 MiB chip,
8 MiB fast): the tram rings at the summit and parks at `(310,0)-(440,134)`, the Corvette/singer/mic
sequence completes, and the original `CopyBits` composition produces the striped VETTE logo. The
opening piano and the bell/engine/mic cues come from the converted `INST` resources; `Signature`
replaces the piano at the logo, plays once, and then stops. The final A1200 and A4000 chunky captures
are byte-identical. Execution then disposes the intro window. Post-intro bring-up can synthesize
only the first `Button` result with `make SKIP_INTRO=1`; the default build still runs the complete
sequence.

⚠⚠ **Read the honesty rule before starting any of these: each stage states what it PROVES, and a
stage that shows the right picture for the wrong reason is a failure, not a milestone.** Displaying
a converted Mac screenshot is a display-path proof and nothing more — it must never be reported as
"the intro screen works".

⛔ **Deferred until execution asks for them:** the Event Manager (`GetNextEvent`, `SystemTask`)
and unobserved late manager operations. `PaintBehind`, `PurgeMem`, `CompactMem`, `DisableItem`,
`NewMenu`, `AppendMenu`, and the empty-`DRVR` `AddResMenu` case are now implemented because the
post-intro path reached them. Do not defer a trap that the loud-stop loop actually reaches.

⚠ **Refer to an item by its TITLE, not its number.** The list is renumbered every time an entry is
closed and deleted, so a `#N` written in another doc goes quietly wrong — three of them already had.

## Small, cheap, and wrong if left

## Phase 0 — scaffolding (see `docs/phases.md`)

4. **`src/platform/platform.h` + `Platform.cpp`** — the abstraction. ⚠ Deliberately NOT copied from
   either prior port: both interfaces are shaped around a 6502 memory bus and an OS-call marshalling
   ABI this port does not have. Write it from this port's own boundary, which the trap map defines.
5. **Port the standing checks.** `docs/amiga-lessons.md` prescribes counters that "must read 0"
   (`g_beamPresentsLate`) and probe scripts (`beam_watch.gdb`, `fill_catch.gdb`) that **do not exist
   in this repo**. A rule that names a counter is an instruction to build it.
6. **Close the inherited silent no-op.** `BitmapAssembler.s`'s two non-interleaved arms are
   unimplemented and retagged `[ASSUMED]`; either assert at `Bitmap` construction that nothing builds
   a non-interleaved one, or implement them. → `src/platform/amiga/framework/UPSTREAM.md`.
7. **One dormant link trap left in the vendored framework.** `Bitmap::patternWithMask()` pulls in
    `__mulsi3`, so it fails the mandatory `muldiv-audit` — with a message that names `__mulsi3`
    rather than the caller. Fix it when something needs it, not speculatively. →
    `src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.

8. ⚠ **The documented `CTRL`+LMB quit chord is not wired into the live Mac loop.** Keyboard state
    now exists, but `MacLoader::run()` does not return, so `PlatformAmiga`'s old bare-button wait is
    unreachable during normal play. Add a deliberate Control+LMB exit request at the event-pump
    boundary when teardown/return is implemented; do not consume ordinary Macintosh clicks.
    → `src/platform/amiga/PlatformAmiga.cpp`.

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
    2 490 B resource, in a single-player driving game. Modem head-to-head is a guess. It matters
    because 9 KB of code that the port may not need at all is 10% of the whole job.
15. **Explain `FRED`** — 6.5 KB in both builds, name says nothing. ⭐ New evidence, and it is a
    strong hint: `FRED` exports **242 of the 509 jump-table entries** — 6 508 bytes across 242
    externally-callable routines is **~27 bytes each**, so `[INFERRED]` it is a library of small leaf
    routines (maths/trig/fixed-point being the obvious candidates, which would fit the table-driven
    trig already found in the data). Cheap to settle: disassemble a dozen of its entries.
16. ⭐ **The two display questions that are still open** — the mode itself is now locked
    (4 bitplanes, hires interlaced; `PROJECT.md` §Decisions), so what remains is:
    **(a)** is the **in-game** surface 512 × 320 or **512 × 342**? One reference-loop probe of the
    front `WindowRecord`'s `portRect` past the garage screen. ⭐ Cheap, and do it on the next
    reference run rather than as its own trip.
    **(b)** is there an **OCS / 68000 fallback**, and which of crop / squeeze / none? ⚠ Gated on
    (a), because a 512 × 342 driving view makes every crop worse. → `PROJECT.md` §Open decisions.
    ⚠⚠ **Chunky → planar is a named, unbudgeted cost either way**, and whether it is even on the
    critical path is unknown: if the driving view is built from QuickDraw primitives, a
    planar-native trap layer skips it; if the game rasterises into the GWorld itself, it does not.
    ⛔ **Do not settle that from inference** — **The trap log stops at the MENU** rerun plus a write tap over the live GWorld's
    pixel range answers it by measurement. → `docs/mac-hardware.md` question 5.

17. ⭐ **Locate the copy-protection check, then patch it out.** Decision locked — patched, not
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
