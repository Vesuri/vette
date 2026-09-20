# Stop when ordinary input first carries the player north from QUAD 251 into
# Freeway Map row 36.  Requires SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2
# FREEWAY_ROUTE=1.
set pagination off
set confirm off
set $row36_hit = 0

# The deterministic garage driver changes this phase as soon as the original
# player record is live, well before the freeway.  Bind the record there, then
# watch the adjacent cell-x/cell-y words without adding target-side state.
watch s_garageGearPhase
continue
delete 1
set $car = *(unsigned int*)(s_currentA5-0x3678)
watch *(unsigned int*)($car+0x3e)
condition 2 *(unsigned short*)($car+0x3e) >= 4 && *(unsigned short*)($car+0x40) == 36
commands 2
  silent
  set $row36_hit = 1
end
continue

if $row36_hit
  printf "freeway row 36 reached tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u gear=%d speed=%d mode=%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+28), *(signed short*)($car+26), *(signed short*)($a5-0x3764)
else
  printf "freeway row-36 observer ceiling tick=%u cell=(%u,%u) local=(%u,%u) heading=%u speed=%d\n", g_macTicks, *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26)
end
detach
quit
