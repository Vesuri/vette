# Snapshot the live state at the runner's wall-time ceiling after the scripted
# garage and vehicle-selector accept path.  A loud stop remains visible because
# its screen and report are captured like any other state.
set pagination off
set confirm off

continue

dump binary memory ../tmp/amiga_post_accept.raw s_colorScreen s_colorScreen+81920
dump binary memory ../tmp/amiga_post_accept.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
printf "\n===== POST-ACCEPT SNAPSHOT =====\n"
printf "PC=$%08x Stage C depth=%u dirty=(%d,%d)-(%d,%d)\n", $pc, g_stageCDepth, s_dirtyTop, s_dirtyLeft, s_dirtyBottom, s_dirtyRight
x/16i $pc-16
printf "================================\n\n"
detach
quit
