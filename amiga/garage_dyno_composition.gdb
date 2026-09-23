# Same fixture as garage_dyno_perf.gdb, but diagnostic presentation bypasses
# C2P to isolate the original chunky composition cost.
set pagination off
set confirm off

break *s_segments[2].begin+0x0dc0
commands
  silent
  set $start_field = g_vbiCount
  set $start_tick = g_macTicks
  set $start_map_identity = g_probeCopyMapIdentity
  set $start_map_hits = g_probeCopyMapHits
  set $start_map_misses = g_probeCopyMapMisses
  set $start_copy_ticks = g_probeCopyBitsTicks
  set $start_copy_calls = g_probeCopyBitsCalls
  set g_probeSkipC2P = 1
  continue
end

break *s_segments[2].begin+0x14d8
commands
  silent
  set g_probeSkipC2P = 0
  printf "garage dyno composition-only fields=%u macTicks=%u gauge=%d\n", g_vbiCount-$start_field, g_macTicks-$start_tick, *(signed short*)($a5-21696)
  printf "copy maps identity=%u hits=%u misses=%u\n", g_probeCopyMapIdentity-$start_map_identity, g_probeCopyMapHits-$start_map_hits, g_probeCopyMapMisses-$start_map_misses
  printf "copyBits beam-units=%u calls=%u\n", g_probeCopyBitsTicks-$start_copy_ticks, g_probeCopyBitsCalls-$start_copy_calls
  detach
  quit
end

continue
