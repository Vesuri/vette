#!/usr/bin/env bash
# Development-run helper. The release archive must not contain either input;
# an installer will extract these raw resource forks from the user's original
# media. Paths remain overridable for local source layouts.

VETTE_APP_RSRC="${VETTE_APP_RSRC:-../tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_Color_VETTE!.rsrc}"
VETTE_DATA_RSRC="${VETTE_DATA_RSRC:-../tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc}"

stage_vette_original_data()
{
  local destination="$1"
  [ -f "$VETTE_APP_RSRC" ] || {
    echo "Color VETTE! resource fork not found: $VETTE_APP_RSRC" >&2
    return 1
  }
  [ -f "$VETTE_DATA_RSRC" ] || {
    echo "VETTE!.Data resource fork not found: $VETTE_DATA_RSRC" >&2
    return 1
  }
  cp -f "$VETTE_APP_RSRC" "$destination/Color VETTE!"
  cp -f "$VETTE_DATA_RSRC" "$destination/VETTE!.Data"
}
