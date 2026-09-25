# Vette! — Amiga

An unofficial Amiga port of the 1991 Macintosh **Color VETTE! 1.02**, originally
published by Spectrum HoloByte / Sphere, Inc. Race a Corvette through San Francisco
against the clock and a computer opponent.

The port runs the original 68000 game code with an Amiga implementation of the
Macintosh services it uses. Graphics use native bitplanes and a hardware mouse
pointer; sound uses Paula. All four single-player courses are supported.
Network play is not supported.

## Requirements and installation

- PAL Amiga with a 68020 or better; **68030 or better and AGA recommended**.
- WHDLoad 17+, Kickstart 2.04+ on the host, and a supported Kickstart 3.1 image
  with its matching RTB file.
- The slave reserves 1 MB Chip RAM and 4.5 MB other RAM, including its ROM image.
  Allow extra memory for the host system and PRELOAD.
- Installer V43+, 3 MB destination space and 12 MB temporary space.

The release is `Vette-0.91.lha`. Open its **Vette! Install** drawer and run
**Install**. Select the destination, temporary drawer and your
`VETTE__1.02_and_extras.sit` archive. Leave that archive compressed; the included
helper extracts and validates the required data. Start the installed **Vette** icon.

No original game code/data, Kickstart image or WHDLoad binary is distributed.
See [the release ReadMe](release/ReadMe) for supported ROM filenames and full
installation instructions.

## Controls

| Key | Action |
| --- | --- |
| Arrow keys | Accelerate, brake and steer |
| 1–6 | Select forward gear |
| 0 / R | Neutral / reverse |
| + / − | Shift up / down |
| A | Automatic shifting |
| Z | Horn |
| P | Pause/options |
| Control + left mouse button | Quit normally and save scores |
| F10 | Immediate WHDLoad quit; pending scores are not saved |

Select a gear before accelerating. In FS-UAE, disable keyboard joystick
emulation if it consumes the cursor keys. More controls and game rules are in
[the playing guide](docs/manual.md).

## Building

The game uses `m68k-amiga-elf-gcc`, `elf2hunk` and vasm. The WHDLoad slave uses
external WHDLoad SDK and Amiga NDK includes; release packaging needs Python 3
and an LH5-capable LHa encoder.

```sh
. amiga/env.sh
make dist
```

This builds `dist/Vette-0.91.lha` without original game data. Tool paths, tests
and local emulator setup are documented in [development.md](docs/development.md).
The [documentation index](docs/README.md) covers architecture and data formats.

## Credits and licensing

VETTE! and its original assets belong to their respective copyright holders.
This is an unofficial fan port, not affiliated with or endorsed by them.

The standalone extraction helper is LGPL-2.1-or-later; see
[its license and provenance](tools/install-data/README.md).
That license applies to the helper only, not to the original game.
