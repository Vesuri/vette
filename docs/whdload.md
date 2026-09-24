# WHDLoad release

WHDLoad is the supported end-user installation and launch method. The standalone
executable remains a developer/debugging target; there is no separate standalone
release package. No game code, game data, Kickstart ROM, WHDLoad binary or RTB is
redistributed.

## Architecture

`whdload/VetteSlave.s` uses the SDK's public-domain `kick31.s` / `kickfs.s`.
Vette uses Exec, graphics, DOS and CIA resources, so a plain loader with no OS is
insufficient. The slave boots Kickstart 3.1, mounts its `data` drawer as the
emulated filesystem, and uses DOS LoadSeg on the Vette executable. Before entry, it scans the loaded hunks for the
12-byte retained `VET!HIRE` block and patches its word at offset 8 from Custom1.
The following reserved word must be zero; an absent/invalid block fails explicitly.
It establishes PROGDIR using a real directory lock, switches to an allocated
16 KiB stack with Exec StackSwap, and calls the entry point. On normal return it
restores the stack and program directory, frees its stack, unloads the executable,
closes DOS and exits through resload_Abort. WHDLoad owns final hardware restoration.

The slave requests 1 MiB chip and 4 MiB expansion RAM plus 512 KiB for Kickstart.
Host OS/WHDLoad/PRELOAD require additional memory. The tested machine has 2 MiB
chip and 8 MiB fast RAM. A 68020 is required by the port's current C2P routine;
68030 or better and AGA are recommended. `WHDLF_EmulLineA` forwards the game's
Macintosh trap vector at $28 despite WHDLoad's relocated VBR.

F10 is WHDLoad's immediate quit. Use the game's normal Control+left-mouse exit
to save pending score changes; abrupt WHDLoad exit cannot run the game's deferred
DOS save. Scores are stored in `data/Vette.scores`.

HIRES is a boolean WHDLoad option (`CUSTOM1=1`). Off by default, it selects
368×283 lores with per-screen crops (see [display geometry](amiga-arch.md#display)).
The intro crop starts at 80,0; driving starts at 80,32. Enabling HIRES restores
the complete 512×320 image in the existing interlaced display. Standalone builds
can select the startup default with `make -C amiga HIRES=1`, without WHDLoad.
Use `HIRES=0` (the default) for lores. Switching this option rebuilds the startup
word automatically; no clean build is needed.

## Cross-compilation

`make -C whdload` works on the macOS host with native vasm 1.9. No Amiga assembler
or emulator is needed to build the slave. The build uses `-pic -x -devpac
-Fhunkexe -nosym` and external WHDLoad SDK + NDK includes. Override `VASM`,
`WHDLOAD` and `NDK` in `whdload/Makefile` for other installations. Four build-local
include aliases accommodate the SDK's short LVO names and the NDK's `_lib.i`
filenames. The small slave is always reassembled, avoiding stale build options.

`make dist` builds the production game, slave and native extraction helper, then
creates `dist/Vette-0.90.lha`. Installer sets the game icon's default tool to
WHDLoad, with `SLAVE=Vette.slave` and `PRELOAD`.
The archive follows the released Rescue on Fractalus conventions: `Vette! Install`
drawer, `Vette.inf` game-icon template, lowercase `.slave`, and `ReadMe` with its
MultiView `ReadMe.info`. Installer creates `Vette!/Vette.info` and copies ReadMe
with its icon. The game, installer and readme artwork comes from that reference;
the package drawer artwork is the WHDLoad template's drawer.

## Regression tests and startup findings

Source `amiga/env.sh`. `make -C whdload smoke boot-test load-test` creates isolated
test slaves. `tools/test_whdload.py --mode smoke` runs without any ROM or game.
For other modes supply `--rom /local/kick40063.A600 --rtb /local/kick40063.A600.RTB`.
Modes `boot` and `load` exit before executing Vette. `quit` expects a clean
`QUIT_PROBE=1` game build. `timed` runs the production or gameplay regression build
until WHDLoad's TIMEOUT, saving COREDUMP and FILELOG. `--hires` tests the Custom1 startup patch; `--no-preload` tests live disk
reads. Each invocation retains an isolated fixture under `tmp/whdload-test-*`
and terminates only its own emulator. No test configuration enters the release.

Confirmed with WHDLoad 19.2.6941 and the local A600 40.063 ROM:

- The plain slave enters, writes a marker, and returns OK without any game or ROM.
- Kickstart-only and DOS LoadSeg-only slaves return OK.
- The unchanged QUIT_PROBE executable loads the originals and exits cleanly.
- A clean production executable renders the tram intro under WHDLoad; the image
  was decoded from its actual planar buffers, not a reference framebuffer.
- A scripted garage-to-driving build reaches the dashboard with PRELOAD disabled;
  both original files are read through kickfs and the planar display was checked.
- Native Installer 43.3 completes installation with T: scratch storage, preserves
  the verified original-file hashes, and produces valid WHDLoad project icons.

Two startup faults were in the slave setup, not the game:

1. DupLock(0) left `pr_HomeDir` zero. The game then waited on an invisible DOS
   requester for PROGDIR. Locking the actual current drawer fixes the launch context.
2. The supplied SDK's A600 `STACKSIZE` patch writes a long at ROM offset $2305c.
   On the tested ROM this is the MOVE.L opcode (`277c`); its immediate starts at
   $2305e. The resulting process had equal stack bounds and corrupted the fast-memory
   free list. The slave deliberately does **not** enable that patch. Exec StackSwap
   supplies stack space independently of ROM instruction offsets.

WHDLoad's own dumps isolated these faults after emulator-debugger traces proved
misleading. `tools/inspect_whdload.py DUMP_DIR` prints waiting tasks;
`tools/whdload_picture.py DUMP_DIR` decodes the lores planar buffers from the dump;
pass `--hires` for an interlaced run.
These tools and all dumps are developer-only.
