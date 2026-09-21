# Stop after export 230 returns the player to Main Map and the diagnostic
# MAIN_START=17 handoff places it at QUAD 136, cell (17,39).  Requires the
# focused FREEWAY_START=30/U=1600/V=1024 MAIN_START=17 build.  This script
# reads game state only.
set pagination off
set confirm off
set $reached = 0

watch s_garageGearPhase
continue
delete 1
set $car = *(unsigned int*)(s_currentA5-0x3678)
watch *(unsigned int*)($car+0x3e)
condition 2 *(unsigned short*)($car+0x3e) >= 17 && *(unsigned short*)($car+0x40) == 39 && *(signed short*)(s_currentA5-0x3764) == 0
commands 2
  silent
  set $reached = 1
end
continue

if $reached
  printf "main-map return boundary reached tick=%u frames=%u/%u world=($%08x,$%08x) physics=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u speed=%d mode=%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned int*)($car+0x6e), *(unsigned int*)($car+0x72), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26), *(signed short*)(s_currentA5-0x3764)
else
  printf "main-map return observer ceiling tick=%u cell=(%u,%u) local=(%u,%u) heading=%u speed=%d mode=%d\n", g_macTicks, *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26), *(signed short*)(s_currentA5-0x3764)
end
detach
quit
