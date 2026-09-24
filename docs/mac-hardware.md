# Original Macintosh display and runtime

This reference describes Color VETTE! 1.02, not the separate B&W executable.
The port executes the original code while providing its required system services.

## CPU, memory and timing

The recursive reachable-code sweep finds no 68020-only instruction in the
original game. That does **not** make the Amiga port 68000-compatible: its current
C2P uses 68020 addressing modes. The release therefore requires a 68020 or better.

All CODE segments use the near model. Their 509 jump-table entries and A5 world
are described in [static-map.md](static-map.md). The original reads Macintosh
system globals directly; the port redirects those accesses to private shadows
rather than reserving or overwriting Amiga Page 0.

The reference machine is a Mac II configuration with 8 MB RAM and System 6.0.8.
Ticks are 60 Hz. Some movements advance by draw iteration rather than elapsed
time; the port's explicit [pacing policy](frame-pacing.md) limits very fast CPUs
without rewriting the physics engine.

## Pixels and palettes

Color QuickDraw surfaces use packed 4-bit pixels: the high nibble is the left
pixel, the low nibble is the next. Respect each PixMap's bounds, rowBytes,
ColorTable and port origin. The game window's drawable surface is 512×320;
the Amiga centers it in a 512×384 display.

A pixel value is an index, not an RGB color. CopyBits may translate between
different ColorTables. Palette Manager activation changes the destination
relationship; direct 3D pattern writers also need the correct index mapping.
Do not infer index permutations from a particular car or palette screenshot.
Dithered panels use two indices, not a single darkened shade.

The Macintosh reference video card applies a gamma table after the QuickDraw
CLUT. The measured reference gamma is about 1.435; raw CLUT components therefore
do not directly represent the displayed screenshot colors. `fb_to_png.py` and
the resource/palette comparison tools retain the explicit conversion.
The Amiga output is limited to 4-bit COLORxx components.

The game's filled primitives choose among 32 packed-nibble raster patterns;
their selection is part of original model data. See [data-formats.md](data-formats.md).

## System services

`MacLoader.cpp` implements the reached Memory/Resource/QuickDraw/Palette/Event
and related managers. Handles and pointer ownership, resource identity, port
state and documented trap semantics matter even where a particular screenshot
would look correct without them.

The original sound interface is Bogas Driver v2.1 (`BGAS` plus `INST`
resources), not direct Paula or merely a generic Mac Sound Manager call.
The port bridges its logical contexts to Paula hardware voices without software
mixing. VBI time/input/audio service remains separate from original callbacks.

Source traces and maps distinguish observed callers from unexecuted static
sites. Optional desktop UI and communications remain unsupported and loud;
a failure-triggered dialog is not evidence that the dialog itself should be added.
