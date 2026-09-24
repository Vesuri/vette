# Open work

The scoped single-player game and WHDLoad release are implemented.
This file tracks remaining limitations and optional work, not completed stages.

- Test on real Amiga hardware, especially 68030/68040 and differing memory
  configurations. The reported FS-UAE 68040-NOMMU + SetPatch startup failure is
  unresolved; cache flushing did not fix it.
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
