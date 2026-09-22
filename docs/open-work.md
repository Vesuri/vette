# Open work — THE QUEUE

⭐⭐ **“What is next?” is answered here, never by a session summary.** This is a queue, not a log:
an entry is deleted in the commit that closes it, and the evidence goes in the relevant technical
document. `make todo` prints this file plus a live marker sweep of the tracked, non-vendored tree.

⚠ Refer to an item by its title, not its number. Entries are deleted when closed, so numbering
changes.

⭐ **HEAD OF QUEUE: Cover materially different race modes.** All four course selections, genuine
starts, source-defined finish handlers, Score, and garage returns are proven. Now check representative
junctions, map boundaries, and freeway transitions across them, then practice/qualifying/race
variants. All three difficulties are proven through selection, finish, damage, police, motion, and
cruise-control branches. All four player cars and all four opponents are proven through their UI
selectors, live PERF records, and complete paired lifecycles.

Long route traces are regressions, not the primary discovery mechanism. Enter unknown behavior
through the shortest faithful checkpoint available; do not patch game decisions merely to reach it.
For bounded driving that must follow the road, build with `GARAGE_CLICK=1 FOLLOW_ROAD=1`. Omitting
`FOLLOW_ROAD` preserves the straight-to-water collision/recovery fixture.

## Core game completion — active queue

1. **Cover materially different race modes.** The four course starts and complete finish lifecycles
   are closed. Check representative junctions, map boundaries, and freeway transitions across them,
   then practice/qualifying/race variants. Player-car, opponent, and TRAINEE/ROOKIE/PRO selection,
   lifecycle, and distinct difficulty behavior are closed. Do not drive for hours to reach a state
   that can be entered faithfully with a checkpoint.
2. **Finish necessary game UI paths.** Car, opponent, course, difficulty, results, and ordinary
   garage-return paths are closed. Cover the remaining garage/dynamometer, options, pause, and quit
   paths. Leave unnecessary classic Mac desktop UI unimplemented so an erroneous fallback remains
   a loud failure.
3. **Implement only traps demanded by real paths.** Every unknown trap reached by the scenarios
   above must either be implemented faithfully or remain a named loud stop. Recheck all resource
   types the game actually consumes; do not implement unused managers speculatively.
4. **Verify resources and persistence.** Determine from code whether preferences, high scores,
   saved settings, or other writable state are required, then implement only what is used.

## Structural verification and release — after core game completion

1. **Finish the formal static map.** Close the remaining trap-site, low-memory, A5-global,
   entry-point, symbol-naming, and static-coverage gates in `docs/phases.md`.
2. **Build the gameplay coverage matrix.** Record the courses, modes, scenarios, traps, resources,
   and endings actually exercised, with short reproducible commands for each.
3. **Add gameplay regressions.** Automate checkpoint scenarios and the production trap audits.
4. **Resolve route-faithfulness debt.** Revisit the `(6,36)` collision, `(18,39)` boundary, and
   other failures found only during natural traversal. Passing a checkpoint does not excuse a
   broken route in the final game.
5. **Decode additional `VETTE!.Data` formats only when demanded.** `OBJS`, `QUAD`, `MAPS`, `COLL`,
   the used `PERF` prefix, road/bounds data, and the exercised response families are understood.
   Base further decoding on the load-segment disassembly, never visual guesses.
6. **Harden production builds.** Repeated clean builds and long runs must survive without resource
   leaks, stale diagnostic state, or broken quit/restart behavior.
7. **Package the game.** Deliver the executable/disk or WHDLoad-style package, Amiga-readable data
   conversion flow, launch configuration, user instructions, and measured machine requirements.

## Deferred until a real caller or later phase requires it

- **Further C2P optimization.** The verified dirty-list kernel averages about 260,675 ticks per
  moving update and occupies 39.097% of the target profile. This presentation cost behaves like a
  slower CPU and no longer blocks fidelity; preserve the current dirty-list design when revisiting
  it after core game completion.
- `Bitmap::patternWithMask()` pulls in `__mulsi3`, so the mandatory `muldiv-audit` rejects a caller.
  Nothing uses it. Fix it if a real path needs it rather than weakening the audit.
- Unobserved manager operations remain loud. A dialog or window request reached only because an
  earlier subsystem failed is evidence to fix that subsystem, not authority to build a windowing
  system.
