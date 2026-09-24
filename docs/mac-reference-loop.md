# Macintosh reference

The unmodified Color 1.02 game under MAME is the fidelity reference. ROMs, system
images, original resources and captures stay local under ignored `ref/` and
`tmp/`; none is distributed.

## Local setup

The reference configuration is MAME `mac2fdhd`, 8 MB RAM, `mdc48` video,
System 6.0.8 with 32-bit QuickDraw and a 16-color desktop. The automation expects
a prepared boot/game volume at `ref/mame/hd/608_2GB_drive.hd`; ROMs go in
`ref/mame/roms`. Supply these yourself. Original media requirements and filenames
are not a substitute for rights to use the originals.

`hfsutils` can copy files onto classic HFS images on hosts that no longer mount
HFS. Preserve both forks (for example `hcopy -m` for MacBinary). The source
archive's NDIF image also needs both forks; see [installation](install-original-data.md).

## Running without taking over the host screen

```sh
mkdir -p ref/mame/snap ref/mame/cfg ref/mame/nvram tmp
timeout -k 5 300 env SDL_VIDEODRIVER=dummy \
  mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
  -ramsize 8M -hard ref/mame/hd/608_2GB_drive.hd \
  -video none -sound none -window -skip_gameinfo -nothrottle \
  -seconds_to_run 120 -snapshot_directory ref/mame/snap \
  -cfg_directory ref/mame/cfg -nvram_directory ref/mame/nvram \
  -autoboot_script tools/mac_launch.lua
```

`-video none` alone is insufficient to prevent a fullscreen window.
Explicit cfg/nvram directories also prevent state leaking into the repository.
Terminate only the process belonging to the current run.

## Automation and comparisons

`mame_mac_input.lua` is the shared launch/input library. `mac_launch.lua`
observes the intro; `mac_play.lua` drives the UI. `mac_probe_model_indices.lua`
provides the state/palette/traffic/audio captures used by the root Makefile.
Inspect their environment switches rather than creating duplicate one-off drivers.

- `make driving-motion-reference`: moving state/viewport reference.
- `make driving-view-reference VIEW=F3`: alternate views.
- `make driving-audio-reference`: original Bogas events and waveform.
- Matching `*-capture` and `*-compare` targets collect/check Amiga output.

Match game state, not ordinal frame numbers: CPU speeds and presentation timing
differ. Fix the diagnostic RNG seed consistently on both sides when a comparison
needs reproducible traffic. Saved artifacts are local evidence; successful checks
do not imply that an unexecuted route was tested.

## Address and timing cautions

- Code identity is (live segment, offset), not a raw address saved after shutdown.
  Finder/System code can occupy earlier game addresses; attribute callers live.
- Mask handles to 24 bits when the reference system runs in 24-bit addressing mode.
- The reference Mac II's supervisor trap parameters start at SP+8; the port's
  own original 68000-style Line-A frame uses its separate documented convention.
- Macintosh ticks advance at 60 Hz. MAME `-nothrottle` changes host execution
  speed, not emulated-time quantities.
- The game needs 16 colors and sufficient memory. Diagnose its error path rather
  than dismissing a resource/memory dialog as another renderer feature.
