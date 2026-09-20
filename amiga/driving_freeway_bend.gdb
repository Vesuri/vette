# Stop when the player's original response-197 collision handling has carried
# the input-only Course Two route through the first Freeway Map bend.  Requires
# SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2 FREEWAY_ROUTE=1 PROBES=1.
# This observer reads game state only.
set pagination off
set confirm off
set $bend_hit = 0

# Traffic+$5338 is jump-table export 197.  QUAD 221 first guides the player
# through cell (2,38); the connected QUAD 220 response proves entry to (3,37).
break *(s_segments[6].begin+0x5338) if *(unsigned short*)(*(unsigned int*)($a5-0x3678)+0x3e) == 3 && *(unsigned short*)(*(unsigned int*)($a5-0x3678)+0x40) == 37
commands
  silent
  set $bend_hit = 1
end
continue

set $car = *(unsigned int*)($a5-0x3678)
if $bend_hit
  printf "freeway bend crossed tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u gear=%d speed=%d mode=%d QUAD=%u selector=%u response=%d/%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+28), *(signed short*)($car+26), *(signed short*)($a5-0x3764), g_probeStaticCollision[5], g_probeStaticCollision[6], g_probeStaticCollision[8], g_probeStaticCollision[9]
else
  printf "freeway bend observer ceiling tick=%u cell=(%u,%u) local=(%u,%u) heading=%u speed=%d QUAD=%u selector=%u\n", g_macTicks, *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff, *(unsigned short*)($car+0x66), *(signed short*)($car+26), g_probeStaticCollision[5], g_probeStaticCollision[6]
end
detach
quit
