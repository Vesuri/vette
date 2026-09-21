# Verify that the source's copy-protection failure state produces the police
# cue through its ordinary driving logic. Requires PROBES=1 SKIP_INTRO=1
# GARAGE_CLICK=1 FOLLOW_ROAD=1 FAIL_PROTECTION=1 POLICE_PROBE=1. POLICE_PROBE
# ages only the original race-start timestamp to Traffic's $1C20 threshold.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "police loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+14) == 12
commands
  silent
  printf "police cue tick=%u frames=%u iterations=%u context=%u duration=%u options=$%08x instrument=%u protectionProcessed=%d protectionFailed=%d\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), *(unsigned short*)($sp+14), *(short*)(s_currentA5-22782), *(short*)(s_currentA5-22784)
  detach
  quit
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 120
commands
  silent
  printf "police ceiling tick=%u frames=%u iterations=%u protectionProcessed=%d protectionFailed=%d\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, *(short*)(s_currentA5-22782), *(short*)(s_currentA5-22784)
  detach
  quit
end

continue
