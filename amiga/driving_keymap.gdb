# Stop immediately after a driving VBL callback with scripted keypad 8 held.
set pagination off
set confirm off

# vette_user_vbl_trampoline+38 is the instruction after JSR (A1).
break *vette_user_vbl_trampoline+38 if *(unsigned short*)(s_currentA5+26) == 0x0008
commands
  silent
  printf "keypad 8 KeyMap[10..11]=$%04x callbackControls=(-20464:%d,-20462:%d) callbackFlag=$%04x ticks=%u phase=%u depth=%u\n", *(unsigned short*)(s_currentA5+26), *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462), *(unsigned short*)(s_currentA5-20436), g_macTicks, s_garageClickPhase, g_stageCDepth
  detach
  quit
end

continue
