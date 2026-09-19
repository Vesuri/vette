# Record the original Damage Indicator state and expiry after its D-key handler.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_EVENT_RAW_KEY=0x22 (D).
set pagination off
set confirm off

break *(s_segments[1].begin+0x37ea) if *(short*)(s_currentA5-14188) == 1
commands
  silent
  printf "Damage Indicator enabled tick=%u expires=%u delta=%u frames=%u/%u depth=%u driving=%u\n", g_macTicks, *(unsigned int*)(s_currentA5-14176), *(unsigned int*)(s_currentA5-14176)-g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, s_drivingFrameStarted
  detach
  quit
end

continue
