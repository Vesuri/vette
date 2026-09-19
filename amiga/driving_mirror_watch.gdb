# Attribute writes to the first differing byte in the synchronized rear-view
# mirror comparison.  Arm when the deterministic accelerator is installed,
# after the vehicle/course UI has finished using the same GWorld.
set pagination off
set confirm off
set $mirrorWrites = 0

define arm_mirror_watch
  watch *(unsigned char*)$mirrorByte
  commands
    silent
    set $mirrorWrites = $mirrorWrites+1
    printf "mirror byte write[%u] tick=%u pc=$%08x value=$%02x\n", $mirrorWrites, g_macTicks, $pc, *(unsigned char*)$mirrorByte
    bt 4
    if $mirrorWrites >= 16
      detach
      quit
    end
    continue
  end
end

break setDrivingKeyState if virtualKey == 0x5b && down
commands
  silent
  set $mirrorByte = s_gworlds[0].pixels+433
  printf "arming mirror byte watch at $%08x initial=$%02x tick=%u\n", $mirrorByte, *(unsigned char*)$mirrorByte, g_macTicks
  disable 1
  arm_mirror_watch
  continue
end

continue
