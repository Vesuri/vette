# Stop on the first BogasLoad request after active driving begins.  In Vette
# this wrapper schedules named sampled effects; the per-frame engine pitch uses
# BogasPlay instead and therefore does not trigger this probe.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands 1
  silent
  printf "sound-path loud stop: ticks=%u frames=%u/%u depth=%u trap=$%04x %s/%s selector=%d caller=%u+$%x\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, g_trapWord, g_trapManager, g_trapRoutine, g_trapSelector, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12c) if s_drivingFrameStarted && g_macFramesPresented >= 40
commands 2
  silent
  printf "driving BogasLoad: ticks=%u frames=%u caller=$%x channel=%u duration=%u scale=$%x instrument=$%x depth=%u\n", g_macTicks, g_macFramesPresented, *(unsigned int*)$sp, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), *(unsigned short*)($sp+14), g_stageCDepth
  set $car = *(unsigned int*)(s_currentA5-13944)
  dump binary memory ../tmp/amiga_driving_sound_event.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/amiga_driving_sound_event.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  dump binary memory ../tmp/amiga_driving_sound_event_car.raw $car $car+256
  printf "segment begins: Main=$%x Initialize=$%x Communication=$%x Traffic=$%x FRED=$%x sound=$%x\n", s_segments[1].begin, s_segments[2].begin, s_segments[3].begin, s_segments[6].begin, s_segments[7].begin, s_segments[9].begin
  detach
  quit
end

continue
