# Describe CopyBits calls made after the first driving frame enters its
# dynamic renderer.  The hot breakpoint stays disabled during setup.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $calls = 0

set logging file ../tmp/driving-sequence.tsv
set logging overwrite on
set logging redirect on
set logging enabled on
printf "capture\tticks\trpm\tgear\tspeed\tx\ty\theading\n"
set logging enabled off
set logging overwrite off

break *(s_segments[1].begin+0x286a)
commands 1
  silent
  enable 2
  disable 1
  continue
end

break copyBits
commands 2
  silent
  set $calls = $calls+1
  set $car = *(unsigned int*)(s_currentA5-0x3678)
  printf "dynamic CopyBits[%u] tick=%u active=%u rpm=%d mode=%u sameBitmap=%u src=$%08x dst=$%08x mask=$%08x\n", $calls, g_macTicks, g_macVBLCallbackActive, *(short*)($car+0x44), mode, sourceBitmap==destinationBitmap, sourceBitmap, destinationBitmap, maskRegion
  if $calls <= 4
    set logging enabled on
    printf "%u\t%u\t%d\t%d\t%d\t%08x\t%08x\t%u\n", $calls, g_macTicks, *(short*)($car+0x44), *(short*)($car+0x1c), *(short*)($car+0x1a), *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x66)
    set logging enabled off
  end
  printf "  source=(%d,%d)-(%d,%d) target=(%d,%d)-(%d,%d)\n", *(short*)sourceRect, *(short*)(sourceRect+2), *(short*)(sourceRect+4), *(short*)(sourceRect+6), *(short*)destinationRect, *(short*)(destinationRect+2), *(short*)(destinationRect+4), *(short*)(destinationRect+6)
  if $calls == 1
    set $i = 0
    while $i < 8
      if s_gworlds[$i].used
        if sourceBitmap == &s_gworlds[$i].port[2]
          printf "  source GWorld slot=%u seed=%u\n", $i, *(unsigned int*)s_gworlds[$i].colorTable
          dump binary memory ../tmp/driving-copy-source.ctab s_gworlds[$i].colorTable s_gworlds[$i].colorTable+136
          set $sourceRows = *(short*)(&s_gworlds[$i].pixMap[10])-*(short*)(&s_gworlds[$i].pixMap[6])
          set $sourceStride = *(unsigned short*)(&s_gworlds[$i].pixMap[4])&0x3fff
          dump binary memory ../tmp/driving-copy-source.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$sourceRows*$sourceStride
        end
        if destinationBitmap == &s_gworlds[$i].port[2]
          printf "  destination GWorld slot=%u seed=%u\n", $i, *(unsigned int*)s_gworlds[$i].colorTable
          dump binary memory ../tmp/driving-copy-destination.ctab s_gworlds[$i].colorTable s_gworlds[$i].colorTable+136
        end
      end
      set $i = $i+1
    end
    if destinationBitmap == s_windowManagerPort+2
      printf "  destination Window Manager seed=%u\n", *(unsigned int*)s_windowManagerColors
      dump binary memory ../tmp/driving-copy-destination.ctab s_windowManagerColors s_windowManagerColors+136
    end
    set $i = 0
    while $i < 8
      if s_windows[$i].used && destinationBitmap == s_windows[$i].window+2
        printf "  destination window slot=%u seed=%u\n", $i, *(unsigned int*)s_windowManagerColors
        dump binary memory ../tmp/driving-copy-destination.ctab s_windowManagerColors s_windowManagerColors+136
      end
      set $i = $i+1
    end
  end
  if $calls <= 4
    set $i = 0
    while $i < 8
      if s_gworlds[$i].used && sourceBitmap == &s_gworlds[$i].port[2]
        set $sourceRows = *(short*)(&s_gworlds[$i].pixMap[10])-*(short*)(&s_gworlds[$i].pixMap[6])
        set $sourceStride = *(unsigned short*)(&s_gworlds[$i].pixMap[4])&0x3fff
        if $calls == 1
          dump binary memory ../tmp/driving-copy-source-1.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$sourceRows*$sourceStride
        end
        if $calls == 2
          dump binary memory ../tmp/driving-copy-source-2.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$sourceRows*$sourceStride
        end
        if $calls == 3
          dump binary memory ../tmp/driving-copy-source-3.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$sourceRows*$sourceStride
        end
        if $calls == 4
          dump binary memory ../tmp/driving-copy-source-4.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$sourceRows*$sourceStride
        end
      end
      set $i = $i+1
    end
  end
  if $calls >= 12
    detach
    quit
  end
  continue
end
disable 2

continue
