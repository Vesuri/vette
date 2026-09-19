# The live copper-list pointer/palette publication must happen in vertical
# blank, never inside Vette's raster window (lines 76..267).
# Run a plain or scripted build; this stops after 32 presented frames or on the
# first violation.
set pagination off
set confirm off

break VetteScreen::presentMacFrame if g_beamPresents >= 32 || g_beamPresentsLate != 0
continue

printf "presents=%u late(in display)=%u\n", g_beamPresents, g_beamPresentsLate
printf "beam line at publication: last=%u min=%u max=%u (display window 76..267)\n", g_beamPresentLine, g_beamPresentMin, g_beamPresentMax
detach
quit
