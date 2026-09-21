# Trace the shipped Traffic byte-raster inputs that produce the first
# multi-frame differential in the RPM digits at packed pixels (324..331,310).
# Arm only after the first synchronized full-window copy so setup drawing
# cannot satisfy it. Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $armed = 0
set $hits = 0

break copyBits
commands 1
  silent
  if !$armed && *(short*)sourceRect == 0 && *(short*)(sourceRect+2) == 0 && *(short*)(sourceRect+4) == 342 && *(short*)(sourceRect+6) == 512 && *(short*)destinationRect == 0 && *(short*)(destinationRect+2) == 0 && *(short*)(destinationRect+4) == 342 && *(short*)(destinationRect+6) == 512
    set $i = 0
    while $i < 8
      if s_gworlds[$i].used && sourceBitmap == &s_gworlds[$i].port[2]
        set $watch_addr = s_gworlds[$i].pixels + 310*260 + 162
        printf "arming Traffic dashboard writer at $%08x, GWorld slot=%u tick=%u presented=%u\n", $watch_addr, $i, g_macTicks, g_macFramesPresented
        set $armed = 1
        disable 1
        enable 2
      end
      set $i = $i+1
    end
  end
  continue
end

# Traffic+$67E8 copies one byte and advances A2/A3; +$67EA is therefore the
# first stable point at which both the written destination and source byte can
# be reported without a hardware-watchpoint trace artefact.
break *(s_segments[6].begin+0x67ea)
commands 2
  silent
  if $a2 > $watch_addr && $a2 <= $watch_addr+4
    set $hits = $hits+1
    set $return = *(unsigned int*)$sp
    printf "dashboard write hit=%u tick=%u presented=%u caller=Traffic+$%x state[-340C]=%d dst=$%08x src=$%08x value=$%02x d0=$%08x d1=$%08x d2=$%08x d3=$%08x d4=$%08x a0=$%08x a1=$%08x\n", $hits, g_macTicks, g_macFramesPresented, $return-(unsigned int)s_segments[6].begin, *(short*)(s_currentA5-0x340c), $a2-1, $a3-1, *(unsigned char*)($a2-1), $d0, $d1, $d2, $d3, $d4, $a0, $a1
    if $hits >= 32
      detach
      quit
    end
  end
  continue
end
disable 2

continue
