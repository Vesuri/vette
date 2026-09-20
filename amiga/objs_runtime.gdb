# Capture the A5 model-ID and descriptor-pointer tables after Initialize has
# loaded OBJS, at the gate to the first dynamic driving render. Requires a
# SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off

tbreak *(s_segments[1].begin+0x286a)
commands
  silent
  printf "OBJS runtime A5=$%08x id_table=$%08x descriptor_table=$%08x\n", $a5, $a5-0x7614, $a5-0x5e06
  dump binary memory ../tmp/objs_runtime_globals.raw $a5-31272 $a5
  set $i = 0
  while *(short*)($a5-0x7614+$i*2) != -1
    printf "model[%u] id=%d descriptor=$%08x\n", $i, *(short*)($a5-0x7614+$i*2), *(unsigned int*)($a5-0x5e06+$i*4)
    set $i = $i+1
  end
  printf "OBJS runtime models=%u\n", $i
  detach
  quit
end

continue
