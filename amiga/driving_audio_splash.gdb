# Cover the named splash cue on the bounded straight-to-lake recovery path.
# Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINITE_AUDIO_PROBE=1
# (without FOLLOW_ROAD).
set pagination off
set confirm off
set $sawSplash = 0
set $splashTick = 0
set $expiryProbeTick = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "splash loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+14) == 15
commands
  silent
  set $caller = *(unsigned int*)$sp
  set $segment = 0
  set $i = 1
  while $i <= 10
    if $caller >= (unsigned int)s_segments[$i].begin && $caller < (unsigned int)s_segments[$i].end
      set $segment = $i
    end
    set $i = $i+1
  end
  printf "splash load tick=%u frames=%u iterations=%u caller=%u+$%x context=%u duration=%u parameter=$%08x instrument=%u previous=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $segment, $caller-(unsigned int)s_segments[$segment].begin, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), *(unsigned short*)($sp+14), s_bogasContexts[*(unsigned short*)($sp+4)].instrument
  set $sawSplash = 1
  set $splashTick = g_macTicks
  continue
end

# Traffic+$5B06 is the return address immediately after the source wrapper.
# The entry observation above proves the untouched 360-tick request; the
# diagnostic build shortens the resulting countdown to two ticks.
break *(s_segments[6].begin+0x5b06) if $sawSplash && $expiryProbeTick == 0
commands
  silent
  printf "splash scheduled tick=%u end0=%u end1=%u remaining0=%u remaining1=%u playing=%u\n", g_macTicks, s_bogasVoiceEndTick[0], s_bogasVoiceEndTick[1], s_bogasVoiceEndTick[0]-g_macTicks, s_bogasVoiceEndTick[1]-g_macTicks, s_bogasContexts[0].playing
  set $expiryProbeTick = g_macTicks
  continue
end

break VetteScreen::presentMacFrame if $expiryProbeTick && g_macTicks >= $expiryProbeTick + 3
commands
  silent
  printf "splash expired tick=%u accelerated-elapsed=%u playing=%u instrument=%u end0=%u end1=%u\n", g_macTicks, g_macTicks-$expiryProbeTick, s_bogasContexts[0].playing, s_bogasContexts[0].instrument, s_bogasVoiceEndTick[0], s_bogasVoiceEndTick[1]
  detach
  quit
end

continue
