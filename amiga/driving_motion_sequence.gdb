# Capture distinct completed moving-driving frames by their complete game state.
# The matching Macintosh capture is produced with VETTE_DRIVING_MOTION=1.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1; that harness shifts into gear 1 and
# holds the original keypad-8 accelerator through the game's normal KeyMap.
set pagination off
set confirm off
set $captures = 0
set $last_rpm = -32768
set $last_gear = -32768
set $last_speed = -32768
set $last_x = 0xffffffff
set $last_y = 0xffffffff
set $last_heading = 0xffff

set logging file ../tmp/driving-motion-sequence.tsv
set logging overwrite on
set logging redirect on
set logging enabled on
printf "capture\tticks\trpm\tgear\tspeed\tx\ty\theading\n"
set logging enabled off
set logging overwrite off

# Stop at the same boundary as the Macintosh trap tap: the full-window
# CopyBits while its 512-row source GWorld is still alive.  By presentation
# time the game has disposed that source and only the clipped 320-row Amiga
# display buffer remains.
break copyBits if s_drivingFrameStarted
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-0x3678)
  set $rpm = *(short*)($car+0x44)
  set $gear = *(short*)($car+0x1c)
  set $speed = *(short*)($car+0x1a)
  set $x = *(unsigned int*)$car
  set $y = *(unsigned int*)($car+8)
  set $heading = *(unsigned short*)($car+0x66)
  set $full = *(short*)sourceRect == 0 && *(short*)(sourceRect+2) == 0 && *(short*)(sourceRect+4) == 342 && *(short*)(sourceRect+6) == 512 && *(short*)destinationRect == 0 && *(short*)(destinationRect+2) == 0 && *(short*)(destinationRect+4) == 342 && *(short*)(destinationRect+6) == 512
  if $full && $gear == 1 && $speed > 0 && ($rpm != $last_rpm || $gear != $last_gear || $speed != $last_speed || $x != $last_x || $y != $last_y || $heading != $last_heading)
    set $i = 0
    while $i < 8
      if s_gworlds[$i].used && sourceBitmap == &s_gworlds[$i].port[2]
        set $captures = $captures+1
        set $last_rpm = $rpm
        set $last_gear = $gear
        set $last_speed = $speed
        set $last_x = $x
        set $last_y = $y
        set $last_heading = $heading
        set logging enabled on
        printf "%u\t%u\t%d\t%d\t%d\t%08x\t%08x\t%u\n", $captures, g_macTicks, $rpm, $gear, $speed, $x, $y, $heading
        set logging enabled off
        set $rows = *(short*)(&s_gworlds[$i].pixMap[10])-*(short*)(&s_gworlds[$i].pixMap[6])
        set $stride = *(unsigned short*)(&s_gworlds[$i].pixMap[4])&0x3fff
        eval "dump binary memory ../tmp/driving-motion-source-%u.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$rows*$stride", $captures
        printf "captured moving state %u tick=%u rpm=%d speed=%d pos=($%08x,$%08x) heading=%u\n", $captures, g_macTicks, $rpm, $speed, $x, $y, $heading
      end
      set $i = $i+1
    end
  end
  if $captures >= 40
    detach
    quit
  end
  continue
end

continue
