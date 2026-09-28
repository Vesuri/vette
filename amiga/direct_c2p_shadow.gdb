# PROBES=1 VERIFY=1 FILLWATCH=1 SKIP_INTRO=1 GARAGE_CLICK=1
# DRIVING_COPY_SHADOW=1. Optional PARKED_PROFILE=1 for the stationary street.
set pagination off
set confirm off
set $captures = 0
break VetteScreen::showLoudStop
commands
 silent
 echo FAIL shadow loud stop\n
 detach
 quit 1
end
break validateConvertedFrame if s_drivingScreenSource && g_macDrivingIterations >= 12
commands
 silent
 eval "dump binary memory ../tmp/direct-shadow-source-%u.raw s_drivingScreenSource s_drivingScreenSource+83200", $captures
 eval "dump binary memory ../tmp/direct-shadow-screen-%u.raw s_colorScreen s_colorScreen+81920", $captures
 set $captures = $captures+1
 if $captures == 45
  printf "SHADOW frames=%u C2P rows=%u failures=%u fillbad=%u iterations=%u\n",$captures,g_c2pVerifyCalls,g_c2pVerifyFailures,g_fillBadPixels,g_macDrivingIterations
  if g_c2pVerifyFailures || g_fillBadPixels
   echo FAIL shadow conversion\n
   quit 1
  end
  echo PASS shadow conversion; compare saved publication bytes\n
  detach
  quit
 end
 continue
end
continue
