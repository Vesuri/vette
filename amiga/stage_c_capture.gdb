# Capture the game-rendered intro at the first Button poll.  The reference trace
# establishes that the intro is complete before this transition.
set pagination off
set confirm off

watch g_stageCDepth
commands
  silent
  if g_stageCDepth < 64
    continue
  end
end
continue

dump binary memory ../tmp/amiga_intro.raw s_colorScreen s_colorScreen+81920
dump binary memory ../tmp/amiga_intro.planes s_loudStopScreen->m_back s_loudStopScreen->m_back+98304
dump binary memory ../tmp/amiga_intro.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
tbreak VetteScreen::vbiUpdate
continue
finish
dump binary memory ../tmp/amiga_intro.front s_loudStopScreen->m_chip s_loudStopScreen->m_chip+98304
dump binary memory ../tmp/amiga_intro.copper_colors s_loudStopScreen->m_copper+8 s_loudStopScreen->m_copper+24
printf "captured 512x384 display with centred 512x320 Mac framebuffer at Stage C depth %u\n", g_stageCDepth
detach
quit
