# Build cleanly with PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
# PARKED_PROFILE=1 CODE_PROFILE=1. Run from amiga/ via diag_run.sh.
# All breakpoints are removed before the emulator's fixed 100-field capture.
# Output: ../tmp/parked-profile/capture.bin and the runner's gdb-out.log.
set pagination off
set confirm off
break VetteScreen::presentMacFrame if g_parkedProfileIteration && g_macDrivingIterations >= g_parkedProfileIteration+12
continue
if !g_parkedProfileIteration || g_macDrivingIterations < g_parkedProfileIteration+12
 echo FAIL: parked workload did not reach the measurement boundary\n
 quit 1
end
delete breakpoints
printf "PARKED frames=%u iterations=%u ticks=%u\n",g_macFramesPresented,g_macDrivingIterations,g_macTicks
set $car = *(unsigned char**)(s_currentA5-13944)
printf "CAR x=%u z=%u speed=%u gear=%u cell=%u,%u heading=%u\n", *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+26), *(unsigned short*)($car+28), *(unsigned short*)($car+62), *(unsigned short*)($car+64), *(unsigned short*)($car+102)
if *(unsigned short*)($car+62) != 25 || *(unsigned short*)($car+64) != 32 || *(unsigned short*)($car+26) != 0 || *(unsigned short*)($car+28) != 0
 echo FAIL: car is not parked in the requested street cell\n
 quit 1
end
set $i=0
while $i<11
 printf "SEG %u %u %u\n",$i,s_segments[$i].begin,s_segments[$i].end
 set $i=$i+1
end
set $startX = *(unsigned int*)$car
set $startZ = *(unsigned int*)($car+8)
set $startIterations = g_macDrivingIterations
set $startFields = g_vbiCount
set $startFrames = g_macFramesPresented
shell mkdir -p ../tmp/parked-profile
monitor profile 100 "" "../tmp/parked-profile/capture.bin"
printf "END iterations=%u x=%u z=%u speed=%u gear=%u objects=%u\n", g_macDrivingIterations, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+26), *(unsigned short*)($car+28), *(unsigned short*)(s_currentA5-0x3696)
printf "WINDOW fields=%u frames=%u iterations=%u\n", (unsigned short)(g_vbiCount-$startFields), (unsigned short)(g_macFramesPresented-$startFrames), g_macDrivingIterations-$startIterations
if *(unsigned int*)$car != $startX || *(unsigned int*)($car+8) != $startZ || *(unsigned short*)($car+26) != 0 || *(unsigned short*)($car+28) != 0
 echo FAIL: car did not remain stationary in neutral\n
 quit 1
end
if g_macDrivingIterations <= $startIterations || g_macFramesPresented == $startFrames
 echo FAIL: game did not keep drawing during capture\n
 quit 1
end
set $i=0
while $i<16
 if *(unsigned char*)(s_currentA5+16+$i) != 0
  echo FAIL: driving input was not released\n
  quit 1
 end
 set $i=$i+1
end
printf "PASS parked original-code profile\n"
detach
quit
