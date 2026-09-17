# STAGE B ACCEPTANCE — stop at the visible loud-stop renderer and inspect the facts
# captured by the Line-A handler. Run with:
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=stage_b.gdb ./diag_run.sh 20
set pagination off
set confirm off

tbreak VetteScreen::showLoudStop
continue

printf "\n===== STAGE B =====\n"
printf "state          = %u        (3 = unimplemented-trap loud stop)\n", g_stageBState
printf "jump entries   = %u        (want 509 validated + patched)\n", g_jumpEntryCount
printf "BlockMove calls= %u        (want 49: shipped %%A5Init stream completed)\n", g_blockMoveCount
printf "resources      = %u        (want 572 across application + data forks)\n", g_resourceCount
printf "trap           = $%04X\n", g_trapWord
printf "manager        = %s\n", g_trapManager
printf "routine        = %s\n", g_trapRoutine
printf "selector       = %d        (-1 = not selector-dispatched)\n", g_trapSelector
printf "caller         = segment %u + $%04X\n", g_trapSegment, g_trapOffset
printf "===================\n\n"
detach
quit
