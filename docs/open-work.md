# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — current compatibility boundary

⭐ **HEAD OF QUEUE: cross a real Main Map -> Freeway Map transition, then trace the first freeway
traffic replacement.** Natural distance retirement is proved at `Traffic+$252C/$257A/$1FB6` and
ordinary city spawning immediately refills the freed slot. The remaining gate is A5-$3764: merely
driving into FWTP-key cell `(2,23)` leaves it clear, so the dispatcher correctly stays on the city
branch. The start survey proves that Courses One, Three, and Four all begin at `(6,2)`, while
Course Two begins at `(2,24)`; simple Manhattan proximity is misleading because full-cell static
bounds isolate the `(2,6)` lane from the shared start. Reach one of the QUAD-selected transition
responses through ordinary race input, then use
`amiga/driving_freeway_spawn.gdb` and `amiga/driving_freeway_movement.gdb` to capture the first
natural `FWTP` -> `JHPF` replacement and its `FWTM` -> `FREE` movement. Do not patch the mode,
count, position, or spawn state merely to make a breakpoint fire. `TURN` is loaded but unread and
`PHAZ` is never requested, so their names do not justify speculative work. → `docs/data-formats.md`.

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

- **Make the original Mouse steering mode effective.** Its Page-0 accesses are safely redirected
  and the menu can select it, but physical testing found no steering, throttle, or braking response.
  Keep Keyboard as the default until the live mode flags, shadow coordinates, and active-low button
  state are traced through the original consumers.

## Phase 0 — scaffolding — COMPLETE (see `docs/phases.md`)

⚠ One dormant framework link trap remains intentionally deferred: `Bitmap::patternWithMask()`
pulls in `__mulsi3`, so the mandatory `muldiv-audit` rejects any caller. Nothing uses it. Fix the
implementation when a real path needs it, rather than weakening the audit or speculating. →
`src/platform/amiga/framework/UPSTREAM.md` §Two latent link traps.

## Phase 1+ — carried forward, not yet actionable

1. **Decode the `VETTE!.Data` record formats.** The *inventory* is done
    (`docs/source-inventory.md`); the formats are not. `PERF` now has a proved 37-word race-template
    prefix; its remaining 17 words are unreferenced dead data in both v1.02 executables.
    `OBJS`, `QUAD`, the outer `MAPS` grids, and `COLL` are now decoded; the QUAD-selected static
    bounds, packed road word, Lake Merced response, other static response families, and moving-object
    separation, traffic response, damage, repair and terminal recovery are closed. ⚠ Do this against
    the `load` segment's disassembly, not by pattern-guessing — RoF's postmortem §1.2 is about
    exactly this.
2. ~~**Explain `FRED`.**~~ **COMPLETE.** The 270-entry QUAD command/factory table references 241
    of its exports; the remaining export is the directly-called per-frame background-band fill.
    It is the world-construction callback library for fixed scenery and placed objects, not generic
    maths. → `docs/data-formats.md` §QUAD dispatch.
3. ~~**Settle the OCS / 68000 fallback.**~~ **COMPLETE.** The exact 512×384 display is legal on
    OCS, so crop and squeeze modes buy nothing. The supported package target is the user-selected
    A1200 with 2 MiB chip and 8 MiB fast; there is no separate OCS support promise. The code keeps
    68000 generation and legacy-correct window arithmetic. → `PROJECT.md` §Closed decisions.

## ⛔ CLOSED — measured dead ends

*Read this section before proposing a lever, so a negative result is not re-derived.
Each entry is ONE line: what was tried, what it measured, and the doc that has the detail.*

- **68020-only instructions in the game** — none. Flow-following sweep of all 509/507 jump-table
  entries in both builds, 67.9 %/63.1 % of code bytes reached, **0** found; the unreached bytes are
  shown to be data by a self-calibrated linear control (18.4 vs 0.07 candidates/KB).
  `tools/m68k_sweep.py`, `docs/mac-hardware.md`.
- **Whole-file LINEAR 68020 sweep** — unusable as evidence: it decodes data as code and yields
  `callm`/`rtm`/`cmp2`/`pack` by the dozen. `docs/mac-hardware.md`.
- **Use the T key as a freeway shortcut during a race** — all five ordinary key presses reached
  `Main+$3456`, but A5-$5318 was zero and the shipped Tour handler rejected them without changing
  its index or the player position. Tour Mode exists as a separate Options-menu state; do not
  patch its guard merely to turn its 26 sightseeing coordinates into a diagnostic teleporter.
  `docs/stage-c.md`.
