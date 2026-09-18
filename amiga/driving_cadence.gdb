# Measure live driving presentation over exactly 300 Macintosh ticks (6 seconds).
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $start_tick = 0
set $target_tick = 0xffffffff
set $start_queued = 0
set $start_presented = 0

break *vette_user_vbl_trampoline+38 if s_garageClickPhase >= 9 && g_macVBLCallbackTask == (unsigned int)s_vblTasks[1]
commands 1
  silent
  set $start_tick = g_macTicks
  set $target_tick = $start_tick + 300
  set $start_queued = g_macFramesQueued
  set $start_presented = g_macFramesPresented
  disable 1
  enable 2
  continue
end

break *vette_user_vbl_trampoline+38 if s_garageClickPhase >= 9 && g_macVBLCallbackTask == (unsigned int)s_vblTasks[1] && g_macTicks >= $target_tick
disable 2
commands 2
  silent
  printf "driving cadence ticks=%u queued=%u presented=%u totals=(%u,%u) controls=(-20464:%d,-20462:%d)\n", g_macTicks-$start_tick, g_macFramesQueued-$start_queued, g_macFramesPresented-$start_presented, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462)
  detach
  quit
end

continue
