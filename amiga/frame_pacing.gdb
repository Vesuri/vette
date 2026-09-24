# Snapshot all six animation limiters; stop immediately on any loud stop.
# Ordinary build for intro; SKIP_INTRO/GARAGE_CLICK/GARAGE_DYNO/
# GARAGE_DEPARTURE_FULL for the complete scripted garage-to-driving path.
set pagination off
set confirm off
break VetteScreen::showLoudStop
continue
printf "pacing fields=%u ticks=%u depth=%u stop=%u driving=%u\n", g_vbiCount, g_macTicks, g_stageCDepth, g_stageBState, g_macDrivingIterations
set $i = 0
while $i < 6
  printf "stream %u: steps=%u waits=%u same-field violations=%u\n", $i, g_framePaceSteps[$i], g_framePaceWaits[$i], g_framePaceViolations[$i]
  set $i = $i + 1
end
detach
quit
