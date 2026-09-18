# Stop immediately after the driving VBL callback has observed a held keypad key.
set pagination off
set confirm off

# vette_user_vbl_trampoline+38 is the instruction after JSR (A1).
break *vette_user_vbl_trampoline+38 if *(unsigned short*)(s_currentA5+26) != 0 && (*(short*)(s_currentA5-20464) != 0 || *(short*)(s_currentA5-20462) != 0)
commands
  silent
  printf "keyMap[10..11]=$%04x controls=(-20464:%d,-20462:%d) callbackFlag=$%04x ticks=%u phase=%u depth=%u\n", *(unsigned short*)(s_currentA5+26), *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462), *(unsigned short*)(s_currentA5-20436), g_macTicks, s_garageClickPhase, g_stageCDepth
  detach
  quit
end

continue
