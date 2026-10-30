# Prove the port 1 joystick and CD32 mappings reach the original controls.
# Build with PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 CONTROLLER_PROBE=1 (joystick)
# or CONTROLLER_PROBE=2 (CD32 pad, which also exercises its detection).
set pagination off
set confirm off
break vetteControllerProbeComplete
continue
set $r = g_controllerProbeResult
printf "controller mode=%u phase=%u gear %u->%u->%u->%u speed=%u stopped=%u heading $%04x->$%04x\n", g_controllerProbeMode, g_controllerProbePhase, $r[0], $r[1], $r[5], $r[6], $r[3], $r[7], $r[2], $r[4]
set $ok = g_controllerProbePhase == 10 && $r[1] == $r[0] + 1 && $r[5] == $r[1] + 1 && $r[6] == $r[1] && $r[3] > 0 && $r[7] == 0 && $r[4] != $r[2]
if g_controllerProbeMode == 2
  printf "controller reverse gear=%u horn=%u paused=%u\n", $r[8], $r[9], *(unsigned short*)(s_currentA5-21316) == 0
  set $ok = $ok && $r[8] != $r[6] && $r[9] && *(unsigned short*)(s_currentA5-21316) == 0
end
if $ok
  printf "PASS controller input mode=%u\n", g_controllerProbeMode
else
  printf "FAIL controller input mode=%u\n", g_controllerProbeMode
end
detach
quit
