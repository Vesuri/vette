#!/usr/bin/env bash
# Source this for the shared Amiga environment that AmigaXDev installs (~/.local/share/amiga):
# the toolchain, FS-UAE and the shared Python on PATH, and the Kickstarts, Workbench, SetPatch,
# WHDLoad and LHa paths.  Every variable can be overridden from the environment.
#   . amiga/env.sh
# or from the amiga/ directory:
#   . env.sh
. "${AMIGA_ENV:-$HOME/.local/share/amiga/env.sh}"
# Project choices from the shared tools: the native FS-UAE build, which carries AmigaXDev's
# emulator corrections (the x86_64 fs-uae on PATH does not), and the elf2hunk that zero-fills
# section padding.
export FSUAE="${FSUAE:-$FSUAE_ARM}"
export ELF2HUNK="${ELF2HUNK:-$AMIGA_SHARE/elf2hunk-fixed}"
