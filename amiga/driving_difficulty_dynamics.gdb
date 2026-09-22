# Observe the resident difficulty-dependent motion scaling and low-speed cruise
# rule. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1,
# GARAGE_DIFFICULTY=1..3, and DIFFICULTY_CRUISE_CHECKPOINT=1.
set pagination off
set confirm off
set $tractionPending = 0
set $tractionSeen = 0
set $cruiseSeen = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "difficulty-dynamics loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[6].begin+0x0ade) if $d0 >= 8 && !$tractionSeen
commands
  silent
  set $tractionInput = $d0
  set $tractionDifficulty = *(signed short*)(s_currentA5-0x542c)
  set $tractionPending = 1
  continue
end

break *(s_segments[6].begin+0x0afc) if $tractionPending
commands
  silent
  set $tractionPending = 0
  set $tractionSeen = 1
  printf "difficulty-dynamics motion difficulty=%d input=%d output=%d\n", $tractionDifficulty, $tractionInput, $d0
  if $cruiseSeen
    detach
    quit
  end
  continue
end

break *(s_segments[6].begin+0x444a) if *(signed short*)(*(unsigned int*)(s_currentA5-0x3678)+0x1a) == 24
commands
  silent
  set $cruiseBefore = *(signed short*)(s_currentA5-0x3782)
  continue
end

break *(s_segments[6].begin+0x4456) if *(signed short*)(*(unsigned int*)(s_currentA5-0x3678)+0x1a) == 24
commands
  silent
  set $cruiseSeen = 1
  printf "difficulty-dynamics cruise difficulty=%d speed=%d before=%d after=%d\n", *(signed short*)(s_currentA5-0x542c), *(signed short*)(*(unsigned int*)(s_currentA5-0x3678)+0x1a), $cruiseBefore, *(signed short*)(s_currentA5-0x3782)
  if $tractionSeen
    detach
    quit
  end
  continue
end

continue
