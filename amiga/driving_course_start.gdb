# Capture the first original player record after a deterministic garage course
# selection.  Requires SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=1..4 PROBES=1.
set pagination off
set confirm off

watch s_garageGearPhase
commands
  silent
  if s_garageGearPhase == 1
    set $car = *(unsigned int*)(s_currentA5-13944)
    printf "course-start tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u freeway=%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed char*)(s_currentA5-0x3764)
    detach
    quit
  end
  continue
end

continue
