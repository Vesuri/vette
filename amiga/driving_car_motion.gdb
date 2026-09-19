# Compare the current car record at two complete-frame boundaries under the
# deterministic keypad-8 trajectory.  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $captured = 0

break vbiHandler if s_drivingFrameStarted && g_macFramesPresented >= 40
commands 1
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  if !$captured
    dump binary memory ../tmp/amiga_driving_car_40.raw $car $car+256
    set $captured = 1
    printf "car frame 40: ticks=%u car=$%x automatic=%d\n", g_macTicks, $car, *(short*)($car+46)
    continue
  end
  if g_macFramesPresented < 80
    continue
  end
  dump binary memory ../tmp/amiga_driving_car_80.raw $car $car+256
  printf "car frame 80: ticks=%u car=$%x automatic=%d depth=%u\n", g_macTicks, $car, *(short*)($car+46), g_stageCDepth
  detach
  quit
end

continue
