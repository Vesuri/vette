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

Outputs are `amiga/out/Vette.exe`, `build/whdload/Vette!.slave` and
`dist/Vette-0.91.lha`. The production build needs no copyrighted game input.
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

The default checks updating an existing installation while reusing its data.
Use `--reinstall` to replace deliberately damaged data while keeping scores,
`--remove` to remove the old drawer first, or `--fresh` for a new installation.
The tests also check conditional prompts, release files and native icon tooltypes.
They need the local Workbench floppy and ROM/RTB paths declared in that script. These are not redistributed. WHDLoad's isolated smoke/load/quit tests
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

### Original-code gameplay profile

`make parked-game-profile` builds a diagnostic A1200 workload, waits until the
car is parked at Main Map cell (25,32), releases the driving keys, lets twelve
iterations settle, and captures 100 PAL fields with FS-UAE's built-in instruction
profiler. The original simulation, traffic and rendering continue. The observer
requires unchanged position, zero speed, neutral gear, released input and continued
drawing. Its `PASS parked original-code profile` line is required by the report tool.

The original-code and port-function reports, per-address cycle totals and first/last field screenshots are written
to `tmp/parked-profile/report/`. The exact diagnostic ELF is also preserved as
`tmp/parked-profile/Vette-profile.elf`, since a later build has different addresses.
`tools/report_port_profile.py` maps the non-original PCs to that ELF, accounting
for each function's self time without adding its callees twice.
The raw trace is about 1 GB. A PAL field is not a
game-rendered frame; the log separately records completed game iterations.

FS-UAE's executable profiler normally drops PCs outside the first code hunk.
`CODE_PROFILE=1` reserves a 128 KiB zero-filled area there and loads the original
CODE resources into it at runtime instead of separate heap allocations. The
resources and ordinary compatibility patches are unchanged, and no original data
is embedded in the executable. `PARKED_PROFILE=1` supplies only the diagnostic
position and released controls. Both options disappear from an ordinary build.
Clean before changing these flags.

The decoder uses the [Barto profiler format](https://github.com/BartmanAbyss/vscode-amiga-debug/blob/master/src/backend/profile.ts):
PC records weighted by emulator cycle units, with 17 saved registers. It checks
every field's accounting and reports self time by original segment and 64-byte
region. These are not inclusive routine timings or real-hardware measurements;
unknown external addresses and IRQ transitions remain explicit. There are no
breakpoints inside the measurement window and no injected sampling interrupts.
The capture uses an empty unwind file argument, because original CODE has no
compiler unwind metadata.

The split between original CODE and port/system code is **not** a slowdown
relative to Macintosh. Macintosh Toolbox/QuickDraw and display services also
consume time outside original CODE. The Amiga's chunky-to-planar conversion is
an additional display-format operation; the frame copy services the original
CopyBits request. A comparison needs a matched Mac scene, CPU/memory model and
rendered-frame workload, including its system services. In-program `PROBES`
counters also contribute time (including counters inlined into presentation),
even when the phase brackets are inactive. Report these limitations explicitly.

The current display owner is `VetteScreen`; the interpreter boundary is
`MacLoader`. Keep changes at the documented interface and verify original
opcodes/operands before changing binary behavior. A loud stop identifies the
manager, routine, selector and original segment/offset.

### Direct driving C2P

Driving's validated full-window `CopyBits` publication retains its resident
GWorld pointer instead of copying 81,920 bytes into `s_colorScreen`. At the
completed driving-loop boundary, both C and assembly C2P consume that source
with its original 260-byte stride. The existing dirty rectangles, crop clipping,
planar synchronization and VBI swap remain in effect. C2P consumes the source
synchronously; the display interrupt never retains a chunky pointer. GWorlds
remain allocated until runtime cleanup, which clears the retained pointer first.

This is specific to the shipped driving renderer, not a general deferred
QuickDraw implementation. Exact rectangle, dimensions, copy mode, mask and
palette-seed checks still guard eligibility. Screen pixel access through
QuickDraw, PICT decoding or BlockMove materializes the logical 256-byte-stride
screen first. Leaving driving also materializes it. Other CopyBits operations
keep their existing implementation. Identity-only bitmap checks do not force a
copy. Dirty regions describe drawing, not pixel-value differences.

`make direct-c2p-check` checks 45 parked frames with zero driving-copy calls,
assembly/C comparison and rolling validation across a complete visible viewport.
It exercises both 256-byte selector screens and 260-byte driving sources.
`make direct-c2p-shadow-check` preserves a diagnostic copy of every original
publication while still displaying directly; 45 moving frame-boundary captures
must match it byte for byte. This detects changes to the source between its last
publication and conversion. `make direct-c2p-fallback-check` lets the original
race-finish sequence request screen materialization and compares all resulting bytes with its GWorld source.
All three targets require explicit debugger PASS records.

For comparison builds, `DRIVING_COPY_LEGACY=1` restores eager publication.
`DRIVING_COPY_C=1` selects the C fallback; combine both to reproduce the old C
publication. The old driving-copy differential needs `DRIVING_COPY_LEGACY=1
VERIFY=1 PROBES=1`. Never compare performance with `VERIFY`, `FILLWATCH`, or
`DRIVING_COPY_SHADOW` enabled. Capture tools must use the active source and stride;
`s_colorScreen` can intentionally be stale during direct driving.
