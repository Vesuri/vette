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
    printf "Traffic+6686[%u] tick=%u return=$%08x d1=$%08x d2=$%08x d3=$%08x d4=$%08x d7=$%08x a1=$%08x\n", $fills, g_macTicks, *(unsigned int*)$sp, $d1, $d2, $d3, $d4, $d7, $a1
    if $d1 == 80 && $d7 == 0x44444444
      set $caller = *(unsigned int*)$sp
      set $i = 0
      while $i < 11
        if $caller >= (unsigned int)s_segments[$i].begin && $caller < (unsigned int)s_segments[$i].end
          printf "  height caller segment=%u offset=$%x range=[$%08x,$%08x)\n", $i, $caller-(unsigned int)s_segments[$i].begin, s_segments[$i].begin, s_segments[$i].end
        end
        set $i = $i+1
      end
    end
  end
  continue
end

break *(s_segments[6].begin+0x66d2)
commands 2
  silent
  if s_garageClickPhase >= 9
    set $copies = $copies+1
    printf "Traffic+66D2[%u] tick=%u return=$%08x d1=$%08x d2=$%08x d3=$%08x d4=$%08x d7=$%08x a1=$%08x\n", $copies, g_macTicks, *(unsigned int*)$sp, $d1, $d2, $d3, $d4, $d7, $a1
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
