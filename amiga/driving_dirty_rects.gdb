# Report the actual rectangle list handed to C2P for consecutive completed
# driving frames. Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $driving_presentations = 0

break VetteScreen::presentMacFrame if s_drivingFrameStarted
commands
  silent
  set $driving_presentations = $driving_presentations+1
  if $driving_presentations == 1
    continue
  end
  printf "driving presentation=%u tick=%u frames=%u/%u pending=%u rects=%u union=(%d,%d)-(%d,%d)\n", $driving_presentations, g_macTicks, g_macFramesQueued, g_macFramesPresented, s_loudStopScreen->m_framePending, dirtyRectCount, s_dirtyTop, s_dirtyLeft, s_dirtyBottom, s_dirtyRight
  set $i = 0
  while $i < dirtyRectCount
    printf "  rect[%u]=(%d,%d)-(%d,%d)\n", $i, dirtyRects[$i].top, dirtyRects[$i].left, dirtyRects[$i].bottom, dirtyRects[$i].right
    set $i = $i+1
  end
  detach
  quit
end

continue
