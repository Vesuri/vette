# Exercise Vette's real Tour Mode menu command and one tour destination.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 TOUR_MODE_PROBE=1.
set pagination off
set confirm off
set $entered = 0
set $moved = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "tour-mode loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[1].begin+0x1198)
commands
  silent
  printf "tour-mode command before=%d item=%d menu=$%04x\n", *(signed short*)(s_currentA5-0x5318), $d1, $d2
  continue
end

break *(s_segments[1].begin+0x3456)
commands
  silent
  set $entered = $entered + 1
  set $beforeIndex = *(unsigned short*)(s_currentA5-0x4ddc)
  set $player = *(unsigned int*)(s_currentA5-0x3678)
  set $beforeX = *(unsigned int*)$player
  set $beforeZ = *(unsigned int*)($player+8)
  printf "tour-mode destination enter=%d enabled=%d index=%u x=$%x z=$%x\n", $entered, *(signed short*)(s_currentA5-0x5318), $beforeIndex, $beforeX, $beforeZ
  continue
end

break *(s_segments[1].begin+0x3504)
commands
  silent
  if *(unsigned short*)(s_currentA5-0x4ddc) != $beforeIndex
    set $moved = 1
    set $player = *(unsigned int*)(s_currentA5-0x3678)
    printf "tour-mode destination moved index=%u x=$%x z=$%x heading=$%04x\n", *(unsigned short*)(s_currentA5-0x4ddc), *(unsigned int*)$player, *(unsigned int*)($player+8), *(unsigned short*)($player+0x66)
  end
  continue
end

break /Users/vesa.halttunen/Documents/Vette/src/mac/MacLoader.cpp:5816
commands
  silent
  printf "tour-mode complete enabled=%d entered=%d moved=%d index=%u iterations=%u\n", *(signed short*)(s_currentA5-0x5318), $entered, $moved, *(unsigned short*)(s_currentA5-0x4ddc), g_macDrivingIterations
  detach
  quit
end

continue
