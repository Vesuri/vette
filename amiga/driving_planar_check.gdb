# Capture the second completed driving conversion. The second update is the
# first one that may omit a covered pending synchronization rectangle.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1 FILLWATCH=1.
set pagination off
set confirm off
set $drivingConversions = 0

break validateConvertedFrame if s_drivingFrameStarted
commands
  silent
  set $drivingConversions = $drivingConversions + 1
  if $drivingConversions >= 2
    # Optimized parameter locations are not reliable at this breakpoint. Use
    # the stable owners whose values the parameters name.
    dump binary memory ../tmp/driving-planar-chunky.raw s_colorScreen s_colorScreen+81920
    dump binary memory ../tmp/driving-planar.planes s_loudStopScreen->m_back s_loudStopScreen->m_back+98304
    printf "captured driving conversion %u queued=%u presented=%u\n", $drivingConversions, g_macFramesQueued, g_macFramesPresented
    detach
    quit
  end
  continue
end

continue
