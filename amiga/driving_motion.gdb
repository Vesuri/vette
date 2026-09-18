# Capture the chunky surface at two consecutive driving VBL callbacks after
# Course One is accepted.  The callbacks bracket original renderer execution;
# unlike display presentation, they continue during long road construction.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $motion_frames = 0

break *vette_user_vbl_trampoline+38 if s_garageClickPhase >= 9 && g_macVBLCallbackTask == (unsigned int)s_vblTasks[1]
commands
  silent
  set $motion_frames = $motion_frames + 1
  if $motion_frames == 1
    dump binary memory ../tmp/amiga_driving_motion_1.raw s_colorScreen s_colorScreen+81920
    continue
  end
  dump binary memory ../tmp/amiga_driving_motion_2.raw s_colorScreen s_colorScreen+81920
  printf "driving frames=%u phase=%u depth=%u ticks=%u keyMap[10..11]=$%04x controls=(-20464:%d,-20462:%d)\n", $motion_frames, s_garageClickPhase, g_stageCDepth, g_macTicks, *(unsigned short*)(s_currentA5+26), *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462)
  detach
  quit
end

continue
