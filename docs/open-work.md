# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — current compatibility boundary

⭐ **HEAD OF QUEUE: establish a representative moving-driving fidelity workload, then fix what it
measures.** Use a short deterministic checkpoint to capture the same moving scene on
the Macintosh reference and the target A1200 configuration (2 MiB chip, 8 MiB fast). Extend the
already exact named first-frame differential across motion, traffic, and the principal views while
measuring time separately in game logic, drawing, resource decoding, C2P, audio, and waiting. Fix
the highest measured visual discrepancy and performance cost in small, independently verified
commits. Do not infer either from an unsynchronised screenshot or emulator wall-clock time.

C2P and presentation time are host-machine costs: once Macintosh tick delivery and callback
semantics are faithful, they may reduce completed-frame cadence exactly as a slower CPU would, but
must not change the result for an equivalent complete game state. Further C2P tuning is deferred;
do not require the A1200 to reproduce the Macintosh's loop count or traffic phase at the same wall
time before continuing fidelity work.

Long route traces are no longer the discovery mechanism. They are useful later as regressions, but
the next unknown behavior must be reached by a short, reproducible checkpoint run. In particular,
Main Map cell `(18,39)` and the natural-route class-2 `VETT`/`GGRY` collision at `(6,36)` are
compatibility debt, not blockers for fidelity or performance work.

⚠ **Refer to an item by its TITLE, not its number.** Entries are deleted when closed and the list
is consequently renumbered.

## Fidelity and performance — active queue

1. **Build the representative driving differential.** Compare synchronized original and Amiga
   sequences for geometry, object placement, palettes, surface heights, clipping, mirrors, traffic,
   animation, and the principal view modes—not merely one exact initial frame. State-keyed capture
   now proves two shared stationary-render states (RPM 11 and 23) exact across 350,208 active pixels.
   The moving harness reaches gear 1 through the original shift scanner and captures 37 Macintosh
   and 40 Amiga source frames at the same full-window CopyBits boundary. Earlier naturally shared
   states proved the 512x198 exterior viewport exact and traced residual dashboard pixels to
   different original Traffic state. The target now dispatches a distinct Vertical Retrace
   Manager pass for every 60 Hz Macintosh tick, including both virtual ticks on every fifth PAL
   field. The pre-driving trace then found and fixed a genuine boundary error: QuickDraw `Random`
   had advanced the redirected Page-0 system `RndSeed`, rather than the application `randSeed` at
   `thePort-126` that Vette seeds and QuickDraw owns. A diagnostic-only `$3BD90000` fixture now
   synchronizes the first road-setup call after MAME's three selector-animation calls, which the
   accelerated Amiga harness intentionally skips. Both first captures consequently contain the
   same `VETT`, `OPPO`, `TAXI` roster. After the C2P work, completed-frame cadence improves from
   about thirteen to ten or eleven Amiga ticks versus roughly seven on the Mac, and three complete
   player tuples now align naturally. The capture records both the verified `Main+$1FD2` driving
   iteration and the absolute second-live-VBL-task callback phase. It proves the Macintosh reaches
   its first moving frame after 333 driving-task callbacks and 45 original loop iterations versus
   109 callbacks and 27 iterations on the faster Amiga setup. `Traffic+$18EC` begins an object pass
   by copying cached position to physics position, and `Traffic+$0BB2` advances TAXI by the measured
   motion delta; the extra pre-motion loop passes therefore explain its accumulated offset. A
   loop-45 target experiment brought TAXI to within one update but had already changed the spawn
   roster, proving that spawn/deadline phase is independent. The new source-level initialization
   trace corrects the earlier interpretation of `Traffic+$2006`: it only links a zeroed, pre-tagged
   pool record. Its `Traffic+$24DE` caller assigns the type and runs the real initializer before
   converging at `$2528`. With the synchronized seed both machines test `COP!`, `GGRY`, then `TAXI`
   and initialize TAXI to exactly `(0x3060,0x2800)`; their tests are also separated by the same
   roughly 40 ticks. Over those first 80 ticks, however, the Mac delivered 26 driving-task
   callbacks and the Amiga only six. The safe-point trampoline now drains every due queue pass
   before resuming the game and presents each callback with its pass's historical `Ticks` value;
   the same interval now delivers 25 callbacks on Amiga. A new motion capture reduces paired-frame
   raster differences from 6,948 to 105 pixels, but TAXI remains behind because its physics pass is
   driven by completed main-loop iterations: the Macintosh reaches the first moving state after 45
   loops at roughly 6–7 ticks per frame, the A1200 after 26 loops at roughly 11–12. All three paired
   frames have different Traffic object state, so their 105 changed pixels are not valid rendering
   discrepancies; they measure the expected phase difference between machines of different speed.
   Make the differential require equivalent full object state, establish such a state through a
   short diagnostic checkpoint when natural captures do not share one, then extend the exact gate
   to motion, traffic, mirrors, and alternate views.
2. **Establish the performance target.** The full-accounting target-A1200 profile is now in place
   and identified presentation as 80.353% of the first moving-driving baseline. After removing a
   fully overwritten synchronization copy, adding the packed word-write C2P kernel, and deriving a
   dirty list from the driving renderer, a four-pixel/256-KiB fast-RAM lookup now halves the
   kernel's table reads. A second 256-KiB pre-shifted copy removes the remaining shift between each
   lookup pair. Its latest assembly/C verifier covers 2,685,680 bytes with zero failures and improves
   the controlled C/assembly ratio from 2.521 to 2.798, about 9.9% less kernel time. Rotating both
   tables around a midpoint base then lets the 68020 use its sign-extended word index directly,
   removing eight register clears per 32 pixels without more memory. That verifier covers 2,685,632
   bytes with zero failures and raises the ratio to 2.927, another 4.4% controlled reduction. The
   A1200-scaled-index kernel is verified across 3,243,112 bytes with zero failures. The warmed
   100-field window averages about 302,406 C2P ticks per update, down 18.0% from the prior 368,582,
   28.0% from the first dirty-list kernel's 419,939, and 45.6% from full-frame conversion's
   555,388. The kernel now walks each whole dirty rectangle per call instead of saving registers
   once per row. Its verifier covers another 3,068,576 plane bytes with zero failures; the current
   300-field profile averages about 287,054 C2P ticks per update, a further 5.4% reduction. A nested
   bracket proved generic CopyBits itself owned 2,914,419 of 2,957,204 drawing ticks over 32 calls:
   98.6% of that row. The fixed 260-to-256-byte driving publish now has a byte-exact 68000 assembly
   path. Its in-process oracle compared 2,048,000 bytes over 25 calls with zero failures and measured
   it at 2.366 times the C path's speed. The following 300-field profile records about 38,036 ticks
   per publish and reduces the complete drawing row from 12.342% to 5.554%. With the pre-shifted
   lookup, the following standard profile records 9,766,871 C2P ticks over 35 updates, about 279,053
   each versus 292,221 immediately before it. The signed-index layout then records 9,384,319 ticks
   over 36 updates, about 260,675 each, and C2P remains the largest port-owned row at 39.097%.
   Measure the same synchronized workload on the original Macintosh and set the target from both
   results.
3. **Fix measured visual discrepancies.** Trace wrong pixels and geometry to their source data or
   implementation; do not add scene-, car-, or color-specific patches.
4. **Finish control fidelity.** Verify keyboard aliases, throttle, brake, steering, gears, mouse
   steering and buttons, pause/options controls, and a reproducible FS-UAE configuration that does
   not capture the keyboard as a joystick.
5. **Finish gameplay audio fidelity.** Implement the measured Bogas wrapper surface over Paula,
   The complete wrapper surface now has a Pascal-compatible private-trap bridge. Live driving calls
   `BogasPlay` from `Traffic+$3762` about
   once per completed frame, with its long argument following RPM from 27,000 upward while the word
   argument remains zero. Initialization opens contexts 0, 1, and 2; the engine is loaded into
   context 0, while bounded driving loads effects into context 2. The original sixteen-name
   initialization now resolves the complete ordinal table; the first observed effects are beep1,
   beep2, and crash, and they begin on `BogasLoad` rather than a later `BogasPlay`. Preserve the
   source wrapper's Pascal arguments/results rather than adding scene-specific triggers. Engine,
   beep1, beep2, and crash now reach Paula from those calls. Shipped BGAS code confirms the Load
   countdown and context-0 16.16 mixer-step semantics; INST loop points are programmed into Paula's
   reload registers and direct effects use their declared source rates. The driver proves its three
   inputs are fixed voices. Paula now preserves all three without software mixing: the engine is
   centred on AUD0/1 and contexts 1/2 occupy AUD3/AUD2. Each load replaces only its own context.
   Command `$08` proves that Vette's `BogasPurge(300)` builds the Macintosh software mix table, but
   an exhaustive INST scan proves ten samples already reach signed full scale. The Amiga bridge
   therefore maps that absolute maximum directly to Paula volume 64, retaining quieter samples'
   authored headroom and avoiding Paula's below-64 resampling artifacts. Next
   compare the result to
   reference audio, then drive real pause/exit paths to establish Stop/Deactivate/Dispose behavior
   (the ordinary intro calls Close/Purge during initialization and Start/Set at its exit), then
   cover gear changes, collisions, skids, horns, police, environment, and result audio, including
   concurrent playback and transitions.
6. **Automate fidelity regressions.** Keep intro and driving framebuffer differentials, palette
   checks, clean-build audits, and eventually basic audio comparisons reproducible.

## Core game completion — after the fidelity/performance pass

1. **Complete one race lifecycle.** Prove garage → choices → countdown → driving → finish →
   win/loss → garage using short checkpoints and the original game code.
2. **Complete adverse gameplay outcomes.** Exercise ordinary and severe collisions, cumulative
   damage, repair, tow, water/lake recovery, police tickets/arrest, and terminal outcomes. Existing
   isolated damage and recovery proofs do not prove every enclosing game-state transition.
3. **Cover every course and materially different mode.** Check representative starts, junctions,
   map boundaries, freeway transitions, and finishes for every course, then cars, opponents,
   difficulty levels, and practice/qualifying/race variants. Do not drive for hours to reach a
   state that can be entered faithfully with a checkpoint.
4. **Finish necessary game UI paths.** Cover the garage, dynamometer, car/opponent/course/difficulty
   choices, options, pause, quit, results, and return paths. Leave unnecessary classic Mac desktop
   UI unimplemented so an erroneous fallback remains a loud failure.
5. **Implement only traps demanded by real paths.** Every unknown trap reached by the scenarios
   above must either be implemented faithfully or remain a named loud stop. Recheck all resource
   types the game actually consumes; do not implement unused managers speculatively.
6. **Verify resources and persistence.** Determine from code whether preferences, high scores,
   saved settings, or other writable state are required, then implement only what is used.
7. **Decide communications scope.** Either support the original head-to-head/communication mode
   for the fidelity target or record its explicit deferral from the first packaged release.

## Structural verification and release — after core game completion

1. **Finish the formal static map.** Close the remaining trap-site, low-memory, A5-global,
   entry-point, symbol-naming, and static-coverage gates in `docs/phases.md`.
2. **Build the gameplay coverage matrix.** Record the courses, modes, scenarios, traps, resources,
   and endings actually exercised, with short reproducible commands for each.
3. **Add gameplay regressions.** Automate checkpoint scenarios and the production trap audits.
4. **Resolve route-faithfulness debt.** Once the state paths work, revisit the `(6,36)` collision,
   `(18,39)` boundary, and other failures found only during natural traversal. Passing a checkpoint
   does not excuse a broken route in the final game.
5. **Decode additional `VETTE!.Data` formats only when demanded.** `OBJS`, `QUAD`, `MAPS`, `COLL`,
   the used `PERF` prefix, road/bounds data, and the currently exercised response families are
   already understood. Base further decoding on the load-segment disassembly, never visual guesses.
6. **Harden production builds.** Repeated clean builds and long runs must survive without resource
   leaks, stale diagnostic state, or broken quit/restart behavior.
7. **Package the game.** Deliver the executable/disk or WHDLoad-style package, Amiga-readable data
   conversion flow, launch configuration, user instructions, and measured machine requirements.

## Deferred until a real caller exists

- **Further C2P optimization.** The verified dirty-list kernel now averages about 260,675 ticks per
  moving update and occupies 39.097% of the target profile. That is an important eventual speed
  target, but it is a host presentation cost rather than a game-logic fidelity failure. Return to
  it after the moving-state, controls, and audio gates, unless measurement proves it is breaking
  callback semantics rather than merely reducing completed-frame cadence. Preserve the current
  dirty list; do not revive the measured dead ends below.

- `Bitmap::patternWithMask()` pulls in `__mulsi3`, so the mandatory `muldiv-audit` rejects any
  caller. Nothing uses it. Fix it if a real path needs it rather than weakening the audit.
- Unobserved manager operations remain loud. A dialog or window request reached only because an
  allocator or earlier subsystem failed is evidence to fix that subsystem, not authority to build
  a windowing system.

## ⛔ CLOSED — measured dead ends

*Read this section before proposing a lever, so a negative result is not re-derived.
Each entry is ONE line: what was tried, what it measured, and the doc that has the detail.*

- **Use renderer dirty rectangles for the final chunky CopyBits** — exact over 40 frames and cut
  transferred data to about 63.3 KiB in 14 coalesced rectangles per update, but the required
  260-byte-source/256-byte-destination row walks made its core about 16.7% slower than the generic
  80 KiB copy; removed. `docs/perf-method.md`.
- **Pipeline C2P chip writes between table lookups** — byte-exact across 2,684,832 output bytes,
  but Kalms-style two-pairs scheduling lowered the controlled C/assembly ratio from 2.521 to 2.315;
  the extra loop structure made the kernel slower, so it was removed. `docs/perf-method.md`.
- **Unroll the C2P kernel from 32 to 64 pixels** — byte-exact across 2,684,832 output bytes, but
  the controlled C/assembly ratio fell from 2.927 to 2.711; doubled inner-loop code and extra tail
  dispatch cost more than the halved branch count, so the 32-pixel loop was restored.
  `docs/perf-method.md`.

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
