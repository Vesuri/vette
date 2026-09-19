# Describe the PICT that populates the intermediate rear-view source at
# (388,0)-(466,168).  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $mirrorPicture = 0
set $mirrorRasters = 0

break drawPicture if s_garageClickPhase >= 9 && *(short*)targetRect == 388 && *(short*)(targetRect+2) == 0 && *(short*)(targetRect+4) == 466 && *(short*)(targetRect+6) == 168
commands 1
  silent
  set $mirrorPicture = 1
  printf "mirror DrawPicture tick=%u handle=$%08x picture=$%08x frame=(%d,%d)-(%d,%d) target=(%d,%d)-(%d,%d)\n", g_macTicks, pictureHandle, *pictureHandle, *(short*)(*pictureHandle+2), *(short*)(*pictureHandle+4), *(short*)(*pictureHandle+6), *(short*)(*pictureHandle+8), *(short*)targetRect, *(short*)(targetRect+2), *(short*)(targetRect+4), *(short*)(targetRect+6)
  continue
end

break drawIndexedPictureBits if $mirrorPicture
commands 2
  silent
  set $mirrorRasters = $mirrorRasters+1
  set $base = offset
  set $colors = *(unsigned short*)(picture+$base+52)+1
  set $rects = picture+$base+54+($colors*8)
  printf "mirror indexed[%u] packed=%u size=%u off=%u rowBytes=%u pixelSize=%u source=(%d,%d)-(%d,%d) colors=%u\n", $mirrorRasters, packed, size, $base, (*(unsigned short*)(picture+$base))&0x3fff, *(unsigned short*)(picture+$base+28), *(short*)(picture+$base+2), *(short*)(picture+$base+4), *(short*)(picture+$base+6), *(short*)(picture+$base+8), $colors
  printf "  copy=(%d,%d)-(%d,%d) raster=(%d,%d)-(%d,%d) target=(%d,%d)-(%d,%d)\n", *(short*)$rects, *(short*)($rects+2), *(short*)($rects+4), *(short*)($rects+6), *(short*)($rects+8), *(short*)($rects+10), *(short*)($rects+12), *(short*)($rects+14), *(short*)targetRect, *(short*)(targetRect+2), *(short*)(targetRect+4), *(short*)(targetRect+6)
  if $mirrorRasters >= 2
    dump binary memory ../tmp/driving-mirror-picture.raw picture picture+size
    detach
    quit
  end
  continue
end

continue
