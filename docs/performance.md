# Rendering performance

The production build enables direct driving C2P, reduced port bookkeeping,
a Traffic copy-row replacement and sparse-matrix geometry kernels. Original
game decisions, projection, clipping, rounding and overflow behavior remain intact.

## Implementation and correctness

- Direct C2P consumes the resident GWorld with its 260-byte stride and existing
  dirty rectangles. Screen consumers and transitions materialize the logical
  screen when needed. See [development.md](development.md#direct-driving-c2p).
- Dirty tracking skips bounds already covered by the driving rectangle. Hidden
  pointers use an empty sprite, and a palette lookup preserves the original
  threshold conversion for every possible component high byte.
- Traffic+$67E6 copies rows using longwords on the supported 68020 target.
  Installation checks all four original instruction words. Forward overlaps of
  one to three bytes retain byte copying. Pointer advancement, registers and
  CCR results, including final-byte N/Z and the X bit, are preserved.
- MAIN+$50FC, MAIN+$4BBE and the transform inside MAIN+$4C30 skip four
  multiplications only when the corresponding matrix coefficients are zero.
  Other matrices retain the original path. Complete replaced ranges have
  CRC-32 guards; original instructions are copied from the user's resources at
  runtime. No original code is embedded in the executable. Polygon code remains
  original.

Correctness gates:

```sh
make direct-c2p-check
make direct-c2p-shadow-check
make direct-c2p-fallback-check
make game-raster-check
make game-kernel-check
```

The copy-row differential covers 866 memory/register/CCR cases; geometry covers
2,240 generated cases plus live driving calls. Direct C2P checks parked output,
moving publications against a logical-screen oracle, and race-finish screen
restoration. Each runtime gate requires explicit PASS records. These commands
need local game inputs and the emulator setup in [development.md](development.md).

## Measurements

Measured on 2026-09-29 in FS-UAE, PAL lores, with 2 MiB Chip and 8 MiB Fast RAM.
Each stage ran twice with seed 0x3BD90000, measuring 120 complete game iterations
and presented frames. The stationary player remained in neutral with no input;
simulation and traffic continued. Timing used PAL fields and beam phase at
presentation boundaries, with no probes, verification, shadow copy or instruction
trace. These are emulated machine timings, not physical-hardware measurements or
comparisons with Macintosh performance.

Pierce/Greenwich uses cell (22,32), position (45184,66563), heading 0x2000,
100 settling iterations and 15 active objects at completion.

| Preset | Stage | Mean ms/frame | FPS | Time reduction from baseline |
| --- | --- | ---: | ---: | ---: |
| A1200 / 68020 | Full-copy baseline | 245.202 | 4.078 | 0.00% |
| A1200 / 68020 | Direct C2P, bookkeeping, copy row | 229.051 | 4.366 | 6.59% |
| A1200 / 68020 | Production, including geometry | 223.414 | 4.476 | 8.89% |
| A4000 preset | Full-copy baseline | 80.215 | 12.466 | 0.00% |
| A4000 preset | Direct C2P, bookkeeping, copy row | 70.205 | 14.244 | 12.48% |
| A4000 preset | Production, including geometry | 70.020 | 14.282 | 12.71% |

The local A4000 preset resolves to **68030 + 68882**, JIT disabled,
`cpu_speed=max`, `cpu_cycle_exact=false`; it is not a cycle-exact A4000/040
benchmark. A1200 repeat ranges were 244.967–245.437, 229.020–229.082 and
223.414–223.414 ms/frame respectively. A4000 within-stage spreads were below
0.001 ms/frame. Geometry alone saves 2.46% on A1200 and 0.26% on this A4000
preset. Overall FPS gains are 9.75% and 14.56% respectively.

The separate four-stage A1200 benchmark uses cell (25,32), position (51328,66563),
twelve settling iterations and ten active objects, with geometry disabled:

| Stage | Mean ms/frame | FPS | Repeat range (ms) |
| --- | ---: | ---: | ---: |
| Full-copy baseline | 166.344 | 6.012 | 166.342–166.345 |
| Direct C2P | 156.883 | 6.374 | 156.875–156.890 |
| Plus bookkeeping | 155.233 | 6.442 | 155.233–155.233 |
| Plus copy row | 147.648 | 6.773 | 147.648–147.648 |

That scene saves 11.24% frame time (12.66% higher FPS). Do not add gains from
different scenes or transfer them between CPU presets. Time saving is
`1 - new/old`; FPS gain is `old/new - 1`. Moving original operations into native
functions changes profiler attribution, so whole-frame timing is the performance
measure. Diagnostic overhead and profiler limitations are described in
[the profiling workflow](development.md#original-code-gameplay-profile).

## Reproduction

From the repository root:

```sh
bash amiga/geometry_benchmark.sh legacy
bash amiga/geometry_benchmark.sh base
bash amiga/geometry_benchmark.sh optimized
python3 tools/report_geometry_benchmark.py --combined
```

For A4000, prefix each benchmark command with `AMIGA_MODEL=A4000` and pass
`tmp/geometry-benchmark-A4000` to the report tool. Default A1200 artifacts go to
`tmp/geometry-benchmark/`. Reports reject missing PASS records, incorrect frame
counts and mismatched position/object counts. Omitting `--combined` compares
only the geometry stages.

For the separate cell (25,32) comparison:

```sh
bash amiga/benchmark.sh legacy
bash amiga/benchmark.sh direct
bash amiga/benchmark.sh port
bash amiga/benchmark.sh game
python3 tools/report_parked_benchmark.py
```

Its executables and logs go to `tmp/optimization/`. Comparison switches are
`DRIVING_COPY_LEGACY=1`, `PORT_WORK_LEGACY=1`, `GAME_RASTER_ORIGINAL=1` and
`GAME_GEOMETRY=0`. Clean and rebuild without diagnostic flags after benchmarking.
