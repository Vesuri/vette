# Stop at the fourth eligible full-surface mapped CopyBits, after three
# same-process C/asm differential calls have completed.  Each call compares
# all 87,552 bytes; more repeats only make this already-doubled probe unwieldy.
# Requires VERIFY=1 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break vetteMappedCopyAsm if g_mappedCopyVerifyCalls >= 3
commands 1
  silent
  printf "mapped copy verify calls=%u failures=%u C=%u ticks asm=%u ticks\n", g_mappedCopyVerifyCalls, g_mappedCopyVerifyFailures, g_mappedCopyCTicks, g_mappedCopyAsmTicks
  detach
  quit
end

continue
