# Trace the original course selector's accepted zero-based course number, then
# report the normalized Traffic start state.  Requires
# SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=1..4 PROBES=1.
set pagination off
set confirm off
set $accepted = -1

break *(s_segments[2].begin+0x1776)
commands
  silent
  set $accepted = $d7 & 0xffff
  printf "course-select accepted=%d choice-flags=(%d,%d,%d,%d)\n", $accepted, *(signed short*)(s_currentA5-0x5310), *(signed short*)(s_currentA5-0x5312), *(signed short*)(s_currentA5-0x5316), *(signed short*)(s_currentA5-0x5314)
  continue
end

break *(s_segments[6].begin+0x73c)
commands
  silent
  printf "course-select traffic-setup course=%d long-course=%d multiplayer=%d\n", *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082), *(signed short*)(s_currentA5-0x79de)
  continue
end

break *(s_segments[6].begin+0x794)
commands
  silent
  printf "course-select normalize-entry course=%d d0=$%08x multiplayer=%d\n", *(signed char*)(s_currentA5-0x555a), $d0, *(signed short*)(s_currentA5-0x79de)
  continue
end

break *(s_segments[6].begin+0x79e)
commands
  silent
  printf "course-select single-player-normalize d0=$%08x\n", $d0
  continue
end

break *(s_segments[6].begin+0x7a8)
commands
  silent
  printf "course-select long-normalize course-before=%d d0=$%08x\n", *(signed char*)(s_currentA5-0x555a), $d0
  continue
end

break *(s_segments[6].begin+0x7b4)
commands
  silent
  printf "course-select normalized-branch course=%d long-course=%d d0=$%08x\n", *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082), $d0
  continue
end

break *(s_segments[6].begin+0x7c6)
commands
  silent
  printf "course-select traffic-normalized course=%d long-course=%d start-index=%d clst-variant=%d\n", *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082), $d0 & 0xffff, *(signed short*)(s_currentA5-0x5080)
  continue
end

break *(s_segments[6].begin+0x5602)
commands
  silent
  printf "course-select endpoint-1 course=%d long-course=%d\n", *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082)
  continue
end

break *(s_segments[6].begin+0x59a2)
commands
  silent
  printf "course-select endpoint-0 course=%d long-course=%d\n", *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082)
  continue
end

break *(s_segments[6].begin+0x59c8)
commands
  silent
  printf "course-select endpoint-2 course=%d long-course=%d\n", *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082)
  continue
end

watch s_garageGearPhase
commands
  silent
  if s_garageGearPhase == 1
    set $car = *(unsigned int*)(s_currentA5-13944)
    printf "course-select start accepted=%d course=%d long-course=%d clst-variant=%d world=($%08x,$%08x) cell=(%u,%u)\n", $accepted, *(signed char*)(s_currentA5-0x555a), *(signed short*)(s_currentA5-0x5082), *(signed short*)(s_currentA5-0x5080), *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40)
    detach
    quit
  end
  continue
end

continue
