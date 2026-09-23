# Measure the complete authored garage departure animation without taking its
# Button skip branch. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break *s_segments[2].begin+0x0fc8
commands
  silent
  set s_garageTransitionSkipped = 1
  set g_probeCopyTraceCount = 0
  set g_probeCopyTraceEnabled = 1
  printf "departure mode=%d\n", *(signed short*)($a5-21566)
  set $start_field = g_vbiCount
  set $start_tick = g_macTicks
  set $start_queued = g_macFramesQueued
  set $start_presented = g_macFramesPresented
  set $start_c2p_frames = g_probeC2PFrames
  set $start_c2p_rects = g_probeC2PRects
  set $start_c2p_pixels = g_probeC2PPixels
  set $start_copy_ticks = g_probeCopyBitsTicks
  set $start_copy_calls = g_probeCopyBitsCalls
  set $start_copy0_ticks = g_probeCopyModeTicks[0]
  set $start_copy0_calls = g_probeCopyModeCalls[0]
  set $start_copy1_ticks = g_probeCopyModeTicks[1]
  set $start_copy1_calls = g_probeCopyModeCalls[1]
  set $start_copy3_ticks = g_probeCopyModeTicks[3]
  set $start_copy3_calls = g_probeCopyModeCalls[3]
  set $start_delay_calls = g_probeDelayCalls
  set $start_delay_requested = g_probeDelayRequested
  set $start_block_ticks = g_probeBlockMoveTicks
  set $start_block_calls = g_probeBlockMoveCalls
  set $start_picture_ticks = g_probeDrawPictureTicks
  set $start_picture_calls = g_probeDrawPictureCalls
  continue
end

break *s_segments[2].begin+0x11c6
commands
  silent
  set g_probeCopyTraceEnabled = 0
  printf "moving destination final=(%d,%d)-(%d,%d)\n", *(signed short*)($a5-21758), *(signed short*)($a5-21756), *(signed short*)($a5-21754), *(signed short*)($a5-21752)
  printf "garage departure fields=%u macTicks=%u frames=%u/%u\n", g_vbiCount-$start_field, g_macTicks-$start_tick, g_macFramesQueued-$start_queued, g_macFramesPresented-$start_presented
  printf "c2p frames=%u rects=%u pixels=%u\n", g_probeC2PFrames-$start_c2p_frames, g_probeC2PRects-$start_c2p_rects, g_probeC2PPixels-$start_c2p_pixels
  printf "copyBits beam-units=%u calls=%u\n", g_probeCopyBitsTicks-$start_copy_ticks, g_probeCopyBitsCalls-$start_copy_calls
  printf "  srcCopy=%u/%u srcOr=%u/%u srcBic=%u/%u\n", g_probeCopyModeTicks[0]-$start_copy0_ticks, g_probeCopyModeCalls[0]-$start_copy0_calls, g_probeCopyModeTicks[1]-$start_copy1_ticks, g_probeCopyModeCalls[1]-$start_copy1_calls, g_probeCopyModeTicks[3]-$start_copy3_ticks, g_probeCopyModeCalls[3]-$start_copy3_calls
  printf "Delay calls=%u requestedTicks=%u\n", g_probeDelayCalls-$start_delay_calls, g_probeDelayRequested-$start_delay_requested
  printf "BlockMove beam-units=%u calls=%u\n", g_probeBlockMoveTicks-$start_block_ticks, g_probeBlockMoveCalls-$start_block_calls
  printf "DrawPicture beam-units=%u calls=%u\n", g_probeDrawPictureTicks-$start_picture_ticks, g_probeDrawPictureCalls-$start_picture_calls
  set $picture = $start_picture_calls
  while $picture < g_probeDrawPictureCalls
    set $slot = $picture & 63
    printf "  PICT %d rect=(%d,%d)-(%d,%d) ticks=%u\n", g_probeDrawPictureTrace[$slot][0], g_probeDrawPictureTrace[$slot][1], g_probeDrawPictureTrace[$slot][2], g_probeDrawPictureTrace[$slot][3], g_probeDrawPictureTrace[$slot][4], g_probeDrawPictureTraceTicks[$slot]
    set $picture = $picture + 1
  end
  set $copy = 0
  while $copy < g_probeCopyTraceCount
    printf "  Copy mode=%d src=(%d,%d)-(%d,%d) dst=(%d,%d)-(%d,%d) same=%d dstScreen=%d srcScreen=%d\n", g_probeCopyTrace[$copy][0], g_probeCopyTrace[$copy][1], g_probeCopyTrace[$copy][2], g_probeCopyTrace[$copy][3], g_probeCopyTrace[$copy][4], g_probeCopyTrace[$copy][5], g_probeCopyTrace[$copy][6], g_probeCopyTrace[$copy][7], g_probeCopyTrace[$copy][8], g_probeCopyTrace[$copy][9], g_probeCopyTrace[$copy][10], g_probeCopyTrace[$copy][11]
    set $copy = $copy + 1
  end
  detach
  quit
end

continue
