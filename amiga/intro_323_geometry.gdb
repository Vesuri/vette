# Measure the first intro DrawPicture destination and the immediately following
# screen CopyBits.  The one-shot probe avoids stopping on every trap; diag_run.sh
# interrupts the final continue at its wall-time ceiling.  Requires PROBES=1.
set pagination off
set confirm off

continue
printf "intro first DrawPicture: seen=%u frame=(%d,%d)-(%d,%d) target=(%d,%d)-(%d,%d)\n", g_probeIntroGeometry[0], g_probeIntroGeometry[1], g_probeIntroGeometry[2], g_probeIntroGeometry[3], g_probeIntroGeometry[4], g_probeIntroGeometry[5], g_probeIntroGeometry[6], g_probeIntroGeometry[7], g_probeIntroGeometry[8]
printf "draw portRect=(%d,%d)-(%d,%d) rowBytes=%u map=(%d,%d)-(%d,%d) clip=(%d,%d)-(%d,%d)\n", g_probeIntroGeometry[9], g_probeIntroGeometry[10], g_probeIntroGeometry[11], g_probeIntroGeometry[12], g_probeIntroGeometry[13], g_probeIntroGeometry[14], g_probeIntroGeometry[15], g_probeIntroGeometry[16], g_probeIntroGeometry[17], g_probeIntroGeometry[18], g_probeIntroGeometry[19], g_probeIntroGeometry[20], g_probeIntroGeometry[21]
printf "following CopyBits: seen=%u sourceRect=(%d,%d)-(%d,%d) destinationRect=(%d,%d)-(%d,%d) mode=%u\n", g_probeIntroGeometry[22], g_probeIntroGeometry[23], g_probeIntroGeometry[24], g_probeIntroGeometry[25], g_probeIntroGeometry[26], g_probeIntroGeometry[27], g_probeIntroGeometry[28], g_probeIntroGeometry[29], g_probeIntroGeometry[30], g_probeIntroGeometry[44]
printf "source rowBytes=%u bounds=(%d,%d)-(%d,%d) destination bounds=(%d,%d)-(%d,%d)\n", g_probeIntroGeometry[31], g_probeIntroGeometry[32], g_probeIntroGeometry[33], g_probeIntroGeometry[34], g_probeIntroGeometry[35], g_probeIntroGeometry[36], g_probeIntroGeometry[37], g_probeIntroGeometry[38], g_probeIntroGeometry[39]
printf "source rows 320..322 nonzero bytes: %u %u %u\n", g_probeIntroGeometry[40], g_probeIntroGeometry[41], g_probeIntroGeometry[42]
if g_probeIntroGeometry[43]
  set $src_base = g_probeIntroGeometry[43]
  set $src_rowbytes = g_probeIntroGeometry[31]
  dump binary memory ../tmp/amiga_intro_rows_320_322.raw $src_base+320*$src_rowbytes $src_base+323*$src_rowbytes
end
detach
quit
