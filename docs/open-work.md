# Open work — THE QUEUE

⭐⭐ **“What is next?” is answered here, never by a session summary.** This is a queue, not a log:
an entry is deleted in the commit that closes it, and the evidence goes in the relevant technical
document. `make todo` prints this file plus a live marker sweep of the tracked, non-vendored tree.

⚠ Refer to an item by its title, not its number. Entries are deleted when closed, so numbering
changes.

⭐ **HEAD OF QUEUE: no required release work remains.** The scoped single-player port and its
structural/release phase are complete. The formal static map, gameplay coverage matrix, bounded
regressions, route-faithfulness checks, original-data installation, and reproducible copyright-clean
package are all gated. Car, opponent, course, difficulty, results, ordinary garage return, all four
race lifecycles, representative city/freeway transitions, necessary session controls, steering,
and persistent score data are covered. High Screen and Preferences are optional desktop UI and
deliberately remain named loud stops; Communications remains single-player only.

Long route traces are regressions, not the primary discovery mechanism. Enter unknown behavior
through the shortest faithful checkpoint available; do not patch game decisions merely to reach it.
For bounded driving that must follow the road, build with `GARAGE_CLICK=1 FOLLOW_ROAD=1`. Omitting
`FOLLOW_ROAD` preserves the straight-to-water collision/recovery fixture.

## Core game completion — complete

The required single-player paths, their demanded traps, and writable `TIME` score state are closed.
Optional classic-Mac desktop dialogs remain named loud stops instead of speculative compatibility
code. Copy-protection `DATE` and network `GNRL` persistence remain excluded with their parent
features.

## Structural verification and release — complete

Production boots from the two byte-identical original resource forks on disk. The complete bounded
matrix covers courses, vehicles, difficulties, damage/recovery, police, city/freeway transitions,
restart, return, normal and emergency quit, score writing, and AmigaOS restoration. The release is
deterministic and contains no copyrighted game data; its installer derives the two required raw
resource forks directly from the user's original StuffIt archive and validates the exact release.
The native `VetteInstallData` helper is self-contained; the older Python tools also accept NDIF
or raw HFS images. Native installation details and verification are in `docs/install-original-data.md`.

## Deferred until a real caller or later phase requires it

- **Further C2P optimization.** The verified dirty-list kernel averages about 260,675 ticks per
  moving update and occupies 39.097% of the target profile. This presentation cost behaves like a
  slower CPU and no longer blocks fidelity; preserve the current dirty-list design when revisiting
  it after core game completion.
- **Decode additional `VETTE!.Data` formats only when demanded.** `OBJS`, `QUAD`, `MAPS`, `COLL`,
  the used `PERF` prefix, road/bounds data, and exercised response families are already understood.
  Base further decoding on the load-segment disassembly, never visual guesses.
- `Bitmap::patternWithMask()` pulls in `__mulsi3`, so the mandatory `muldiv-audit` rejects a caller.
  Nothing uses it. Fix it if a real path needs it rather than weakening the audit.
- Unobserved manager operations remain loud. A dialog or window request reached only because an
  earlier subsystem failed is evidence to fix that subsystem, not authority to build a windowing
  system.
