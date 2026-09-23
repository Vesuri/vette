# Check Course One's source-authored DHDVText placement after PICT 6398 has
# returned. Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off

break VetteScreen::showLoudStop
commands
  silent
  printf "course-text FAIL loud stop trap=$%04x %s/%s caller=%u+$%x\n", g_trapWord, g_trapManager, g_trapRoutine, g_trapSegment, g_trapOffset
  detach
  quit
end

# Main+$173A is the PaintRect immediately following the course-description
# DrawPicture. PICT 6398's Finish line has source origin (329,109); translation
# into its destination makes the compact F begin at screen (314,78).
break *(s_segments[2].begin+0x173a)
commands
  silent
  set $row = s_colorScreen + 78 * 256
  if $row[157] == 0xff && $row[158] == 0xff && ($row[159] & 0xf0) == 0xf0
    printf "course-text PASS finish-origin=(314,78) pixels=$%02x,$%02x,$%02x\n", $row[157], $row[158], $row[159]
  else
    printf "course-text FAIL finish-origin=(314,78) pixels=$%02x,$%02x,$%02x\n", $row[157], $row[158], $row[159]
  end
  detach
  quit
end

continue
