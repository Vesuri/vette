# Trace one-shot milestones after the deterministic plate selection without
# extending the runner's wall-time ceiling.
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=garage_transition.gdb ./diag_run.sh 20
set pagination off
set confirm off

tbreak *vette_code_2+0xfc8
commands
  silent
  printf "garage transition: entered common branch\n"
  continue
end

tbreak *vette_code_2+0x10aa
commands
  silent
  printf "garage transition: entered plate animation loop\n"
  printf "background source: "
  x/4hd $a5-566
  printf "plate source: "
  x/4hd $a5-558
  printf "plate mask source: "
  x/4hd $a5-550
  printf "moving destination: "
  x/4hd $a5-21758
  printf "background destination: "
  x/4hd $a5-21750
  continue
end

tbreak *vette_code_2+0x11c6
commands
  silent
  printf "garage transition: completed plate animation loop\n"
  continue
end

tbreak *vette_code_2+0x1292
commands
  silent
  printf "garage transition: entered window replacement\n"
  continue
end

tbreak *vette_code_2+0x1340
commands
  silent
  printf "garage transition: entered driving setup\n"
  continue
end

tbreak *vette_code_2+0x149c
commands
  silent
  printf "garage transition: initialized driving state\n"
  continue
end

tbreak *vette_code_2+0x14d8
commands
  silent
  printf "garage transition: entered common handler tail\n"
  continue
end

tbreak *vette_code_2+0x150a
commands
  silent
  printf "garage transition: returned to the main event loop\n"
  detach
  quit
end

continue

printf "garage transition: stopped with moving destination at "
x/4hd s_currentA5-21758
detach
quit
