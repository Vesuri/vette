# Open work — THE QUEUE

⭐⭐ **“What is next?” is answered here, never by a session summary.** This is a queue, not a log:
an entry is deleted in the commit that closes it, and the evidence goes in the relevant technical
document. `make todo` prints this file plus a live marker sweep of the tracked, non-vendored tree.

⚠ Refer to an item by its title, not its number. Entries are deleted when closed, so numbering
changes.

⭐ **HEAD OF QUEUE: Add gameplay regressions.** Core single-player game completion, the formal
static map, and the gameplay coverage matrix are closed.
Car, opponent, course, difficulty, results, ordinary garage return, all four race lifecycles,
representative city/freeway transitions, necessary session controls, Steering, and persistent score
data are covered. High Screen and Preferences are optional desktop UI and deliberately remain named
loud stops; Communications remains single-player only.

Long route traces are regressions, not the primary discovery mechanism. Enter unknown behavior
through the shortest faithful checkpoint available; do not patch game decisions merely to reach it.
For bounded driving that must follow the road, build with `GARAGE_CLICK=1 FOLLOW_ROAD=1`. Omitting
`FOLLOW_ROAD` preserves the straight-to-water collision/recovery fixture.

## Core game completion — complete

The required single-player paths, their demanded traps, and writable `TIME` score state are closed.
Optional classic-Mac desktop dialogs remain named loud stops instead of speculative compatibility
code. Copy-protection `DATE` and network `GNRL` persistence remain excluded with their parent
features.

## Structural verification and release — after core game completion

1. **Add gameplay regressions.** Automate checkpoint scenarios and the production trap audits.
2. **Resolve route-faithfulness debt.** Revisit the `(6,36)` collision, `(18,39)` boundary, and
   other failures found only during natural traversal. Passing a checkpoint does not excuse a
   broken route in the final game.
3. **Decode additional `VETTE!.Data` formats only when demanded.** `OBJS`, `QUAD`, `MAPS`, `COLL`,
   the used `PERF` prefix, road/bounds data, and the exercised response families are understood.
   Base further decoding on the load-segment disassembly, never visual guesses.
4. **Harden production builds.** Repeated clean builds and long runs must survive without resource
   leaks, stale diagnostic state, or broken quit/restart behavior.
5. **Package the game.** Deliver the executable/disk or WHDLoad-style package, Amiga-readable data
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
