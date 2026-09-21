# Record Bogas administrative calls through a complete ordinary intro.  These
# wrapper entries are stable CODE 9 boundaries whether the shipped driver or
# the Paula bridge is installed.
set pagination off
set confirm off

break *(s_segments[9].begin+0x05c)
commands 1
  silent
  printf "BogasDispose tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x08c)
commands 2
  silent
  printf "BogasClose tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x1e6)
commands 3
  silent
  printf "BogasPurge tick=%u caller=$%x instrument=%u\n", g_macTicks, *(unsigned int*)$sp, *(unsigned short*)($sp+4)
  continue
end
break *(s_segments[9].begin+0x21c)
commands 4
  silent
  printf "BogasSet tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x24c)
commands 5
  silent
  printf "BogasStart tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x27c)
commands 6
  silent
  printf "BogasStop tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end
break *(s_segments[9].begin+0x2ac)
commands 7
  silent
  printf "BogasDeactivate tick=%u caller=$%x\n", g_macTicks, *(unsigned int*)$sp
  continue
end

break updateIntroAudio if g_macTicks >= 4000
commands 8
  silent
  printf "Bogas lifecycle ceiling tick=%u frames=%u depth=%u\n", g_macTicks, g_macFramesPresented, g_stageCDepth
  detach
  quit
end

continue
