# Trace Palette Manager state across the deterministic selector-to-driving path.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $palette_calls = 0

break src/mac/MacLoader.cpp:4700
commands
  silent
  set $palette_calls = $palette_calls + 1
  set $usp = (unsigned char *)$a4
  printf "GetNewPalette #%u id=%d ticks=%u frames=%u/%u driving=%d\n", $palette_calls, (short)(($usp[0] << 8) | $usp[1]), g_macTicks, g_macFramesQueued, g_macFramesPresented, s_drivingFrameStarted
  continue
end

break src/mac/MacLoader.cpp:4718
commands
  silent
  set $usp = (unsigned char *)$a4
  printf "SetPalette window=%p palette=%p front=%p ticks=%u driving=%d\n", (void *)(($usp[6] << 24) | ($usp[7] << 16) | ($usp[8] << 8) | $usp[9]), (void *)(($usp[2] << 24) | ($usp[3] << 16) | ($usp[4] << 8) | $usp[5]), s_windowList, g_macTicks, s_drivingFrameStarted
  continue
end

break src/mac/MacLoader.cpp:4741
commands
  silent
  set $usp = (unsigned char *)$a4
  printf "ActivatePalette target=%p front=%p seed=%u ticks=%u driving=%d\n", (void *)(($usp[0] << 24) | ($usp[1] << 16) | ($usp[2] << 8) | $usp[3]), s_windowList, (unsigned int)((s_windowManagerColors[0] << 24) | (s_windowManagerColors[1] << 16) | (s_windowManagerColors[2] << 8) | s_windowManagerColors[3]), g_macTicks, s_drivingFrameStarted
  continue
end

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 40
commands
  silent
  dump binary memory ../tmp/amiga_driving_palette_trace.ctab s_windowManagerColors s_windowManagerColors+136
  printf "driving palette captured ticks=%u frames=%u/%u calls=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, $palette_calls
  detach
  quit
end

continue
