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
set $last_physics_x = 0xffffffff
set $last_physics_y = 0xffffffff
set $last_objects = 0xffff

set logging file ../tmp/driving-motion-sequence.tsv
set logging overwrite on
set logging redirect on
set logging enabled on
printf "capture\tticks\titeration\ttraffic_phase\trpm\tgear\tspeed\tx\ty\theading\tphysics_x\tphysics_y\tobjects\n"
set logging enabled off
set logging overwrite off

# Diagnostic builds call this no-op only after a successful full-window
# driving CopyBits, with the original source PixMap still alive.
break vetteMotionCaptureBoundary
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-0x3678)
  set $rpm = *(short*)($car+0x44)
  set $gear = *(short*)($car+0x1c)
  set $speed = *(short*)($car+0x1a)
  set $x = *(unsigned int*)$car
  set $y = *(unsigned int*)($car+8)
  set $heading = *(unsigned short*)($car+0x66)
  set $physics_x = *(unsigned int*)($car+0x6e)
  set $physics_y = *(unsigned int*)($car+0x72)
  set $objects = *(unsigned short*)(s_currentA5-0x3696)
  if $gear == 1 && $speed > 0 && ($rpm != $last_rpm || $gear != $last_gear || $speed != $last_speed || $x != $last_x || $y != $last_y || $heading != $last_heading || $physics_x != $last_physics_x || $physics_y != $last_physics_y || $objects != $last_objects)
        set $captures = $captures+1
        set $last_rpm = $rpm
        set $last_gear = $gear
        set $last_speed = $speed
        set $last_x = $x
        set $last_y = $y
        set $last_heading = $heading
        set $last_physics_x = $physics_x
        set $last_physics_y = $physics_y
        set $last_objects = $objects
        set logging enabled on
        printf "%u\t%u\t%u\t%u\t%d\t%d\t%d\t%08x\t%08x\t%u\t%08x\t%08x\t%u\n", $captures, g_macTicks, g_macDrivingIterations, g_macDrivingCallbacks, $rpm, $gear, $speed, $x, $y, $heading, $physics_x, $physics_y, $objects
        set logging enabled off
        set $world = 0
        while $world < 8
          if s_gworlds[$world].used && sourceBitmap == &s_gworlds[$world].port[2]
            set $stride = *(unsigned short*)(&s_gworlds[$world].pixMap[4])&0x3fff
            set $rows = *(short*)(&s_gworlds[$world].pixMap[10])-*(short*)(&s_gworlds[$world].pixMap[6])
            eval "dump binary memory ../tmp/driving-motion-source-%u.raw s_gworlds[$world].pixels s_gworlds[$world].pixels+$rows*$stride", $captures
          end
          set $world = $world+1
        end
        eval "dump binary memory ../tmp/driving-motion-globals-%u.bin s_currentA5-31272 s_currentA5", $captures
        eval "dump binary memory ../tmp/driving-motion-car-%u.bin $car $car+0xc8", $captures
        set $object_count = *(unsigned short*)(s_currentA5-0x3696)
        set $object_end = *(unsigned int*)(s_currentA5-0x367c)
        set $object_index = 0
        while $object_index < $object_count && $object_index < 32
          set $object = *(unsigned int*)($object_end-$object_count*4+$object_index*4)
          eval "dump binary memory ../tmp/driving-motion-object-%u-%u.bin $object $object+0xc8", $captures, $object_index
          set $object_index = $object_index+1
        end
        printf "captured moving state %u tick=%u rpm=%d speed=%d pos=($%08x,$%08x) heading=%u\n", $captures, g_macTicks, $rpm, $speed, $x, $y, $heading
  end
  if $captures >= 40
    detach
    quit
  end
  continue
end

continue
