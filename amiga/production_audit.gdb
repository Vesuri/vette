# Production-path audit: no skip, scripted UI, checkpoint, or probe-only game
# behavior. Stop on the first loud boundary, or after the original intro has
# produced a substantial sequence of live frames without one.
set pagination off
set confirm off
set $loud = 0

break VetteScreen::showLoudStop
commands
  silent
  set $loud = 1
  printf "production-audit FAIL loud stop trap=$%04x %s/%s caller=%u+$%x tick=%u frames=%u\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset, g_macTicks, g_macFramesPresented
  detach
  quit
end

break VetteScreen::presentMacFrame if g_macTicks >= 1200
commands
  silent
  printf "production-audit PASS tick=%u frames=%u depth=%u resources=%u jumps=%u\n", g_macTicks, g_macFramesPresented, g_stageCDepth, g_resourceCount, g_jumpEntryCount
  detach
  quit
end

continue
