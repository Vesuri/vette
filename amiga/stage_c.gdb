# STAGE C PROGRESS — break on the next loud stop and print the implemented depth.
# Run with: EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=stage_c.gdb ./diag_run.sh 20
set pagination off
set confirm off

# g_stageBState is written before the trap report fields, so watching it can
# stop on a half-built report.  showLoudStop is called only after every field
# is populated and immediately before the permanent loud-stop loop.
break VetteScreen::showLoudStop
commands
  silent
end
continue

printf "\n===== STAGE C =====\n"
printf "implemented depth = %u trap(s) in measured first-use order\n", g_stageCDepth
printf "next trap         = $%04X %s / %s\n", g_trapWord, g_trapManager, g_trapRoutine
printf "selector          = %d (-1 = N/A)\n", g_trapSelector
printf "caller            = segment %u + $%04X\n", g_trapSegment, g_trapOffset
printf "absolute PC       = $%08X\n", g_trapPC
printf "USP               = $%08X\n", g_trapUserStack
printf "USP words         = "
x/8hx g_trapUserStack
printf "D0-D7/A0-A6:\n"
x/15wx g_trapRegisters
x/8i g_trapPC-8
printf "===================\n\n"
detach
quit
