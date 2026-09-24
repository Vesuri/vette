# Requires PROBES=1 VERIFY=1 FILLWATCH=1 SKIP_INTRO=1 GARAGE_CLICK=1.
# Observe the original selector controls and their committed crop origins.
set pagination off
set confirm off
set $seen = 0
set $mouseFailures = 0
break nextEvent
commands
 silent
 if !s_screen->m_mouseAllowed
  set $mouseFailures = $mouseFailures + 1
 end
 printf "CROP phase=%u origin=%u,%u mouse=%d,%d sprite=%04x,%04x pending=%u\n",s_garageClickPhase,s_screen->m_cropLeft,s_screen->m_cropTop,s_mouseX,s_mouseY,s_screen->m_mouseSprite[0][0],s_screen->m_mouseSprite[0][1],s_screen->m_framePending
 if s_screen->m_cropLeft == 128 && s_screen->m_cropTop == 26
  set $seen = $seen | 1
 end
 if s_screen->m_cropLeft == 144 && s_screen->m_cropTop == 8
  set $seen = $seen | 2
 end
 if s_screen->m_cropLeft == 64 && s_screen->m_cropTop == 37
  set $seen = $seen | 4
 end
 continue
end
break VetteScreen::showLoudStop
break VetteScreen::presentMacFrame if g_macDrivingIterations >= 4
continue
printf "RESULT seen=%u state=%u driving=%u crop=%u,%u verify=%u failures=%u fillbad=%u\n",$seen,g_stageBState,g_macDrivingIterations,s_screen->m_cropLeft,s_screen->m_cropTop,g_c2pVerifyCalls,g_c2pVerifyFailures,g_fillBadPixels
printf "MOUSE selector failures=%u driving allowed=%u\n",$mouseFailures,s_screen->m_mouseAllowed
if $mouseFailures == 0 && !s_screen->m_mouseAllowed && $seen == 7 && g_stageBState != 3 && g_macDrivingIterations >= 4 && s_screen->m_cropLeft == 80 && s_screen->m_cropTop == 32 && g_c2pVerifyFailures == 0 && g_fillBadPixels == 0
 echo PASS dynamic crops and C2P\n
else
 echo FAIL dynamic crops\n
end
detach
quit
