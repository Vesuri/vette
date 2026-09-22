# Prove the requested difficulty is selected by the original three-rectangle
# UI and retained into live driving. Requires PROBES=1 SKIP_INTRO=1,
# GARAGE_CLICK=1, and GARAGE_DIFFICULTY=1..3.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "difficulty-start loud stop tick=%u trap=$%04x %s/%s segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

# Return from Main's three-entry TRAINEE/ROOKIE/PRO tracker.
break *vette_code_2+0xd10
commands
  silent
  printf "difficulty-start UI index=%d point=(%d,%d)\n", $d0, *(signed short*)($a5-21814), *(signed short*)($a5-21812)
  disable 2
  continue
end

break *(s_segments[6].begin+0x7c6)
commands
  silent
  printf "difficulty-start driving difficulty=%d course=%d long=%d player=%d opponent=%d\n", *(signed short*)(s_currentA5-0x542c), *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082), *(signed short*)(s_currentA5-0x5532), *(signed short*)(s_currentA5-0x5530)
  detach
  quit
end

continue
