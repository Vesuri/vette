# PROBES=1 FILLWATCH=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINISH_CHECKPOINT=1.
# Let the original finish sequence request the screen, without debugger calls
# or changing control flow while a frame is being presented.
set pagination off
set confirm off
break VetteScreen::showLoudStop
break vetteDrivingCopyAsm if g_macDrivingIterations > 2
continue
if g_stageBState == 3 || $pc != &vetteDrivingCopyAsm
 echo FAIL: fallback not reached\n
 quit 1
end
set $source = *(unsigned char**)($sp+4)
set $return = *(unsigned int*)$sp
dump binary memory ../tmp/direct-c2p-source.raw $source $source+83200
tbreak *$return
continue
if $pc != $return || s_drivingScreenSource || g_fillBadPixels
 echo FAIL: fallback or planar pixels\n
 quit 1
end
dump binary memory ../tmp/direct-c2p-screen.raw s_colorScreen s_colorScreen+81920
echo PASS direct C2P fallback; compare saved publication bytes\n
detach
quit
