# Stop at the first context-2 gameplay effect outside the normal-road
# beep1/beep2/thud set. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 and the
# straight-to-water collision fixture (omit FOLLOW_ROAD).
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "audio-cue loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a)
commands
  silent
  set $context = *(unsigned short*)($sp+4)
  set $duration = *(unsigned int*)($sp+6)
  set $options = *(unsigned int*)($sp+10)
  set $instrument = *(unsigned short*)($sp+14)
  printf "audio-cue load tick=%u context=%u duration=%u options=$%08x instrument=%u\n", g_macTicks, $context, $duration, $options, $instrument
  if $context == 2 && $instrument != 10 && $instrument != 11 && $instrument != 13
    printf "audio-cue next effect tick=%u frames=%u iterations=%u instrument=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $instrument
    detach
    quit
  end
  continue
end

continue
