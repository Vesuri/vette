# Installing the original game data

The release contains no Vette! graphics, sound, maps, or Macintosh executable
code. You must supply the `VETTE!.img` disk image from an original Vette! 1.02
archive. The installer copies no Macintosh filesystem wrapper into the Amiga
directory: it writes the two original resource forks, byte for byte, under the
names the port opens at startup.

## One-command host install

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
saved as the ordinary Amiga files named above. The Python installer remains the
reference path because it also performs the exact-version and integrity gates.
