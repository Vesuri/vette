# Verify the GARAGE_CLICK path's post-setup keypad event and capture its screen.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off

continue

dump binary memory ../tmp/amiga_driving_input.raw s_colorScreen s_colorScreen+81920
dump binary memory ../tmp/amiga_driving_input.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
printf "\n===== DRIVING INPUT =====\n"
printf "phase=%u (want >=9) depth=%u ticks=%u PC=$%08x dirty=(%d,%d)-(%d,%d)\n", s_garageClickPhase, g_stageCDepth, g_macTicks, $pc, s_dirtyTop, s_dirtyLeft, s_dirtyBottom, s_dirtyRight
printf "VBL tasks=%u lastTick=%u callback entry=$%08x task=$%08x A5=$%08x return=$%08x\n", s_vblTaskCount, s_vblLastTick, g_macVBLCallbackEntry, g_macVBLCallbackTask, g_macVBLCallbackA5, g_macVBLCallbackReturn
printf "keyMap[10..11]=$%04x controls=(-20464:%d,-20462:%d) callbackFlag=$%04x\n", *(unsigned short*)(s_currentA5+26), *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462), *(unsigned short*)(s_currentA5-20436)
set $i = 0
while $i < s_vblTaskCount
  printf "task[%u] at $%08x: link=$%08x type=%u addr=$%08x count=%d phase=%d\n", $i, s_vblTasks[$i], *(unsigned int*)s_vblTasks[$i], *(unsigned short*)(s_vblTasks[$i]+4), *(unsigned int*)(s_vblTasks[$i]+6), *(short*)(s_vblTasks[$i]+10), *(short*)(s_vblTasks[$i]+12)
  x/24bx s_vblTasks[$i]
  x/20i *(unsigned int*)(s_vblTasks[$i]+6)
  set $i = $i + 1
end
printf "=========================\n\n"
detach
quit
