# Prove that the S toggle remains in active driving and reaches a bounded frame
# count without an unimplemented trap.  Requires SKIP_INTRO=1 GARAGE_CLICK=1
# INPUT_PROBE_EVENT_RAW_KEY=0x21 (S).
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands 1
  silent
  printf "S toggle loud stop: ticks=%u frames=%u/%u depth=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 50
commands 2
  silent
  printf "S toggle settled: ticks=%u frames=%u/%u depth=%u soundFlag=%d driving=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, *(short*)(s_currentA5-14208), s_drivingFrameStarted
  detach
  quit
end

continue
