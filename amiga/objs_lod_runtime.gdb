# Trace the original Main+$4DCE model selector.  Each call exposes the live
# object metric and the threshold/flags/shared/model records selected from the
# initialized A5 world.  Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $calls = 0

break *(s_segments[1].begin+0x4dce)
commands
  silent
  set $calls = $calls+1
  set $object = $a0
  set $template = *(unsigned int*)($object+0x12)
  set $lod = *(unsigned int*)($template+4)
  set $metric = *(unsigned int*)($object+0x1e)
  printf "LOD[%u] metric=%u object=$%08x template=$%08x table=$%08x\n", $calls, $metric, $object, $template, $lod
  set $i = 0
  while $i < 4
    printf "  entry[%u] threshold=%d flags=$%04x shared=$%08x model=$%08x\n", $i, *(short*)$lod, *(unsigned short*)($lod+2), *(unsigned int*)($lod+4), *(unsigned int*)($lod+8)
    if *(short*)$lod == -1
      set $i = 4
    else
      set $lod = $lod+12
      set $i = $i+1
    end
  end
  if $calls >= 24
    detach
    quit
  end
  continue
end

continue
