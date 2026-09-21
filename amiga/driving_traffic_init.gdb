# Capture Traffic records both when Traffic+$2006 links their zeroed storage
# and when its Traffic+$24DE caller finishes the actual initializer.  Requires
# SKIP_INTRO=1 GARAGE_CLICK=1 and the same FIDELITY_RANDOM_SEED used by the
# Macintosh reference.
set pagination off
set confirm off
set $appends = 0
set $pending = 0
set $pending_index = 0

break *vette_code_6+0x2018
commands
  silent
  if *(unsigned int*)($a6+4) == vette_code_6+0x2508
    set $appends = $appends+1
    set $pending = $a0
    set $pending_index = $appends
    printf "TRAFFIC APPEND #%u ticks=%u iteration=%u phase=%u count=%u record=$%08x tag=$%08x return=$%08x pos=$%08x/$%08x physics=$%08x/$%08x\n", $appends, g_macTicks, g_macDrivingIterations, g_macDrivingCallbacks, *(unsigned short*)(s_currentA5-0x3696), $a0, *(unsigned int*)($a0+0x54), *(unsigned int*)($a6+4), *(unsigned int*)$a0, *(unsigned int*)($a0+8), *(unsigned int*)($a0+0x6e), *(unsigned int*)($a0+0x72)
    eval "dump binary memory ../tmp/traffic-init-%u.bin $a0 $a0+0xc8", $appends
  end
  continue
end

break *vette_code_6+0x2528
commands
  silent
  if $pending != 0
    printf "TRAFFIC READY #%u ticks=%u iteration=%u phase=%u record=$%08x tag=$%08x type=%u pos=$%08x/$%08x physics=$%08x/$%08x\n", $pending_index, g_macTicks, g_macDrivingIterations, g_macDrivingCallbacks, $pending, *(unsigned int*)($pending+0x54), *(unsigned short*)($pending+0x28), *(unsigned int*)$pending, *(unsigned int*)($pending+8), *(unsigned int*)($pending+0x6e), *(unsigned int*)($pending+0x72)
    eval "dump binary memory ../tmp/traffic-ready-%u.bin $pending $pending+0xc8", $pending_index
    set $pending = 0
    if $appends >= 8
      detach
      quit
    end
  end
  continue
end

continue
