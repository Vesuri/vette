# Verify a one-scan press/release of the documented Z horn control, after the
# race countdown and initial acceleration, reaches its original Bogas
# lifecycle. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 HORN_PROBE=1.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "horn loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

set $hornLoads = 0
set $hornPlays = 0
break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+4) == 1
commands
  silent
  set $hornLoads = $hornLoads + 1
  printf "horn context1 load=%u tick=%u frames=%u iterations=%u context=%u duration=%u options=$%08x instrument=%u\n", $hornLoads, g_macTicks, g_macFramesPresented, g_macDrivingIterations, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), *(unsigned short*)($sp+14)
  continue
end

break *(s_segments[9].begin+0x174) if *(unsigned short*)($sp+8) == 1
commands
  silent
  set $hornPlays = $hornPlays + 1
  printf "horn context1 play=%u tick=%u frames=%u iterations=%u pitch=$%08x\n", $hornPlays, g_macTicks, g_macFramesPresented, g_macDrivingIterations, *(unsigned int*)($sp+4)
  continue
end

break *(s_segments[9].begin+0x1b0)
commands
  silent
  printf "horn pitch tick=%u frames=%u iterations=%u value=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, *(unsigned short*)($sp+4)
  continue
end

break *(s_segments[9].begin+0x1e6)
commands
  silent
  printf "horn purge tick=%u frames=%u iterations=%u instrument=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, *(unsigned short*)($sp+4)
  continue
end

break *(s_segments[9].begin+0x21c)
commands
  silent
  printf "horn set tick=%u frames=%u iterations=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations
  continue
end

break *(s_segments[9].begin+0x27c)
commands
  silent
  printf "horn stop tick=%u frames=%u iterations=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations
  continue
end

break *(s_segments[9].begin+0x2ac)
commands
  silent
  printf "horn deactivate tick=%u frames=%u iterations=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 80
commands
  silent
  printf "horn ceiling tick=%u frames=%u iterations=%u loads=%u plays=%u playing=%u instrument=%u channel=%u end=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $hornLoads, $hornPlays, s_bogasContexts[1].playing, s_bogasContexts[1].instrument, s_bogasContexts[1].channel, s_bogasVoiceEndTick[3]
  detach
  quit
end

continue
