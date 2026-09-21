# Verify that documented F4 helicopter view replaces the context-0 engine
# with `heli`, and F2 forward view restores `engine`, through original input
# and BogasLoad calls. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
# VIEW_AUDIO_PROBE=1.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "heli loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

set $sawHeli = 0
set $sawEngine = 0
break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+4) == 0
commands
  silent
  set $caller = *(unsigned int*)$sp
  set $instrument = *(unsigned short*)($sp+14)
  if $instrument == 5
    set $sawHeli = 1
    printf "heli load tick=%u frames=%u iterations=%u caller=Main+$%x context=%u duration=%u pitch=$%08x instrument=%u previous=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $caller-(unsigned int)s_segments[1].begin, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), $instrument, s_bogasContexts[0].instrument
  end
  if $sawHeli && $instrument == 4
    printf "engine restore tick=%u frames=%u iterations=%u caller=Main+$%x context=%u duration=%u pitch=$%08x instrument=%u previous=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $caller-(unsigned int)s_segments[1].begin, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), $instrument, s_bogasContexts[0].instrument
    set $sawEngine = 1
  end
  continue
end

break *(s_segments[1].begin+0x2f76) if $sawEngine
commands
  silent
  printf "forward-view audio active tick=%u iterations=%u playing=%u instrument=%u pitch=$%08x channel=%u AUD0/1-period=%u\n", g_macTicks, g_macDrivingIterations, s_bogasContexts[0].playing, s_bogasContexts[0].instrument, s_bogasContexts[0].pitch, s_bogasContexts[0].channel, 20905984/s_bogasContexts[0].pitch
  detach
  quit
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 20
commands
  silent
  printf "heli ceiling tick=%u frames=%u iterations=%u saw-heli=%u context0=%u context1=%u context2=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $sawHeli, s_bogasContexts[0].instrument, s_bogasContexts[1].instrument, s_bogasContexts[2].instrument
  detach
  quit
end

continue
