# Verify that a physical raw-key state reaches the live Macintosh KeyMap at a
# completed driving-frame boundary, without consuming the queued key event.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_RAW_KEY=0x45.
set pagination off
set confirm off
set $armed_tick = 0
watch s_drivingFrameStarted
commands 1
  silent
  if s_drivingFrameStarted
    set $armed_tick = g_macTicks
    disable 1
  end
  continue
end

watch g_macFramesPresented
commands 2
  silent
  if $armed_tick && g_macTicks > $armed_tick
    printf "physical Escape refresh keyMap[6]=$%02x queued=%u presented=%u\n", *(unsigned char*)(s_currentA5+22), g_macFramesQueued, g_macFramesPresented
    detach
    quit
  end
  continue
end

continue
