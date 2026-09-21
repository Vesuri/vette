# Trace selector 72 record 2 through jump-table export 230, the shipped
# Freeway_Map -> Main_Map relocation.  A focused run uses FREEWAY_START=30,
# FREEWAY_START_U=1600 and FREEWAY_START_V=1024 to begin inside that exact
# source-defined response rectangle.  This script reads game state only.
set pagination off
set confirm off
set $exited = 0

break *(s_segments[6].begin+0x5b26)
commands 1
  silent
  printf "freeway export 230 entry tick=%u world=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) heading=%u speed=%d mode=%d\n", g_macTicks, *(unsigned int*)$a0, *(unsigned int*)($a0+8), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), (*(unsigned int*)$a0)&0x7ff, (*(unsigned int*)($a0+8))&0x7ff, *(unsigned short*)($a0+0x66), *(signed short*)($a0+26), *(signed short*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x5b4e)
commands 2
  silent
  set $exited = 1
  printf "freeway export 230 exit tick=%u physics=($%08x,$%08x) cached=($%08x,$%08x) cell=(%u,%u) local=(%u,%u) mode=%d\n", g_macTicks, *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72), *(unsigned int*)$a0, *(unsigned int*)($a0+8), *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), (*(unsigned int*)($a0+0x6e))&0x7ff, (*(unsigned int*)($a0+0x72))&0x7ff, *(signed short*)($a5-0x3764)
  continue
end

break *(s_segments[6].begin+0x69dc) if $exited && $a3 == *(unsigned int*)($a5-0x3678)
commands 3
  silent
  printf "freeway export 230 landing tick=%u physics=($%08x,$%08x) cached=($%08x,$%08x) cell=(%u,%u) physics-local=(%u,%u) heading=%u speed=%d mode=%d\n", g_macTicks, *(unsigned int*)($a3+0x6e), *(unsigned int*)($a3+0x72), *(unsigned int*)$a3, *(unsigned int*)($a3+8), *(unsigned short*)($a3+0x3e), *(unsigned short*)($a3+0x40), (*(unsigned int*)($a3+0x6e))&0x7ff, (*(unsigned int*)($a3+0x72))&0x7ff, *(unsigned short*)($a3+0x66), *(signed short*)($a3+26), *(signed short*)($a5-0x3764)
  detach
  quit
end

continue
