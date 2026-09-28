# GAME_RASTER_VERIFY=1 SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_macDrivingIterations >= 4
continue
printf "RASTER cases=%u failures=%u iterations=%u\n",g_gameRasterVerifyCases,g_gameRasterVerifyFailures,g_macDrivingIterations
if g_stageBState == 3 || g_gameRasterVerifyCases != 866 || g_gameRasterVerifyFailures || g_macDrivingIterations < 4
 echo FAIL game raster differential\n
 quit 1
end
echo PASS game raster differential\n
detach
quit
