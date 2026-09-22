# Exercise High Screen item 6 through the original Score segment, then stop
# after AmigaOS restoration and the deferred score-file write. Requires
# PROBES=1 SKIP_INTRO=1 SCORE_PERSISTENCE_PROBE=1.
set pagination off
set confirm off

break vetteScoreSaveComplete
commands 1
  silent
  printf "score persistence changed=%u writes=%u load-valid=%u saved=%u exit=%u restore DMA=$%04x/$%04x INTENA=$%04x/$%04x view=%u\n", g_scorePersistenceChanged, g_scorePersistenceWrites, g_scoreFileLoadValid, g_scoreFileSaveBytes, g_macExitState, g_restoreSavedDmacon, g_restoreActualDmacon, g_restoreSavedIntena, g_restoreActualIntena, g_restoreViewMatches
  detach
  quit
end

continue
