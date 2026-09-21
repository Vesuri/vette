# Record Bogas administrative calls through a deterministic driving transition.
# The wrapper entries are stable CODE 9 boundaries whether the shipped driver
# or the Paula bridge is installed.  With INPUT_PROBE_EVENT_RAW_KEY=0x19 this
# captures the real P pause/options path; with 0x45 it captures Escape.
set pagination off
set confirm off

break *(s_segments[9].begin+0x05c)
commands
  silent
  printf "BogasDispose tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x08c)
commands
  silent
  printf "BogasClose tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x1e6)
commands
  silent
  printf "BogasPurge tick=%u caller=$%x instrument=%u\n", g_macTicks, *(unsigned int*)$sp, *(unsigned short*)($sp+4)
  continue
end
break *(s_segments[9].begin+0x21c)
commands
  silent
  printf "BogasSet tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x24c)
commands
  silent
  printf "BogasStart tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x27c)
commands
  silent
  printf "BogasStop tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x2ac)
commands
  silent
  printf "BogasDeactivate tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end

# First change enters driving; second leaves through the requested original
# handler.  Stop two Macintosh seconds later so any delayed lifecycle call is
# included without turning this into another long route run.
watch s_drivingFrameStarted
continue
continue
set $ceiling = g_macTicks + 120
break vbiHandler if g_macTicks >= $ceiling
commands
  silent
  printf "Bogas transition ceiling tick=%u frames=%u depth=%u driving=%u started=%u\n", g_macTicks, g_macFramesPresented, g_stageCDepth, s_drivingFrameStarted, s_bogasStarted
  detach
  quit
end

continue
