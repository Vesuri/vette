# Bind the first object naturally created after the Course Two freeway
# transition, then follow that exact pointer through FWTM selection and its
# first byte-delta FREE movement.  This script observes only.
set pagination off
set confirm off
set $entered = 0
set $spawned = 0
set $free_kind = 0

break *(s_segments[6].begin+0x5632)
commands
  silent
  set $entered = 1
  continue
end

# A0 is the completed object and becomes A3 on the next instruction.
break *(s_segments[6].begin+0x242a)
commands
  silent
  if $entered && $spawned == 0 && *(signed short*)($a5-0x3764) != 0
    set $spawned = $a0
    printf "freeway-object object=$%08x tick=%u id=%u cell=(%u,%u) world=($%08x,$%08x) heading=%u mode=%d\n", $spawned, g_macTicks, *(unsigned char*)($spawned+0xbe), *(unsigned short*)($spawned+0x3e), *(unsigned short*)($spawned+0x40), *(unsigned int*)$spawned, *(unsigned int*)($spawned+8), *(unsigned short*)($spawned+0x0c), *(signed short*)($a5-0x3764)
  end
  continue
end

# $0C78 has projected the object 512 units along its heading and returned the
# corresponding NavigationMap cell in A1.  Its first word is the FWTM key.
break *(s_segments[6].begin+0x0d24) if $spawned != 0 && $a3 == $spawned
commands
  silent
  printf "FWTM-navigation tick=%u object=$%08x nav=$%08x key=$%04x world=($%08x,$%08x) heading=%u\n", g_macTicks, $a3, $a1, *(unsigned short*)$a1, *(unsigned int*)$a3, *(unsigned int*)($a3+8), *(unsigned short*)($a3+0x0e)
  continue
end

# $0CFA has replaced A1 with the matching six-byte FWTM record.
break *(s_segments[6].begin+0x0d2a) if $spawned != 0 && $a3 == $spawned
commands
  silent
  printf "FWTM-record tick=%u record=$%08x key=$%04x ids=(%u,%u,%u,%u)\n", g_macTicks, $a1, *(unsigned short*)$a1, *(unsigned char*)($a1+2), *(unsigned char*)($a1+3), *(unsigned char*)($a1+4), *(unsigned char*)($a1+5)
  continue
end

break *(s_segments[6].begin+0x0da0) if $spawned != 0 && $a3 == $spawned
commands
  silent
  printf "FWTM-selected tick=%u selector=%u FREE=$%08x\n", g_macTicks, $d0, *(unsigned int*)($a3+0x34)
  continue
end

break *(s_segments[6].begin+0x1564) if $spawned != 0 && $a3 == $spawned
commands
  silent
  set $free_kind = 1
  printf "FREE-byte entry tick=%u cursor=$%08x delta=(%d,%d) world=($%08x,$%08x)\n", g_macTicks, *(unsigned int*)($a3+0x34), *(signed char*)*(unsigned int*)($a3+0x34), *(signed char*)(*(unsigned int*)($a3+0x34)+1), *(unsigned int*)$a3, *(unsigned int*)($a3+8)
  continue
end

break *(s_segments[6].begin+0x1594) if $free_kind == 1 && $a3 == $spawned
commands
  silent
  printf "FREE-byte exit tick=%u cursor=$%08x target=($%08x,$%08x) world=($%08x,$%08x)\n", g_macTicks, *(unsigned int*)($a3+0x34), *(unsigned int*)($a3+0x48), *(unsigned int*)($a3+0x4c), *(unsigned int*)$a3, *(unsigned int*)($a3+8)
  detach
  quit
end

break *(s_segments[6].begin+0x15be) if $spawned != 0 && $a3 == $spawned
commands
  silent
  set $free_kind = 2
  printf "FREE-alt entry tick=%u cursor=$%08x delta=(%d,%d) world=($%08x,$%08x)\n", g_macTicks, *(unsigned int*)($a3+0x34), *(signed char*)*(unsigned int*)($a3+0x34), *(signed char*)(*(unsigned int*)($a3+0x34)+1), *(unsigned int*)$a3, *(unsigned int*)($a3+8)
  continue
end

break *(s_segments[6].begin+0x15ee) if $free_kind == 2 && $a3 == $spawned
commands
  silent
  printf "FREE-alt exit tick=%u cursor=$%08x target=($%08x,$%08x) world=($%08x,$%08x)\n", g_macTicks, *(unsigned int*)($a3+0x34), *(unsigned int*)($a3+0x48), *(unsigned int*)($a3+0x4c), *(unsigned int*)$a3, *(unsigned int*)($a3+8)
  detach
  quit
end

continue

printf "freeway-object ceiling entered=%u object=$%08x tick=%u mode=%d\n", $entered, $spawned, g_macTicks, *(signed short*)(s_currentA5-0x3764)
detach
quit
