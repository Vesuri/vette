# Report the first virtual key dispatched by the original Main+$2D26 KeyMap
# scanner after scripted driving starts.  Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
watch s_segments[1].begin
continue
delete 1

break *(s_segments[1].begin+0x2dea)
commands 2
  silent
  printf "KeyMap dispatch: virtual=$%02x KeyMap[10..11]=$%04x\n", $d0, *(unsigned short*)(s_currentA5+26)
  detach
  quit
end

continue
