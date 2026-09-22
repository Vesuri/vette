# Prove the source difficulty split at a naturally reached Course One impact.
# Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_DIFFICULTY=1..3 and
# DIFFICULTY_DAMAGE_CHECKPOINT=1, without FOLLOW_ROAD.
set pagination off
set confirm off
set $attempts = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "difficulty-damage loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[6].begin+0x4dce)
commands
  silent
  set $attempts = $attempts + 1
  if *(signed short*)(s_currentA5-0x542c) == 0
    printf "difficulty-damage immune tick=%u attempts=%u difficulty=0 cells=%d,%d,%d,%d,%d,%d,%d,%d\n", g_macTicks, $attempts, *(short*)(s_currentA5-0x346a), *(short*)(s_currentA5-0x3468), *(short*)(s_currentA5-0x3466), *(short*)(s_currentA5-0x3464), *(short*)(s_currentA5-0x3462), *(short*)(s_currentA5-0x3460), *(short*)(s_currentA5-0x345e), *(short*)(s_currentA5-0x345c)
    detach
    quit
  end
  continue
end

break *(s_segments[6].begin+0x4e04)
commands
  silent
  set $sum = *(short*)(s_currentA5-0x346a) + *(short*)(s_currentA5-0x3468) + *(short*)(s_currentA5-0x3466) + *(short*)(s_currentA5-0x3464) + *(short*)(s_currentA5-0x3462) + *(short*)(s_currentA5-0x3460) + *(short*)(s_currentA5-0x345e) + *(short*)(s_currentA5-0x345c)
  if $sum
    printf "difficulty-damage applied tick=%u attempts=%u difficulty=%d cells=%d,%d,%d,%d,%d,%d,%d,%d steering=%d\n", g_macTicks, $attempts, *(signed short*)(s_currentA5-0x542c), *(short*)(s_currentA5-0x346a), *(short*)(s_currentA5-0x3468), *(short*)(s_currentA5-0x3466), *(short*)(s_currentA5-0x3464), *(short*)(s_currentA5-0x3462), *(short*)(s_currentA5-0x3460), *(short*)(s_currentA5-0x345e), *(short*)(s_currentA5-0x345c), *(short*)(s_currentA5-0x4ff6)
    detach
    quit
  end
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 120
commands
  silent
  printf "difficulty-damage ceiling tick=%u attempts=%u difficulty=%d\n", g_macTicks, $attempts, *(signed short*)(s_currentA5-0x542c)
  detach
  quit
end

continue
