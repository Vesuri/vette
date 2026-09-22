# Prove that the deterministic development path reaches active driving.  All
# executable CODE is loaded from the original resource fork, so resolve the
# breakpoint from the resident segment table rather than a linked blob symbol.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "gameplay-smoke FAIL loud stop trap=$%04x %s/%s caller=%u+$%x\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 2
commands
  silent
  printf "gameplay-smoke PASS tick=%u frames=%u iterations=%u depth=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, g_stageCDepth
  detach
  quit
end

continue
