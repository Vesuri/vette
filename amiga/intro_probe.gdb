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
printf "intro audio state=%u bytes=%u Paula period=%u\n", g_introAudioState, g_introAudioBytes, g_introAudioPeriod
printf "VBL tasks=%u\n", s_vblTaskCount
printf "intro instrument refs: opening=$%08X mic=$%08X signature=$%08X bell=$%08X engine=$%08X\n", *(unsigned int*)(s_currentA5-0x5a88), *(unsigned int*)(s_currentA5-0x5a80), *(unsigned int*)(s_currentA5-0x5a8c), *(unsigned int*)(s_currentA5-0x5a84), *(unsigned int*)(s_currentA5-0x5a70)
printf "intro instrument names (Pascal bytes):\n"
x/64bx s_currentA5-0x5b10
printf "intro phases: done=%d singer=%d car=%d mic=%d tramTop=%d tramBell=%d\n", *(short*)(s_currentA5-0x8a), *(short*)(s_currentA5-0x8c), *(short*)(s_currentA5-0x90), *(short*)(s_currentA5-0x8e), *(short*)(s_currentA5-0x94), *(short*)(s_currentA5-0x58)
printf "intro deadlines: tram=%u cable=%u car=%u logo=%u\n", *(unsigned int*)(s_currentA5-0xa6), *(unsigned int*)(s_currentA5-0xa2), *(unsigned int*)(s_currentA5-0x9e), *(unsigned int*)(s_currentA5-0x9a)
printf "logo draws=%u parked=%u end=%u\n", s_introLogoFrames, s_introLogoParked, *(unsigned int*)(s_currentA5-0x5004)
printf "tram dst rect: "
x/4hd s_currentA5-0x19e
printf "car/singer dst rect: "
x/4hd s_currentA5-0x15e
printf "logo rectangles (source/mask/composite/work/destination):\n"
x/20hd s_currentA5-0xd6
dump binary memory ../tmp/intro_probe.raw s_colorScreen s_colorScreen+81920
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
