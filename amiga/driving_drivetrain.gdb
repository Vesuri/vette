# Inspect the original drivetrain state after the deterministic garage route.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1.
set pagination off
set confirm off

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 80
commands 1
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  set $kind = *(short*)(s_currentA5-21810)
  set $ratio = *(short*)(s_currentA5-12982 + $kind*16 + *(short*)($car+28)*2)
  printf "drivetrain: ticks=%u frames=%u startState=%d car=$%x kind=%d xyz=(%d,%d,%d) speed=%d gear=%d maxgear=%d throttle=%d brake=%d automatic=%d rpm=%d/%d ratio=%d\n", g_macTicks, g_macFramesPresented, *(short*)(s_currentA5-13296), $car, $kind, *(int*)$car, *(int*)($car+4), *(int*)($car+8), *(short*)($car+26), *(short*)($car+28), *(short*)($car+30), *(short*)($car+32), *(short*)($car+34), *(short*)($car+46), *(short*)($car+66), *(short*)($car+68), $ratio
  x/40hd s_currentA5-12982
  detach
  quit
end

continue
