# Installing the original game data

The release contains no Vette! graphics, sound, maps, or Macintosh executable
code. Supply the original `VETTE__1.02_and_extras.sit` archive, unexpanded.
The installer copies no Macintosh filesystem wrapper into the Amiga
directory: it writes the two original resource forks, byte for byte, under the
names the port opens at startup.

`make dist` builds `dist/Vette-0.90.lha` (also available through the `make release`
alias). Its `Vette! Install` drawer contains only `Vette`, `Vette.info`,
`VetteInstallData`, `Install`, `Install.info`, and `README.txt`. A sibling
`Vette! Install.info` supplies the drawer icon from the WHDLoad template.
`Install.info` reuses the Rescue on Fractalus installer artwork, with APPNAME
changed to Vette! and its Installer default tool and AVERAGE user level retained.
The readme
contains the helper's license and repository source link. No original data,
sources, emulator configuration, checksum manifest or host tools are bundled.
The deterministic generic level-zero LH0 archive needs no host compression tool;
its CRCs and file listing were independently verified with Lhasa.

## Native Amiga installation

### Hardware and OS requirements audit

The current executable is not wholly 68000-compatible: `C2P.s` uses scaled
word indexing (`d0.w*4`), assembled with `-mcpu=68020`. Most other code remains
68000-targeted. AGA is recommended rather than naming a particular Amiga model.
No broader OCS/ECS visual-fidelity claim has been established by this audit.

Kickstart 1.3 is not a supported claim for this build: game disk access uses
`PROGDIR:` and `PutStr`, and the helper opens dos.library V37 and uses `ReadArgs`.
The API baseline is OS 2.04; runtime tests use 3.1. An attempted 2.04/ECS debugger
run failed during remote symbol relocation (`E01`, unrelocated breakpoint), so
it establishes neither compatibility nor a game defect on 2.04.

Reduced-memory tests passed with **1 MiB chip + 4 MiB fast RAM**, not the old
2+8 MiB recommendation. `memory_requirements.gdb` samples Exec's memory lists
at each frame boundary. The full production intro reached garage setup (depth
68), with minima of 472,680 free chip bytes and 68,544 free fast bytes. A clean
scripted-driving build reached depth 93 with 681,200 free chip bytes and 26,776
free fast bytes. These are separate minima, not necessarily simultaneous.
They include AmigaOS usage, and do not measure every transient allocation or
every game route; the readme calls this a tested configuration, not an exact
minimum. Both runs used a clean emulated system; other resident programs need
additional headroom.

Reproduce using `CHIP_MEMORY=1024 FAST_MEMORY=4096 EXTRA_ARGS=--warp_mode=1`
with `amiga/diag_run.sh`, `memory_requirements.gdb` for a normal production
build, or `memory_driving.gdb` with `PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1`.
Use a 180-second host ceiling for the full intro and 80 for driving.

### Installation procedure

Temporary-space checks resolve the selected drawer with Installer's `getdevice`.
If it matches the device behind `RAM:`, use `(+ (database "total-mem"))` minus
a 256 KiB helper reserve. Otherwise use `getdiskspace`. This covers `T:` and
other assigns/subdirectories without assuming that T: is necessarily in RAM.
Installer 43.3 documents `database` as returning a string and unary `+` as the
numeric conversion. RAM disk filesystem free blocks do not describe its ability
to grow, so a zero from `getdiskspace` must not reject it when enough RAM is free.
Native Installer 43.3 tests confirmed `disk=0` but `usable=26637424` for both
RAM: and the RAM-backed T: assign. Fresh installations completed through both
paths with exact final hashes; the T: test also checked inside the guest that
its private scratch directory had been deleted. `icon.library` verified the
borrowed project/drawer icons, default tool and application-specific tooltypes.

Double-click `Install` in the release drawer. Choose the parent installation
drawer, temporary drawer (default `T:`), then the downloaded `.sit`. The script
creates `Vette!` with a drawer icon, `Vette!` executable and icon, and `data`.
Standard Amiga Installer V43 or later is
required for this graphical script. The included `VetteInstallData` helper does
all extraction on the Amiga; no xadmaster, Python, Deark or Mac emulator is needed.

For Shell use, invoke the helper directly, then place `Vette` in the destination:

```
VetteInstallData "Work:Downloads/VETTE__1.02_and_extras.sit" "Work:Games/Vette!/data" "Work:Temp"
```

It extracts only the two `VETTE!.img` fork entries, decodes the NDIF image into a
temporary raw HFS file, reads the HFS catalog/extents, and extracts the Color
application and game-data resource forks. Both final SHA-256 fingerprints must
match before either new file is installed. Existing matching files are retained;
different existing files are rejected without modification.

Create the parent game drawer before this Shell command. Allow 12 MiB free in
the selected temporary drawer and 3 MiB at the destination, excluding the archive.
`T:` usually uses RAM, so select a hard disk drawer on machines with less spare RAM.
The optional third helper argument selects temporary storage (omitting it uses
the destination). Private scratch directories are cleaned up. Verified files
are copied to private staging on the destination volume before publication;
temporary and destination drawers may be on different volumes.
The helper uses a shared 64 KiB decompression history window, small I/O buffers,
and no whole-image allocation. It works with a 4 KiB stack. Installation may
take several minutes on an A1200. Ctrl-C cancels during buffered I/O; normal
errors/cancellation close files and clean up this run's temporary directory.

The end-to-end A1200/Kickstart 3.1 test completed with a 4,096-byte stack and
3,272 bytes still untouched (824-byte measured high-water mark). Its two outputs
matched the expected SHA-256 hashes and no temporary files remained. Production
working storage is about 105 KiB of BSS, plus code/constants and OS file buffers.

Installer's documented `working` message stays visible during extraction;
`complete` supplies stage percentages before and after its synchronous `run`.
These are installation milestones, not a live decompression percentage. No
Intuition window or GUI dependency is added to the helper. The script follows
Installer 43.3's `makedir (infos)` and `copyfiles (infos) (newname ...)` semantics.
The game prefers `PROGDIR:data/` and still accepts the older adjacent-file layout.

The script was exercised with the actual Installer 43.3 on FS-UAE A1200,
Kickstart 3.1, and locally supplied Workbench commands. Both a fresh extraction
and repeat installation passed, including drawer/game icons, executable copying,
exact output hashes, and scratch cleanup. `test_installer_script.py` supplies
deterministic requester answers; it does not replace the installation operations.
The Workbench floppy and Installer executable are local test dependencies only,
not redistributed in the release.

The helper is a separate LGPL-2.1-or-later program; its complete C source and
license are in the repository's `tools/install-data`. See its README for supported
format limits and tests. These are original, unmodified resource forks, not a
custom bundle and not data embedded in the game executable.

## Unix build

From the repository:

```
make install-data-helper
build/install-data/VetteInstallData VETTE__1.02_and_extras.sit /path/to/Vette
```

From the repository's `tools/install-data` directory: `make BUILD=build`, then invoke
`build/VetteInstallData`. The portable C core and Amiga binary use the same
parsing, decompression and integrity checks.

## Older Python host installation

First expand the original StuffIt archive with a tool that preserves Macintosh
resource forks. On macOS, `unar` does this. Then run:

```sh
python3 tools/install_original_data.py \
  "/path/to/VETTE!.img" "/path/to/Amiga/Vette"
```

`VETTE!.img` may instead be the 8 MB raw HFS image emitted by
`tools/ndif2raw.py`. The installer detects both forms, locates the Color release
inside HFS, strictly parses both resource maps, and accepts only the supported
Vette! 1.02 files. It reports their byte counts, resource counts, and SHA-256
fingerprints before completing.

The destination will contain:

| file | bytes | resources | purpose |
|---|---:|---:|---|
| `Color VETTE!` | 1,587,389 | 341 | Macintosh application resource fork, including all 11 CODE segments |
| `VETTE!.Data` | 577,498 | 231 | maps, objects, collision data, pictures, palettes, and sounds |

Place the Amiga `Vette` executable beside those two files. Do not substitute
the empty Macintosh data forks, MacBinary files, AppleDouble wrappers, or the
NDIF image itself; those are containers, not the raw resource forks the game
opens.

## Manual/raw-image route

For inspection or use with other extraction tools:

```sh
python3 tools/ndif2raw.py "/path/to/VETTE!.img" VETTE.raw
python3 tools/hfs_extract.py VETTE.raw list
python3 tools/install_original_data.py VETTE.raw "/path/to/Amiga/Vette"
```

On an Amiga, Deark can inspect/extract the resulting raw HFS image. The two
required source files are in
`VETTE!/VETTE! Folder/(Folder) Color VETTE!/`; their *resource forks* must be
saved as the ordinary Amiga files named above. The Python tools remain independent
references; the native helper applies the same exact-file SHA-256 gates.
