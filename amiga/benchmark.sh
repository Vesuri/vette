#!/usr/bin/env bash
# Reproduce the four cumulative stages using emulated fields, never host time.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
name="${1:-game}"
case "$name" in
  legacy) flags=(DRIVING_COPY_LEGACY=1 PORT_WORK_LEGACY=1 GAME_RASTER_ORIGINAL=1) ;;
  direct) flags=(PORT_WORK_LEGACY=1 GAME_RASTER_ORIGINAL=1) ;;
  port) flags=(GAME_RASTER_ORIGINAL=1) ;;
  game) flags=() ;;
  *) echo 'Usage: bash amiga/benchmark.sh legacy|direct|port|game' >&2; exit 2 ;;
esac
mkdir -p ../tmp/optimization
make clean
make -j4 SKIP_INTRO=1 GARAGE_CLICK=1 PARKED_PROFILE=1 \
  FIDELITY_RANDOM_SEED=0x3BD90000 "${flags[@]}" > "../tmp/optimization/$name-build.log" 2>&1
cp out/Vette.elf "../tmp/optimization/$name.elf"
cp out/Vette.exe "../tmp/optimization/$name.exe"
for run in 1 2; do
  log="../tmp/optimization/$name-$run.log"
  AMIGA_MODEL=A1200 CHIP_MEMORY=2048 FAST_MEMORY=8192 \
    GDBTAIL=30 EXTRA_ARGS='--warp_mode=1' GDBSCRIPT=parked_benchmark.gdb ./diag_run.sh 150 > "$log" 2>&1
  grep -q 'PASS parked benchmark' "$log"
  grep '^BENCH ' "$log"
done
