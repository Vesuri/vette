# Original data and release packaging

## Installed layout

WHDLoad is the supported installation method. The installer takes the user's
compressed `VETTE__1.02_and_extras.sit`, asks for a parent destination and scratch
drawer, and creates:

```text
Vette!/
  Vette!.slave
  Vette!.info          WHDLoad icon: SLAVE=Vette!.slave, PRELOAD
  ReadMe
  ReadMe.info
  data/
    Vette!            game executable
    Color VETTE!      original application resource fork
    VETTE!.Data       original game-data resource fork
    Vette.scores      created when changed scores are saved on normal exit
```

An existing Vette! drawer can be removed first or updated in place. Keeping
it preserves scores. If both original data files exist, the installer offers
Reinstall or Use existing; reusing them skips temporary-directory and archive
selection. Other release files are always copied. Data reinstall extracts into
a unique temporary drawer and verifies both originals before copying them over
the installed data; failed extraction leaves the installed files unchanged.

The executable first tries `PROGDIR:data/`, then adjacent original files in
`PROGDIR:`. The WHDLoad slave mounts the data drawer and sets PROGDIR correctly.
Missing/unreadable or unsupported originals produce a DOS error and return code
20 before display takeover; a black display is not the intended missing-data UI.

The helper validates exact originals:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| Color VETTE! | 1,587,389 | `77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b` |
| VETTE!.Data | 577,498 | `e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f` |

These are original forks, not a custom archive or embedded game data.
The original archive is available from the [Vette! page at Macintosh
Repository](https://www.macintoshrepository.org/4948-vette-); it is a collection
containing the game, not an original publisher distribution package.

## Extraction and temporary storage

`VetteInstallData` is a self-contained portable C helper. It extracts the two
NDIF image forks from StuffIt, decodes a temporary raw HFS image, walks its
catalog/extents, and selects only the Color application's two resource forks.
It validates both files before publication. Matching existing files are retained;
different existing files are rejected. Scratch/staging files are removed after
success, errors or ordinary cancellation.

Allow 12 MB temporary space and 3 MB destination space, excluding the downloaded
archive. The temporary drawer defaults to T: but can be on disk. Installer's RAM
device check uses available memory minus a reserve rather than filesystem free
blocks: expandable RAM: commonly reports zero blocks free. Assigns are resolved
with `getdevice`, so T: on either RAM or disk is handled correctly.

The helper uses about 105 KiB BSS and bounded buffers; it does not allocate the
whole image. Installer shows a working message and stage percentages, not a live
decompression percentage. See [helper documentation](../tools/install-data/README.md)
for formats, limits, licenses and native tests.

For developer extraction:

```sh
make install-data-helper
build/install-data/VetteInstallData VETTE__1.02_and_extras.sit destination scratch
```

The older `ndif2raw.py`, `hfs_extract.py`, `resource_fork.py` and `macbin.py`
remain independent inspection/reference tools, not installation dependencies.
NDIF needs its resource fork for the block map; a data-fork-only image is insufficient.
Do not use the unidentified NDIF checksum as a validation gate.

## Release archive

`make dist` produces `dist/Vette-0.91.lha`, with a `Vette! Install` drawer
and sibling drawer icon. It contains the game executable, slave, `Vette!.inf`
icon template, extraction helper, Install with its icon, ReadMe with its icon,
and `LICENSE.LGPL.txt` without an icon. The LGPL text applies only to the helper
and remains in the release drawer; Installer does not copy it.

No source tree, original data, checksum manifest, emulator configuration, host
tools, ROM, RTB or WHDLoad executable is included. Icons follow the released
Rescue on Fractalus conventions; provenance is in
[release/icons/README.md](../release/icons/README.md).

Every archive member uses LH5 with deterministic generic level-zero headers.
Packaging requires [LHa for UNIX](https://github.com/jca02266/lha), not the
extraction-only Homebrew Lhasa. Install the encoder as `lha-compress` on PATH
or set `LHA` to its absolute path. Example host build (C compiler, autoconf,
automake required):

```sh
git clone https://github.com/jca02266/lha.git tmp/lha-compressor
cd tmp/lha-compressor
git checkout 16619b066b189ef289bb8b07b37d1c38d550da99
autoreconf -is
./configure
make -j4
cd ../..
LHA="$PWD/tmp/lha-compressor/src/lha" make dist
```

`tools/check_release.py` independently decodes members using `lha` (Lhasa),
checks CRCs, exact membership, reference icons, helper license and installer
conventions. Packaging fails rather than silently falling back to LH0.
