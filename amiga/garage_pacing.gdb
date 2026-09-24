# Complete TEST, departure and selection path. Build with PROBES=1,
# SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_DYNO=1 GARAGE_DEPARTURE_FULL=1.
set pagination off
set confirm off
set $test_done = 0
break *s_segments[2].begin+0x0dc0
commands
 silent
 set $test_start = g_vbiCount
 continue
end
break *s_segments[2].begin+0x14d8
commands
 silent
 if !$test_done
  printf "TEST fields=%u steps=%u waits=%u violations=%u\n", (unsigned short)(g_vbiCount-$test_start),g_framePaceSteps[2],g_framePaceWaits[2],g_framePaceViolations[2]
  set $test_done = 1
 end
 continue
end
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_macDrivingIterations >= 4
continue
printf "departure steps=%u waits=%u violations=%u driving=%u state=%u\n",g_framePaceSteps[1],g_framePaceWaits[1],g_framePaceViolations[1],g_macDrivingIterations,g_stageBState
if $test_done && g_framePaceSteps[2] == 59 && g_framePaceViolations[2] == 0 && g_framePaceSteps[1] == 198 && g_framePaceViolations[1] == 0 && g_macDrivingIterations >= 4 && g_stageBState != 3
 echo PASS completed-frame garage pacing\n
else
 echo FAIL garage pacing\n
end
detach
quit
