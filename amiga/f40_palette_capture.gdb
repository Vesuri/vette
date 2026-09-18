set pagination off
set confirm off

break MacLoader.cpp:3609 if s_dirtyTop == 165 && s_dirtyLeft == 177 && s_dirtyBottom == 316 && s_dirtyRight == 505
commands
  silent
  if $capture == 0
    dump binary memory ../tmp/porsche_screen.raw s_colorScreen s_colorScreen+81920
    dump binary memory ../tmp/porsche_screen.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
    set $capture = 1
    continue
  end
  dump binary memory ../tmp/f40_screen.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/f40_screen.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  printf "captured post-selection model update\n"
  detach
  quit
end

set $capture = 0
continue
