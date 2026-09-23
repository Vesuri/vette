#!/usr/bin/env bash
# Executable gameplay/release regression groups. Each case builds from clean,
# runs an event-driven observer under the target A1200 configuration, and
# requires an explicit success record rather than treating a timeout as green.
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh

group="${1:-smoke}"

run_case()
{
  local name="$1" seconds="$2" script="$3" success="$4"
  shift 4
  echo "=== regression: $name ==="
  make clean >/dev/null 2>&1
  make -j4 "$@" >/dev/null 2>&1
  GDBTAIL=240 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT="$script" \
    ./diag_run.sh "$seconds"
  if ! grep -Eq "$success" .run/gdb-out.log; then
    echo "FAIL: $name did not emit: $success" >&2
    tail -80 .run/gdb-out.log >&2
    return 1
  fi
  if grep -Eq "(FAIL loud stop|[[:alnum:]-]+ loud stop)" .run/gdb-out.log; then
    echo "FAIL: $name reached a loud stop" >&2
    tail -80 .run/gdb-out.log >&2
    return 1
  fi
  echo "PASS: $name"
}

run_smoke()
{
  run_case production 90 production_audit.gdb 'production-audit PASS.*resources=572.*jumps=509'
  run_case intro-click-audio 90 intro_click_audio.gdb 'intro-click-audio PASS' \
    PROBES=1 INTRO_AUDIO_SKIP_PROBE=1
  run_case driving-smoke 35 gameplay_smoke.gdb 'gameplay-smoke PASS' \
    PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
}

run_courses()
{
  local course
  for course in 1 2 3 4; do
    run_case "course-$course" 45 driving_course_lifecycle.gdb \
      'course-lifecycle settled.*finish=1.*score=1/1.*driving=0' \
      PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINISH_CHECKPOINT=1 \
      "GARAGE_COURSE=$course"
  done
}

run_vehicles()
{
  local vehicle index
  for vehicle in 1 2 3 4; do
    index=$((vehicle - 1))
    run_case "vehicles-$vehicle" 45 driving_course_lifecycle.gdb \
      "course-lifecycle settled.*race-player=$index race-opponent=$index.*driving=0" \
      PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINISH_CHECKPOINT=1 \
      "GARAGE_CAR=$vehicle" "GARAGE_OPPONENT=$vehicle"
  done
}

run_difficulties()
{
  local difficulty index
  for difficulty in 1 2 3; do
    index=$((difficulty - 1))
    run_case "difficulty-$difficulty" 45 driving_course_lifecycle.gdb \
      "course-lifecycle settled.*difficulty=$index.*driving=0" \
      PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINISH_CHECKPOINT=1 \
      "GARAGE_DIFFICULTY=$difficulty"
  done
  run_case trainee-damage 45 driving_difficulty_damage.gdb \
    'difficulty-damage immune' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 \
    GARAGE_DIFFICULTY=1 DIFFICULTY_DAMAGE_CHECKPOINT=1
  run_case pro-damage 80 driving_difficulty_damage.gdb \
    'difficulty-damage applied.*difficulty=2' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 \
    GARAGE_DIFFICULTY=3 DIFFICULTY_DAMAGE_CHECKPOINT=1
  run_case pro-cruise 45 driving_difficulty_dynamics.gdb \
    'difficulty-dynamics cruise difficulty=2' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 \
    GARAGE_DIFFICULTY=3 DIFFICULTY_CRUISE_CHECKPOINT=1
}

run_recovery()
{
  run_case water-recovery 80 driving_lake_static_collision.gdb \
    'at PICT: hits=[1-9]' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
  run_case damage-repair 55 driving_damage_repair.gdb \
    'damage-repair cleared.*cells=0,0,0,0,0,0,0,0' \
    PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 DAMAGE_REPAIR_CHECKPOINT=1
  run_case terminal-tow 55 driving_terminal_tow.gdb \
    'terminal-tow settled.*picture=1.*driving=0' \
    PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 TERMINAL_DAMAGE_CHECKPOINT=1
  run_case police 55 driving_police_ticket.gdb \
    'police released.*offenses=\$00' \
    PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 POLICE_TICKET_CHECKPOINT=1
}

run_routes()
{
  run_case city-to-freeway 190 driving_freeway_activation.gdb \
    'natural-freeway-spawn' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 \
    GARAGE_COURSE=2 FREEWAY_ROUTE=1
  run_case freeway-straight 360 driving_freeway_straight.gdb \
    'freeway straight reached.*cell=\([6-9],[[:space:]]*36\).*mode=1' \
    PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 \
    GARAGE_COURSE=2 FREEWAY_ROUTE=1
  run_case freeway-to-city 70 driving_main_return.gdb \
    'main-map return boundary reached' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 \
    GARAGE_COURSE=2 FREEWAY_ROUTE=1 FREEWAY_START=30 \
    FREEWAY_START_U=1600 FREEWAY_START_V=1024 MAIN_START=17
}

run_session()
{
  run_case return-to-game 45 driving_session_control.gdb \
    'session-control resumed.*item=6.*handler=6' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 SESSION_CONTROL_ITEM=6
  run_case restart-race 50 driving_session_control.gdb \
    'session-control resumed.*item=5.*handler=5' PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 SESSION_CONTROL_ITEM=5
  run_case menu-quit 50 driving_menu_quit.gdb \
    'menu-quit restore.*view=1.*selected=1' \
    PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 SESSION_CONTROL_ITEM=8
  run_case emergency-quit 90 quit_path.gdb \
    'emergency-quit PASS: view=1.*live=0.*pointers=0.*handles=0' \
    PROBES=1 QUIT_PROBE=1 SKIP_INTRO=1
  run_case scores 45 score_persistence.gdb \
    'score persistence changed=[1-9].*writes=[1-9].*load-valid=1.*saved=[1-9][0-9]*.*view=1' \
    PROBES=1 SKIP_INTRO=1 SCORE_PERSISTENCE_PROBE=1
}

case "$group" in
  smoke) run_smoke ;;
  courses) run_courses ;;
  vehicles) run_vehicles ;;
  difficulties) run_difficulties ;;
  recovery) run_recovery ;;
  routes) run_routes ;;
  session) run_session ;;
  all)
    run_smoke
    run_courses
    run_vehicles
    run_difficulties
    run_recovery
    run_routes
    run_session
    ;;
  *)
    echo "usage: $0 {smoke|courses|vehicles|difficulties|recovery|routes|session|all}" >&2
    exit 2
    ;;
esac
