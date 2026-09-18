# Capture the settled game surface after the development-only garage click.
# Run with a SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1 build:
#   GDBSCRIPT=garage_capture.gdb ./diag_run.sh 20
set pagination off
set confirm off

continue

dump binary memory ../tmp/amiga_garage_accept.raw s_colorScreen s_colorScreen+81920
dump binary memory ../tmp/amiga_garage_accept.palette s_loudStopScreen->m_nextPalette s_loudStopScreen->m_nextPalette+16
printf "captured settled post-ACCEPT surface at Stage C depth %u\n", g_stageCDepth
detach
quit
