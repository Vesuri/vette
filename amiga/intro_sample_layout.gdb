# PROBES=1, full intro. Verify the resident DMA data for the actual resources.
set pagination off
set confirm off
set $engineChecked = 0
break VetteScreen::showLoudStop
commands
  silent
  printf "intro-samples FAIL loud stop\n"
  detach
  quit
end
break VetteScreen::presentMacFrame if s_introSoundStarted[2] && !$engineChecked
commands
  silent
  set $sample = &s_introSamples[2]
  if $sample->size != 6053 || $sample->dma.attackBytes != 5682 || $sample->dma.reloadOffset != 370 || $sample->dma.reloadBytes != 5312 || $sample->chipData[0] != 23 || $sample->chipData[5681] != 81
    printf "intro-samples FAIL engine layout/header\n"
    detach
    quit
  end
  set $engineChecked = 1
  printf "intro-samples engine PASS attack=5682 loop=370..5682 PCM-first=23\n"
  continue
end
break VetteScreen::presentMacFrame if s_introSoundStarted[4]
commands
  silent
  set $sample = &s_introSamples[4]
  if !$engineChecked || $sample->dma.attackBytes != 44928 || $sample->dma.reloadBytes != 2 || $sample->chipData[$sample->dma.reloadOffset] != 0 || $sample->chipData[$sample->dma.reloadOffset+1] != 0
    printf "intro-samples FAIL signature one-shot\n"
  else
    printf "intro-samples PASS engine header/loop and signature silent reload\n"
  end
  detach
  quit
end
continue
