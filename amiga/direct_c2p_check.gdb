# PROBES=1 VERIFY=1 FILLWATCH=1 SKIP_INTRO=1 GARAGE_CLICK=1 PARKED_PROFILE=1
# Selectors exercise stride 256; driving exercises stride 260. Audit a complete
# parked viewport over more than 40 rolling-check frames, with both C2P kernels.
set pagination off
set confirm off
break VetteScreen::showLoudStop
break validateConvertedFrame if g_parkedProfileIteration && g_macDrivingIterations >= g_parkedProfileIteration+12
continue
if g_stageBState == 3 || !s_drivingScreenSource
 echo FAIL: direct source not active\n
 quit 1
end
set $start = g_macDrivingIterations
set $copies = 0
set $checks = g_fillWatchFrames
delete breakpoints
break vetteDrivingCopyAsm
commands
 silent
 set $copies = $copies+1
 continue
end
break validateConvertedFrame if g_macDrivingIterations >= $start+45
continue
printf "DIRECT iterations=%u checks=%u copies=%u C2P rows=%u failures=%u fillbad=%u source=%p\n",g_macDrivingIterations-$start,g_fillWatchFrames-$checks,$copies,g_c2pVerifyCalls,g_c2pVerifyFailures,g_fillBadPixels,s_drivingScreenSource
if $copies || g_c2pVerifyFailures || g_fillBadPixels || g_fillWatchFrames-$checks < 40 || !s_drivingScreenSource
 echo FAIL direct C2P\n
 quit 1
end
echo PASS direct C2P; zero copies and exact dirty conversion\n
detach
quit
