# Capture the F1 Helicopter View Left result at a fixed presented-frame count.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_EVENT_RAW_KEY=0x50.
set pagination off
set confirm off

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 40
commands
  silent
  dump binary memory ../tmp/amiga_driving_f1.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/amiga_driving_f1.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  printf "captured F1 view at ticks=%u frames=%u/%u depth=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth
  detach
  quit
end

continue
