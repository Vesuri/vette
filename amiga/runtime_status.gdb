# General snapshot; a loud stop ends the run immediately.
set pagination off
set confirm off
break VetteScreen::showLoudStop
continue
printf "state=%u depth=%u fields=%u ticks=%u driving=%u\n", g_stageBState, g_stageCDepth, g_vbiCount, g_macTicks, g_macDrivingIterations
printf "frames queued/presented=%u/%u\n", g_macFramesQueued, g_macFramesPresented
if g_stageBState == 3
  printf "trap=$%04x %s / %s selector=%d caller=%u+$%04x\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSelector, g_trapSegment, g_trapOffset
end
detach
quit
