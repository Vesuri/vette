# Prove the Z horn plays at its Load step and stops on release. Main+$30C0
# loads the horn on context 1 with step 2 (BGAS advances effects by whole
# bytes per 11.127 kHz sample), and Main+$2E12 silences context 1 through
# CODE 9+$BA when Z is released. Requires PROBES=1 SKIP_INTRO=1
# GARAGE_CLICK=1 HORN_PROBE=1.
set pagination off
set confirm off
set $loaded = 0
set $checked = 0
set $quieted = 0

break VetteScreen::showLoudStop
commands
  silent
  printf "horn loud stop tick=%u trap=$%04x segment=%u offset=$%x\n", g_macTicks, g_trapWord, g_trapSegment, g_trapOffset
  detach
  quit
end

break *(s_segments[9].begin+0x12a) if *(unsigned short*)($sp+4) == 1
commands
  silent
  set $loaded = 1
  set $options = *(unsigned int*)($sp+10)
  set $instrument = *(unsigned short*)($sp+14)
  continue
end

break *(s_segments[9].begin+0x0ba) if *(unsigned short*)($sp+4) == 1 && $loaded
commands
  silent
  set $quieted = 1
  continue
end

break VetteScreen::presentMacFrame if $loaded
commands
  silent
  if !$checked
    set $checked = 1
    set $period = s_paulaPeriodCeiling[3]
    set $playing = s_bogasContexts[1].playing
    printf "horn load options=%u instrument=%u period=%u playing=%u\n", $options, $instrument, $period, $playing
  end
  if $quieted
    printf "horn quiet playing=%u volume=%u zeroed=%u\n", s_bogasContexts[1].playing, s_bogasVoiceVolume[3], (g_probePaulaZeroedMask >> 3) & 1
    if $options == 2 && $period == 160 && $playing && !s_bogasContexts[1].playing && s_bogasVoiceVolume[3] == 0 && (g_probePaulaZeroedMask & 8)
      printf "horn PASS\n"
    else
      printf "horn FAIL\n"
    end
    detach
    quit
  end
  continue
end

break VetteScreen::presentMacFrame if s_drivingFrameStarted && g_macDrivingIterations >= 300
commands
  silent
  printf "horn FAIL ceiling loaded=%u quieted=%u\n", $loaded, $quieted
  detach
  quit
end

continue
