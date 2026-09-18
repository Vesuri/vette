# Sample the code address interrupted by VERTB during the first driving render.
# The +34 slot is the PC in the saved 68020 exception frame: the live VBI stack
# shows SR=$2009 immediately before it and vector word $006c immediately after.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off
set $samples = 0
set $last_tick = 0

break vbiHandler if s_garageClickPhase >= 9 && g_macTicks-$last_tick >= 30
commands
  silent
  set $last_tick = g_macTicks
  set $samples = $samples + 1
  printf "sample[%u]=$%08x\n", $samples, *(unsigned int*)($sp+34)
  if $samples >= 16
    printf "segments:"
    set $segment = 1
    while $segment <= 10
      printf " %u=[$%08x,$%08x)", $segment, s_segments[$segment].begin, s_segments[$segment].end
      set $segment = $segment + 1
    end
    printf "\n"
    detach
    quit
  end
  continue
end

continue
