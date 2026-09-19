# Trace the original game's sound-play requests during the deterministic
# straight-ahead garage trajectory.  This arms only after the driving task is
# live, so selector/garage setup sounds do not obscure the first course event.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1 build.
set pagination off
set confirm off
set $sound_armed = 0
set $sound_hits = 0

break *vette_user_vbl_trampoline+38 if !$sound_armed && s_garageClickPhase >= 9 && g_macVBLCallbackTask == (unsigned int)s_vblTasks[1]
commands 1
  silent
  set $sound_armed = 1
  set $sound_play = (unsigned int)s_segments[9].begin + 0x174
  printf "driving sound trace armed: ticks=%u frames=%u sound+$0174=$%x\n", g_macTicks, g_macFramesPresented, $sound_play
  break *$sound_play
  commands 3
    silent
    set $sound_hits = $sound_hits + 1
    printf "sound play %u: ticks=%u frames=%u caller=$%x long=$%x word=$%x\n", $sound_hits, g_macTicks, g_macFramesPresented, *(unsigned int*)$sp, *(unsigned int*)($sp+4), *(unsigned short*)($sp+8)
    continue
  end
  continue
end

break VetteScreen::presentMacFrame if $sound_armed && g_macFramesPresented >= 480
commands 2
  silent
  dump binary memory ../tmp/amiga_driving_lake.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/amiga_driving_lake.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  printf "lake ceiling: ticks=%u frames=%u sound plays=%u depth=%u driving=%u\n", g_macTicks, g_macFramesPresented, $sound_hits, g_stageCDepth, s_drivingFrameStarted
  printf "segment begins: Main=$%x Initialize=$%x Communication=$%x Traffic=$%x FRED=$%x sound=$%x\n", s_segments[1].begin, s_segments[2].begin, s_segments[3].begin, s_segments[6].begin, s_segments[7].begin, s_segments[9].begin
  detach
  quit
end

continue
