#!/usr/bin/env bash
# Verify all four course selections and preserve before-driving panel captures.
set -euo pipefail
cd "$(dirname "$0")/.."
. amiga/env.sh
mkdir -p tmp/course-bubbles
for course in 1 2 3 4; do
  make -C amiga clean > "tmp/course-bubbles/build-$course.log" 2>&1
  make -C amiga -j4 HIRES=0 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE="$course" >> "tmp/course-bubbles/build-$course.log" 2>&1
  for mode in 0 1; do
    make -C amiga HIRES="$mode" PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE="$course" > "tmp/course-bubbles/build-$course-$mode.log" 2>&1
    printf 'set $expectedCourse=%s\nsource course_panels.gdb\n' "$course" > tmp/course-bubbles/current.gdb
    (cd amiga && GDBTAIL=15 EXTRA_ARGS='--warp_mode=1' GDBSCRIPT=../tmp/course-bubbles/current.gdb ./diag_run.sh 100) > "tmp/course-bubbles/course-$course-$mode.log" 2>&1
    grep 'PASS course panel selection' "tmp/course-bubbles/course-$course-$mode.log"
    cp amiga/.run/course-panel.raw "tmp/course-bubbles/course-$course-$mode.raw"
    cp amiga/.run/course-panel.ctab "tmp/course-bubbles/course-$course-$mode.ctab"
    python3 tools/render_mac_chunky.py "tmp/course-bubbles/course-$course-$mode.raw" "tmp/course-bubbles/course-$course-$mode.ctab" "tmp/course-bubbles/course-$course-$mode.png" --width 512 --height 320 --row-bytes 256
  done
done
