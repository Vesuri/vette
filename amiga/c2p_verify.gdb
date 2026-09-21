# Read the in-process C2P assembly/C differential after diag_run.sh interrupts.
# Requires VERIFY=1 PROBES=1 and a scripted driving build.
set pagination off
set confirm off

continue

printf "C2P verify calls=%u bytes=%u failures=%u\n", g_c2pVerifyCalls, g_c2pVerifyBytes, g_c2pVerifyFailures
printf "C2P beam ticks asm=%u C=%u ratio(C/asm)=%.3f\n", g_c2pAsmTicks, g_c2pCTicks, 1.0*g_c2pCTicks/g_c2pAsmTicks
detach
quit
