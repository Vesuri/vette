# Capture full-row Traffic fill/copy helpers before the first displayed driving
# frame.  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $fills = 0
set $copies = 0

break *(s_segments[6].begin+0x6686)
commands 1
  silent
  if s_garageClickPhase >= 9
    set $fills = $fills+1
    printf "Traffic+6686[%u] tick=%u d1=$%08x d2=$%08x d3=$%08x d4=$%08x d7=$%08x a1=$%08x\n", $fills, g_macTicks, $d1, $d2, $d3, $d4, $d7, $a1
  end
  continue
end

break *(s_segments[6].begin+0x66d2)
commands 2
  silent
  if s_garageClickPhase >= 9
    set $copies = $copies+1
    printf "Traffic+66D2[%u] tick=%u d1=$%08x d2=$%08x d3=$%08x d4=$%08x d7=$%08x a1=$%08x\n", $copies, g_macTicks, $d1, $d2, $d3, $d4, $d7, $a1
  end
  continue
end

break *(s_segments[1].begin+0x286a)
commands 3
  silent
  disable 3
  enable 4
  continue
end

break copyBits
commands 4
  silent
  printf "first post-gate CopyBits tick=%u fill/copy calls=%u/%u\n", g_macTicks, $fills, $copies
  detach
  quit
end
disable 4

continue
