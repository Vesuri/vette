# Measure the same assembly C2P rectangles writing chip RAM and fast RAM.
# The host interrupts a deterministic moving-driving run after enough samples.
set pagination off
set confirm off

continue

printf "C2P split frames=%u rects=%u pixels=%u\n", g_c2pSplitFrames, g_c2pSplitRects, g_c2pSplitPixels
printf "chip ticks=%u fast ticks=%u chip/fast=%.3f\n", g_c2pSplitChipTicks, g_c2pSplitFastTicks, 1.0*g_c2pSplitChipTicks/g_c2pSplitFastTicks
printf "pixels/frame=%.1f coverage=%.3f%% rects/frame=%.3f\n", 1.0*g_c2pSplitPixels/g_c2pSplitFrames, 100.0*g_c2pSplitPixels/(g_c2pSplitFrames*163840.0), 1.0*g_c2pSplitRects/g_c2pSplitFrames
detach
quit
