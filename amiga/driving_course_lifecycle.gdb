# Prove a selected course's original endpoint chain and complete return to the
# garage. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINISH_CHECKPOINT=1
# and optionally GARAGE_COURSE=1..4 (default Course One).
set pagination off
set confirm off
set $endpoint0 = 0
set $endpoint1 = 0
set $endpoint2 = 0
set $finishCore = 0
set $scoreCalls = 0
set $scoreReturned = 0
set $mainExit = 0
set $outerReturn = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "course-lifecycle loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[6].begin+0x59a2)
commands
  silent
  set $endpoint0 = $endpoint0 + 1
  printf "course-lifecycle endpoint-0 tick=%u course=%d long=%d\n", g_macTicks, *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082)
  continue
end

break *(s_segments[6].begin+0x5602)
commands
  silent
  set $endpoint1 = $endpoint1 + 1
  printf "course-lifecycle endpoint-1 tick=%u course=%d long=%d\n", g_macTicks, *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082)
  continue
end

break *(s_segments[6].begin+0x59c8)
commands
  silent
  set $endpoint2 = $endpoint2 + 1
  printf "course-lifecycle endpoint-2 tick=%u course=%d long=%d\n", g_macTicks, *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082)
  continue
end

break *(s_segments[6].begin+0x52a6)
commands
  silent
  set $finishCore = $finishCore + 1
  printf "course-lifecycle finish-core tick=%u course=%d long=%d\n", g_macTicks, *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082)
  continue
end

break *(s_segments[5].begin+0x56)
commands
  silent
  set $scoreCalls = $scoreCalls + 1
  continue
end

break *(s_segments[5].begin+0x7c2)
commands
  silent
  set $scoreReturned = $scoreReturned + 1
  continue
end

break *(s_segments[1].begin+0x29e6) if $finishCore && $scoreReturned
commands
  silent
  set $mainExit = $mainExit + 1
  continue
end

break *(s_segments[1].begin+0x1f52) if $mainExit && $scoreReturned
commands
  silent
  set $outerReturn = $outerReturn + 1
  continue
end

break *(s_segments[1].begin+0x1f56) if $outerReturn
commands
  silent
  printf "course-lifecycle settled tick=%u endpoints=(%u,%u,%u) finish=%u score=%u/%u main-exit=%u outer-return=%u course=%d long=%d difficulty=%d driving=%u\n", g_macTicks, $endpoint0, $endpoint1, $endpoint2, $finishCore, $scoreCalls, $scoreReturned, $mainExit, $outerReturn, *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082), *(signed short*)(s_currentA5-0x542c), s_drivingFrameStarted
  detach
  quit
end

continue
