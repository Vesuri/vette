# Assert authentic three-context overlap and one subsequent context-2
# replacement on Course Two. The diagnostic physical Z-key edge supplies an
# indefinite horn on context 1 while original traffic supplies crash on
# context 2. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2
# FREEWAY_ROUTE=1 HORN_PROBE=1 FIDELITY_RANDOM_SEED=0x3BD90000.
set pagination off
set confirm off
set $seenContext1 = 0
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
  if $context == 1 && $instrument == 6
    set $seenContext1 = 1
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

break VetteScreen::presentMacFrame if $seenContext1 && $seenCrash
commands
  silent
  if !$tripleSeen && s_bogasContexts[0].playing && s_bogasContexts[0].instrument == 4 && s_bogasContexts[1].playing && s_bogasContexts[1].instrument == 6 && s_bogasContexts[2].playing && s_bogasContexts[2].instrument == 8
    if s_bogasInstruments[6].dma.attackBytes != 4990 || s_bogasInstruments[6].dma.reloadBytes != 7122 || s_bogasInstruments[6].dma.reloadOffset != 4990
      printf "overlap FAIL horn loop alignment\n"
      detach
      quit
    end
    set $tripleSeen = 1
    printf "overlap triple tick=%u iterations=%u level=%u contexts=%u/%u/%u channels=%u/%u/%u volumes=%u/%u/%u/%u deadlines=%u/%u/%u/%u dma=$%04x\n", g_macTicks, g_macDrivingIterations, s_bogasMixLevel, s_bogasContexts[0].instrument, s_bogasContexts[1].instrument, s_bogasContexts[2].instrument, s_bogasContexts[0].channel, s_bogasContexts[1].channel, s_bogasContexts[2].channel, s_bogasVoiceVolume[0], s_bogasVoiceVolume[1], s_bogasVoiceVolume[2], s_bogasVoiceVolume[3], s_bogasVoiceEndTick[0], s_bogasVoiceEndTick[1], s_bogasVoiceEndTick[2], s_bogasVoiceEndTick[3], *(unsigned short*)0xdff002
  end
  if $pendingReplacement && s_bogasContexts[$replacementContext].instrument == $replacementInstrument && s_bogasContexts[3-$replacementContext].playing
    printf "overlap replacement settled tick=%u iterations=%u replaced-context=%u level=%u contexts=%u/%u/%u channels=%u/%u/%u playing=%u/%u/%u volumes=%u/%u/%u/%u deadlines=%u/%u/%u/%u dma=$%04x\n", g_macTicks, g_macDrivingIterations, $replacementContext, s_bogasMixLevel, s_bogasContexts[0].instrument, s_bogasContexts[1].instrument, s_bogasContexts[2].instrument, s_bogasContexts[0].channel, s_bogasContexts[1].channel, s_bogasContexts[2].channel, s_bogasContexts[0].playing, s_bogasContexts[1].playing, s_bogasContexts[2].playing, s_bogasVoiceVolume[0], s_bogasVoiceVolume[1], s_bogasVoiceVolume[2], s_bogasVoiceVolume[3], s_bogasVoiceEndTick[0], s_bogasVoiceEndTick[1], s_bogasVoiceEndTick[2], s_bogasVoiceEndTick[3], *(unsigned short*)0xdff002
    detach
    quit
  end
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 300
commands
  silent
  printf "overlap ceiling tick=%u iterations=%u context1=%u crash=%u triple=%u pending=%u\n", g_macTicks, g_macDrivingIterations, $seenContext1, $seenCrash, $tripleSeen, $pendingReplacement
  detach
  quit
end

continue
