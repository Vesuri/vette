# Measure the five controls in the post-garage vehicle selector.
# Run with a SKIP_INTRO=1 GARAGE_CLICK=1 build:
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=vehicle_control.gdb ./diag_run.sh 20
set pagination off
set confirm off

# The first measured selector presentation is earlier than its next event-loop
# dispatch, but the handler's static control table is already initialized.
break MacLoader.cpp:3016 if s_dirtyTop == 165 && s_dirtyLeft == 177 && s_dirtyBottom == 316 && s_dirtyRight == 505
commands
  silent
  printf "\n===== VEHICLE SELECTOR =====\n"
  printf "five rectangles (top,left,bottom,right):\n"
  x/20hd s_currentA5-21544
  printf "============================\n\n"
  detach
  quit
end

continue
