# Trace every QuickDraw Random call on the deterministic garage-to-driving
# route.  The handler line is reached before quickDrawRandom mutates the
# application QuickDraw randSeed, so each row is directly comparable with the
# MAME oracle's VETTE_RANDOM_TRACE output.  The Page-0 RndSeed column is the
# separate system entropy source that Vette copies once after InitCursor.
# Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $random_calls = 0

break quickDrawRandom
commands
  silent
  set $random_calls = $random_calls + 1
  set $system_seed = *(unsigned int*)(s_currentA5+4)
  set $qd_seed = *(unsigned int*)(s_qdThePort-126)
  printf "RANDOM #%u tick=%u pc=$%08x system-seed=$%08x qd-seed=$%08x\n", $random_calls, g_macTicks, s_randomTrapPC, $system_seed, $qd_seed
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted
commands
  silent
  printf "DRIVING tick=%u random-calls=%u system-seed=$%08x qd-seed=$%08x objects=%u\n", g_macTicks, $random_calls, *(unsigned int*)(s_currentA5+4), *(unsigned int*)(s_qdThePort-126), *(unsigned short*)(s_currentA5-0x3696)
  detach
  quit
end

continue
