# Sample interrupted PCs only after the first frame enters its dynamic renderer.
# Stop at the next loop entry if the complete frame is reached.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $active = 0
set $samples = 0
set $start_tick = 0
set $last_tick = 0

break *(s_segments[1].begin+0x286a)
commands 1
  silent
  set $active = 1
  set $start_tick = g_macTicks
  set $last_tick = g_macTicks
  enable 2
  enable 3
  disable 1
  printf "dynamic sampling start tick=%u queued=%u presented=%u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented
  continue
end

break vbiHandler if $active && g_macTicks-$last_tick >= 20
commands 2
  silent
  set $last_tick = g_macTicks
  set $samples = $samples+1
  printf "dynamic sample[%u] elapsed=%u active=%u pc=$%08x\n", $samples, g_macTicks-$start_tick, g_macVBLCallbackActive, *(unsigned int*)($sp+34)
  if $samples >= 24
    printf "dynamic sample limit reached\n"
    detach
    quit
  end
  continue
end
disable 2

break *(s_segments[1].begin+0x1fea)
commands 3
  silent
  printf "dynamic frame complete elapsed=%u samples=%u queued=%u presented=%u\n", g_macTicks-$start_tick, $samples, g_macFramesQueued, g_macFramesPresented
  detach
  quit
end
disable 3

continue
