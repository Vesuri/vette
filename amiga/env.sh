#!/usr/bin/env bash
# Source this for the shared Amiga environment that AmigaXDev installs (~/.local/share/amiga):
# the toolchain, FS-UAE and the shared Python on PATH, and the Kickstarts, Workbench, SetPatch,
# WHDLoad and LHa paths.  Every variable can be overridden from the environment.
#   . amiga/env.sh
# or from the amiga/ directory:
#   . env.sh
# WHDLoad 19.2: the version the slave builds against (whdload/) and the tests run.
export WHDLOAD="${WHDLOAD:-$HOME/.local/share/amiga/WHDLoad}"
. "${AMIGA_ENV:-$HOME/.local/share/amiga/env.sh}"
