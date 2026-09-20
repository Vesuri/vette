# STAGE C PROGRESS — break on the next loud stop and print the implemented depth.
# Run with: EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=stage_c.gdb ./diag_run.sh 20
set pagination off
set confirm off
set $loud_stop_hit = 0

# g_stageBState is written before the trap report fields, so watching it can
# stop on a half-built report.  showLoudStop is called only after every field
# is populated and immediately before the permanent loud-stop loop.
break VetteScreen::showLoudStop
commands
  silent
  set $loud_stop_hit = 1
end
continue

if $loud_stop_hit == 0
  printf "\n===== STAGE C =====\n"
  printf "no loud stop observed before the runner's wall-time ceiling\n"
  printf "implemented depth = %u trap(s)\n", g_stageCDepth
  printf "Mac ticks = %u, frames queued/presented = %u/%u, driving armed = %u\n", g_macTicks, g_macFramesQueued, g_macFramesPresented, s_drivingFrameStarted
  if s_drivingFrameStarted
    set $car = *(unsigned int*)(s_currentA5-13944)
    printf "player = world ($%08x,$%08x), cell (%u,%u), local (%u,%u)\n", *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x3e), *(unsigned short*)($car+0x40), (*(unsigned int*)$car)&0x7ff, (*(unsigned int*)($car+8))&0x7ff
    printf "driving = heading %u, gear %d, speed %d, throttle %d, brake %d, freeway mode %d\n", *(unsigned short*)($car+0x66), *(signed short*)($car+28), *(signed short*)($car+26), *(signed short*)($car+32), *(signed short*)($car+34), *(signed short*)(s_currentA5-0x3764)
    printf "last static collision = hit %u at tick %u/frame %u, cell (%u,%u), QUAD %u, selector %u, rectangle %u, edge %u, response/export %d/%d\n", g_probeStaticCollision[0], g_probeStaticCollision[10], g_probeStaticCollision[11], g_probeStaticCollision[3], g_probeStaticCollision[4], g_probeStaticCollision[5], g_probeStaticCollision[6], g_probeStaticCollision[7], g_probeStaticCollision[2], g_probeStaticCollision[8], g_probeStaticCollision[9]
    set $slot = (unsigned int*)(s_currentA5-13944)
    set $active_end = *(unsigned int**)(s_currentA5-13948)
    set $object_index = 0
    while $slot < $active_end
      set $object = *$slot
      printf "object[%u] = $%08x tag $%08x world ($%08x,$%08x), cell (%u,%u), state $%02x/$%02x/$%02x\n", $object_index, $object, *(unsigned int*)($object+0x54), *(unsigned int*)$object, *(unsigned int*)($object+8), *(unsigned short*)($object+0x3e), *(unsigned short*)($object+0x40), *(unsigned char*)($object+0x6a), *(unsigned char*)($object+0x6b), *(unsigned char*)($object+0x6c)
      set $slot = $slot+1
      set $object_index = $object_index+1
    end
  end
  printf "===================\n\n"
  detach
  quit
end

printf "\n===== STAGE C =====\n"
printf "implemented depth = %u trap(s) in measured first-use order\n", g_stageCDepth
printf "next trap         = $%04X %s / %s\n", g_trapWord, g_trapManager, g_trapRoutine
printf "selector          = %d (-1 = N/A)\n", g_trapSelector
printf "caller            = segment %u + $%04X\n", g_trapSegment, g_trapOffset
printf "absolute PC       = $%08X\n", g_trapPC
printf "USP               = $%08X\n", g_trapUserStack
printf "USP words         = "
x/8hx g_trapUserStack
printf "D0-D7/A0-A6:\n"
x/15wx g_trapRegisters
x/8i g_trapPC-8
printf "===================\n\n"
detach
quit
