# Stop at the first shipped special-collision response which sets freeway
# mode.  Requires a SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1 input-only route.
set pagination off
set confirm off

define report_freeway_gate
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "freeway gate Traffic+$%x tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u gear=%d speed=%d mode-before=%d\n", $pc-(unsigned int)s_segments[6].begin, g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+28), *(signed short*)($car+26), *(signed short*)(s_currentA5-0x3764)
  detach
  quit
end

break *(s_segments[6].begin+0x54f8)
commands
  silent
  report_freeway_gate
end
break *(s_segments[6].begin+0x5632)
commands
  silent
  report_freeway_gate
end
break *(s_segments[6].begin+0x565c)
commands
  silent
  report_freeway_gate
end
break *(s_segments[6].begin+0x5886)
commands
  silent
  report_freeway_gate
end
break *(s_segments[6].begin+0x593c)
commands
  silent
  report_freeway_gate
end
break *(s_segments[6].begin+0x5b50)
commands
  silent
  report_freeway_gate
end

continue

set $car = *(unsigned int*)(s_currentA5-13944)
printf "freeway gate ceiling tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u gear=%d speed=%d mode=%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+28), *(signed short*)($car+26), *(signed short*)(s_currentA5-0x3764)
detach
quit
