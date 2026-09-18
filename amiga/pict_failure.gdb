# Identify and dump the PICT resource at a DrawPicture loud stop.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
end
continue

printf "\n===== PICT FAILURE =====\n"
printf "trap=$%04X %s / %s caller=%u+$%04X\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
set $handle = *(unsigned int*)(g_trapUserStack + 4)
set $index = ($handle - (unsigned int)&s_resourceMasters) / 4
set $entry = s_resourceArchive.m_bytes + s_resourceArchive.m_directory + $index * 24
set $dataOffset = *(unsigned int*)($entry + 16)
set $dataSize = *(unsigned int*)($entry + 20)
set $data = s_resourceArchive.m_bytes + $dataOffset
printf "handle=$%08X resource[%u] fork=%u type='%.4s' id=%d size=%u data=$%08X\n", $handle, $index, *(unsigned short*)$entry, $entry+4, *(short*)($entry+2), $dataSize, $data
set $rect = *(unsigned int*)g_trapUserStack
printf "destination=(%d,%d)-(%d,%d)\n", *(short*)($rect+2), *(short*)$rect, *(short*)($rect+6), *(short*)($rect+4)
printf "unsupported opcode=$%02X at offset=$%X\n", s_unsupportedPictureOpcode, s_unsupportedPictureOffset
x/32bx $data
dump binary memory ../tmp/failing.pict $data $data+$dataSize
printf "========================\n"
detach
quit
