# PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=1
set pagination off
set confirm off
set $seen = 0
set $course_hit = 0
break *(s_segments[2].begin+0x1824)
commands
 silent
 if $d0 == 0 && s_garageClickPhase >= 9
  set $course_hit = 1
 end
 continue
end
break nextEvent if s_garageClickPhase == 8
commands
 silent
 set $seen = 1
 x/20hd s_currentA5-0x53fc
 dump binary memory .run/course-buttons.raw (char*)s_colorScreen (char*)s_colorScreen+81920
 dump binary memory .run/course-buttons.ctab (char*)s_windowManagerColors (char*)s_windowManagerColors+136
 continue
end
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_macDrivingIterations >= 4
continue
printf "LAYOUT seen=%u course=%u driving=%u state=%u\n",$seen,*(unsigned char*)(s_currentA5-0x555a),g_macDrivingIterations,g_stageBState
if $seen && $course_hit && *(unsigned char*)(s_currentA5-0x555a) == 0 && g_macDrivingIterations >= 4 && g_stageBState != 3
 echo PASS relocated COURSE 1 and ACCEPT\n
else
 echo FAIL relocated course buttons\n
end
detach
quit
