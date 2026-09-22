# Follow the source-defined splash result through the lake recovery transition.
# Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINITE_AUDIO_PROBE=1, without
# FOLLOW_ROAD. The companion splash regression proves the untouched 360-tick
# arguments; this one accelerates only the resulting deadline.
set pagination off
set confirm off
set $sawSplash = 0
set $splashTick = 0
set $postSplashLoads = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "recovery-audio loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+4) == 0
commands
  silent
  set $instrument = *(unsigned short*)($sp+14)
  if $instrument == 15
    set $sawSplash = 1
    set $splashTick = g_macTicks
    printf "recovery splash tick=%u iterations=%u duration=%u pitch=$%08x previous=%u\n", g_macTicks, g_macDrivingIterations, *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), s_bogasContexts[0].instrument
  else
    if $sawSplash
      set $postSplashLoads = $postSplashLoads + 1
      printf "recovery context0 reload=%u tick=%u instrument=%u duration=%u pitch=$%08x previous=%u\n", $postSplashLoads, g_macTicks, $instrument, *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), s_bogasContexts[0].instrument
    end
  end
  continue
end

break VetteScreen::presentMacFrame if $sawSplash && g_macTicks >= $splashTick + 3 && !s_drivingFrameStarted
commands
  silent
  printf "recovery audio settled tick=%u accelerated-elapsed=%u frames=%u driving=%u context0-playing=%u instrument=%u end0=%u end1=%u reloads=%u exit-state=%u\n", g_macTicks, g_macTicks-$splashTick, g_macFramesPresented, s_drivingFrameStarted, s_bogasContexts[0].playing, s_bogasContexts[0].instrument, s_bogasVoiceEndTick[0], s_bogasVoiceEndTick[1], $postSplashLoads, g_macExitState
  detach
  quit
end

continue
