# Prove difficulty controls the ordinary police path. Requires PROBES=1,
# SKIP_INTRO=1, GARAGE_CLICK=1, GARAGE_DIFFICULTY=1..3, and
# POLICE_TICKET_CHECKPOINT=1. The fixture supplies the same nearby COP! and
# offense bits; resident Traffic must reject Trainee or catch higher levels.
set pagination off
set confirm off
set $checks = 0
set $caught = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "difficulty-police loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[6].begin+0x0e5a)
commands
  silent
  set $checks = $checks + 1
  continue
end

break *(s_segments[6].begin+0x0f3e)
commands
  silent
  set $caught = $caught + 1
  printf "difficulty-police caught tick=%u iterations=%u difficulty=%d checks=%u offenses=$%02x\n", g_macTicks, g_macDrivingIterations, *(signed short*)(s_currentA5-0x542c), $checks, *(unsigned char*)(*(unsigned int*)(s_currentA5-0x3678)+0x32)
  detach
  quit
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 80
commands
  silent
  printf "difficulty-police inactive tick=%u iterations=%u difficulty=%d checks=%u caught=%u\n", g_macTicks, g_macDrivingIterations, *(signed short*)(s_currentA5-0x542c), $checks, $caught
  detach
  quit
end

continue
