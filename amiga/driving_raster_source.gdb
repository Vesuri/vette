# Capture the source supplied to the 78x84-byte Traffic raster that paints the
# first driving frame's rear-view scene.  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break *(s_segments[6].begin+0x67a4)
commands 1
  silent
  if s_garageClickPhase >= 9 && $d1 == 78 && $d2 == 21 && $d3 == 344 && $d4 == 0
    set $caller = *(unsigned int*)$sp
    printf "Traffic+67A4 mirror source tick=%u caller=$%08x source=$%08x rows=%u rowBytes=%u destination=$%08x\n", g_macTicks, $caller, $a1, $d1, 260, *(unsigned int*)($a5-0x4fda)
    set $i = 0
    while $i < 11
      if $caller >= (unsigned int)s_segments[$i].begin && $caller < (unsigned int)s_segments[$i].end
        printf "  caller segment=%u offset=$%x\n", $i, $caller-(unsigned int)s_segments[$i].begin
      end
      set $i = $i+1
    end
    dump binary memory ../tmp/driving-mirror-source.raw $a1 $a1+20280
    detach
    quit
  end
  continue
end

continue
