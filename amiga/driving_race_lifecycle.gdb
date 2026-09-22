# Prove Course One's original finish/result/score/garage lifecycle. Requires
# PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINISH_CHECKPOINT=1.
set pagination off
set confirm off
set $finishLine = 0
set $finishCore = 0
set $scoreCalls = 0
set $scoreScreenReturned = 0
set $mainExit = 0
set $outerReturn = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "race-lifecycle loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[6].begin+0x59a2)
commands
  silent
  set $finishLine = $finishLine + 1
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "race-lifecycle finish-line tick=%u iterations=%u cell=(%u,%u) local=(%u,%u) course=%d\n", g_macTicks, g_macDrivingIterations, *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(signed char*)(s_currentA5-0x555a)
  continue
end

break *(s_segments[6].begin+0x52a6)
commands
  silent
  set $finishCore = $finishCore + 1
  printf "race-lifecycle finish-core tick=%u iterations=%u driving=%d\n", g_macTicks, g_macDrivingIterations, *(signed short*)(s_currentA5-0x5344)
  continue
end

break *(s_segments[5].begin+0x56)
commands
  silent
  set $scoreCalls = $scoreCalls + 1
  printf "race-lifecycle score tick=%u calls=%u\n", g_macTicks, $scoreCalls
  continue
end

break *(s_segments[5].begin+0x7c2)
commands
  silent
  set $scoreScreenReturned = $scoreScreenReturned + 1
  printf "race-lifecycle score-screen-return tick=%u calls=%u result-entered=%u result-skipped=%u\n", g_macTicks, $scoreScreenReturned, s_finishResultScreenEntered, s_finishResultSkipped
  continue
end

# Main's driving-loop exit target is reached only after the finish handler and
# Score return.  The original Main code then owns the garage transition.
break *(s_segments[1].begin+0x29e6) if $finishCore && $scoreScreenReturned
commands
  silent
  set $mainExit = $mainExit + 1
  printf "race-lifecycle main-exit tick=%u calls=%u\n", g_macTicks, $mainExit
  continue
end

break *(s_segments[1].begin+0x1f52) if $mainExit && $scoreScreenReturned
commands
  silent
  set $outerReturn = $outerReturn + 1
  printf "race-lifecycle outer-return tick=%u calls=%u\n", g_macTicks, $outerReturn
  continue
end

# The outer loop's A5+$462 callback performs the post-driving/garage handoff.
break *(s_segments[1].begin+0x1f56) if $outerReturn
commands
  silent
  printf "race-lifecycle settled tick=%u frames=%u finish-line=%u finish-core=%u score=%u score-return=%u main-exit=%u outer-return=%u result-entered=%u result-skipped=%u driving=%u windows=%p depth=%u\n", g_macTicks, g_macFramesPresented, $finishLine, $finishCore, $scoreCalls, $scoreScreenReturned, $mainExit, $outerReturn, s_finishResultScreenEntered, s_finishResultSkipped, s_drivingFrameStarted, s_windowList, g_stageCDepth
  detach
  quit
end

continue
