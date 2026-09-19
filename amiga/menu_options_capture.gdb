# Capture the first event-loop surface after correctly encoded Escape leaves
# driving.  Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_RAW_KEY=0x45.
set pagination off
set confirm off

# First change arms the bridge's driving state; second change is Escape exit.
watch s_drivingFrameStarted
continue
continue
delete 1

# Allow both queued Escape edges and any resulting drawing to pass through the
# ordinary event loop, then capture a settled state three Macintosh seconds on.
set $capture_tick = g_macTicks + 180
break vbiHandler if g_macTicks >= $capture_tick
continue
dump binary memory ../tmp/amiga_menu_options.raw s_colorScreen s_colorScreen+81920
dump binary memory ../tmp/amiga_menu_options.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
printf "captured settled post-Escape state at ticks=%u frames=%u/%u depth=%u driving=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, s_drivingFrameStarted
detach
quit
