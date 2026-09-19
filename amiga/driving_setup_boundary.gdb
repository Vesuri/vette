# Measure consecutive completed driving-frame presentations.  Production
# replaces Main+$1FD2's verified TST/BEQ pair with a private Line-A boundary
# hook, so do not plant a software breakpoint on that instruction.  A hardware
# watch on the presentation counter observes the hook's result without trace
# state leaking through Line-A dispatch.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $hits = 0
set $armed = 0
set $armed_tick = 0
set $start_tick = 0
set $start_queued = 0
set $start_presented = 0

watch s_drivingFrameStarted
commands 1
  silent
  if s_drivingFrameStarted && !$armed
    set $armed = 1
    set $armed_tick = g_macTicks
    disable 1
  end
  continue
end

watch g_macFramesPresented
commands 2
  silent
  if $armed && g_macTicks > $armed_tick
    set $hits = $hits+1
    if $hits == 1
      set $start_tick = g_macTicks
      set $start_queued = g_macFramesQueued
      set $start_presented = g_macFramesPresented
      printf "driving frame 1 presented ticks=%u totals=(%u,%u)\n", g_macTicks, g_macFramesQueued, g_macFramesPresented
      continue
    end
    printf "driving frame boundary ticks=%u queued=%u presented=%u totals=(%u,%u) controls=(-20464:%d,-20462:%d)\n", g_macTicks-$start_tick, g_macFramesQueued-$start_queued, g_macFramesPresented-$start_presented, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462)
    detach
    quit
  end
  continue
end

continue
