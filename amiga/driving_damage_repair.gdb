# Exercise ordinary damage and the source-defined gas-station repair.
# Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
# DAMAGE_REPAIR_CHECKPOINT=1, without FOLLOW_ROAD. The checkpoint changes only
# source-authored preconditions at safe frame boundaries; this script observes.
set pagination off
set confirm off
set $damage = 0
set $repair = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "damage-repair loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[6].begin+0x4cb4) if !$damage
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "damage-repair impact tick=%u iterations=%u difficulty=%d speed=%d side=%d\n", g_macTicks, g_macDrivingIterations, *(short*)(s_currentA5-0x542c), *(short*)($car+0x1a), *(short*)(s_currentA5-0x5104)
  set $damage = 1
  continue
end

break *(s_segments[6].begin+0x4e04) if $damage == 1
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "damage-repair damaged tick=%u cells=%d,%d,%d,%d,%d,%d,%d,%d steering=%d\n", g_macTicks, *(short*)(s_currentA5-0x346a), *(short*)(s_currentA5-0x3468), *(short*)(s_currentA5-0x3466), *(short*)(s_currentA5-0x3464), *(short*)(s_currentA5-0x3462), *(short*)(s_currentA5-0x3460), *(short*)(s_currentA5-0x345e), *(short*)(s_currentA5-0x345c), *(short*)(s_currentA5-0x4ff6)
  set $damage = 2
  continue
end

break *(s_segments[6].begin+0x5688) if $damage
commands
  silent
  set $repair = 1
  printf "damage-repair station tick=%u iterations=%u cell=(%u,%u) local=(%u,%u)\n", g_macTicks, g_macDrivingIterations, *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), (*(unsigned int*)$a0)&0x7ff, (*(unsigned int*)($a0+8))&0x7ff
  continue
end

break *(s_segments[6].begin+0x5732) if $repair
commands
  silent
  printf "damage-repair cleared tick=%u repair-until=%u active=%d cells=%d,%d,%d,%d,%d,%d,%d,%d steering=%d\n", g_macTicks, *(unsigned int*)(s_currentA5-0x343c), *(short*)(s_currentA5-0x3458), *(short*)(s_currentA5-0x346a), *(short*)(s_currentA5-0x3468), *(short*)(s_currentA5-0x3466), *(short*)(s_currentA5-0x3464), *(short*)(s_currentA5-0x3462), *(short*)(s_currentA5-0x3460), *(short*)(s_currentA5-0x345e), *(short*)(s_currentA5-0x345c), *(short*)(s_currentA5-0x4ff6)
  detach
  quit
end

continue
