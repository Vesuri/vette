# Verify the original Main `kill` and Traffic `joel` callers after the bounded
# source-predicate checkpoint has made them eligible. Requires PROBES=1,
# SKIP_INTRO=1, GARAGE_CLICK=1, FOLLOW_ROAD=1, REMAINING_AUDIO_PROBE=1.
set pagination off
set confirm off
set $seen = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "remaining-audio loud stop tick=%u trap=$%04x segment=%u offset=$%x seen=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset, $seen
  detach
  quit
end

break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+14) == 9 || *(unsigned short*)($sp+14) == 14
commands
  silent
  set $instrument = *(unsigned short*)($sp+14)
  if ($seen & (1 << $instrument)) != 0
    continue
  end
  set $caller = *(unsigned int*)$sp
  set $segment = 0
  set $i = 1
  while $i <= 10
    if $caller >= (unsigned int)s_segments[$i].begin && $caller < (unsigned int)s_segments[$i].end
      set $segment = $i
    end
    set $i = $i+1
  end
  printf "remaining cue tick=%u iterations=%u caller=%u+$%x context=%u duration=%u options=$%08x instrument=%u previous=%u\n", g_macTicks, g_macDrivingIterations, $segment, $caller-(unsigned int)s_segments[$segment].begin, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), $instrument, s_bogasContexts[*(unsigned short*)($sp+4)].instrument
  set $seen = $seen | (1 << $instrument)
  if ($seen & (1 << 9)) && ($seen & (1 << 14))
    detach
    quit
  end
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 100
commands
  silent
  printf "remaining-audio ceiling tick=%u frames=%u iterations=%u seen=$%x high-memory=%d joel-handle=%u\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $seen, *(short*)(s_currentA5-0x5950), *(unsigned int*)(s_currentA5-0x5a5c)
  detach
  quit
end

continue
