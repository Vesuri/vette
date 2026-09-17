# Snapshot the live intro without assuming that it has reached a loud stop.
# The harness interrupts `continue`; commands below then report timing, frame
# delivery and the Vertical Retrace task installed by the original sound shim.
set pagination off
set confirm off

continue

printf "\n===== INTRO PROBE =====\n"
printf "vbi=%u macTicks=%u stageCDepth=%u loudStopState=%u\n", g_vbiCount, g_macTicks, g_stageCDepth, g_stageBState
printf "screenDirty=%u framePending=%u checksum=$%08X\n", s_screenDirty, s_loudStopScreen->m_framePending, s_loudStopScreen->m_checksum
printf "Mac frames queued=%u presented=%u\n", g_macFramesQueued, g_macFramesPresented
printf "VBL tasks=%u\n", s_vblTaskCount
set $i = 0
while $i < s_vblTaskCount
  printf "task[%u] at $%08X: qLink=$%08X qType=%u addr=$%08X count=%d phase=%d\n", $i, s_vblTasks[$i], *(unsigned int*)s_vblTasks[$i], *(unsigned short*)(s_vblTasks[$i]+4), *(unsigned int*)(s_vblTasks[$i]+6), *(short*)(s_vblTasks[$i]+10), *(short*)(s_vblTasks[$i]+12)
  set $i = $i + 1
end
printf "trap=$%04X %s / %s selector=%d caller=%u+$%04X\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSelector, g_trapSegment, g_trapOffset
printf "PC and stack:\n"
x/12i $pc-12
bt 8
printf "=======================\n\n"
detach
quit
