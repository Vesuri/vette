# Resolve the key chart's Automatic Shift key A (Mac virtual $00) through
# Main's live 128-key dispatch table.  Requires SKIP_INTRO=1 GARAGE_CLICK=1
# INPUT_PROBE_EVENT_RAW_KEY=0x20 (Amiga A).
set pagination off
set confirm off

# At Main+$2E04 D0 is the virtual-key index times four.  A is entry zero.
break *(s_segments[1].begin+0x2e04) if $d0 == 0
commands
  silent
  set $target = *(unsigned int*)($a3+2)
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "A dispatch tick=%u stub=$%08x target=$%08x driving=%u frames=%u/%u\n", g_macTicks, $a3, $target, s_drivingFrameStarted, g_macFramesQueued, g_macFramesPresented
  printf "automatic-shift gate=%d state=%d car=$%08x\n", *(short*)(s_currentA5-14740), *(short*)($car+46), $car
  x/2i $a3
  set $i = 0
  while $i < 11
    if $target >= (unsigned int)s_segments[$i].begin && $target < (unsigned int)s_segments[$i].end
      printf "A handler segment=%u offset=$%x\n", $i, $target-(unsigned int)s_segments[$i].begin
    end
    set $i = $i+1
  end
  detach
  quit
end

continue
