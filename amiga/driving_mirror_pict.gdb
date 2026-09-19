# Identify an indexed PICT operation that covers the first differing rear-view
# mirror pixel in the synchronized driving differential.  Requires
# SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break drawIndexedPictureBits
commands
  silent
  if s_garageClickPhase >= 9
    set $port = *(unsigned char**)s_qdThePort
    set $pixmapHandle = *(unsigned char***)($port+2)
    set $pixmap = *$pixmapHandle
    if $pixmap == s_gworlds[0].pixMap
      set $top = *(short*)targetRect
      set $left = *(short*)(targetRect+2)
      set $bottom = *(short*)(targetRect+4)
      set $right = *(short*)(targetRect+6)
      if $top <= 1 && $bottom > 1 && $left <= 346 && $right > 346
        printf "mirror PICT tick=%u size=%u offset=%u packed=%u target=(%d,%d)-(%d,%d) frame=(%d,%d)-(%d,%d)\n", g_macTicks, size, offset, packed, $top, $left, $bottom, $right, *(short*)pictureFrame, *(short*)(pictureFrame+2), *(short*)(pictureFrame+4), *(short*)(pictureFrame+6)
        detach
        quit
      end
    end
  end
  continue
end

continue
