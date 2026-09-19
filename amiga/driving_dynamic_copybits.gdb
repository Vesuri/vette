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
  if $calls >= 12
    detach
    quit
  end
  continue
end
disable 2

continue
