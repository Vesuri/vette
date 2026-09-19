# Inventory the original Traffic packed-raster helpers used to construct the
# first driving frame.  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $calls67a4 = 0
set $calls67fa = 0
set $calls6850 = 0

break *(s_segments[6].begin+0x67a4)
commands 1
  silent
  if s_garageClickPhase >= 9
    set $calls67a4 = $calls67a4+1
    printf "Traffic+67A4[%u] tick=%u d1=$%08x d2=$%08x d3=$%08x d4=$%08x a0=$%08x a1=$%08x\n", $calls67a4, g_macTicks, $d1, $d2, $d3, $d4, $a0, $a1
  end
  continue
end

break *(s_segments[6].begin+0x67fa)
commands 2
  silent
  if s_garageClickPhase >= 9
    set $calls67fa = $calls67fa+1
    printf "Traffic+67FA[%u] tick=%u d1=$%08x d2=$%08x d3=$%08x d4=$%08x a0=$%08x a1=$%08x\n", $calls67fa, g_macTicks, $d1, $d2, $d3, $d4, $a0, $a1
  end
  continue
end

break *(s_segments[6].begin+0x6850)
commands 3
  silent
  if s_garageClickPhase >= 9
    set $calls6850 = $calls6850+1
    printf "Traffic+6850[%u] tick=%u d1=$%08x d2=$%08x d3=$%08x d4=$%08x a0=$%08x a1=$%08x\n", $calls6850, g_macTicks, $d1, $d2, $d3, $d4, $a0, $a1
  end
  continue
end

break *(s_segments[1].begin+0x286a)
commands 4
  silent
  disable 4
  enable 5
  continue
end

break copyBits
commands 5
  silent
  printf "first post-gate CopyBits tick=%u raster calls=%u/%u/%u\n", g_macTicks, $calls67a4, $calls67fa, $calls6850
  detach
  quit
end
disable 5

continue
