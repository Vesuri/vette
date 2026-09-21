# Open work — THE QUEUE

⭐⭐ **"What is next?" is answered here, never by a session summary** (which only remembers what
that session touched). ⚠⚠ **This is a QUEUE, not a log:** an entry is **DELETED** in the commit that
closes it, and what the work taught goes in the doc that was wrong. `make todo` prints this file
plus a live sweep for TODO/FIXME/HACK markers in the tracked, non-vendored tree.

## Blocking — current compatibility boundary

⭐ **HEAD OF QUEUE: establish a representative moving-driving fidelity/performance workload, then
fix what it measures.** Use a short deterministic checkpoint to capture the same moving scene on
the Macintosh reference and the target A1200 configuration (2 MiB chip, 8 MiB fast). Extend the
already exact named first-frame differential across motion, traffic, and the principal views while
measuring time separately in game logic, drawing, resource decoding, C2P, audio, and waiting. Fix
the highest measured visual discrepancy and performance cost in small, independently verified
commits. Do not infer either from an unsynchronised screenshot or emulator wall-clock time.

Long route traces are no longer the discovery mechanism. They are useful later as regressions, but
the next unknown behavior must be reached by a short, reproducible checkpoint run. In particular,
Main Map cell `(18,39)` and the natural-route class-2 `VETT`/`GGRY` collision at `(6,36)` are
compatibility debt, not blockers for fidelity or performance work.

⚠ **Refer to an item by its TITLE, not its number.** Entries are deleted when closed and the list
is consequently renumbered.

## Fidelity and performance — active queue

1. **Build the representative driving differential.** Compare synchronized original and Amiga
   sequences for geometry, object placement, palettes, surface heights, clipping, mirrors, traffic,
   animation, and the principal view modes—not merely one exact initial frame.
2. **Establish the performance target.** The full-accounting target-A1200 profile is now in place
   and identified presentation as 80.353% of the first moving-driving baseline. After removing a
   fully overwritten synchronization copy and adding the packed word-write C2P kernel, the focused
   100-field window attributes 55.955% to C2P, 0.240% to palette, and zero to synchronization.
   Measure the same synchronized workload on the original Macintosh and set the target from both
   results.
3. **Fix measured visual discrepancies.** Trace wrong pixels and geometry to their source data or
   implementation; do not add scene-, car-, or color-specific patches.
4. **Optimize measured bottlenecks.** Start with the measured C2P/back-buffer/palette presentation
   path, now narrowed specifically to conversion rather than palette or buffer synchronization.
   Prefer representation and algorithm changes before assembly; verify every optimization against
   the reference differential and preserve game behavior.
5. **Finish control fidelity.** Verify keyboard aliases, throttle, brake, steering, gears, mouse
   steering and buttons, pause/options controls, and a reproducible FS-UAE configuration that does
   not capture the keyboard as a joystick.
6. **Finish gameplay audio fidelity.** Verify engine pitch/load, gear changes, collisions, skids,
   horns, police, environment, and result audio, including concurrent playback and transitions.
7. **Automate fidelity regressions.** Keep intro and driving framebuffer differentials, palette
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

- `Bitmap::patternWithMask()` pulls in `__mulsi3`, so the mandatory `muldiv-audit` rejects any
  caller. Nothing uses it. Fix it if a real path needs it rather than weakening the audit.
- Unobserved manager operations remain loud. A dialog or window request reached only because an
  allocator or earlier subsystem failed is evidence to fix that subsystem, not authority to build
  a windowing system.

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
