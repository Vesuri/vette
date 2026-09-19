# Prove that Automatic Shift changes the original car state and remains in
# active driving.  Requires SKIP_INTRO=1 GARAGE_CLICK=1
# INPUT_PROBE_EVENT_RAW_KEY=0x20 (Amiga A).
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands 1
  silent
  printf "Automatic Shift loud stop: ticks=%u frames=%u/%u depth=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 50
commands 2
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "Automatic Shift settled: ticks=%u frames=%u/%u depth=%u gate=%d state=%d car=$%08x driving=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, *(short*)(s_currentA5-14740), *(short*)($car+46), $car, s_drivingFrameStarted
  detach
  quit
end

continue
