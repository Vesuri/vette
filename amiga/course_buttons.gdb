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
 set $i = 0
 while $i < 5
  set $rect = (unsigned short*)(s_currentA5-0x53fc+$i*8)
  set $left = 82+72*$i
  if vette_hires_value
   set $left = 38+94*$i-($i == 4)
  end
  if $rect[0] != 297 || $rect[1] != $left || $rect[2] != 317 || $rect[3] != $left+64
   echo FAIL course button rectangle\n
   detach
   quit 1
  end
  set $i = $i+1
 end
 printf "BUTTONS hires=%u: all five rectangles match\n",vette_hires_value
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
 echo PASS display-mode COURSE 1 and ACCEPT\n
else
 echo FAIL display-mode course buttons\n
end
detach
quit
