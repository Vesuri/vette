# Verify that a deferred Control+left-mouse request enters the game's installed
# ExitToShell replacement, chains to the restored original trap, and returns to
# PlatformAmiga teardown.  Use with PROBES=1 QUIT_PROBE=1.
set pagination off
set confirm off

break vette_user_exit_trampoline
commands
  silent
  printf "ExitToShell original reached: state=%u hostSP=$%08x\n", g_macExitState, g_macHostReturnSP
  continue
end

break vetteInputShutdown()
commands
  silent
  printf "Mac code returned to Amiga teardown: state=%u hostSP=$%08x trap=$%04x depth=%u\n", g_macExitState, g_macHostReturnSP, g_trapWord, g_stageCDepth
  continue
end

break vetteRestoreComplete
commands
  silent
  printf "AmigaOS restore complete: DMA saved=$%04x actual=$%04x INTENA saved=$%04x actual=$%04x view=%u\n", g_restoreSavedDmacon, g_restoreActualDmacon, g_restoreSavedIntena, g_restoreActualIntena, g_restoreViewMatches
  continue
end

break vetteRuntimeAllocationsReleased
commands
  silent
  set $live = s_memoryManager.allocationCount + s_handleAllocationCount
  set $i = 0
  while $i < 5
    if s_introSamples[$i].chipData != 0
      set $live = $live + 1
    end
    set $i = $i + 1
  end
  set $i = 0
  while $i < 16
    if s_bogasInstruments[$i].chipData != 0
      set $live = $live + 1
    end
    set $i = $i + 1
  end
  set $i = 0
  while $i < 8
    if s_gworlds[$i].pixels != 0
      set $live = $live + 1
    end
    set $i = $i + 1
  end
  printf "emergency-quit PASS: view=%u DMA=$%04x/$%04x INTENA=$%04x/$%04x live=%u pointers=%u handles=%u freed=%u/%u/%u/%u/%u\n", g_restoreViewMatches, g_restoreSavedDmacon, g_restoreActualDmacon, g_restoreSavedIntena, g_restoreActualIntena, $live, s_memoryManager.allocationCount, s_handleAllocationCount, g_probeReleasedIntroSamples, g_probeReleasedBogasSamples, g_probeReleasedGWorlds, g_probeReleasedPointers, g_probeReleasedHandles
  detach
  quit
end

continue
