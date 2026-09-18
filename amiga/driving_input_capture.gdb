# Verify the GARAGE_CLICK path's post-setup keypad event and capture its screen.
# Requires a SKIP_INTRO=1 GARAGE_CLICK=1 build.
set pagination off
set confirm off

continue

dump binary memory ../tmp/amiga_driving_input.raw s_colorScreen s_colorScreen+81920
dump binary memory ../tmp/amiga_driving_input.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
printf "\n===== DRIVING INPUT =====\n"
printf "phase=%u (want 12) depth=%u PC=$%08x dirty=(%d,%d)-(%d,%d)\n", s_garageClickPhase, g_stageCDepth, $pc, s_dirtyTop, s_dirtyLeft, s_dirtyBottom, s_dirtyRight
printf "=========================\n\n"
detach
quit
