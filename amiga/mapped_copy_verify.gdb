# Stop at the thirteenth eligible full-surface mapped CopyBits, after twelve
# same-process C/asm differential calls have completed.
# Requires VERIFY=1 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break vetteMappedCopyAsm if g_mappedCopyVerifyCalls >= 12
commands 1
  silent
  printf "mapped copy verify calls=%u failures=%u C=%u ticks asm=%u ticks\n", g_mappedCopyVerifyCalls, g_mappedCopyVerifyFailures, g_mappedCopyCTicks, g_mappedCopyAsmTicks
  detach
  quit
end

continue
