# Inventory source-driven effects on Course Two's traffic-dense bridge/freeway
# route. Requires PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2
# FREEWAY_ROUTE=1.
set pagination off
set confirm off
set $loads = 0
set $effects = 0
set $seen = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "bridge-audio loud stop tick=%u trap=$%04x segment=%u offset=$%x loads=%u effects=%u mask=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset, $loads, $effects, $seen
  detach
  quit
end

break *(s_segments[9].begin+0x12a)
commands
  silent
  set $loads = $loads + 1
  set $context = *(unsigned short*)($sp+4)
  set $duration = *(unsigned int*)($sp+6)
  set $options = *(unsigned int*)($sp+10)
  set $instrument = *(unsigned short*)($sp+14)
  if $context != 0
    set $effects = $effects + 1
    set $bit = 1 << $instrument
    if ($seen & $bit) == 0
      printf "bridge-audio new-effect=%u tick=%u iteration=%u context=%u duration=%u options=$%08x instrument=%u\n", $effects, g_macTicks, g_macDrivingIterations, $context, $duration, $options, $instrument
    end
    set $seen = $seen | (1 << $instrument)
  end
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 900
commands
  silent
  set $car = *(unsigned int*)(s_currentA5-13944)
  printf "bridge-audio ceiling tick=%u frames=%u iterations=%u loads=%u effects=%u mask=$%x pos=($%08x,$%08x) heading=$%04x speed=%d gear=%d\n", g_macTicks, g_macFramesPresented, g_macDrivingIterations, $loads, $effects, $seen, *(unsigned int*)$car, *(unsigned int*)($car+8), *(unsigned short*)($car+0x66), *(short*)($car+0x1a), *(short*)($car+0x1c)
  detach
  quit
end

continue
