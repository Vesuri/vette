# Capture the ordinary scripted driving view at the same presented-frame count
# as driving_f1_capture.gdb.  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 40
commands
  silent
  dump binary memory ../tmp/amiga_driving_baseline.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/amiga_driving_baseline.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  printf "captured baseline view at ticks=%u frames=%u/%u depth=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth
  detach
  quit
end

continue
