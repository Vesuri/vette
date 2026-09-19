# Drive straight under the deterministic garage path and record the first
# substantial loss of the current car's paired engine-motion words.  This is a
# candidate marker, not collision proof; the 900-frame measurement established
# that the words can remain capped independently of course position.  Retain a
# short post-marker window so a loud stop wins if one follows.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1.
set pagination off
set confirm off
set $last_frame = 0
set $max_motion = 0
set $impact_frame = 0

break VetteScreen::showLoudStop
commands 1
  silent
  printf "collision-path loud stop: ticks=%u frames=%u/%u depth=%u trap=$%04x %s/%s selector=%d caller=%u+$%x\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, g_stageCDepth, g_trapWord, g_trapManager, g_trapRoutine, g_trapSelector, g_trapSegment, g_trapOffset
  detach
  quit
end

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 40
commands 2
  silent
  if g_macFramesPresented == $last_frame
    continue
  end
  set $last_frame = g_macFramesPresented
  set $car = *(unsigned int*)(s_currentA5-13944)
  set $motion = *(unsigned short*)($car+66)
  if $motion > $max_motion
    set $max_motion = $motion
  end
  if g_macFramesPresented % 100 == 0
    printf "straight milestone: ticks=%u frames=%u motion=%u max=%u state=$%x/$%x/$%x\n", g_macTicks, g_macFramesPresented, $motion, $max_motion, *(unsigned int*)($car+120), *(unsigned int*)($car+128), *(unsigned int*)($car+136)
  end
  if !$impact_frame && $max_motion > 40 && $motion + 12 < $max_motion
    set $impact_frame = g_macFramesPresented
    dump binary memory ../tmp/amiga_driving_collision.raw s_colorScreen s_colorScreen+81920
    dump binary memory ../tmp/amiga_driving_collision.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
    dump binary memory ../tmp/amiga_driving_collision_car.raw $car $car+256
    printf "motion-drop candidate: ticks=%u frame=%u motion=%u max=%u state=$%x/$%x/$%x\n", g_macTicks, $impact_frame, $motion, $max_motion, *(unsigned int*)($car+120), *(unsigned int*)($car+128), *(unsigned int*)($car+136)
  end
  if $impact_frame && g_macFramesPresented >= $impact_frame + 40
    printf "motion drop settled without loud stop: ticks=%u frames=%u depth=%u motion=%u max=%u driving=%u\n", g_macTicks, g_macFramesPresented, g_stageCDepth, $motion, $max_motion, s_drivingFrameStarted
    detach
    quit
  end
  if g_macFramesPresented >= 900
    printf "collision ceiling: ticks=%u frames=%u depth=%u motion=%u max=%u driving=%u\n", g_macTicks, g_macFramesPresented, g_stageCDepth, $motion, $max_motion, s_drivingFrameStarted
    detach
    quit
  end
  continue
end

continue
