# Resolve Macintosh virtual S ($01) through Main's live 128-key dispatch table.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_EVENT_RAW_KEY=0x21 (S).
set pagination off
set confirm off

# At Main+$2E04 D0 is the virtual-key index times four.  S is below the
# table's removed slot 8, so its adjusted index remains 1*4=4.
break *(s_segments[1].begin+0x2e04) if $d0 == 4
commands
  silent
  set $target = *(unsigned int*)($a3+2)
  printf "S dispatch tick=%u stub=$%08x target=$%08x driving=%u frames=%u/%u\n", g_macTicks, $a3, $target, s_drivingFrameStarted, g_macFramesQueued, g_macFramesPresented
  x/2i $a3
  printf "sound flag=%d service-off/on stubs:\n", *(short*)(s_currentA5-14208)
  x/1i s_currentA5+4066
  x/1i s_currentA5+4074
  set $offTarget = *(unsigned int*)(s_currentA5+4068)
  set $onTarget = *(unsigned int*)(s_currentA5+4076)
  set $i = 0
  while $i < 11
    if $target >= (unsigned int)s_segments[$i].begin && $target < (unsigned int)s_segments[$i].end
      printf "S handler segment=%u offset=$%x\n", $i, $target-(unsigned int)s_segments[$i].begin
    end
    if $offTarget >= (unsigned int)s_segments[$i].begin && $offTarget < (unsigned int)s_segments[$i].end
      printf "sound-off service segment=%u offset=$%x\n", $i, $offTarget-(unsigned int)s_segments[$i].begin
    end
    if $onTarget >= (unsigned int)s_segments[$i].begin && $onTarget < (unsigned int)s_segments[$i].end
      printf "sound-on service segment=%u offset=$%x\n", $i, $onTarget-(unsigned int)s_segments[$i].begin
    end
    set $i = $i+1
  end
  detach
  quit
end

continue
