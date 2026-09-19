# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — current compatibility boundary

⭐ **HEAD OF QUEUE: build a driving reference differential at one named game state.**
Complete frames are presented at the exact original `Main+$1FD2` loop boundary;
sustained driving covers 6,422 Macintosh ticks and 143/143 frames at implemented depth 93 without
a loud stop. Corrected Escape takes the shipped Menu Options exit at tick 1,864 after 32/32 frames.
The physical-style queued down/up regression proves both edges are consumed after exit, but the
settled result remains at depth 94 without a loud stop: the upper 198-row driving viewport is
cleared, the dashboard remains, and execution waits in the supported outer event loop. That branch
is closed for compatibility discovery. F1 is also now measured: it remains in driving at depth 93,
presents 65/65 frames without a loud stop, and its 40th presented surface differs from the
frame-matched baseline in 53,940 of 81,920 packed bytes. The view branch therefore executed; this
is not merely proof that a key was queued. F5 “Front Dash” is measured too: it remains at depth 93
through 70/70 frames and changes 31,214 packed bytes at the matched 40th presentation, removing the
cockpit/dashboard overlay while retaining the forward road and mirror. P is now measured as well:
Mac virtual `$23` dispatches through the game's live key table to `Initialize+$1862`, stops frame
production at a complete-frame boundary, blanks the upper viewport while retaining the dashboard,
and settles at depth 94 without a loud stop. S is now measured too: Mac virtual `$01` dispatches
to `Main+$3134`, changes the game's own sound flag from 1 to 0, calls the resident `sound` segment
at offsets `$021C`/`$024C`, and remains in active driving through 50/50 frames at depth 93 without
a loud stop. A then closes the planned transmission-state slice: Mac virtual `$00` dispatches to
`Main+$31AA`, changes the current car's automatic-shift field from 1 to 0, advances the game's
transmission gate from 0 to 1, and remains at depth 93 through 50/50 frames without a loud stop.
The deliberate control matrix has reached no new compatibility boundary. The extended Macintosh
run now reaches driving, raises the measured trap floor from 51 to 63, and reads a 512×320 front
window above the separate 512×342 surface. An initial unsynchronised capture has already closed
the color-realization branch: the Macintosh and Amiga source RGB tables match entry for entry, as
do their destination/device RGB tables; each machine gives source and destination the same
`ctSeed`; and both live copies are index-preserving `srcCopy` operations over exactly
`(0,0)-(342,512)`. Rendering the captured packed pixels through the captured destination tables
also gives the same light-blue sky, blue horizon band, dark road, and gray dashboard on both
machines. The old pink-road/salmon-car frame is not produced by the current build. Next synchronize
vehicle, input, and frame boundary and compare the packed indices themselves. The first mismatch
then belongs to simulation or rendering, not palette realization or Amiga bitplane order. Do not
return to straight-line accelerator soaking or exhausted PICT/palette work.

The key chart labels Escape “Menu Options,” which exposed a real input gap: the driving loop does
not call `GetNextEvent`, so each CIA keyboard edge updates the corresponding bit in the full
Macintosh KeyMap while also remaining in the event queue. That timing matters beyond driving
frames: P enters an original wait that reads Page-0 KeyMap directly without making another Toolbox
call. Refreshing only at the frame boundary made the released key permanent there. The first
probe also exposed a byte-local bit-order bug: the port wrote virtual Escape `$35` as byte 6 bit
`$04`, but the game's scanner at `Main+$2DD2` consumes each byte LSB first, making that virtual key
`$32`. Correct Escape is byte 6 bit `$20`, and keypad 8 `$5B` is byte 11 bit `$08`. The dedicated
probes now prove both: keypad 8 reaches the original scanner as virtual `$5B`, and held Escape takes
the Menu Options exit. `INPUT_PROBE_EVENT_RAW_KEY` additionally injects one diagnostic-only
physical-style down/up pair through the CIA queue's own state/update helper, with the release timed
at the exact exit boundary. Production builds never define it.

The MAME A-trap log remains a measured reference-run inventory → `docs/trap-log.md`,
but Stage C has proved that it is **not an exact standalone-port first-use script**. The port has
already executed initialization calls absent from, or much later in, that 63-row ordering. Treat
63 and the intro's 36 as floors until the tracer omission is explained. Three earlier questions
are nevertheless answered:
the game patches exactly one trap (`_ExitToShell`), `%A5Init` calls exactly one (`_BlockMove`), and
`QDExtensions` is dispatched by `D0` with Target 1 needing selectors 0 (`NewGWorld`) and
1 (`LockPixels`).

1. ✅ **The copy-protection requester is removed in the port.** It first fired after Course One was
   accepted. `Main+$05FE` is now replaced only after verifying the exact shipped 12-byte prologue;
   the replacement sets `protection passed = -1`, clears the retry flag, and returns. This is the
   state left by the correct-answer path, without implementing `GetDItem`, text editing, modal
   events, or persistent writable resources. ⚠ Ground truth still runs the **unpatched** original.

2. ⚠ **`512×323` vs `512×320` is unreconciled.** The intro's first `DrawPicture` destination rect
   is 512 wide by **323** tall `[MEASURED]`; `docs/mac-hardware.md` records the game painting
   **320** rows at (64,92). Three rows are unexplained — clipped, or the recorded 320 is short.
   Settle it before the Stage A viewport geometry is fixed, by capturing the GWorld and the screen
   at frame 1758 and diffing the row extents. The separate driving-size question is closed and does
   not answer these three intro rows.

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
16. ⭐ **The remaining display question is the OCS / 68000 fallback** — crop, squeeze, or none.
    The primary mode is locked at four-bitplane hires interlaced, and the reference run now proves
    the live driving front window is 512×320 above a separate 512×342 surface. The driving
    `CopyBits` probe also proves the game rasterises into its indexed GWorld, so chunky→planar is
    a real critical-path cost rather than a hypothetical one. → `PROJECT.md` §Open decisions.

## ⛔ CLOSED — measured dead ends

*Read this section before proposing a lever, so a negative result is not re-derived.
Each entry is ONE line: what was tried, what it measured, and the doc that has the detail.*

- **68020-only instructions in the game** — none. Flow-following sweep of all 509/507 jump-table
  entries in both builds, 67.9 %/63.1 % of code bytes reached, **0** found; the unreached bytes are
  shown to be data by a self-calibrated linear control (18.4 vs 0.07 candidates/KB).
  `tools/m68k_sweep.py`, `docs/mac-hardware.md`.
- **Whole-file LINEAR 68020 sweep** — unusable as evidence: it decodes data as code and yields
  `callm`/`rtm`/`cmp2`/`pack` by the dozen. `docs/mac-hardware.md`.
