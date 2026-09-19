# Validate the Vette-specific equivalent of the inherited fill invariant: after
# dirty-buffer synchronization and C2P, every pixel in the complete planar back
# buffer must decode to the game's current 4-bit chunky surface.  Eight complete
# rows are checked per frame; 320 checked rows are one full-screen audit.
# Requires FILLWATCH=1; never use this diagnostic build for timing.
set pagination off
set confirm off

break VetteScreen::presentMacFrame if g_fillWatchRows >= 320 || g_fillBadFrames != 0
continue

printf "validated frames=%u rows=%u bad frames=%u bad pixels=%u\n", g_fillWatchFrames, g_fillWatchRows, g_fillBadFrames, g_fillBadPixels
printf "first mismatch: (%u,%u) expected=%u actual=%u\n", g_fillBadX, g_fillBadY, g_fillBadExpected, g_fillBadActual
detach
quit
