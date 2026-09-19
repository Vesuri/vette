# Capture the original FRED state that determines the first driving viewport
# base fill height.  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $calls = 0

break *(s_segments[7].begin+0x00fc)
commands 1
  silent
  if s_garageClickPhase >= 9
    set $calls = $calls+1
    printf "FRED+00FC[%u] tick=%u A5=$%08x height=$%04x subtract20=$%04x viewportBottom=$%04x stride=%u buffers=$%08x/$%08x/$%08x gworld0=$%08x\n", $calls, g_macTicks, $a5, *(unsigned short*)($a5-0x3a7a), *(unsigned short*)($a5-0x03c4), *(unsigned short*)($a5-0x0350), *(unsigned int*)($a5-0x03c0), *(unsigned int*)($a5-0x4fe2), *(unsigned int*)($a5-0x4fde), *(unsigned int*)($a5-0x4fda), s_gworlds[0].pixels
  end
  continue
end

break *(s_segments[7].begin+0x012c)
commands 2
  silent
  if s_garageClickPhase >= 9
    printf "FRED+012C tick=%u fillHeight=%u width=%u origin=(%u,%u) pen=$%08x\n", g_macTicks, $d1, $d2, $d3, $d4, $d7
    detach
    quit
  end
  continue
end

continue
