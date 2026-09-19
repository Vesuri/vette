# Sample interrupted PCs only between the last initial DrawPicture and the
# dynamic-renderer gate of the first driving frame.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $active = 0
set $samples = 0
set $start_tick = 0
set $last_tick = 0

break *(s_segments[1].begin+0x256c)
commands 1
  silent
  set $active = 1
  set $start_tick = g_macTicks
  set $last_tick = g_macTicks
  printf "post-picture sampling start tick=%u\n", g_macTicks
  disable 1
  continue
end

break vbiHandler if $active && g_macTicks-$last_tick >= 20
commands 2
  silent
  set $last_tick = g_macTicks
  set $samples = $samples+1
  printf "post-picture sample[%u] elapsed=%u active=%u task=$%08x pc=$%08x\n", $samples, g_macTicks-$start_tick, g_macVBLCallbackActive, g_macVBLCallbackTask, *(unsigned int*)($sp+34)
  continue
end

break *(s_segments[1].begin+0x286a)
commands 3
  silent
  printf "post-picture sampling end elapsed=%u samples=%u\n", g_macTicks-$start_tick, $samples
  printf "segments:"
  set $segment = 1
  while $segment <= 10
    printf " %u=[$%08x,$%08x)", $segment, s_segments[$segment].begin, s_segments[$segment].end
    set $segment = $segment+1
  end
  printf "\n"
  detach
  quit
end

continue
