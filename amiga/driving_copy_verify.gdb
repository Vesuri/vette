# Read the in-process 260-to-256 driving-copy differential after the host
# interrupts a deterministic moving run.  No breakpoint enters the timed path.
set pagination off
set confirm off

continue

printf "driving copy calls=%u bytes=%u failures=%u\n", g_drivingCopyVerifyCalls, g_drivingCopyVerifyBytes, g_drivingCopyVerifyFailures
printf "C ticks=%u asm ticks=%u C/asm=%.3f\n", g_drivingCopyCTicks, g_drivingCopyAsmTicks, 1.0*g_drivingCopyCTicks/g_drivingCopyAsmTicks
detach
quit
