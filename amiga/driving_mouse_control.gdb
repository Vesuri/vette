# Physical mouse end-to-end trace.  Requires
# SKIP_INTRO=1 GARAGE_CLICK=1 MOUSE_CONTROL_PROBE=1 PROBES=1.
set pagination off
set confirm off
set $mode_seen = 0
set $move_seen = 0
set $button_seen = 0
set $dispatch_seen = 0

# Main has selected the active steering callback from the four shipped modes.
break *(s_segments[1].begin+0x2c54)
commands
  silent
  if !$mode_seen
    set $mode_seen = 1
    printf "mouse-mode keyboard=%u mouse=%u joystick=%u alternate=%u callback=$%08x currentA5=$%08x shadowA5=$%08x\n", *(unsigned short*)($a5-0x5312), *(unsigned short*)($a5-0x5316), *(unsigned short*)($a5-0x5314), *(unsigned short*)($a5-0x5310), $a0, $a5, *(unsigned int*)($a5-31292)
  end
  continue
end

# Main's post-countdown Mouse-mode call through jump-table export 251.
break *(s_segments[1].begin+0x275c)
commands
  silent
  if !$dispatch_seen
    set $dispatch_seen = 1
    printf "mouse-dispatch tick=%u start=%d target=$%08x expected=$%08x\n", g_macTicks, *(signed short*)($a5-0x5344), *(unsigned int*)($a5+0x7fc), s_segments[6].begin+0x6d24
  end
  continue
end

# End of the original Mouse steering callback, after it has translated Mouse.h
# into the game's left/right and signed-steering globals.
break *(s_segments[1].begin+0x2bbc)
commands
  silent
  if !$move_seen
    # Isolate the original consumer from host delivery with a known off-centre
    # Mouse.h value.  The exit breakpoint below records the resulting controls.
    set *(short*)(s_currentA5-31274) = 400
  end
  continue
end

break *(s_segments[1].begin+0x2c18)
commands
  silent
  if !$move_seen && *(signed short*)(s_currentA5-31274) != 200
    set $move_seen = 1
    printf "mouse-steer host=(%d,%d) joy=$%04x shadow=(v=%d,h=%d) left=%d right=%d signed=%d callbackA5=$%08x\n", s_mouseX, s_mouseY, *(unsigned short*)0xdff00a, *(signed short*)(s_currentA5-31276), *(signed short*)(s_currentA5-31274), *(signed short*)(s_currentA5-0x4ff0), *(signed short*)(s_currentA5-0x4fee), *(signed short*)(s_currentA5-0x33fe), $a5
  end
  if $move_seen && $button_seen
    detach
    quit
  end
  continue
end

# End of the original mouse-button accelerator callback.
break *(s_segments[6].begin+0x6d04)
commands
  silent
  if !$button_seen
    set *(unsigned char*)(s_currentA5-31288) = 0
  end
  continue
end

break *(s_segments[6].begin+0x6d20)
commands
  silent
  if !$button_seen && *(unsigned char*)(s_currentA5-31288) == 0
    set $button_seen = 1
    set $car = *(unsigned int*)(s_currentA5-0x3678)
    printf "mouse-button-internal shadow=$%02x throttle=%d brake=%d car=$%08x latch=%d\n", *(unsigned char*)(s_currentA5-31288), *(signed short*)($car+0x20), *(signed short*)($car+0x22), $car, *(signed short*)(s_currentA5-0x2e9c)
  end
  if $move_seen && $button_seen
    detach
    quit
  end
  continue
end

break *(s_segments[6].begin+0x6d24)
commands
  silent
  if !$button_seen
    # Active-low MBState pressed, injected only to isolate this shipped
    # consumer.  Physical delivery is measured separately by pollMacMouse.
    set *(unsigned char*)(s_currentA5-31288) = 0
  end
  continue
end

break *(s_segments[6].begin+0x6d34)
commands
  silent
  if !$button_seen && *(unsigned char*)(s_currentA5-31288) == 0
    set $button_seen = 1
    set $car = *(unsigned int*)(s_currentA5-0x3678)
    printf "mouse-button shadow=$%02x throttle=%d brake=%d car=$%08x\n", *(unsigned char*)(s_currentA5-31288), *(signed short*)($car+0x20), *(signed short*)($car+0x22), $car
  end
  if $move_seen && $button_seen
    detach
    quit
  end
  continue
end

continue

printf "mouse-control ceiling dispatch=%u move=%u button=%u tick=%u start=%d mode=%u shadow=(v=%d,h=%d,button=$%02x)\n", $dispatch_seen, $move_seen, $button_seen, g_macTicks, *(signed short*)(s_currentA5-0x5344), *(unsigned short*)(s_currentA5-0x5316), *(signed short*)(s_currentA5-31276), *(signed short*)(s_currentA5-31274), *(unsigned char*)(s_currentA5-31288)
detach
quit
