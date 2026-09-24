# Development

## Build dependencies

The production game is the Amiga executable; there is no host game renderer.

- GNU make, a shell and Python 3.
- `m68k-amiga-elf-gcc/g++`, `elf2hunk`, vasm and Amiga NDK headers.
- WHDLoad SDK includes for the slave. See [whdload.md](whdload.md).
- LHa for UNIX for LH5 encoding, plus Lhasa's `lha` for independent archive
  verification. Set `LHA` to the encoder's absolute path or install it as
  `lha-compress` on PATH. Build instructions: [installation](install-original-data.md).

`amiga/env.sh` adds the development toolchain under `~/.local` to PATH.
Adjust PATH for another installation; `WHDLOAD`, `NDK` and `VASM` override
slave dependencies. FS-UAE launchers also use
`${FSUAE_COMMON:-$HOME/.local/share/amiga/fsuae_common.sh}` for shared,
PID-scoped emulator/debug-port management. It is an external developer dependency,
not included in the release. `KICKSTART` selects your local boot ROM.

```sh
. amiga/env.sh
make -C amiga clean
make -C amiga -j4
make -C whdload
make dist
```

Outputs are `amiga/out/Vette.exe`, `build/whdload/Vette.slave` and
`dist/Vette-0.90.lha`. The production build needs no copyrighted game input.
Use `make -C amiga HIRES=1` for a standalone hires-interlaced executable, or
`HIRES=0` for lores. This option automatically updates an existing build.
Always clean when changing other build flags or shared headers.

## Running a development build

Supply your own original archive under ignored `tmp/`. The standalone emulator
launcher stages the original files through `amiga/stage_original_data.sh`.
WHDLoad remains the supported release installation method.

```sh
. amiga/env.sh
make install-data-helper
build/install-data/VetteInstallData tmp/VETTE__1.02_and_extras.sit tmp/runtime-data
cd amiga
export VETTE_APP_RSRC='../tmp/runtime-data/Color VETTE!'
export VETTE_DATA_RSRC='../tmp/runtime-data/VETTE!.Data'
./run.sh
```

Check `stage_original_data.sh` for its local input paths before first use.
The default model has 2 MB chip and 8 MB fast RAM. A clean production build
shows the intro; `SKIP_INTRO=1` uses the original first-button skip branch.
`GARAGE_CLICK=1` scripts real selector events into driving.
`FOLLOW_ROAD=1` adds road-following input; without it the straight-to-water
fixture is intentional.

## Tests

```sh
make frame-pacing-test coverage-check driving-control-audit
make install-data-test
make gameplay-regression-smoke
make dist
```

Helper tests require the original archive. Emulator tests additionally need
FS-UAE, cross-GDB, the shared launcher helper and a legal Kickstart ROM.
`amiga/regression.sh` exposes `smoke`, `courses`, `vehicles`, `difficulties`,
`recovery`, `routes`, `session` and `all`. Each case builds cleanly, requires
an explicit success record and rejects loud stops. See the
[coverage matrix](gameplay-coverage.md).

`make static-map-check` needs extracted Color CODE resources and generated
Ghidra listings/trap CSVs under `tmp/`; it is not a fixture-free checkout test.
The `driving-*-reference/capture/compare` targets similarly need local original
Macintosh captures. `make fidelity-check` checks those saved artifacts, not a
fresh emulator run. `make release-check` combines static/coverage/runtime tests,
helper tests, deterministic executable builds and the release audit.

Native installation testing:

```sh
. amiga/env.sh
python3 tools/install-data/test_installer_script.py /path/to/Installer --t-temp
```

It also needs the local Workbench floppy and ROM/RTB paths declared in that
script. These are not redistributed. WHDLoad's isolated smoke/load/quit tests
are described in [whdload.md](whdload.md).

## Debugging and profiling

```sh
cd amiga
. ./env.sh
make clean
make -j4 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1
EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=runtime_status.gdb ./diag_run.sh 30
```

The runner stops early when an event-driven observer finishes. Otherwise its
seconds argument is a safety ceiling, not proof of success. It preserves output
in `amiga/.run/gdb-out.log` and stops only the emulator it owns.

For lores crop transitions and C2P verification, build cleanly with
`PROBES=1 VERIFY=1 FILLWATCH=1 SKIP_INTRO=1 GARAGE_CLICK=1`, then run
`GDBSCRIPT=viewport_verify.gdb EXTRA_ARGS="--warp_mode=1" ./diag_run.sh 55`
from `amiga/`. Require `PASS dynamic crops and C2P`; the time limit alone is not
success. The observer checks all selectors and the return to the driving crop.

Useful reusable observers include `frame_pacing.gdb`, `intro_probe.gdb`,
`driving_phase_profile.gdb`, `memory_requirements.gdb`, `memory_driving.gdb`,
`wbstartup.gdb` and the C2P/mapped-copy/driving-copy verification scripts.
`make driving-profile` measures a fixed 300-field window. Do not compare
instrumented throughput to shipping-build throughput.

The current display owner is `VetteScreen`; the interpreter boundary is
`MacLoader`. Keep changes at the documented interface and verify original
opcodes/operands before changing binary behavior. A loud stop identifies the
manager, routine, selector and original segment/offset.
