# Stop when the player's original response-197 collision handling has carried
# the input-only Course Two route through the first Freeway Map bend.  Requires
# SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2 FREEWAY_ROUTE=1 PROBES=1.
# This observer reads game state only.
set pagination off
set confirm off

# Traffic+$5338 is jump-table export 197.  QUAD 221 first guides the player
# through cell (2,38); the connected QUAD 220 response proves entry to (3,37).
break *(s_segments[6].begin+0x5338) if $a0 == *(unsigned int*)($a5-0x3678) && *(unsigned short*)($a0+0x3e) == 3 && *(unsigned short*)($a0+0x40) == 37
continue

printf "freeway bend crossed tick=%u frames=%u/%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u gear=%d speed=%d mode=%d QUAD=%u selector=%u response=%d/%d\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), (*(unsigned int*)($a0+0x6e))&0x7ff, (*(unsigned int*)($a0+0x72))&0x7ff, *(unsigned short*)($a0+0x66), *(signed short*)($a0+28), *(signed short*)($a0+26), *(signed short*)($a5-0x3764), g_probeStaticCollision[5], g_probeStaticCollision[6], g_probeStaticCollision[8], g_probeStaticCollision[9]
detach
quit
