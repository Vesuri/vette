# Wait for the regression-only Button click during the tram/bell phase, then
# verify that retiring the intro window relinquishes its direct Paula voices.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "intro-click-audio FAIL loud stop trap=$%04x %s/%s caller=%u+$%x\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break paintBehind if s_introAudioRetired
commands
  silent
  if g_introAudioState == 2 && s_introMusicEndTick == 0 && s_introEffectEndTick[0] == 0 && s_introEffectEndTick[1] == 0 && g_probePaulaZeroedMask == 15
    printf "intro-click-audio PASS tick=%u state=%u deadlines=%u/%u/%u zeroed=$%x\n", g_macTicks, g_introAudioState, s_introMusicEndTick, s_introEffectEndTick[0], s_introEffectEndTick[1], g_probePaulaZeroedMask
  else
    printf "intro-click-audio FAIL state=%u deadlines=%u/%u/%u zeroed=$%x\n", g_introAudioState, s_introMusicEndTick, s_introEffectEndTick[0], s_introEffectEndTick[1], g_probePaulaZeroedMask
  end
  detach
  quit
end

continue
