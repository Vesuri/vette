# Press physical Escape in a live race and verify the original garage command.
# PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 SESSION_CONTROL_ITEM=7
set pagination off
set confirm off
set $garage_command = 0
break *(s_segments[1].begin+0x10e4)
commands
 silent
 set $garage_command = $garage_command + 1
 continue
end
break VetteScreen::showLoudStop
break nextEvent if g_sessionControlProbePhase == 3 && $garage_command != 0
continue
printf "ESC garage commands=%u phase=%u driving=%u iterations=%u crop=%u,%u mouse=%u state=%u\n",$garage_command,g_sessionControlProbePhase,*(unsigned short*)(s_currentA5-21316),g_macDrivingIterations,s_screen->m_cropLeft,s_screen->m_cropTop,s_screen->m_mouseAllowed,g_stageBState
if $garage_command == 1 && *(unsigned short*)(s_currentA5-21316) == 0 && s_screen->m_cropLeft == 128 && s_screen->m_cropTop == 26 && s_screen->m_mouseAllowed && g_stageBState != 3
 echo PASS Escape returns to garage\n
else
 echo FAIL Escape to garage\n
end
detach
quit
