# Sample free memory at frame boundaries; not every transient allocation/route.
set pagination off
set confirm off
init-if-undefined $memory_driving = 0
set $minchip = 0xffffffff
set $minother = 0xffffffff
define sample_memory
  set $node = (char*)SysBase->MemList.lh_Head
  set $chip = 0
  set $other = 0
  while *(unsigned long*)$node
    set $flags = *(unsigned short*)($node + 14)
    set $free = *(unsigned long*)($node + 28)
    if $flags & 2
      set $chip = $chip + $free
    else
      set $other = $other + $free
    end
    set $node = (char*)*(unsigned long*)$node
  end
  if $chip < $minchip
    set $minchip = $chip
  end
  if $other < $minother
    set $minother = $other
  end
end
sample_memory
break VetteScreen::presentMacFrame
commands
  silent
  sample_memory
  if g_stageCDepth >= 93 || (!$memory_driving && s_introAudioRetired && g_macTicks > 1200)
    printf "memory PASS chip-free-min=%u other-free-min=%u depth=%u\n", $minchip, $minother, g_stageCDepth
    detach
    quit
  end
  continue
end
break VetteScreen::showLoudStop
commands
  silent
  printf "memory FAIL loud stop trap=$%04x %s/%s\n", g_trapWord, g_trapManager, g_trapRoutine
  detach
  quit
end
continue
