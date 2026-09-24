# Prove that the ready/set/GO sequence reaches three complete Paula AUD2 DMA
# restart protocols. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FOLLOW_ROAD=1.
set pagination off
set confirm off
set $countdown = 0
set $goLoaded = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "countdown-audio FAIL loud stop trap=$%04x %s/%s caller=%u+$%x\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a)
commands
  silent
  set $context = *(unsigned short*)($sp+4)
  set $instrument = *(unsigned short*)($sp+14)
  if $context == 2
    if $countdown == 0 && $instrument == 10
      set $countdown = 1
    else
      if $countdown == 1 && $instrument == 10
        set $countdown = 2
      else
        if $countdown == 2 && $instrument == 11
          set $countdown = 3
          set $goLoaded = 1
        else
          printf "countdown-audio FAIL unexpected context-2 sequence step=%u instrument=%u\n", $countdown, $instrument
          detach
          quit
        end
      end
    end
  end
  continue
end

# The wrapper breakpoint above precedes the host implementation. The next
# presented frame is after bogasLoad has completed both required DMA waits.
break VetteScreen::presentMacFrame if $goLoaded
commands
  silent
  if s_bogasInstruments[4].dma.attackBytes != 5682 || s_bogasInstruments[4].dma.reloadBytes != 5312 || s_bogasInstruments[10].dma.attackBytes != 8400 || s_bogasInstruments[10].dma.reloadBytes != 2 || s_bogasInstruments[11].dma.attackBytes != 4608 || s_bogasInstruments[11].dma.reloadBytes != 2
    printf "countdown-audio FAIL engine/beep DMA layout\n"
    detach
    quit
  end
  if $countdown == 3 && g_probeBogasDmaRestarts[2] == 3 && s_bogasContexts[2].playing && s_bogasContexts[2].instrument == 11 && s_bogasContexts[2].channel == 2 && s_bogasVoiceVolume[2] == 64
    printf "countdown-audio PASS tick=%u sequence=10,10,11 AUD2-restarts=%u playing=%u instrument=%u volume=%u dma=$%04x\n", g_macTicks, g_probeBogasDmaRestarts[2], s_bogasContexts[2].playing, s_bogasContexts[2].instrument, s_bogasVoiceVolume[2], *(unsigned short*)0xdff002
  else
    printf "countdown-audio FAIL tick=%u step=%u AUD2-restarts=%u playing=%u instrument=%u channel=%u volume=%u dma=$%04x\n", g_macTicks, $countdown, g_probeBogasDmaRestarts[2], s_bogasContexts[2].playing, s_bogasContexts[2].instrument, s_bogasContexts[2].channel, s_bogasVoiceVolume[2], *(unsigned short*)0xdff002
  end
  detach
  quit
end

continue
