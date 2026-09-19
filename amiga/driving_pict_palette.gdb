# Capture the large driving/dashboard PICT and the exact destination ColorTable
# used when it is decoded into the offscreen world.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break drawIndexedPictureBits if *(short*)targetRect == 120 && *(short*)(targetRect+2) == 0 && *(short*)(targetRect+4) == 406 && *(short*)(targetRect+6) == 408
commands
  silent
  set $port = *(unsigned char**)s_qdThePort
  set $pixmapHandle = *(unsigned char***)($port+2)
  set $pixmap = *$pixmapHandle
  set $ctabHandle = *(unsigned char***)($pixmap+42)
  set $ctab = *$ctabHandle
  printf "driving PICT tick=%u port=$%08x pixmap=$%08x table=$%08x seed=%u screenSeed=%u size=%u offset=%u\n", g_macTicks, $port, $pixmap, $ctab, *(unsigned int*)$ctab, *(unsigned int*)s_windowManagerColors, size, offset
  dump binary memory ../tmp/driving-pict.bin picture picture+size
  dump binary memory ../tmp/driving-pict-destination.ctab $ctab $ctab+136
  dump binary memory ../tmp/driving-pict-screen.ctab s_windowManagerColors s_windowManagerColors+136
  detach
  quit
end

continue
