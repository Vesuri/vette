set pagination off
set confirm off

# Stop after presentMacFrame has populated the Amiga palette for the rotating
# model update.  Keep this breakpoint in the presentation routine rather than
# on a volatile MacLoader.cpp line number.
break VetteScreen.cpp:337 if s_garageClickPhase >= 6 && s_dirtyTop == 165 && s_dirtyLeft == 177 && s_dirtyBottom == 316 && s_dirtyRight == 505
commands
  silent
  dump binary memory ../tmp/f40_screen.raw s_colorScreen s_colorScreen+81920
  dump binary memory ../tmp/f40_screen.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
  dump binary memory ../tmp/f40_screen.ctab s_windowManagerColors s_windowManagerColors+136
  dump binary memory ../tmp/f40_gworld0.ctab s_gworlds[0].colorTable s_gworlds[0].colorTable+136
  dump binary memory ../tmp/f40_gworld0.raw s_gworlds[0].pixels s_gworlds[0].pixels+133120
  printf "captured post-selection model update\n"
  detach
  quit
end

continue
