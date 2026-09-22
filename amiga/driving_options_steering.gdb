# Exercise MENU 126's shipped Command-N/K/M/J equivalents and verify its four
# mutually exclusive state sets, ending back at Numeric keypad. Requires
# PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 OPTIONS_STEERING_PROBE=1.
set pagination off
set confirm off
set $commands = 0
set $pending = 0

break menuKey if g_optionsSteeringProbePhase <= 20
commands 1
  silent
  if requestedKey == 0x6e || requestedKey == 0x6b || requestedKey == 0x6d || requestedKey == 0x6a
    printf "steering MenuKey key=$%02x phase=%u tick=%u\n", requestedKey, g_optionsSteeringProbePhase, g_macTicks
  end
  continue
end

break *(s_segments[1].begin+0x103e) if g_optionsSteeringProbePhase <= 20
commands 2
  silent
  if ($d0 & 0xffff0000) == 0x007e0000
    set $pending = 1
    printf "steering packed=$%08x phase=%u tick=%u\n", $d0, g_optionsSteeringProbePhase, g_macTicks
  end
  continue
end

# All menu handlers share this return.  Record state only after a MENU 126
# command; the five expected active-flag tuples are N, K, M, J, N.
break *(s_segments[1].begin+0x1774) if g_optionsSteeringProbePhase <= 20
commands 3
  silent
  set $n = *(unsigned short*)(s_currentA5-0x5310)
  set $k = *(unsigned short*)(s_currentA5-0x5312)
  set $m = *(unsigned short*)(s_currentA5-0x5316)
  set $j = *(unsigned short*)(s_currentA5-0x5314)
  if $pending
    set $commands = $commands + 1
    printf "steering state %d flags=(%u,%u,%u,%u) cursor=%d\n", $commands, $n, $k, $m, $j, *(signed short*)(s_currentA5-0x5006)
    set $pending = 0
  end
  continue
end

break nextEvent if g_optionsSteeringProbeComplete
commands 4
  silent
  printf "steering complete commands=%d phase=%u flags=(%u,%u,%u,%u)\n", $commands, g_optionsSteeringProbePhase, *(unsigned short*)(s_currentA5-0x5310), *(unsigned short*)(s_currentA5-0x5312), *(unsigned short*)(s_currentA5-0x5316), *(unsigned short*)(s_currentA5-0x5314)
  detach
  quit
end

continue
