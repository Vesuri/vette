# Minimal original Mouse-button accelerator trace.  Keep this below FS-UAE's
# practical remote-breakpoint limit.  Requires MOUSE_CONTROL_PROBE=1.
set pagination off
set confirm off

break *(s_segments[1].begin+0x275c)
commands
  silent
  printf "mouse-dispatch tick=%u start=%d mode=%u target=$%08x expected=$%08x\n", g_macTicks, *(signed short*)($a5-0x5344), *(unsigned short*)($a5-0x5316), *(unsigned int*)($a5+0x7fc), s_segments[6].begin+0x6d24
  continue
end

break *(s_segments[6].begin+0x6d24)
commands
  silent
  # FS-UAE's remote stub does not accept debugger writes to the A5 data byte.
  # Enter the fall-through path that TST.B selects for active-low zero instead.
  set $pc = s_segments[6].begin+0x6d2a
  printf "mouse-button pressed-branch tick=%u physical-shadow=$%02x\n", g_macTicks, *(unsigned char*)(s_currentA5-31288)
  continue
end

break *(s_segments[6].begin+0x6d34)
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-0x3678)
  printf "mouse-button exit tick=%u shadow=$%02x throttle=%d brake=%d car=$%08x\n", g_macTicks, *(unsigned char*)(s_currentA5-31288), *(signed short*)($car+0x20), *(signed short*)($car+0x22), $car
  detach
  quit
end

continue

printf "mouse-button ceiling tick=%u start=%d mode=%u\n", g_macTicks, *(signed short*)(s_currentA5-0x5344), *(unsigned short*)(s_currentA5-0x5316)
detach
quit
