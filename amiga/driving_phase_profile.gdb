# Read the in-program steady-driving phase profile after diag_run.sh interrupts
# the emulator.  There are deliberately no breakpoints or watchpoints inside
# the fixed-field measurement window.
#
# Build and run:
#   source ./env.sh
#   make clean && make -j4 PROBES=1 PROBEFIELDS=300 SKIP_INTRO=1 GARAGE_CLICK=1
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_phase_profile.gdb ./diag_run.sh 60
set pagination off
set confirm off

continue

printf "\n===== STEADY DRIVING PHASE PROFILE =====\n"
printf "state=%u (2=frozen) generation=%u fields=%u frames=%u\n", g_profileState, g_profileGeneration, g_profileStopField-g_profileStartField, g_profileStopFrames-g_profileStartFrames
set $elapsed = g_profileStopEpoch-g_profileStartEpoch
set $drawing = g_profileTicks[0]
set $resource = g_profileTicks[1]
set $audio = g_profileTicks[2]
set $otherInclusive = g_profileTicks[3]
set $present = g_profileTicks[4]
set $sync = g_profileTicks[5]
set $wait = g_profileTicks[6]
set $control = g_profileTicks[7]
set $vbi = g_profileTicks[8]
set $c2p = g_profileTicks[9]
set $palette = g_profileTicks[10]
set $other = $otherInclusive-$audio-$present-$wait
set $resident = $elapsed-$drawing-$resource-$otherInclusive
set $presentOverhead = $present-$sync-$c2p-$palette
set $accounted = $resident+$drawing+$resource+$audio+$other+$c2p+$palette+$presentOverhead+$sync+$wait
printf "beamTicks=%u (256 ticks/scanline)\n", $elapsed
printf "resident game / callbacks  ticks=%u share=%.3f%%\n", $resident, 100.0*$resident/$elapsed
printf "drawing traps              ticks=%u share=%.3f%% calls=%u\n", $drawing, 100.0*$drawing/$elapsed, g_profileCalls[0]
printf "resource traps             ticks=%u share=%.3f%% calls=%u\n", $resource, 100.0*$resource/$elapsed, g_profileCalls[1]
printf "audio shim                 ticks=%u share=%.3f%% calls=%u\n", $audio, 100.0*$audio/$elapsed, g_profileCalls[2]
printf "other compatibility        ticks=%u share=%.3f%% calls=%u\n", $other, 100.0*$other/$elapsed, g_profileCalls[3]
printf "C2P                       ticks=%u share=%.3f%% calls=%u\n", $c2p, 100.0*$c2p/$elapsed, g_profileCalls[9]
printf "palette construction       ticks=%u share=%.3f%% calls=%u\n", $palette, 100.0*$palette/$elapsed, g_profileCalls[10]
printf "presentation overhead      ticks=%u share=%.3f%% calls=%u\n", $presentOverhead, 100.0*$presentOverhead/$elapsed, g_profileCalls[4]
printf "back-buffer synchronization ticks=%u share=%.3f%% calls=%u\n", $sync, 100.0*$sync/$elapsed, g_profileCalls[5]
printf "display back-pressure      ticks=%u share=%.3f%% calls=%u\n", $wait, 100.0*$wait/$elapsed, g_profileCalls[6]
printf "ACCOUNTING                 ticks=%u share=%.3f%% (MUST be ~100%%)\n", $accounted, 100.0*$accounted/$elapsed
printf "nested VBI diagnostic      ticks=%u share=%.3f%% calls=%u\n", $vbi, 100.0*$vbi/$elapsed, g_profileCalls[8]
printf "empty bracket control      ticks=%u share=%.3f%% calls=%u\n", $control, 100.0*$control/$elapsed, g_profileCalls[7]
printf "========================================\n\n"
detach
quit
