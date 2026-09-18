# Describe indexed PICT rasters reached while constructing the first driving frame.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $calls = 0

break drawIndexedPictureBits if s_garageClickPhase >= 9
commands
  silent
  set $base = offset
  set $colors = *(unsigned short*)(picture+$base+52)+1
  set $rects = picture+$base+54+($colors*8)
  set $calls = $calls+1
  printf "indexed[%u] packed=%u size=%u off=%u rowBytes=%u pixelSize=%u source=(%d,%d)-(%d,%d) colors=%u\n", $calls, packed, size, $base, (*(unsigned short*)(picture+$base))&0x3fff, *(unsigned short*)(picture+$base+28), *(short*)(picture+$base+2), *(short*)(picture+$base+4), *(short*)(picture+$base+6), *(short*)(picture+$base+8), $colors
  printf "  copy=(%d,%d)-(%d,%d) raster=(%d,%d)-(%d,%d) frame=(%d,%d)-(%d,%d) target=(%d,%d)-(%d,%d)\n", *(short*)$rects, *(short*)($rects+2), *(short*)($rects+4), *(short*)($rects+6), *(short*)($rects+8), *(short*)($rects+10), *(short*)($rects+12), *(short*)($rects+14), *(short*)pictureFrame, *(short*)(pictureFrame+2), *(short*)(pictureFrame+4), *(short*)(pictureFrame+6), *(short*)targetRect, *(short*)(targetRect+2), *(short*)(targetRect+4), *(short*)(targetRect+6)
  if $calls >= 40
    detach
    quit
  end
  continue
end

continue
