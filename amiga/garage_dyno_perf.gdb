# Measure the original garage dynamometer between its real control handler and
# common garage-loop return. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
# GARAGE_DYNO=1. Diagnostic only: probe register reads perturb shipping timing.
set pagination off
set confirm off

break *s_segments[2].begin+0x0dc0
commands
  silent
  set $start_field = g_vbiCount
  set $start_tick = g_macTicks
  set $start_queued = g_macFramesQueued
  set $start_presented = g_macFramesPresented
  set $start_c2p_frames = g_probeC2PFrames
  set $start_c2p_rects = g_probeC2PRects
  set $start_c2p_pixels = g_probeC2PPixels
  set $start_map_identity = g_probeCopyMapIdentity
  set $start_map_hits = g_probeCopyMapHits
  set $start_map_misses = g_probeCopyMapMisses
  set $start_copy_ticks = g_probeCopyBitsTicks
  set $start_copy_calls = g_probeCopyBitsCalls
  continue
end

break *s_segments[2].begin+0x14d8
commands
  silent
  printf "garage dyno fields=%u macTicks=%u frames=%u/%u gauge=%d\n", g_vbiCount-$start_field, g_macTicks-$start_tick, g_macFramesQueued-$start_queued, g_macFramesPresented-$start_presented, *(signed short*)($a5-21696)
  printf "c2p frames=%u rects=%u pixels=%u\n", g_probeC2PFrames-$start_c2p_frames, g_probeC2PRects-$start_c2p_rects, g_probeC2PPixels-$start_c2p_pixels
  printf "copy maps identity=%u hits=%u misses=%u\n", g_probeCopyMapIdentity-$start_map_identity, g_probeCopyMapHits-$start_map_hits, g_probeCopyMapMisses-$start_map_misses
  printf "copyBits beam-units=%u calls=%u\n", g_probeCopyBitsTicks-$start_copy_ticks, g_probeCopyBitsCalls-$start_copy_calls
  detach
  quit
end

continue
