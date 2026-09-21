# Capture the completed Amiga frames that share a full game state with the
# saved Macintosh reference, rather than pairing by presentation ordinal.
# The Macintosh-only RPM 15 and 18 construction states remain visible as
# reference-only coverage in the comparator.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_RAW_KEY=62.
set pagination off
set confirm off
set $captured11 = 0
set $captured23 = 0

set logging file ../tmp/driving-sequence.tsv
set logging overwrite on
set logging redirect on
set logging enabled on
printf "capture\tticks\trpm\tgear\tspeed\tx\ty\theading\n"
set logging enabled off
set logging overwrite off

break VetteScreen::presentMacFrame if s_drivingFrameStarted
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-0x3678)
  set $rpm = *(short*)($car+0x44)
  set $gear = *(short*)($car+0x1c)
  set $speed = *(short*)($car+0x1a)
  set $x = *(unsigned int*)$car
  set $y = *(unsigned int*)($car+8)
  set $heading = *(unsigned short*)($car+0x66)
  set $capture = 0
    if !$captured11 && $rpm == 11 && $gear == 0 && $speed == 0 && $x == 0x3140 && $y == 0x17e0 && $heading == 12288
      set $capture = 1
      set $captured11 = 1
    end
    if !$captured23 && $rpm == 23 && $gear == 0 && $speed == 0 && $x == 0x3140 && $y == 0x17e0 && $heading == 12288
      set $capture = 4
      set $captured23 = 1
    end
    if $capture
      set logging enabled on
      printf "%u\t%u\t%d\t%d\t%d\t%08x\t%08x\t%u\n", $capture, g_macTicks, $rpm, $gear, $speed, $x, $y, $heading
      set logging enabled off
      set $i = 0
      while $i < 8
        if s_gworlds[$i].used && *(short*)(&s_gworlds[$i].pixMap[6]) == 0 && *(short*)(&s_gworlds[$i].pixMap[8]) == 0 && *(short*)(&s_gworlds[$i].pixMap[10]) == 342 && *(short*)(&s_gworlds[$i].pixMap[12]) == 512
          set $rows = *(short*)(&s_gworlds[$i].pixMap[10])-*(short*)(&s_gworlds[$i].pixMap[6])
          set $stride = *(unsigned short*)(&s_gworlds[$i].pixMap[4])&0x3fff
          if $capture == 1
            dump binary memory ../tmp/driving-copy-source-1.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$rows*$stride
          end
          if $capture == 4
            dump binary memory ../tmp/driving-copy-source-4.raw s_gworlds[$i].pixels s_gworlds[$i].pixels+$rows*$stride
          end
        end
        set $i = $i+1
      end
      printf "captured reference state %u at tick=%u rpm=%d\n", $capture, g_macTicks, $rpm
    end
  if $captured11 && $captured23
    detach
    quit
  end
  continue
end

continue
