# Record the original sound segment's Bogas context lifecycle.  The wrappers
# use Pascal stack arguments and dispatch command records to BGAS 128; this
# probe observes that public boundary without changing game state.
# Requires SKIP_INTRO=1 GARAGE_CLICK=1.
set pagination off
set confirm off
set $opens = 0
set $loads = 0
set $plays = 0
set $enginePlays = 0
set $pitches = 0
set $stops = 0
set $kills = 0

printf "Bogas bases: Main=$%x Traffic=$%x sound=$%x\n", s_segments[1].begin, s_segments[6].begin, s_segments[9].begin

break *(s_segments[9].begin+0x0ba)
commands 1
  silent
  set $opens = $opens+1
  printf "BogasOpen %u: tick=%u caller=$%x word0=$%x\n", $opens, g_macTicks, *(unsigned int*)$sp, *(unsigned short*)($sp+4)
  continue
end

break *(s_segments[9].begin+0x12a)
commands 2
  silent
  set $loads = $loads+1
  printf "BogasLoad %u: tick=%u caller=$%x word0=$%x long0=$%x long1=$%x word1=$%x\n", $loads, g_macTicks, *(unsigned int*)$sp, *(unsigned short*)($sp+4), *(unsigned int*)($sp+6), *(unsigned int*)($sp+10), *(unsigned short*)($sp+14)
  continue
end

break *(s_segments[9].begin+0x174) if s_drivingFrameStarted
commands 3
  silent
  set $plays = $plays+1
  set $playContext = *(unsigned short*)($sp+8)
  if $playContext != 0
    printf "BogasPlay effect %u: tick=%u caller=$%x long0=$%x word0=$%x\n", $plays, g_macTicks, *(unsigned int*)$sp, *(unsigned int*)($sp+4), $playContext
  else
    if $enginePlays < 12
      set $enginePlays = $enginePlays+1
      printf "BogasPlay engine %u: tick=%u caller=$%x long0=$%x word0=$%x\n", $enginePlays, g_macTicks, *(unsigned int*)$sp, *(unsigned int*)($sp+4), $playContext
    end
  end
  continue
end

break *(s_segments[9].begin+0x1b0)
commands 4
  silent
  set $pitches = $pitches+1
  printf "BogasPitch %u: tick=%u caller=$%x word0=$%x\n", $pitches, g_macTicks, *(unsigned int*)$sp, *(unsigned short*)($sp+4)
  continue
end

break *(s_segments[9].begin+0x27c)
commands 5
  silent
  set $stops = $stops+1
  printf "BogasStop %u: tick=%u caller=$%x\n", $stops, g_macTicks, *(unsigned int*)$sp
  continue
end

break *(s_segments[9].begin+0x0ee)
commands 6
  silent
  set $kills = $kills+1
  set $killName = *(unsigned int*)($sp+6)
  printf "BogasKill %u: tick=%u caller=$%x word0=$%x long0=$%x name-length=%u\n", $kills, g_macTicks, *(unsigned int*)$sp, *(unsigned short*)($sp+4), $killName, *(unsigned char*)$killName
  x/20bx $killName
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macFramesPresented >= 120
commands 7
  silent
  printf "Bogas context ceiling: opens=%u loads=%u plays=%u pitches=%u stops=%u kills=%u tick=%u frames=%u\n", $opens, $loads, $plays, $pitches, $stops, $kills, g_macTicks, g_macFramesPresented
  printf "Paula bridge: started=%u instruments=%u mix-level=%u Paula-volume=%u engine-playing=%u engine-instrument=%u engine-pitch=$%x engine-period=%u INST-period=%u engine-loop=%u..%u effect2-end=%u effect3-end=%u\n", s_bogasStarted, s_bogasInstrumentCount, s_bogasMixLevel, (s_bogasMixLevel/3+1)/2, s_bogasContexts[0].playing, s_bogasContexts[0].instrument, s_bogasContexts[0].pitch, 20905984/s_bogasContexts[0].pitch, s_bogasInstruments[4].basePeriod, s_bogasInstruments[4].loopStart, s_bogasInstruments[4].loopEnd, s_bogasVoiceEndTick[2], s_bogasVoiceEndTick[3]
  detach
  quit
end

continue
