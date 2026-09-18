# Capture the first active driving update reached by the deterministic garage path.
# Run with a SKIP_INTRO=1 GARAGE_CLICK=1 build:
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_capture.gdb ./diag_run.sh 20
set pagination off
set confirm off

break MacLoader.cpp:3016 if s_dirtyTop == 165 && s_dirtyLeft == 177 && s_dirtyBottom == 316 && s_dirtyRight == 505
commands
  silent
  dump binary memory ../tmp/amiga_driving.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/amiga_driving.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  printf "captured first active driving update at Stage C depth %u\n", g_stageCDepth
  detach
  quit
end

continue
