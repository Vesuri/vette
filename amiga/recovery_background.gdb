# PROBES=1 HIRES=1 SKIP_INTRO=1 GARAGE_CLICK=1.
# After capture: python3 tools/check_recovery_background.py amiga/.run
set pagination off
set confirm off
set $armed = 0
break *(s_segments[1].begin+0x0f82) if $d7 == 140
commands
 silent
 set $armed = 1
 printf "WATER ticks=%u driving=%u\n",g_macTicks,g_macDrivingIterations
 continue
end
break *(s_segments[1].begin+0x0fc8) if $armed
commands
 silent
 dump binary memory .run/recovery-before.bin (char*)s_colorScreen (char*)s_colorScreen+81920
 continue
end
break *(s_segments[1].begin+0x0fce) if $armed
commands
 silent
 dump binary memory .run/recovery-dialog.bin (char*)s_colorScreen (char*)s_colorScreen+81920
 continue
end
break drawPicture if $armed
commands
 silent
 printf "PICT target t,l,b,r: "
 x/4hd targetRect
 continue
end
break *(s_segments[1].begin+0x0fe2) if $armed
commands
 silent
 dump binary memory .run/recovery-picture.bin (char*)s_colorScreen (char*)s_colorScreen+81920
 printf "DIRTY count=%u\n",s_dirtyRectCount
 p s_dirtyRects[0]
 echo CAPTURE COMPLETE\n
 detach
 quit
end
break VetteScreen::showLoudStop
continue
