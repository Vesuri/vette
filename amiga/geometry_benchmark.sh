#!/usr/bin/env bash
# Same scene/seed/120 presented frames; instrumented kernel replay is separate.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
name="${1:-optimized}"
flags=()
case "$name" in
  legacy) geometry=0; flags=(DRIVING_COPY_LEGACY=1 PORT_WORK_LEGACY=1 GAME_RASTER_ORIGINAL=1) ;;
  base) geometry=0 ;;
  optimized) geometry=1 ;;
  *) echo 'Usage: bash amiga/geometry_benchmark.sh legacy|base|optimized' >&2; exit 2 ;;
esac
mkdir -p ../tmp/geometry-benchmark
make clean
make -j4 SKIP_INTRO=1 GARAGE_CLICK=1 PARKED_PROFILE=1 PARKED_PROFILE_SCENE=2 \
  FIDELITY_RANDOM_SEED=0x3BD90000 GAME_GEOMETRY="$geometry" "${flags[@]}" \
  > "../tmp/geometry-benchmark/$name-build.log" 2>&1
cp out/Vette.elf "../tmp/geometry-benchmark/$name.elf"
cp out/Vette.exe "../tmp/geometry-benchmark/$name.exe"
for run in 1 2; do
  log="../tmp/geometry-benchmark/$name-$run.log"
  AMIGA_MODEL=A1200 CHIP_MEMORY=2048 FAST_MEMORY=8192 GDBTAIL=25 \
    EXTRA_ARGS='--warp_mode=1' GDBSCRIPT=geometry_benchmark.gdb ./diag_run.sh 240 > "$log" 2>&1
  grep -q 'PASS parked benchmark' "$log"
  grep '^BENCH ' "$log"
done
