# Prove requested player/opponent cars survive their original UI selectors and
# PERF setup into live driving. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
# and optionally GARAGE_CAR=1..4 / GARAGE_OPPONENT=1..4.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "vehicle-start loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

break *vette_code_2+0xcce
commands
  silent
  printf "vehicle-start garage control=%d point=(%d,%d) player=%d opponent=%d difficulty=%d mode=%d\n", $d0, *(signed short*)($a5-21814), *(signed short*)($a5-21812), *(signed short*)($a5-0x5532), *(signed short*)($a5-0x5530), *(signed short*)($a5-0x542c), *(signed short*)($a5-21546)
  continue
end

break *(s_segments[6].begin+0x7c6)
commands
  silent
  set $player = *(unsigned char**)(s_currentA5-13944)
  set $opponent = *(unsigned char**)(s_currentA5-13940)
  printf "vehicle-start player=%d opponent=%d player-record=%p opponent-record=%p player-gears=%d player-auto=%d opponent-gears=%d opponent-auto=%d\n", *(signed short*)(s_currentA5-0x5532), *(signed short*)(s_currentA5-0x5530), $player, $opponent, *(signed short*)($player+30), *(signed short*)($player+46), *(signed short*)($opponent+30), *(signed short*)($opponent+46)
  detach
  quit
end

continue
