# Timestamp the major construction phases of the first complete driving frame.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $start_tick = 0xffffffff

watch s_drivingFrameStarted
commands 1
  silent
  if s_drivingFrameStarted && $start_tick == 0xffffffff
    set $start_tick = g_macTicks
    printf "frame phase start tick=%u queued=%u presented=%u callback=%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20462)
    disable 1
    enable 2
    enable 3
    enable 4
    continue
  end
  continue
end

break *(s_segments[1].begin+0x24ea)
commands 2
  silent
  printf "frame phase first-picture-batch elapsed=%u queued=%u presented=%u callback=%d\n", g_macTicks-$start_tick, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20462)
  disable 2
  continue
end
disable 2

break *(s_segments[1].begin+0x256c)
commands 3
  silent
  printf "frame phase all-pictures elapsed=%u queued=%u presented=%u callback=%d\n", g_macTicks-$start_tick, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20462)
  disable 3
  continue
end
disable 3

break *(s_segments[1].begin+0x286a)
commands 4
  silent
  printf "frame phase dynamic-renderer elapsed=%u queued=%u presented=%u callback=%d\n", g_macTicks-$start_tick, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20462)
  disable 4
  continue
end
disable 4

watch g_macFramesPresented
commands 5
  silent
  if s_drivingFrameStarted && $start_tick != 0xffffffff && g_macTicks > $start_tick
    printf "frame phase complete elapsed=%u queued=%u presented=%u callback=%d\n", g_macTicks-$start_tick, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20462)
    detach
    quit
  end
  continue
end

continue
