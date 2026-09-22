# Capture the final road device palette after sustained driving. Requires
# SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break vbiHandler if s_drivingFrameStarted && g_macDrivingIterations >= 30 && *(short*)(s_currentA5-13296) >= 3
commands
  silent
  dump binary memory ../tmp/amiga_driving_palette_trace.ctab s_windowManagerColors s_windowManagerColors+136
  dump binary memory ../tmp/amiga_driving.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  printf "driving palette captured ticks=%u frames=%u/%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented
  detach
  quit
end

continue
