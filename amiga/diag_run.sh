#!/usr/bin/env bash
# Launch FS-UAE gdb-stub, connect gdb, let Vette run, SIGINT gdb after a delay so it
# breaks in and prints the standby-build timing probes.
set -uo pipefail
cd "$(dirname "$0")"
. "${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}"
. ./stage_original_data.sh
FSUAE="${FSUAE:-fs-uae}"
GDB="${GDB:-m68k-amiga-elf-gdb}"
ROM="${KICKSTART:-$HOME/Documents/RetroPie/BIOS/kick31.rom}"
DELAY="${1:-14}"
# Production target: A1200, 2 MiB chip RAM and 8 MiB fast RAM.
MODEL="${AMIGA_MODEL:-A1200}"
# Optional extra fs-uae args, e.g. EXTRA_ARGS="--cpu=68040 --jit_compiler=1".
EXTRA_ARGS="${EXTRA_ARGS:-}"

RUN=.run; DH0="$RUN/dh0"; DH1="$RUN/dh1"; GDBHOME="$RUN/gdbhome"
mkdir -p "$DH0/s" "$DH1" "$RUN/state" "$GDBHOME"
printf 'cd dh1:\nVette\n' > "$DH0/s/startup-sequence"
cp -f out/Vette.exe "$DH1/Vette"
stage_vette_original_data "$DH1"

fsuae_claim_port
"$FSUAE" \
  --amiga_model="$MODEL" --chip_memory="${CHIP_MEMORY:-2048}" --fast_memory="${FAST_MEMORY:-8192}" \
  --kickstart_file="$ROM" \
  --hard_drive_0="$DH0" --hard_drive_1="$DH1" \
  --joystick_port_0=mouse --joystick_port_1=nothing \
  --full_keyboard=1 \
  --keyboard_key_up=action_key_cursor_up --keyboard_key_down=action_key_cursor_down \
  --keyboard_key_left=action_key_cursor_left --keyboard_key_right=action_key_cursor_right \
  --automatic_input_grab=0 --fullscreen=0 --window_width=720 --window_height=568 \
  $EXTRA_ARGS \
  --remote_debugger=20 --remote_debugger_port="$DEBUG_PORT" --remote_debugger_trigger=Vette \
  --ntsc_mode=0 --state_dir="$RUN/state" > "$RUN/fsuae-dbg.log" 2>&1 &
FSUAE_PID=$!
fsuae_track "$FSUAE_PID"
echo "FS-UAE pid=$FSUAE_PID; waiting for stub..."
for i in $(seq 1 60); do
  kill -0 "$FSUAE_PID" 2>/dev/null || { echo "FS-UAE exited early; see $RUN/fsuae-dbg.log"; exit 1; }
  lsof -nP -iTCP:"$DEBUG_PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
  sleep 1
done

cat > "$RUN/connect.gdb" <<EOF
set pagination off
set confirm off
set remotetimeout 90
target remote 127.0.0.1:$DEBUG_PORT
# CODE segments are disk-loaded during PlatformAmiga startup.  Pause once at
# MacLoader::run, after prepareResourceForks has populated s_segments, before
# sourcing observers whose breakpoint expressions use those resident bases.
tbreak MacLoader::run
commands
  silent
end
continue
EOF

env HOME="$GDBHOME" XDG_CACHE_HOME="$GDBHOME" \
  "$GDB" -q -l 10 -x "$RUN/connect.gdb" -x "${GDBSCRIPT:-runtime_status.gdb}" out/Vette.elf \
  > "$RUN/gdb-out.log" 2>&1 &
GDB_PID=$!
echo "gdb pid=$GDB_PID; running for ${DELAY}s..."
# Finish immediately when an event-driven gdb script (such as gameplay_smoke.gdb)
# prints its result and exits; snapshot/profiling scripts still run until the
# wall-time ceiling and receive SIGINT below.
for i in $(seq 1 "$DELAY"); do
  kill -0 "$GDB_PID" 2>/dev/null || break
  sleep 1
done
kill -INT "$GDB_PID" 2>/dev/null || true
# give gdb time to print + detach
for i in $(seq 1 20); do kill -0 "$GDB_PID" 2>/dev/null || break; sleep 1; done
kill -INT "$GDB_PID" 2>/dev/null || true
sleep 2
kill -9 "$GDB_PID" 2>/dev/null || true
fsuae_stop
echo "=== gdb output (filtered) ==="
# ⚠⚠ $GDBTAIL: the default 40 lines is enough for a phase table and NOTHING ELSE — it cuts the
# `=== vbi=... loopFrames=... ===` header, `phase 0` and `FRAME = ... ms`.  The parked-comparison
# protocol (amiga/Makefile §SPANFILL) *requires* phase 0, whose tick count is bit-identical
# across runs of the same trajectory, so raise this for any run you intend to compare:
#   GDBTAIL=200 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_phase_profile.gdb ./diag_run.sh 30
# ⚠ and raise it for BOTH arms — never diff two runs captured with different amounts of output.
grep -v "Internal error: pc" "$RUN/gdb-out.log" | grep -vE "^warning:" | tail -"${GDBTAIL:-40}"
