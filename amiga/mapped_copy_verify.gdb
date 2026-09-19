# Stop after at least 200,000 mapped bytes have passed through the same-process
# C/asm differential.  Counting bytes instead of calls covers both contiguous
# full-surface copies and strided rectangles without assuming their geometry.
# Requires VERIFY=1 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break vetteMappedCopyRowsAsm if g_mappedCopyVerifyBytes >= 200000
commands 1
  silent
  printf "mapped copy verify calls=%u bytes=%u failures=%u C=%u ticks asm=%u ticks\n", g_mappedCopyVerifyCalls, g_mappedCopyVerifyBytes, g_mappedCopyVerifyFailures, g_mappedCopyCTicks, g_mappedCopyAsmTicks
  detach
  quit
end

continue
