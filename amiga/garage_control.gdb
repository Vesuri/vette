# Identify the control selected by the deterministic garage click.
# Run with a SKIP_INTRO=1 GARAGE_CLICK=1 build:
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=garage_control.gdb ./diag_run.sh 20
set pagination off
set confirm off

# This is the instruction immediately after Main's call to its six-rectangle
# control tracker.  Using the linked CODE symbol lets GDB apply the AmigaDOS
# load relocation instead of baking a runtime address into this probe.
break *vette_code_2+0xcce
commands
  silent
  printf "\n===== GARAGE CONTROL =====\n"
  printf "selected index = %d\n", $d0
  printf "local point (v,h): "
  x/2hd $a5-21814
  printf "mode = %d\n", *(short *)($a5-21546)
  printf "six rectangles (top,left,bottom,right):\n"
  x/24hd $a5-21806
  printf "==========================\n\n"
  detach
  quit
end

continue
