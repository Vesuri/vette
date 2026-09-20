# Stop when ordinary input first carries the player into the selector-81
# eastbound straight at Freeway Map (6,36).  Requires SKIP_INTRO=1
# GARAGE_CLICK=1 GARAGE_COURSE=2 FREEWAY_ROUTE=1.
set pagination off
set confirm off
set $straight_hit = 0

watch s_garageGearPhase
continue
delete 1
set $car = *(unsigned int*)(s_currentA5-0x3678)
watch *(unsigned int*)($car+0x3e)
condition 2 *(unsigned short*)($car+0x3e) >= 6 && *(unsigned short*)($car+0x40) == 36
commands 2
  silent
  set $straight_hit = 1
end
continue

if $straight_hit
  printf "freeway straight reached tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u gear=%d speed=%d mode=%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+28), *(signed short*)($car+26), *(signed short*)(s_currentA5-0x3764)
else
  printf "freeway straight observer ceiling tick=%u cell=(%u,%u) local=(%u,%u) heading=%u speed=%d\n", g_macTicks, *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26)
end
detach
quit
