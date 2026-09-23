# STAGE A ACCEPTANCE — did the display come up, in the mode that was asked for, showing
# the bytes that were meant to be there?
#
# ⚠⚠ FS-UAE HAS NO HEADLESS SCREENSHOT, so the port cannot be verified here the way the
# Macintosh reference is (MAME dumps its framebuffer).  What replaces the picture is this:
# the program records what it DID.  Production startup is deliberately black: captured
# emulator framebuffers are not linked into the executable.  The game-rendered pixel path
# is verified separately by stage_c_capture.gdb and verify_stage_c_intro.py.
#
# Run:
#   EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=stage_a.gdb ./diag_run.sh 20
#
# ⚠ A gdb script ABORTS THE WHOLE FILE at the first unknown symbol.  If this prints only
# its header, suspect a renamed global (and PROBE_SYMS), not a dead probe.
set pagination off
set confirm off

# ⚠⚠ THE PROGRAM IS STOPPED AT ENTRY WHEN THIS SCRIPT STARTS.  diag_run.sh passes
# --remote_debugger_trigger=Vette, so FS-UAE halts at program load and gdb attaches THERE --
# before main() has run.  Reading the globals straight away prints all zeros, which reads
# exactly like a dead program: measured on the first run of this script (screenReady=0,
# vbiCount=0).  So: break AFTER the display has been up for a while, then print.
#
# ⭐ The breakpoint is on VetteScreen::vbiUpdate() because it is called once per FIELD from
# the VERTB handler, so the condition is evaluated against a clock that only advances if the
# interrupt is actually firing.  250 fields = 5 seconds of emulated time.
tbreak VetteScreen::vbiUpdate if g_laceFields >= 250
continue

printf "\n===== STAGE A =====\n"

printf "screenReady   = %u        (1 = both chip allocations succeeded and the list is installed)\n", g_screenReady
printf "planeChecksum = 0x%08X   (want 00000000: 98304-byte startup display is black)\n", g_planeChecksum
printf "vbiCount      = %u        (all fields, including the OS display before the takeover)\n", g_vbiCount
printf "laceFields    = %u        (fields since the mode registers were written)\n", g_laceFields
printf "longFields    = %u        (...of which long)\n", g_longFields

# ⭐ THE INTERLACE CHECK, and it is the one number that cannot be faked by a stuck register.
# A laced display alternates long and short fields, so longFields must be ~half of vbiCount.
# If LACE never took (the framework's dropped-flag failure), every field is a long field and
# this ratio goes to 1.0 while BPLCON0 may still read back correct on an emulator that
# accepts the bit without honouring it.
printf "long/lace     = %f        (want ~0.5; 1.0 means the display is NOT interlaced)\n", (double)g_longFields / (double)g_laceFields
printf "VPOSR[0..7]   = %04X %04X %04X %04X %04X %04X %04X %04X\n", \
    g_lofSamples[0], g_lofSamples[1], g_lofSamples[2], g_lofSamples[3], \
    g_lofSamples[4], g_lofSamples[5], g_lofSamples[6], g_lofSamples[7]
printf "                (bit 15 must ALTERNATE; a constant word = not interlaced, FFFF = bad read)\n"
printf "BPLCON2       = %04X      (want 0024: every sprite pair ahead of both playfields)\n", *(unsigned short*)0xdff104
printf "===================\n\n"
detach
quit
