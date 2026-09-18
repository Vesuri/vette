# Count indexed PICT raster opcodes and decoded bytes during the same interval
# used by driving_cadence.gdb.  This intentionally counts calls rather than
# printing each one, keeping debugger disturbance bounded.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $calls4 = 0
set $calls8 = 0
set $bytes4 = 0
set $bytes8 = 0
set $start_tick = 0
set $target_tick = 0xffffffff

break drawIndexedPictureBits if s_garageClickPhase >= 9
commands 1
  silent
  set $row_bytes = (*(unsigned short*)(picture+offset))&0x3fff
  set $height = *(short*)(picture+offset+6)-*(short*)(picture+offset+2)
  if *(unsigned short*)(picture+offset+28) == 4
    set $calls4 = $calls4+1
    set $bytes4 = $bytes4+($row_bytes*$height)
  else
    set $calls8 = $calls8+1
    set $bytes8 = $bytes8+($row_bytes*$height)
    if $row_bytes*$height >= 8192
      printf "heavy8 picture=$%08x size=%u offset=%u geometry=%ux%u decoded=%u target=(%d,%d)-(%d,%d)\n", picture, size, offset, $row_bytes, $height, $row_bytes*$height, *(short*)targetRect, *(short*)(targetRect+2), *(short*)(targetRect+4), *(short*)(targetRect+6)
    end
  end
  continue
end

break *vette_user_vbl_trampoline+38 if s_garageClickPhase >= 9 && $target_tick == 0xffffffff
commands 2
  silent
  set $start_tick = g_macTicks
  set $target_tick = $start_tick+300
  continue
end

break *vette_user_vbl_trampoline+38 if $target_tick != 0xffffffff && g_macTicks >= $target_tick
commands 3
  silent
  printf "driving PICT progress ticks=%u 4-bit=%u/%uB 8-bit=%u/%uB controls=%d\n", g_macTicks-$start_tick, $calls4, $bytes4, $calls8, $bytes8, *(short*)(s_currentA5-20462)
  detach
  quit
end

continue
