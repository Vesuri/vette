# Prove that correctly encoded physical Escape takes the shipped Menu Options
# transition out of driving.  Requires:
#   SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_RAW_KEY=0x45
set pagination off
set confirm off
set $saw_driving = 0

watch s_drivingFrameStarted
commands 1
  silent
  if s_drivingFrameStarted
    set $saw_driving = 1
    continue
  end
  if $saw_driving
    printf "Escape transition: ticks=%u frames=%u/%u depth=%u KeyMap[6]=$%02x drivingGlobal=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, *(unsigned char*)(s_currentA5+22), *(unsigned short*)(s_currentA5-21316)
    detach
    quit
  end
  continue
end

continue
