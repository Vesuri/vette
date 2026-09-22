# Inventory successful driving CopyBits geometry for alternate view modes.
# Requires a MOTION_CAPTURE diagnostic build and the desired input probe.
set pagination off
set confirm off
set $calls = 0

break vetteMotionCaptureBoundary
commands
  silent
  set $calls = $calls+1
  set $world = -1
  set $i = 0
  while $i < 8
    if s_gworlds[$i].used && sourceBitmap == &s_gworlds[$i].port[2]
      set $world = $i
    end
    set $i = $i+1
  end
  set $car = *(unsigned int*)(s_currentA5-0x3678)
  printf "view CopyBits[%u] tick=%u iteration=%u gear=%d speed=%d rpm=%d source=(%d,%d)-(%d,%d) destination=(%d,%d)-(%d,%d) world=%d", $calls, g_macTicks, g_macDrivingIterations, *(short*)($car+0x1c), *(short*)($car+0x1a), *(short*)($car+0x44), *(short*)sourceRect, *(short*)(sourceRect+2), *(short*)(sourceRect+4), *(short*)(sourceRect+6), *(short*)destinationRect, *(short*)(destinationRect+2), *(short*)(destinationRect+4), *(short*)(destinationRect+6), $world
  if $world >= 0
    printf " bounds=(%d,%d)-(%d,%d) rowBytes=%u\n", *(short*)(&s_gworlds[$world].pixMap[6]), *(short*)(&s_gworlds[$world].pixMap[8]), *(short*)(&s_gworlds[$world].pixMap[10]), *(short*)(&s_gworlds[$world].pixMap[12]), (*(unsigned short*)(&s_gworlds[$world].pixMap[4]))&0x3fff
  else
    printf "\n"
  end
  if $calls >= 40
    detach
    quit
  end
  continue
end

continue
