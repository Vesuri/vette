set pagination off
set confirm off
break vetteInstallGameKernels
continue
finish
printf "STARTUP cases=%u failures=%u livefail=%u\n",g_gameKernelCases,g_gameKernelFailures,g_gameKernelLiveFailures
if g_gameKernelCases != 2240 || g_gameKernelFailures || g_gameKernelLiveFailures
 echo FAIL game kernel startup differential\n
 detach
 quit 1
end
delete breakpoints
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_macDrivingIterations >= 90
continue
printf "KERNEL cases=%u failures=%u first=%u iterations=%u\n",g_gameKernelCases,g_gameKernelFailures,g_gameKernelFirstFailure,g_macDrivingIterations
printf "LIVE cases=%u failures=%u kind=%u\n",g_gameKernelLiveCases,g_gameKernelLiveFailures,g_gameKernelLiveKind
set $kind=0
while $kind<2
 printf "PAIRED kind=%u cases=%u fast=%u original=%u\n",$kind,g_gameKernelTimedCases[$kind],g_gameKernelFastTicks[$kind],g_gameKernelOriginalTicks[$kind]
 set $kind=$kind+1
end
set $car=*(unsigned char**)(s_currentA5-13944)
printf "CAR x=%u z=%u speed=%u gear=%u\n",*(unsigned int*)$car,*(unsigned int*)($car+8),*(unsigned short*)($car+26),*(unsigned short*)($car+28)
if g_stageBState == 3 || g_gameKernelCases != 2240 || g_gameKernelFailures || g_gameKernelLiveFailures || !g_gameKernelTimedCases[0] || !g_gameKernelTimedCases[1] || g_macDrivingIterations < 90
 echo FAIL game kernel differential\n
 quit 1
end
echo PASS game kernel differential\n
detach
quit
