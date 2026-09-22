# Exercise the original cumulative-damage terminal branch and tow recovery.
# Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
# TERMINAL_DAMAGE_CHECKPOINT=1, without FOLLOW_ROAD. The checkpoint supplies
# source-authored preconditions; Traffic still makes every terminal decision.
set pagination off
set confirm off
set $armed = 0
set $picture = 0
set $mainExit = 0
set $outerReturn = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "terminal-tow loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[6].begin+0x4cb4) if !$armed
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  set $armed = 1
  printf "terminal-tow impact tick=%u iterations=%u difficulty=%d natural-speed=%d threshold=8\n", g_macTicks, g_macDrivingIterations, *(short*)(s_currentA5-0x542c), *(short*)($car+0x1a)
  continue
end

break getResource if $armed && type == 0x50494354 && id == 147
commands
  silent
  set $picture = $picture + 1
  printf "terminal-tow picture tick=%u frames=%u iterations=%u id=%d driving=%d terminal=%d\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, id, *(short*)(s_currentA5-0x5344), *(short*)(s_currentA5-0x341a)
  continue
end

break *(s_segments[1].begin+0x29e6) if $picture
commands
  silent
  set $mainExit = $mainExit + 1
  printf "terminal-tow main-exit tick=%u calls=%u\n", g_macTicks, $mainExit
  continue
end

break *(s_segments[1].begin+0x1f52) if $mainExit
commands
  silent
  set $outerReturn = $outerReturn + 1
  printf "terminal-tow outer-return tick=%u calls=%u\n", g_macTicks, $outerReturn
  continue
end

break *(s_segments[1].begin+0x1f56) if $outerReturn
commands
  silent
  printf "terminal-tow settled tick=%u frames=%u picture=%u main-exit=%u outer-return=%u driving=%u recovery-loaded=%u recovery-skipped=%u depth=%u\n", g_macTicks, g_macFramesPresented, $picture, $mainExit, $outerReturn, s_drivingFrameStarted, s_garageRecoveryPictureLoaded, s_garageRecoverySkipped, g_stageCDepth
  detach
  quit
end

continue
