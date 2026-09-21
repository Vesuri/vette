# Capture the source Bogas command timeline over the bounded normal-road
# workload. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FOLLOW_ROAD=1.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "AUDIO loud-stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a)
commands
  silent
  printf "AUDIO load tick=%u context=%u duration=%u options=$%08x instrument=%u\n", g_macTicks, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), *(unsigned short*)($sp+14)
  continue
end

break *(s_segments[9].begin+0x174)
commands
  silent
  printf "AUDIO play tick=%u context=%u pitch=$%08x\n", g_macTicks, *(unsigned short*)($sp+8), *(unsigned int*)($sp+4)
  continue
end

break *(s_segments[9].begin+0x24c)
commands
  silent
  printf "AUDIO start tick=%u\n", g_macTicks
  continue
end

break *(s_segments[9].begin+0x27c)
commands
  silent
  printf "AUDIO stop tick=%u\n", g_macTicks
  continue
end

break *(s_segments[9].begin+0x2ac)
commands
  silent
  printf "AUDIO deactivate tick=%u\n", g_macTicks
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 100
commands
  silent
  printf "AUDIO ceiling tick=%u frames=%u iterations=%u started=%u suspended=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, s_bogasStarted, s_bogasSuspended
  printf "AUDIO context0 playing=%u instrument=%u pitch=$%08x channel=%u\n", s_bogasContexts[0].playing, s_bogasContexts[0].instrument, s_bogasContexts[0].pitch, s_bogasContexts[0].channel
  printf "AUDIO context1 playing=%u instrument=%u pitch=$%08x channel=%u end=%u\n", s_bogasContexts[1].playing, s_bogasContexts[1].instrument, s_bogasContexts[1].pitch, s_bogasContexts[1].channel, s_bogasVoiceEndTick[3]
  printf "AUDIO context2 playing=%u instrument=%u pitch=$%08x channel=%u end=%u\n", s_bogasContexts[2].playing, s_bogasContexts[2].instrument, s_bogasContexts[2].pitch, s_bogasContexts[2].channel, s_bogasVoiceEndTick[2]
  detach
  quit
end

continue
