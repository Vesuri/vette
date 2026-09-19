# Capture the Damage Indicator result at the baseline's fixed presented-frame
# count.  Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_EVENT_RAW_KEY=0x22.
set pagination off
set confirm off

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 40
commands
  silent
  dump binary memory ../tmp/amiga_driving_d.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/amiga_driving_d.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  printf "captured Damage Indicator at ticks=%u frames=%u/%u depth=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth
  detach
  quit
end

continue
