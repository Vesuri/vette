#!/usr/bin/env bash
# Source-level debug the Amiga Vette build via FS-UAE's GDB stub.
#   ./debug.sh [path-to-kickstart] [script.gdb]
# Build first, then run this. `continue` at the gdb prompt runs the program.
# HOME/XDG_CACHE_HOME must be set for gdb; connect to 127.0.0.1 (not localhost).
set -uo pipefail
cd "$(dirname "$0")"
. "${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}"

FSUAE="${FSUAE:-fs-uae}"
GDB="${GDB:-m68k-amiga-elf-gdb}"
MODEL="${AMIGA_MODEL:-A1200}"
ROM="${1:-${KICKSTART:-$HOME/Documents/RetroPie/BIOS/kick31.rom}}"
[ -f "$ROM" ] || { echo "Kickstart ROM not found: $ROM  (pass as \$1 or set \$KICKSTART)"; exit 1; }
[ -f out/Vette.elf ] || { echo "build first: make"; exit 1; }

RUN=.run; DH0="$RUN/dh0"; DH1="$RUN/dh1"; GDBHOME="$RUN/gdbhome"
mkdir -p "$DH0/s" "$DH1" "$RUN/state" "$GDBHOME"
printf 'cd dh1:\nVette\n' > "$DH0/s/startup-sequence"
cp -f out/Vette.exe "$DH1/Vette"

fsuae_claim_port
"$FSUAE" \
  --amiga_model="$MODEL" --chip_memory=2048 --fast_memory=8192 \
  --kickstart_file="$ROM" \
  --hard_drive_0="$DH0" --hard_drive_1="$DH1" \
  --joystick_port_0=mouse --joystick_port_1=nothing \
  --full_keyboard=1 \
  --keyboard_key_up=action_key_cursor_up --keyboard_key_down=action_key_cursor_down \
  --keyboard_key_left=action_key_cursor_left --keyboard_key_right=action_key_cursor_right \
  --automatic_input_grab=0 --fullscreen=0 --window_width=720 --window_height=568 \
  --remote_debugger=20 --remote_debugger_port="$DEBUG_PORT" --remote_debugger_trigger=Vette \
  --ntsc_mode=0 --state_dir="$RUN/state" > "$RUN/fsuae-dbg.log" 2>&1 &
FSUAE_PID=$!
fsuae_track "$FSUAE_PID"
echo "FS-UAE (gdb stub) pid=$FSUAE_PID; waiting for stub..."

for i in $(seq 1 60); do
  kill -0 "$FSUAE_PID" 2>/dev/null || { echo "FS-UAE exited early; see $RUN/fsuae-dbg.log"; exit 1; }
  lsof -nP -iTCP:"$DEBUG_PORT" -sTCP:LISTEN >/dev/null 2>&1 && break
  sleep 1
done

PREAMBLE="$RUN/connect.gdb"
{ printf 'set pagination off\nset confirm off\nset remotetimeout 90\n'
  printf 'target remote 127.0.0.1:%s\n' "$DEBUG_PORT"   # $DEBUG_PORT: see fsuae_common.sh
  cat <<'EOF'
echo \n>>> connected. `continue` runs; Ctrl-C breaks back in. <<<\n
EOF
} > "$PREAMBLE"

if [ "${2:-}" ] && [ -f "${2:-}" ]; then
  exec env HOME="$GDBHOME" XDG_CACHE_HOME="$GDBHOME" \
    "$GDB" -q -l 10 -x "$PREAMBLE" -x "$2" out/Vette.elf
fi
exec env HOME="$GDBHOME" XDG_CACHE_HOME="$GDBHOME" \
  "$GDB" -q -l 10 -x "$PREAMBLE" out/Vette.elf
