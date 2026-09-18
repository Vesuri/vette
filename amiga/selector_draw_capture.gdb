set pagination off
set confirm off

break MacLoader.cpp:1480 if *(short*)targetRect == 0 && *(short*)(targetRect+2) == 0 && *(short*)(targetRect+4) == 322 && *(short*)(targetRect+6) == 512
commands
  silent
  dump binary memory ../tmp/selector_draw.ctab destinationColors destinationColors+136
  printf "captured selector DrawPicture color environment\n"
  detach
  quit
end

continue
