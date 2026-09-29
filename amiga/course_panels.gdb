# PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=1..4
# Set $expectedCourse to the matching one-based course before sourcing.
set pagination off
set confirm off
set $seen=0
set $hit=0
break *(s_segments[2].begin+0x1824)
commands
 silent
 if $d0 == $expectedCourse-1 && s_garageClickPhase >= 9
  set $hit=1
 end
 continue
end
break nextEvent if s_garageClickPhase == 10
commands
 silent
 set $seen=$seen+1
 dump binary memory .run/course-panel.raw (char*)s_colorScreen (char*)s_colorScreen+81920
 dump binary memory .run/course-panel.ctab (char*)s_windowManagerColors (char*)s_windowManagerColors+136
 if !vette_hires_value
  set $r=(unsigned char*)s_colorScreen+77*256+132
  if $r[0] != 0xff || $r[1] != 0xff || ($r[2]&0xf0) != 0xf0
   echo FAIL compact Finish text\n
   detach
   quit 1
  end
 else
  # The original game places each course panel at a different destination.
  set $picture=6398
  if $expectedCourse == 2
   set $picture=5383
  end
  if $expectedCourse == 3
   set $picture=27402
  end
  if $expectedCourse == 4
   set $picture=15714
  end
  set $n=0
  set $found=0
  while $n<64 && !$found
   set $index=(g_probeDrawPictureCalls-1-$n)&63
   if g_probeDrawPictureTrace[$index][0] == $picture
    set $found=1
    set $finishX=g_probeDrawPictureTrace[$index][2]+14
    set $finishY=g_probeDrawPictureTrace[$index][1]+68
   end
   set $n=$n+1
  end
  if !$found
   echo FAIL missing course picture trace\n
   detach
   quit 1
  end
  if $expectedCourse == 3
   set $finishX=$finishX-2
  end
  if $expectedCourse == 4
   set $finishY=$finishY+1
  end
  set $r=(unsigned char*)s_colorScreen+$finishY*256+$finishX/2
  if $r[0] != 0xff || $r[1] != 0xff || ($r[2]&0xf0) != 0xf0
   echo FAIL original Finish text\n
   detach
   quit 1
  end
 end
 continue
end
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_macDrivingIterations >= 4
continue
printf "PANEL mode=%u expected=%u seen=%u hit=%u course=%u long=%u driving=%u state=%u\n",vette_hires_value,$expectedCourse,$seen,$hit,*(unsigned char*)(s_currentA5-0x555a),*(unsigned short*)(s_currentA5-0x5082),g_macDrivingIterations,g_stageBState
if !$seen || !$hit || g_macDrivingIterations < 4 || g_stageBState == 3
 echo FAIL course panel selection\n
 detach
 quit 1
end
echo PASS course panel selection\n
detach
quit
