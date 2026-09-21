# Stop when the player reaches the selector-81 cell after Freeway Map
# (10,36).  This observes either the ordinary input route or the diagnostic
# FREEWAY_START=11 handoff; it never changes target state.  Requires
# SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2 FREEWAY_ROUTE=1.
set pagination off
set confirm off
set $cleared = 0
set $collision = 0

break *(s_segments[6].begin+0x0202) if *(unsigned short*)($a3+0x3e) == 6 && *(unsigned short*)($a3+0x40) == 36
commands 1
  silent
  set $collision = 1
end

watch s_garageGearPhase
continue
delete 2
set $car = *(unsigned int*)(s_currentA5-0x3678)
watch *(unsigned int*)($car+0x3e)
condition 3 *(unsigned short*)($car+0x3e) >= 11 && *(unsigned short*)($car+0x40) == 36
commands 3
  silent
  set $cleared = 1
end
continue

if $collision
  printf "freeway x6 collision tick=%u world=($%08x,$%08x) local=(%u,%u) heading=%u speed=%d other-local=(%u,%u)\n", g_macTicks, *(unsigned int*)$a3, *(unsigned int*)($a3+8), (*(unsigned int*)$a3)&0x7ff, (*(unsigned int*)($a3+8))&0x7ff, *(unsigned short*)($a3+0x66), *(signed short*)($a3+26), (*(unsigned int*)$a2)&0x7ff, (*(unsigned int*)($a2+8))&0x7ff
else
if $cleared
  printf "freeway cell 11 reached tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u speed=%d mode=%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26), *(signed short*)(s_currentA5-0x3764)
else
  printf "freeway selector-90 observer ceiling tick=%u cell=(%u,%u) local=(%u,%u) heading=%u speed=%d\n", g_macTicks, *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26)
end
end
detach
quit
