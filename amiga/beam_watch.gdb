# The completed inactive Copper list must be installed before line 16, ahead
# of sprite control DMA as well as the bitplane window (lines 76..267).
# Run a plain or scripted build; this stops after 128 field handoffs or on the
# first violation.
set pagination off
set confirm off

break VetteScreen::presentMacFrame if g_beamPresents >= 128 || g_beamPresentsLate != 0
continue

printf "field handoffs=%u late(at/after line 16)=%u\n", g_beamPresents, g_beamPresentsLate
printf "beam line at handoff: last=%u min=%u max=%u\n", g_beamPresentLine, g_beamPresentMin, g_beamPresentMax
if g_beamPresentsLate != 0
  quit 1
end
detach
quit
