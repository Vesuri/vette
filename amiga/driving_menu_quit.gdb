# Prove that a live race suspended with physical P accepts the shipped
# Command-Q MENU 222 item 8, runs Vette's installed ExitToShell cleanup, and
# returns through complete AmigaOS restoration.  Requires PROBES=1,
# SKIP_INTRO=1, GARAGE_CLICK=1, SESSION_CONTROL_ITEM=8.
set pagination off
set confirm off
set $selected = 0

break menuKey if g_sessionControlProbePhase == 3
commands
  silent
  if requestedKey == 0x71
    printf "menu-quit MenuKey Q tick=%u\n", g_macTicks
  end
  continue
end

break *(s_segments[1].begin+0x103e) if g_sessionControlProbePhase == 3
commands
  silent
  set $selected = $d0 == 0x00de0008
  printf "menu-quit selection packed=$%08x tick=%u selected=%d\n", $d0, g_macTicks, $selected
  continue
end

break vette_user_exit_trampoline
commands
  silent
  printf "menu-quit original ExitToShell state=%u hostSP=$%08x selected=%d\n", g_macExitState, g_macHostReturnSP, $selected
  continue
end

break vetteInputShutdown()
commands
  silent
  printf "menu-quit Amiga teardown state=%u hostSP=$%08x selected=%d\n", g_macExitState, g_macHostReturnSP, $selected
  continue
end

break vetteRestoreComplete
commands
  silent
  printf "menu-quit restore DMA=$%04x/$%04x INTENA=$%04x/$%04x view=%u selected=%d\n", g_restoreSavedDmacon, g_restoreActualDmacon, g_restoreSavedIntena, g_restoreActualIntena, g_restoreViewMatches, $selected
  detach
  quit
end

continue
