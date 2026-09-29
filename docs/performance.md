# Measured rendering optimizations

Measured 2026-09-29 in FS-UAE's PAL A1200 configuration: 68020, 2 MiB Chip RAM,
8 MiB Fast RAM, normal lores crop. These are emulated machine timings, not host
wall-clock timings or measurements on physical hardware.

The initial port/copy-row comparison below predates the geometry changes.
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

The copy-row stage uses **11.24% less time per frame**, corresponding to **12.66%
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


## Geometry: Pierce/Greenwich

The next profile's three largest game groups were vertex transformation and
projection (15.56% of the whole capture), supporting coordinate/matrix work
(9.75%), and polygon span/edge/row work (15.43%). Their combined 40.74% is time
spent in those groups, not the amount that can be eliminated.

The retained change skips four multiplications when the corresponding matrix
coefficients are exactly zero. The vertex pass tests this once per model;
other matrices and cached coordinates use the original instructions. Point
transforms use the same exact sparse-matrix path. Projection, clipping, fixed-point
rounding and overflow handling remain original. Complete replaced ranges have
CRC-32 guards, and original code is copied from the user's loaded resources at
runtime rather than embedded in the executable.

Two polygon-row experiments were rejected: an eight-row unrolled loop increased
whole-frame time by about 1.8%, and a compact loop with a uniform-pattern shortcut
also ran slower. Polygon code therefore remains original. This optimization
improves work in the two geometry groups; it does not accelerate all three groups.

The final comparison uses the same PAL A1200 configuration as above, but a
**different scene**: Pierce/Greenwich, cell (22,32), position (45184,66563), heading
0x2000. The player stays stationary in neutral without input while simulation
and traffic continue. Both builds use seed 0x3BD90000, 100 settling iterations,
and 120 complete measured frames/iterations, repeated twice. Each run ends with
15 active objects; that count does not imply 15 visible vehicles. Prior port and
copy-row optimizations are enabled in both builds. No verification, probes or
instruction tracing is active during these measurements.

| Geometry | Mean ms/frame | FPS | Frame-time reduction | Repeat range (ms) |
| --- | ---: | ---: | ---: | ---: |
| Original (`GAME_GEOMETRY=0`) | 229.051 | 4.366 | 0.00% | 229.020–229.082 |
| Optimized (default) | 223.414 | 4.476 | 2.46% | 223.414–223.414 |

This saves **5.64 ms/frame (2.46%)**, or about **2.52% higher throughput**, in this
scene. Do not compare these absolute times to the earlier cell (25,32) table.
The result is scene-specific and measures emulated Amiga performance, not a
speed difference from the Macintosh version.

Differential verification passed 2,240 generated cases, including sparse and
arbitrary matrices, signed and rounding boundaries, complete vertex passes,
cached coordinates, clipping and projection overflow. It compares output memory,
all registers and the five CCR condition bits. A moving driving run additionally
passed 37,311 timed live comparisons against the original instructions with zero
mismatches. Paired transform timings were 7.70% and 11.46% lower for the general
and translated-point kernels respectively; both arms include register-bridge and
clock-read overhead, so the whole-frame table is the performance result.
Production, intro/audio and driving smoke regressions passed. The profiler-enabled
code storage passed the generated cases and a short live replay; the restored
normal build passed the software multiply/divide and probe-symbol link audits.

Reproduce with:

```sh
bash amiga/geometry_benchmark.sh base
bash amiga/geometry_benchmark.sh optimized
python3 tools/report_geometry_benchmark.py
make game-kernel-check
```

The benchmark retains both executables and logs under ignored
`tmp/geometry-benchmark/` and rejects missing PASS records, incorrect frame counts,
or mismatched position/object counts. The older four-stage benchmark explicitly
sets `GAME_GEOMETRY=0`. Clean and rebuild without diagnostic flags afterwards.


## Combined port and game gain in the same scene

The full-copy baseline was also measured at Pierce/Greenwich with the exact
scene, seed, 100-iteration settling period and 120-frame window used above.
Both repeats passed the stationary-position, frame-count and 15-active-object
checks. The optimized and pre-geometry measurements are the saved runs above;
only the missing full-copy baseline needed another clean build and two runs.

| Cumulative stage | Mean ms/frame | FPS | Frame-time reduction | Repeat range (ms) |
| --- | ---: | ---: | ---: | ---: |
| Before these port/game optimizations | 245.202 | 4.078 | 0.00% | 244.967–245.437 |
| Direct C2P, port bookkeeping and game copy row | 229.051 | 4.366 | 6.59% | 229.020–229.082 |
| All of the above plus geometry | 223.414 | 4.476 | 8.89% | 223.414–223.414 |

Together these changes save **21.79 ms/frame (8.89%)**, equivalent to **9.75%
higher FPS**, in this scene. Frame-time saving is `1 - new/old`; FPS gain is
`old/new - 1`. The baseline repeat spread is 0.47 ms, much smaller than the gain.
The earlier 11.24% result used cell (25,32); adding it to the geometry percentage
would mix different workloads. These are FS-UAE PAL A1200 measurements, not
Macintosh comparisons or guarantees for every scene and CPU.

To reproduce the cumulative comparison, run all three stages:

```sh
bash amiga/geometry_benchmark.sh legacy
bash amiga/geometry_benchmark.sh base
bash amiga/geometry_benchmark.sh optimized
python3 tools/report_geometry_benchmark.py --combined
```

`legacy` enables `DRIVING_COPY_LEGACY=1`, `PORT_WORK_LEGACY=1`,
`GAME_RASTER_ORIGINAL=1`, and `GAME_GEOMETRY=0`. The default report still compares
only the two geometry stages. Restore a clean normal build after benchmarking.


## A4000 preset comparison

Repeating all three stages with `AMIGA_MODEL=A4000` keeps the Pierce/Greenwich
scene, seed, 100 settling iterations, 120 complete measured frames, two repeats,
2 MiB Chip RAM and 8 MiB Fast RAM unchanged. All six runs passed the position,
frame/iteration count and 15-active-object checks. Emulator logs confirm A4000
and the requested memory sizes for every run.

This local FS-UAE build resolves `A4000` to **68030 + 68882**, JIT disabled,
`cpu_speed=max`, and `cpu_cycle_exact=false`. These are timings for that emulator
preset, not a cycle-exact physical A4000/040 benchmark. No CPU override was added.

| Cumulative stage | Mean ms/frame | FPS | Frame-time reduction | Repeat range (ms) |
| --- | ---: | ---: | ---: | ---: |
| Before these port/game optimizations | 80.215 | 12.466 | 0.00% | 80.214944–80.215174 |
| Direct C2P, port bookkeeping and game copy row | 70.205 | 14.244 | 12.48% | 70.205007–70.205107 |
| All of the above plus geometry | 70.020 | 14.282 | 12.71% | 70.020347–70.020347 |

The combined saving is **10.195 ms/frame (12.71%)**, equivalent to **14.56%
higher FPS**. Geometry alone saves **0.185 ms/frame (0.26%)** on this preset,
versus 2.46% on the A1200 preset. Thus the total relative gain is larger on A4000,
while the incremental geometry gain is smaller. Do not transfer an optimization's
percentage between CPU presets.

```sh
AMIGA_MODEL=A4000 bash amiga/geometry_benchmark.sh legacy
AMIGA_MODEL=A4000 bash amiga/geometry_benchmark.sh base
AMIGA_MODEL=A4000 bash amiga/geometry_benchmark.sh optimized
python3 tools/report_geometry_benchmark.py tmp/geometry-benchmark-A4000 --combined
```

A4000 artifacts are kept separately under ignored `tmp/geometry-benchmark-A4000/`;
the script preserves each run's emulator output along with the measurement log.
The default A1200 paths and settings are unchanged. The normal optimized build
was restored after the measurements and passed both link audits.
