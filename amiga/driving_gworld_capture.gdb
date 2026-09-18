# Capture every live offscreen GWorld at the runner's wall-time ceiling.  This
# distinguishes direct game rendering from a missing screen composition step.
set pagination off
set confirm off

continue

printf "\n===== DRIVING GWORLDS =====\n"
set $i = 0
while $i < 8
  if s_gworlds[$i].used
    set $map = (unsigned char*)&s_gworlds[$i].pixMap
    set $rowBytes = *(unsigned short*)($map + 4) & 0x3fff
    set $top = *(short*)($map + 6)
    set $left = *(short*)($map + 8)
    set $bottom = *(short*)($map + 10)
    set $right = *(short*)($map + 12)
    printf "slot %u pixels=$%08x rowBytes=%u bounds=(%d,%d)-(%d,%d) locked=%u\n", $i, s_gworlds[$i].pixels, $rowBytes, $top, $left, $bottom, $right, s_gworlds[$i].locked
    if $i == 0
      dump binary memory ../tmp/driving_gworld0.raw s_gworlds[0].pixels s_gworlds[0].pixels+$rowBytes*($bottom-$top)
    end
    if $i == 1
      dump binary memory ../tmp/driving_gworld1.raw s_gworlds[1].pixels s_gworlds[1].pixels+$rowBytes*($bottom-$top)
    end
    if $i == 2
      dump binary memory ../tmp/driving_gworld2.raw s_gworlds[2].pixels s_gworlds[2].pixels+$rowBytes*($bottom-$top)
    end
    if $i == 3
      dump binary memory ../tmp/driving_gworld3.raw s_gworlds[3].pixels s_gworlds[3].pixels+$rowBytes*($bottom-$top)
    end
    if $i == 4
      dump binary memory ../tmp/driving_gworld4.raw s_gworlds[4].pixels s_gworlds[4].pixels+$rowBytes*($bottom-$top)
    end
    if $i == 5
      dump binary memory ../tmp/driving_gworld5.raw s_gworlds[5].pixels s_gworlds[5].pixels+$rowBytes*($bottom-$top)
    end
    if $i == 6
      dump binary memory ../tmp/driving_gworld6.raw s_gworlds[6].pixels s_gworlds[6].pixels+$rowBytes*($bottom-$top)
    end
    if $i == 7
      dump binary memory ../tmp/driving_gworld7.raw s_gworlds[7].pixels s_gworlds[7].pixels+$rowBytes*($bottom-$top)
    end
  end
  set $i = $i + 1
end
printf "depth=%u PC=$%08x dirty=(%d,%d)-(%d,%d)\n", g_stageCDepth, $pc, s_dirtyTop, s_dirtyLeft, s_dirtyBottom, s_dirtyRight
printf "===========================\n\n"
detach
quit
