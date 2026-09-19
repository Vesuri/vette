# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — current compatibility boundary

⭐ **HEAD OF QUEUE: define the shared platform boundary and move `main` off the Amiga backend.**
The runnable port now has a proven boundary: application startup asks a platform to run the
resident Macintosh program, while the Amiga implementation owns takeover, input, display, audio,
and restoration. Express that small boundary in `src/platform/platform.h` plus `Platform.cpp`, and
leave the backend-specific machinery behind it. Do not import either prior port's 6502 bus or OS
call interfaces; neither exists here.

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
crop is `(64,91,512,320)`; the offscreen 323-row composition and the following 320-row window copy
are recorded in `docs/stage-c.md`.

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

4. **Port the standing checks.** `docs/amiga-lessons.md` prescribes counters that "must read 0"
   (`g_beamPresentsLate`) and probe scripts (`beam_watch.gdb`, `fill_catch.gdb`) that **do not exist
   in this repo**. A rule that names a counter is an instruction to build it.
5. **Close the inherited silent no-op.** `BitmapAssembler.s`'s two non-interleaved arms are
   unimplemented and retagged `[ASSUMED]`; either assert at `Bitmap` construction that nothing builds
   a non-interleaved one, or implement them. → `src/platform/amiga/framework/UPSTREAM.md`.
6. **One dormant link trap left in the vendored framework.** `Bitmap::patternWithMask()` pulls in
    `__mulsi3`, so it fails the mandatory `muldiv-audit` — with a message that names `__mulsi3`
    rather than the caller. Fix it when something needs it, not speculatively. →
    `src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.

## Phase 1+ — carried forward, not yet actionable

7. **Write `ghidra_scripts/DumpTraps.java`.** The trap map is the abstraction boundary and there is
    no inherited script for it (Revs's `DumpHwAccesses.java` hardcodes BBC I/O ranges and was not
    carried over). → `docs/toolchain.md`.
8. **Fill `ghidra_scripts/entrypoints.csv` from `CODE 0`.** The jump table makes the postmortem's
    §1.1 sweep *enumerable* rather than a search — take the win.
9. **Read the manual / the extras before the binary.** RoF's `docs/manual.md` earned its place.
    Present and unread: `scans/Manual.pdf` (5.2 MB), `Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`,
    `Package.pdf`, `web_docs/cheats.txt`. ⭐ `KeyChart.jpg` is the input map and `cheats.txt` may
    name states worth reaching in the reference loop.
10. **Decode the `VETTE!.Data` record formats.** The *inventory* is done
    (`docs/source-inventory.md`); the formats are not. ⭐ Start with **`PERF`** — eight records of
    exactly 110 bytes with meaningful names (`Stock`, `ZR1`, `F40`, …), which is the cheapest
    possible place to calibrate a decode. Then `OBJS` (160 models, recurring exact sizes, and
    `QUAD`'s `Quad Discripter Data` says the renderer is quad-based) and `MAPS`. ⚠ Do this against
    the `load` segment's disassembly, not by pattern-guessing — RoF's postmortem §1.2 is about
    exactly this.
11. **Confirm or kill the `OBJS` two-level-of-detail reading.** The `C`/`S` name pairs
    (`F40C`/`F40S1`, `GenericC`/`GenericS`, `Taxi`/`TaxiS`, …) `[INFERRED]` a near/far pair per
    object. It is load-bearing for the Amiga frame budget, so it should be confirmed early rather
    than discovered during optimisation. → `docs/source-inventory.md` §OBJS.
12. **Explain the `Communication` segment and `COMM` 0.** 9.1 KB of code in *both* builds plus a
    2 490 B resource, in a single-player driving game. Modem head-to-head is a guess. It matters
    because 9 KB of code that the port may not need at all is 10% of the whole job.
13. **Explain `FRED`** — 6.5 KB in both builds, name says nothing. ⭐ New evidence, and it is a
    strong hint: `FRED` exports **242 of the 509 jump-table entries** — 6 508 bytes across 242
    externally-callable routines is **~27 bytes each**, so `[INFERRED]` it is a library of small leaf
    routines (maths/trig/fixed-point being the obvious candidates, which would fit the table-driven
    trig already found in the data). Cheap to settle: disassemble a dozen of its entries.
14. ⭐ **The remaining display question is the OCS / 68000 fallback** — crop, squeeze, or none.
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
