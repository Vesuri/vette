# Capture the last shipped static-bounds collision when the Lake Merced
# recovery picture is requested.  Requires SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1.
set pagination off
set confirm off

continue
printf "PICT 140: ticks=%u frames=%u trapPC=$%x savedReturn=$%x\n", g_probePicture140Ticks, g_probePicture140Frames, g_probePicture140TrapPC, g_probePicture140Return
printf "current: hits=%u rect=$%x edge=%u cell=(%u,%u) quad=%u selector=%u ordinal=%u responseIndex=%u export=%u ticks=%u frames=%u\n", g_probeStaticCollision[0], g_probeStaticCollision[1], g_probeStaticCollision[2], g_probeStaticCollision[3], g_probeStaticCollision[4], g_probeStaticCollision[5], g_probeStaticCollision[6], g_probeStaticCollision[7], g_probeStaticCollision[8], g_probeStaticCollision[9], g_probeStaticCollision[10], g_probeStaticCollision[11]
printf "at PICT: hits=%u rect=$%x edge=%u cell=(%u,%u) quad=%u selector=%u ordinal=%u responseIndex=%u export=%u ticks=%u frames=%u\n", g_probeLakeCollision[0], g_probeLakeCollision[1], g_probeLakeCollision[2], g_probeLakeCollision[3], g_probeLakeCollision[4], g_probeLakeCollision[5], g_probeLakeCollision[6], g_probeLakeCollision[7], g_probeLakeCollision[8], g_probeLakeCollision[9], g_probeLakeCollision[10], g_probeLakeCollision[11]
printf "segment begins: Main=$%x Traffic=$%x\n", s_segments[1].begin, s_segments[6].begin
detach
quit
