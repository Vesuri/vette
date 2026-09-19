# Identify the original GetPicture request that begins the lake-crash recovery
# artwork.  The probe records it without a debugger breakpoint on every trap;
# diag_run.sh interrupts the final continue at its wall-time ceiling.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1.
set pagination off
set confirm off

continue
printf "collision PICT 140: ticks=%u frames=%u trapPC=$%x savedReturn=$%x nowTicks=%u nowFrames=%u driving=%u depth=%u\n", g_probePicture140Ticks, g_probePicture140Frames, g_probePicture140TrapPC, g_probePicture140Return, g_macTicks, g_macFramesPresented, s_drivingFrameStarted, g_stageCDepth
printf "segment begins: Main=$%x Initialize=$%x Communication=$%x Traffic=$%x FRED=$%x sound=$%x\n", s_segments[1].begin, s_segments[2].begin, s_segments[3].begin, s_segments[6].begin, s_segments[7].begin, s_segments[9].begin
detach
quit
