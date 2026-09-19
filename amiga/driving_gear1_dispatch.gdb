# Resolve top-row + through the shipped KeyMap table and retain the exact
# current-car/global mutation made by its handler.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1.
set pagination off
set confirm off
set $gear_seen = 0

# At Main+$2E04, virtual keys >= 8 have been decremented and multiplied by 4.
# Top-row + is Macintosh virtual $18, hence table byte offset ($18-1)*4 = $5c.
break *(s_segments[1].begin+0x2e04) if $d0 == 0x5c
commands 1
  silent
  set $car = $a0
  set $stub = $a3
  set $target = *(unsigned int*)($stub+2)
  dump binary memory ../tmp/amiga_driving_gear1_car_before.raw $car $car+256
  dump binary memory ../tmp/amiga_driving_gear1_globals_before.raw s_currentA5-31272 s_currentA5
  set $gear_seen = 1
  printf "upshift dispatch: virtual=$18 stub=$%x target=$%x Main+$%x car=$%x ticks=%u frames=%u\n", $stub, $target, $target-(unsigned int)s_segments[1].begin, $car, g_macTicks, g_macFramesPresented
  continue
end

break *(s_segments[1].begin+0x2e06) if $gear_seen
commands 2
  silent
  dump binary memory ../tmp/amiga_driving_gear1_car_after.raw $car $car+256
  dump binary memory ../tmp/amiga_driving_gear1_globals_after.raw s_currentA5-31272 s_currentA5
  printf "gear-1 returned: word28=%d automatic=%d word32=%d engine66/68=%d/%d depth=%u\n", *(short*)($car+28), *(short*)($car+46), *(short*)($car+32), *(short*)($car+66), *(short*)($car+68), g_stageCDepth
  detach
  quit
end

continue
