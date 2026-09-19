# Resolve Macintosh virtual P ($23) through Main's live 128-key dispatch table.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_EVENT_RAW_KEY=0x19 (P).
set pagination off
set confirm off

# At Main+$2E04 D0 is the adjusted virtual-key index times four and A3 is the
# selected handler.  Virtual keys >=8 are decremented, so P becomes 34*4=136.
break *(s_segments[1].begin+0x2e04) if $d0 == 136
commands
  silent
  set $target = *(unsigned int*)($a3+2)
  printf "P dispatch tick=%u stub=$%08x target=$%08x driving=%u frames=%u/%u\n", g_macTicks, $a3, $target, s_drivingFrameStarted, g_macFramesQueued, g_macFramesPresented
  x/2i $a3
  set $i = 0
  while $i < 11
    if $target >= (unsigned int)s_segments[$i].begin && $target < (unsigned int)s_segments[$i].end
      printf "P handler segment=%u offset=$%x\n", $i, $target-(unsigned int)s_segments[$i].begin
    end
    set $i = $i+1
  end
  detach
  quit
end

continue
