# Clean build: SKIP_INTRO=1 GARAGE_CLICK=1 PARKED_PROFILE=1
# PARKED_PROFILE_SCENE=2, GAME_GEOMETRY=0 or 1.
# FIDELITY_RANDOM_SEED=0x3BD90000. No PROBES, VERIFY, or FILLWATCH.
# Same complete 120-iteration window and field phase in every comparison.
set pagination off
set confirm off
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_parkedProfileIteration && g_macDrivingIterations >= g_parkedProfileIteration+100
continue
if !g_parkedProfileIteration || g_stageBState == 3
 echo FAIL benchmark startup\n
 quit 1
end
set $car = *(unsigned char**)(s_currentA5-13944)
set $x = *(unsigned int*)$car
set $z = *(unsigned int*)($car+8)
if $x != 45184 || $z != 66563 || *(unsigned short*)($car+26) || *(unsigned short*)($car+28)
 echo FAIL wrong benchmark scene\n
 quit 1
end
set $start = g_macDrivingIterations
set $field = g_vbiCount
set $beam = ((*(unsigned short*)0xdff004 & 1)*65536 + *(unsigned short*)0xdff006)
set $frames = g_macFramesPresented
delete breakpoints
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_macDrivingIterations >= $start+120
continue
set $endbeam = ((*(unsigned short*)0xdff004 & 1)*65536 + *(unsigned short*)0xdff006)
set $elapsed = (unsigned short)(g_vbiCount-$field) + ($endbeam-$beam)/80128.0
if g_stageBState == 3 || g_macDrivingIterations != $start+120 || (unsigned short)(g_macFramesPresented-$frames) != 120 || *(unsigned int*)$car != $x || *(unsigned int*)($car+8) != $z || *(unsigned short*)($car+26) || *(unsigned short*)($car+28)
 echo FAIL benchmark workload\n
 quit 1
end
printf "BENCH iterations=%u frames=%u fields=%.6f ms_per_frame=%.6f fps=%.6f x=%u z=%u objects=%u\n",g_macDrivingIterations-$start,(unsigned short)(g_macFramesPresented-$frames),$elapsed,$elapsed*20/120,6000/$elapsed,$x,$z,*(unsigned short*)(s_currentA5-0x3696)
echo PASS parked benchmark\n
detach
quit
