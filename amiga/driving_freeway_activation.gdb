# Observe the Course Two FWTP handler and stop only when the original freeway
# allocator is entered with freeway mode active.  Requires the input-only
# SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2 FREEWAY_ROUTE=1 build.
set pagination off
set confirm off
set $entered = 0

break *(s_segments[6].begin+0x5632)
commands
  silent
  set $entered = 1
  printf "freeway-transition-212 entry tick=%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), (*(unsigned int*)($a0+0x6e))&0x7ff, (*(unsigned int*)($a0+0x72))&0x7ff, *(unsigned short*)($a0+0x66), *(signed short*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x565a)
commands
  silent
  printf "freeway-transition-212 exit tick=%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), (*(unsigned int*)($a0+0x6e))&0x7ff, (*(unsigned int*)($a0+0x72))&0x7ff, *(unsigned short*)($a0+0x66), *(signed short*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x2318)
commands
  silent
  if $entered && *(signed short*)($a5-0x3764) != 0
    printf "natural-freeway-spawn tick=%u count=%u/%u player-cell=(%u,%u) heading=%u mode=%d FWTP=$%08x\n", g_macTicks, *(unsigned short*)($a5-0x3696), *(unsigned short*)($a5-0x3698), *(unsigned short*)($a2+0x3e), *(unsigned short*)($a2+0x40), *(unsigned short*)($a2+0x66), *(signed short*)($a5-0x3764), $a1
    detach
    quit
  end
  continue
end

continue

printf "freeway activation ceiling entered=%u tick=%u mode=%d\n", $entered, g_macTicks, *(signed short*)(s_currentA5-0x3764)
detach
quit
