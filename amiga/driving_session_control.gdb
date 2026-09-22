# Prove a P-suspended session's shipped Restart Race or Return to Game command.
# Build with PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 SESSION_CONTROL_ITEM=5 or 6.
set pagination off
set confirm off
set $handler = 0

break menuKey if g_sessionControlProbePhase == 3
commands
  silent
  printf "session-control MenuKey key=$%02x tick=%u\n", requestedKey, g_macTicks
  if requestedKey == 0x61 || requestedKey == 0x72
    set $fileHandle = *(unsigned int*)(s_currentA5-0x5b70)
    set $fileMenu = *(unsigned int*)$fileHandle
    printf "session-control File flags=$%08x id=%u\n", *(unsigned int*)($fileMenu+10), *(unsigned short*)$fileMenu
  end
  continue
end

break *(s_segments[1].begin+0x103e) if g_sessionControlProbePhase == 3
commands
  silent
  printf "session-control dispatch packed=$%08x tick=%u\n", $d0, g_macTicks
  continue
end

break *(s_segments[1].begin+0x1086)
commands
  silent
  set $handler = 5
  printf "session-control handler item=5 tick=%u phase=%u driving=%u iterations=%u\n", g_macTicks, g_sessionControlProbePhase, s_drivingFrameStarted, g_macDrivingIterations
  continue
end

break *(s_segments[1].begin+0x10cc)
commands
  silent
  set $handler = 6
  printf "session-control handler item=6 tick=%u phase=%u driving=%u iterations=%u\n", g_macTicks, g_sessionControlProbePhase, s_drivingFrameStarted, g_macDrivingIterations
  continue
end

break *(s_segments[1].begin+0x10e4)
commands
  silent
  set $handler = 7
  printf "session-control handler item=7 tick=%u phase=%u driving=%u iterations=%u\n", g_macTicks, g_sessionControlProbePhase, s_drivingFrameStarted, g_macDrivingIterations
  continue
end

break *(s_segments[1].begin+0x1fd2) if $handler == g_sessionControlProbeItem
commands
  silent
  printf "session-control resumed tick=%u item=%u handler=%u phase=%u iterations=%u race-state=%d driving-global=%u bridge=%u\n", g_macTicks, g_sessionControlProbeItem, $handler, g_sessionControlProbePhase, g_macDrivingIterations, *(signed short*)(s_currentA5-13296), *(unsigned short*)(s_currentA5-21316), s_drivingFrameStarted
  detach
  quit
end

continue
