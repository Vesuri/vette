# Assert authentic three-context overlap and one subsequent context-2
# replacement on Course Two. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
# GARAGE_COURSE=2 FREEWAY_ROUTE=1.
set pagination off
set confirm off
set $seenSkid = 0
set $seenCrash = 0
set $tripleSeen = 0
set $pendingReplacement = 0
set $replacementContext = 0
set $replacementInstrument = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "overlap loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+4) != 0
commands
  silent
  set $context = *(unsigned short*)($sp+4)
  set $instrument = *(unsigned short*)($sp+14)
  if $context == 1 && $instrument == 7
    set $seenSkid = 1
  end
  if $context == 2 && $instrument == 8
    set $seenCrash = 1
  end
  if $tripleSeen && $pendingReplacement == 0
    if ($context == 1 && s_bogasContexts[2].playing) || ($context == 2 && s_bogasContexts[1].playing)
      set $pendingReplacement = 1
      set $replacementContext = $context
      set $replacementInstrument = $instrument
      printf "overlap pending replacement tick=%u iterations=%u context=%u instrument=%u previous=%u other=%u context0=%u\n", g_macTicks, g_macDrivingIterations, $context, $instrument, s_bogasContexts[$context].instrument, s_bogasContexts[3-$context].instrument, s_bogasContexts[0].instrument
    end
  end
  continue
end

break VetteScreen::presentMacFrame if $seenSkid && $seenCrash
commands
  silent
  if !$tripleSeen && s_bogasContexts[0].playing && s_bogasContexts[0].instrument == 4 && s_bogasContexts[1].playing && s_bogasContexts[1].instrument == 7 && s_bogasContexts[2].playing && s_bogasContexts[2].instrument == 8
    set $tripleSeen = 1
    printf "overlap triple tick=%u iterations=%u contexts=%u/%u/%u channels=%u/%u/%u deadlines=%u/%u/%u/%u dma=$%04x\n", g_macTicks, g_macDrivingIterations, s_bogasContexts[0].instrument, s_bogasContexts[1].instrument, s_bogasContexts[2].instrument, s_bogasContexts[0].channel, s_bogasContexts[1].channel, s_bogasContexts[2].channel, s_bogasVoiceEndTick[0], s_bogasVoiceEndTick[1], s_bogasVoiceEndTick[2], s_bogasVoiceEndTick[3], *(unsigned short*)0xdff002
  end
  if $pendingReplacement && s_bogasContexts[$replacementContext].instrument == $replacementInstrument && s_bogasContexts[3-$replacementContext].playing
    printf "overlap replacement settled tick=%u iterations=%u replaced-context=%u contexts=%u/%u/%u channels=%u/%u/%u playing=%u/%u/%u deadlines=%u/%u/%u/%u dma=$%04x\n", g_macTicks, g_macDrivingIterations, $replacementContext, s_bogasContexts[0].instrument, s_bogasContexts[1].instrument, s_bogasContexts[2].instrument, s_bogasContexts[0].channel, s_bogasContexts[1].channel, s_bogasContexts[2].channel, s_bogasContexts[0].playing, s_bogasContexts[1].playing, s_bogasContexts[2].playing, s_bogasVoiceEndTick[0], s_bogasVoiceEndTick[1], s_bogasVoiceEndTick[2], s_bogasVoiceEndTick[3], *(unsigned short*)0xdff002
    detach
    quit
  end
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 220
commands
  silent
  printf "overlap ceiling tick=%u iterations=%u skid=%u crash=%u triple=%u pending=%u\n", g_macTicks, g_macDrivingIterations, $seenSkid, $seenCrash, $tripleSeen, $pendingReplacement
  detach
  quit
end

continue
