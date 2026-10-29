# Open work

The scoped single-player game and WHDLoad release are implemented.
This file tracks remaining limitations and optional work, not completed stages.

- Test on real Amiga hardware, especially 68030/68040 and differing memory
  configurations. The reported FS-UAE 68040-NOMMU + SetPatch startup failure is
  unresolved; cache flushing did not fix it.
- 68040/68060 copyback data cache under WHDLoad. With the data cache on (`CACHE`,
  or `CACHECHIPDATA`'s values), an FS-UAE `a1200-040` run with `CACHE` and
  `a1200-060` runs with either reached the game's fatal alert in Initialize's
  buffer setup (DLOG 700 via `Initialize+$1A40`; loud stop at GetDItem,
  `Initialize+$1AA6`) in a `SKIP_INTRO=1 GARAGE_CLICK=1 FOLLOW_ROAD=1` build. No
  Memory Manager allocation failed. The result is deterministic per binary but
  disappears when diagnostic code moves the layout, so it may be the port or
  FS-UAE's non-cycle-exact 040/060 MMU core; it may share a cause with the
  report above. The slave therefore keeps 040/060 data caching off. Before
  enabling it, reproduce with `tools/test_whdload.py --setup a1200-040` against a
  slave variant and require driving under `CACHE` on 040 and 060.
- Further C2P optimization is deferred. Preserve explicit dirty rectangles and
  source-derived bounds, not shadow-buffer or tile comparisons.
- A native options interface is not implemented. The Macintosh menu bar/desktop
  are hidden; supported keyboard shortcuts remain available. Optional High Screen
  and Preferences dialogs remain named loud stops.
- Decode additional resource fields or implement additional manager operations
  only when a genuine single-player caller requires them. Do not add UI merely
  to conceal a failure elsewhere.

Network play is explicitly out of scope. The complete original CODE set stays
resident, but communications paths are unsupported.

Use [gameplay-coverage.md](gameplay-coverage.md) for existing regression scope
and [development.md](development.md) for commands. Enter a new behavior through
the shortest source-faithful fixture; long route traces are regressions, not
the default discovery method.
