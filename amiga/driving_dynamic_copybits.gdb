# Describe CopyBits calls made after the first driving frame enters its
# dynamic renderer.  The hot breakpoint stays disabled during setup.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $calls = 0

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
  printf "dynamic CopyBits[%u] tick=%u active=%u mode=%u sameBitmap=%u src=$%08x dst=$%08x mask=$%08x\n", $calls, g_macTicks, g_macVBLCallbackActive, mode, sourceBitmap==destinationBitmap, sourceBitmap, destinationBitmap, maskRegion
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
  end
  if $calls >= 12
    detach
    quit
  end
  continue
end
disable 2

continue
