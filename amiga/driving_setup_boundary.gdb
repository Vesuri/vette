# Measure from the first driving VBL callback to the game's next SystemTask,
# which is immediately before its GetNextEvent loop.  This is the stable end
# of first-frame road setup, unlike a scan of the surface under construction.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $start_tick = 0xffffffff

break *vette_user_vbl_trampoline+38 if s_garageClickPhase >= 9 && $start_tick == 0xffffffff
commands 1
  silent
  set $start_tick = g_macTicks
  continue
end

break vetteLineADispatch if $start_tick != 0xffffffff && *(unsigned short*)frame == 0xa9b4
commands 2
  silent
  printf "driving setup boundary ticks=%u queued=%u presented=%u controls=(-20464:%d,-20462:%d)\n", g_macTicks-$start_tick, g_macFramesQueued, g_macFramesPresented, *(short*)(s_currentA5-20464), *(short*)(s_currentA5-20462)
  detach
  quit
end

continue
