# VetteInstallData

A standalone C99 installer for the original Vette! 1.02 StuffIt archive.
No xadmaster, Python, host resource forks, or archive libraries are used by the
executable. On Amiga it uses dos.library and exec.library directly.

```
make -C tools/install-data
build/install-data/VetteInstallData VETTE__1.02_and_extras.sit destination
. amiga/env.sh
make -C tools/install-data amiga
make -C tools/install-data test
```

The destination may be new or an existing directory. Existing game files are
accepted only if their SHA-256 hashes match; they are never overwritten. Both
new files are validated before either is installed. Failure rolls back newly
installed files and removes this run's private temporary directory. The source
archive is opened read-only. Ctrl-C cancels at the next buffered I/O operation.

The helper supports StuffIt 5 entries with methods 0 and 13 (including all five
fixed table sets and dynamic tables), NDIF version 11 raw/ADC/free extents, and
classic HFS. It reads the catalog and extents-overflow leaf chains, selects the
Color folder, then extracts only the two resource forks. Fragmentation of the
extents-overflow file itself is rejected. Unsupported methods, encryption,
ambiguous files, inconsistent bounds and checksums fail explicitly.

Inputs are limited to signed 31-bit file offsets; decoded NDIF images and image
forks are limited to 32 MiB. No recursion, variable-length stack arrays, libc on
Amiga, stack enlargement, or whole-image allocations are used. Large buffers are
static BSS, automatically released with the executable's segment list. The two
decompressors share a 64 KiB history window and 4 KiB input/output buffers.
The Amiga build emits `.su` stack reports and has no unresolved runtime helpers.

Measured on FS-UAE A1200 / Kickstart 3.1, with `Stack 4096`: a complete extraction
finished successfully with 3,276 bytes of stack watermark intact (820 bytes used,
including the measured OS-call path). Both final file hashes matched the Unix
reference and all temporary files were removed. Production BSS is 104,220 bytes;
the HUNK executable is approximately 34 KiB. `test_amiga.py` reproduces this test
after sourcing `amiga/env.sh`. It uses a separate directory and only stops its own
emulator process.

The installer needs about 12 MiB free disk space in the destination volume
(excluding the downloaded archive); temporary files are stored on disk there,
not in RAM:. Final original data totals 2,164,887 bytes.

## License and references

This helper (all C, headers and startup assembly in this directory) is available
under LGPL-2.1-or-later; see COPYING.LIB. It is separate from the game executable.
The release includes its complete source and build files so it can be modified
and rebuilt without the game or any XAD library.

StuffIt 5 layout and method 13 decoding were implemented with reference to:

- https://github.com/MacPaw/XADMaster/blob/master/XADStuffIt5Parser.m
- https://github.com/MacPaw/XADMaster/blob/master/XADStuffIt13Handle.m

`sit13_tables.h` adapts the format tables from the latter, copyright
2017-present MacPaw Way Ltd., LGPL-2.1-or-later. The decoder uses our own bounded,
iterative prefix-tree implementation and platform adapters. There is no XAD
runtime dependency. NDIF and HFS parsing follow the existing Python reference
tools in this repository. SHA-256 follows FIPS 180-4.

Tests require the user's original archive under the ignored tmp/ directory.
No game data or test extraction is distributed. Production validation uses the
two existing exact SHA-256 fingerprints, not the unidentified NDIF checksum.
