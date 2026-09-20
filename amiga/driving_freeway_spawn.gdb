# Trace the first two FWTP -> JHPF freeway spawns.  Requires a
# SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $spawns = 0
set $base_jhpf = 0

break *(s_segments[6].begin+0x2318)
commands
  silent
  set $spawns = $spawns+1
  set $player = $a2
  set $fwtp = $a1
  printf "spawn[%u] tick=%u key=$%04x playerCell=(%u,%u) heading=%u FWTP=$%08x\n", $spawns, g_macTicks, ((*(unsigned short*)($player+0x3e))<<8)|(*(unsigned char*)($player+0x41)), *(unsigned short*)($player+0x3e), *(unsigned short*)($player+0x40), *(unsigned short*)($player+0x66), $fwtp
  continue
end

break *(s_segments[6].begin+0x2356)
commands
  silent
  printf "  selected cell=(%u,%u) jhpf=%u secondTriplet=%u\n", $d0, $d1, $d2, (*(unsigned short*)($player+0x66)>0x1800 && *(unsigned short*)($player+0x66)<0x3800)
  continue
end

break *(s_segments[6].begin+0x2376)
commands
  silent
  set $base_jhpf = $a1
  continue
end

break *(s_segments[6].begin+0x238e)
commands
  silent
  printf "  JHPF base=$%08x final=$%08x linked=%u link=%u local=(%u,%u) quadrant=%u\n", $base_jhpf, $a1, $a1!=$base_jhpf, *(unsigned short*)$base_jhpf, *(unsigned short*)($a1+2), *(unsigned short*)($a1+4), *(unsigned char*)($a1+6)
  continue
end

break *(s_segments[6].begin+0x23a8)
commands
  silent
  printf "  object cell=(%u,%u) world=($%08x,$%08x) heading=%u id=%u\n", *(unsigned short*)($a0+0x3e), *(unsigned short*)($a0+0x40), *(unsigned int*)$a0, *(unsigned int*)($a0+8), *(unsigned int*)($a0+0x0c), *(unsigned char*)($a0+0xbe)
  if $spawns >= 2
    detach
    quit
  end
  continue
end

continue
