# Verify the deterministic Course One normal-road workload.  The harness uses
# only the game's keypad controls: accelerate-right to the road's initial bend,
# then straight acceleration.  Requires SKIP_INTRO=1 GARAGE_CLICK=1
# FOLLOW_ROAD=1 PROBES=1.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "road workload loud stop: tick=%u frames=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_macFramesPresented, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break vbiHandler if s_drivingFrameStarted && g_macDrivingIterations >= 100
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "road follow checkpoint: tick=%u frames=%u iterations=%u pos=($%08x,$%08x) heading=$%04x speed=%d rpm=%d gear=%d\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x66), *(short*)($car+0x1a), *(short*)($car+0x44), *(short*)($car+0x1c)
  detach
  quit
end

continue
