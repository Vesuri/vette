# Observe the ordinary in-race police lifecycle. The checkpoint supplies a
# nearby valid traffic object and all four source-authored offense bits; the
# original Traffic/Main state machines must catch the player, draw the charge
# list, apply 55 seconds cumulatively, release the car, and resume racing.
set pagination off
set confirm off
set $caught = 0
set $penalized = 0
set $released = 0
set $start = 0
set $penaltyStart = 0

break *(s_segments[6].begin+0x0f3e)
commands
  silent
  set $player = *(unsigned int*)(s_currentA5-0x3678)
  set $caught = 1
  set $start = *(unsigned int*)(s_currentA5-0x3408)
  printf "police caught tick=%u iterations=%u offenses=$%02x raceStart=%u\n", g_macTicks, g_macDrivingIterations, *(unsigned char*)($player+0x32), $start
  continue
end

break *(s_segments[6].begin+0x1066) if $caught
commands
  silent
  if !$penalized
    set $penaltyStart = *(unsigned int*)($a5-0x3408)
  end
  set $penalized = 1
  printf "police penalty-step tick=%u bit=%u amount=%d accumulated=%u\n", g_macTicks, $d3, *(signed int*)($a1-4), (unsigned int)($penaltyStart-$d2)
  continue
end

break *(s_segments[6].begin+0x0fa6) if $caught
commands
  silent
  set $player = *(unsigned int*)(s_currentA5-0x3678)
  set $released = 1
  printf "police released tick=%u iterations=%u offenses=$%02x state=%u player-state=%d\n", g_macTicks, g_macDrivingIterations, *(unsigned char*)($player+0x32), *(unsigned char*)($player+0x33), *(signed char*)($player+0x3a)
  detach
  quit
end

break VetteScreen::showLoudStop
commands
  silent
  printf "police loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

continue
