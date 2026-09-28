# Measured rendering optimizations

Measured 2026-09-29 in FS-UAE's PAL A1200 configuration: 68020, 2 MiB Chip RAM,
8 MiB Fast RAM, normal lores crop. These are emulated machine timings, not host
wall-clock timings or measurements on physical hardware.

Each version ran twice, measuring 120 complete driving iterations and 120
presented frames after twelve settling iterations in the parked street at cell
(25,32). Position remained (51328,66563), speed and gear stayed zero, and each run
ended with ten active traffic objects. All versions used random seed 0x3BD90000.
The original simulation and traffic continued; this fixes the workload setup,
not every time-dependent traffic state. No PROBES, VERIFY, FILLWATCH, shadow copy,
or instruction trace was active during timing. The debugger stopped only at
presentation boundaries; elapsed PAL fields and beam phase supplied the clock.

| Version | Mean ms/frame | FPS | Frame time reduction | Repeat range (ms) |
| --- | ---: | ---: | ---: | ---: |
| Full-frame copy baseline | 166.344 | 6.012 | 0.00% | 166.342–166.345 |
| Direct C2P | 156.883 | 6.374 | 5.69% | 156.875–156.890 |
| Plus port bookkeeping fixes | 155.233 | 6.442 | 6.68% | 155.233–155.233 |
| Plus game copy-loop optimization | 147.648 | 6.773 | 11.24% | 147.648–147.648 |

The final version uses **11.24% less time per frame**, corresponding to **12.66%
higher throughput** than the full-copy baseline. The port bookkeeping changes
alone save 1.05% relative to direct C2P; the game copy loop then saves 4.89%.
The largest within-version spread was 0.015 ms/frame, well below these effects.
These figures apply to this scene and machine configuration, not every view or CPU.

## Changes and correctness

- Direct C2P reads the resident GWorld with its 260-byte stride and retains the
  existing dirty rectangles. Screen consumers and transitions still materialize
  the logical Mac screen when needed.
- Dirty tracking returns immediately for already-covered bounds and omits
  exterior bounds already covered by the unconditional driving-view rectangle.
- Hidden mouse sprites use the existing empty sprite; no hidden rows are rebuilt.
- A 256-entry palette lookup exactly reproduces the prior threshold conversion.
  Every possible input high byte was compared with the committed implementation.
- Traffic+$67E6's byte-at-a-time copy row uses longwords on the supported 68020.
  The original clipping, row strides, caller, dirty hook and game decisions remain.
  Installation checks all four original instruction words. Forward overlaps of
  one to three bytes use byte copying. All registers, pointer advancement and CCR
  results are preserved, including the original final-byte N/Z flags and X bit.

The row differential ran 866 cases against the exact original byte-loop operations:
four alignments, short and maximum DBF lengths, forward/backward overlap, disjoint
buffers and both X states. Every memory byte and every register/CCR result matched.
Forty-five parked frames made zero full-frame copies with zero assembly/C C2P or
rolling planar mismatches. Forty-five moving-frame publications also matched the
logical-screen oracle byte for byte with no planar mismatches. Dynamic viewport
and mouse transitions, the production/intro-audio/driving smoke suite, and a full
race-finish/score/garage return also passed. The final normal build passed the
software multiply/divide and probe-symbol audits.

The optimized game row now executes in the executable's native code. That moves
its time between profiler labels; the table measures the whole frame, so moving
work between labels cannot produce the reported speedup by itself.

## Reproduction

Run each stage from the repository root (local original game data and FS-UAE
prerequisites are described in development.md):

```sh
bash amiga/benchmark.sh legacy
bash amiga/benchmark.sh direct
bash amiga/benchmark.sh port
bash amiga/benchmark.sh game
python3 tools/report_parked_benchmark.py
```

The script builds cleanly for each stage and keeps its executable, ELF and two
logs under ignored `tmp/optimization/`. The report rejects missing PASS records,
wrong frame counts, or mismatched position/object-count checks. The independent
switches are `DRIVING_COPY_LEGACY=1`, `PORT_WORK_LEGACY=1` and
`GAME_RASTER_ORIGINAL=1`; ordinary builds enable all measured optimizations.

Correctness gates are `make game-raster-check`, `make direct-c2p-check`,
`make direct-c2p-shadow-check` and `make direct-c2p-fallback-check`.
Build cleanly without flags afterwards to restore the normal executable.
