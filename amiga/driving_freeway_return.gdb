# Observe the first original map-mode change after the Course Two export-212
# freeway entry.  Requires the input-only SKIP_INTRO=1 GARAGE_CLICK=1
# GARAGE_COURSE=2 FREEWAY_ROUTE=1 build.  This script never changes game state.
set pagination off
set confirm off

break *(s_segments[6].begin+0x5632) if $a0 == *(unsigned int*)($a5-0x3678) && *(signed short*)($a5-0x3764) == 0
continue

printf "freeway entry response tick=%u world=($%08x,$%08x) mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(signed short*)($a5-0x3764)
delete 1

# Stop after the response has performed its original relocation and mode write.
break *(s_segments[6].begin+0x565a) if $a0 == *(unsigned int*)($a5-0x3678)
continue
printf "freeway entered tick=%u world=($%08x,$%08x) mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(signed short*)($a5-0x3764)
delete 2

watch *(short*)(s_currentA5-0x3764)
continue

set $car = *(unsigned int*)(s_currentA5-13944)
printf "freeway mode changed at Traffic+$%x tick=%u mode=%d world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u speed=%d\n", $pc-(unsigned int)s_segments[6].begin, g_macTicks, *(signed short*)(s_currentA5-0x3764), *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26)
detach
quit
