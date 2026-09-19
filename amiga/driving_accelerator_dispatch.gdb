# Resolve keypad 8 through the shipped KeyMap table and retain the exact
# current-car/global mutation made by its handler.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1.
set pagination off
set confirm off
set $accelerator_seen = 0

# At Main+$2E04, virtual keys >= 8 have been decremented and multiplied by 4.
# Keypad 8 is $5B, hence table byte offset ($5B-1)*4 = $168.
break *(s_segments[1].begin+0x2e04) if $d0 == 0x168
commands 1
  silent
  set $car = $a0
  set $stub = $a3
  set $target = *(unsigned int*)($stub+2)
  dump binary memory ../tmp/amiga_driving_accelerator_car_before.raw $car $car+256
  dump binary memory ../tmp/amiga_driving_accelerator_globals_before.raw s_currentA5-31272 s_currentA5
  set $accelerator_seen = 1
  printf "accelerator dispatch: virtual=$5b stub=$%x target=$%x Main+$%x car=$%x ticks=%u frames=%u\n", $stub, $target, $target-(unsigned int)s_segments[1].begin, $car, g_macTicks, g_macFramesPresented
  continue
end

break *(s_segments[1].begin+0x2e06) if $accelerator_seen
commands 2
  silent
  dump binary memory ../tmp/amiga_driving_accelerator_car_after.raw $car $car+256
  dump binary memory ../tmp/amiga_driving_accelerator_globals_after.raw s_currentA5-31272 s_currentA5
  printf "accelerator returned: gear=%d automatic=%d rpm=%d/%d depth=%u\n", *(short*)($car+28), *(short*)($car+46), *(short*)($car+66), *(short*)($car+68), g_stageCDepth
  detach
  quit
end

continue
