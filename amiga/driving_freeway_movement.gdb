# Trace the shipped freeway traffic path and the removal which naturally frees
# a slot for Traffic+$2302.  Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build;
# GARAGE_COURSE and any input-only route may be selected separately.  This
# script observes only.
set pagination off
set confirm off
set $fwtm = 0
set $free = 0
set $scans = 0
set $removed = 0
set $retired = 0

break *(s_segments[6].begin+0x54f8)
commands
  silent
  printf "freeway-transition entry tick=%u world=($%08x,$%08x) cell=(%u,%u) heading=%u mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), *(unsigned short*)($a0+0x66), *(signed char*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x5522)
commands
  silent
  printf "freeway-transition exit tick=%u world=($%08x,$%08x) cell=(%u,%u) heading=%u mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), *(unsigned short*)($a0+0x66), *(signed char*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x593c)
commands
  silent
  printf "freeway-transition-221 entry tick=%u world=($%08x,$%08x) cell=(%u,%u) heading=%u mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), *(unsigned short*)($a0+0x66), *(signed char*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x596e)
commands
  silent
  printf "freeway-transition-221 exit tick=%u world=($%08x,$%08x) cell=(%u,%u) heading=%u mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), *(unsigned short*)($a0+0x66), *(signed char*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x0d1c)
commands
  silent
  set $fwtm = $fwtm+1
  if $fwtm <= 12
    printf "FWTM[%u] tick=%u object=$%08x tag=$%08x world=($%08x,$%08x) cell=(%u,%u) heading=%u mode=%d path=$%08x\n", $fwtm, g_macTicks, $a3, *(unsigned int*)($a3+0x54), *(unsigned int*)($a3+0x6e), *(unsigned int*)($a3+0x72), *(unsigned short*)($a3+0x3e), *(unsigned short*)($a3+0x40), *(unsigned short*)($a3+0x0e), *(signed char*)($a3+0x3b), *(unsigned int*)($a3+0x34)
  end
  continue
end

break *(s_segments[6].begin+0x1564)
commands
  silent
  set $free = $free+1
  if $free <= 16
    printf "FREE-byte[%u] tick=%u object=$%08x tag=$%08x world=($%08x,$%08x) mode=%d remaining=%d path=$%08x delta=(%d,%d)\n", $free, g_macTicks, $a3, *(unsigned int*)($a3+0x54), *(unsigned int*)($a3+0x6e), *(unsigned int*)($a3+0x72), *(signed char*)($a3+0x3b), *(signed char*)($a3+0x3a), *(unsigned int*)($a3+0x34), *(signed char*)*(unsigned int*)($a3+0x34), *(signed char*)(*(unsigned int*)($a3+0x34)+1)
  end
  continue
end

break *(s_segments[6].begin+0x15be)
commands
  silent
  set $free = $free+1
  if $free <= 16
    printf "FREE-alt[%u] tick=%u object=$%08x tag=$%08x world=($%08x,$%08x) mode=%d remaining=%d path=$%08x delta=(%d,%d)\n", $free, g_macTicks, $a3, *(unsigned int*)($a3+0x54), *(unsigned int*)($a3+0x6e), *(unsigned int*)($a3+0x72), *(signed char*)($a3+0x3b), *(signed char*)($a3+0x3a), *(unsigned int*)($a3+0x34), *(signed char*)*(unsigned int*)($a3+0x34), *(signed char*)(*(unsigned int*)($a3+0x34)+1)
  end
  continue
end

break *(s_segments[6].begin+0x252c)
commands
  silent
  set $scans = $scans+1
  if $scans <= 8
    printf "retire-scan[%u] tick=%u count=%u/%u player=$%08x world=($%08x,$%08x)\n", $scans, g_macTicks, *(unsigned short*)($a5-0x3696), *(unsigned short*)($a5-0x3698), *(unsigned int*)($a5-0x3678), *(unsigned int*)*(unsigned int*)($a5-0x3678), *(unsigned int*)(*(unsigned int*)($a5-0x3678)+8)
  end
  continue
end

break *(s_segments[6].begin+0x257a)
commands
  silent
  set $retired = $retired+1
  if $retired <= 20
    printf "retire-select[%u] tick=%u object=$%08x tag=$%08x world=($%08x,$%08x) player=($%08x,$%08x) distance=$%08x count=%u/%u\n", $retired, g_macTicks, $a0, *(unsigned int*)($a0+0x54), *(unsigned int*)$a0, *(unsigned int*)($a0+8), *(unsigned int*)$a4, *(unsigned int*)($a4+8), $d0, *(unsigned short*)($a5-0x3696), *(unsigned short*)($a5-0x3698)
  end
  continue
end

break *(s_segments[6].begin+0x1fb6)
commands
  silent
  set $removed = $removed+1
  if $removed <= 20
    printf "remove[%u] tick=%u object=$%08x tag=$%08x count-before=%u active-end=$%08x\n", $removed, g_macTicks, $a3, *(unsigned int*)($a3+0x54), *(unsigned short*)($a5-0x3696), *(unsigned int*)($a5-0x367c)
  end
  continue
end

break *(s_segments[6].begin+0x2318)
commands
  silent
  printf "natural-spawn tick=%u count=%u/%u player-cell=(%u,%u) heading=%u\n", g_macTicks, *(unsigned short*)($a5-0x3696), *(unsigned short*)($a5-0x3698), *(unsigned short*)($a2+0x3e), *(unsigned short*)($a2+0x40), *(unsigned short*)($a2+0x66)
  detach
  quit
end

continue
