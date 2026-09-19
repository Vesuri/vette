# Measure one complete iteration of the game's driving loop.  Main+$1FEA is
# the first trap after the loop entry at Main+$1FD2.  Its first hit begins
# frame 1; its second hit follows the completed-frame branch at Main+$29C6
# and begins frame 2.  Main+$29E6 is the event-loop path taken only when
# driving exits, not a per-frame boundary.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $hits = 0
set $start_tick = 0
set $start_queued = 0
set $start_presented = 0

break *(s_segments[1].begin+0x1fea)
commands 1
  silent
  set $hits = $hits+1
  if $hits == 1
    set $start_tick = g_macTicks
    set $start_queued = g_macFramesQueued
    set $start_presented = g_macFramesPresented
    printf "driving frame 1 began ticks=%u totals=(%u,%u)\n", g_macTicks, g_macFramesQueued, g_macFramesPresented
  end
  if $hits == 2
    printf "driving frame boundary ticks=%u queued=%u presented=%u totals=(%u,%u) controls=(-20464:%d,-20462:%d)\n", g_macTicks-$start_tick, g_macFramesQueued-$start_queued, g_macFramesPresented-$start_presented, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462)
    detach
    quit
  end
  continue
end

continue
