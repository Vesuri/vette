# Amiga architecture

## Original game and compatibility layer

The executable loads the two original resource forks from disk before hardware
takeover. All eleven Color CODE resources are resident. The loader allocates
31,272 bytes below A5 and 4,104 above, patches all 509 jump-table entries to
absolute jumps, runs the shipped %A5Init initializer and installs the Line-A
handler on vector $28. See [static-map.md](static-map.md).

Macintosh low-memory references are byte-checked and redirected to semantic
shadows in/near the A5 allocation; Page 0 never overwrites Amiga vectors or Exec.
The Resource Manager supplies original resources, not a repacked custom bundle.
QuickDraw, input, timers and sound implement the services actually used by the
game. Unknown traps produce a named loud stop rather than a guessed success.

The port deliberately bypasses copy protection and removes the Macintosh menu
bar/desktop. Window dragging is inert. Optional desktop UI and network play
are not implemented. Original physics, resource interpretation and game decisions
remain in the shipped instructions.

## Display

`src/platform/amiga/VetteScreen.*` owns the custom display registers.

- Four bitplanes / 16 colors, selected once from the retained HIRES word.
- HIRES: PAL 512×384 interlaced; the 512×320 game has 32-row vertical margins.
- Default lores: 368×283 with a window-specific origin in the 512×320 game
  surface (table below). Fetch 46 bytes per plane from `(32 + top) * 256 + left/8`;
  modulo 210 advances one 256-byte bitmap row.
  DIW is (97,29)..(465,312), DDF $28..$d8, with no horizontal scroll.
  RKM table 3-13 places PAL blanking stop at $1D: lines 29–311 provide
  the full 283-row window, with stop line 312 exclusive.
- Lores C2P and dirty synchronization touch only that crop; both assembly and
  C conversion retain the full source/destination strides.
- Each row has four consecutive 64-byte planes: 256-byte interleaved stride.
- Double-buffered chip-memory bitmaps and copper lists.
- Explicit dirty-rectangle list (up to 32), normalized to C2P alignment.
  No shadow framebuffer, tile cache or full-screen pixel comparison.
- The back buffer inherits uncovered rectangles changed in the previous update
  before new conversion; partial updates must not leave two-frame-old pixels.
- Completed buffers are published in VBI. Interlace pointer offsets and modulos
  must agree with field parity. Build the inactive copper list, then install it
  during blanking; never edit active pointer words mid-field.
- Copper/plane/sprite publication comes first in the VBI, before input and audio.

The Window Manager retains the original WIND resource ID to choose the lores
viewport; it does not infer scenes from pixels or change game decisions.

| Screen | WIND | Crop left, top |
| --- | --- | --- |
| Intro | 333 / 222 | 80, 0 |
| Garage | 140 | 128, 26 |
| Opponent / difficulty | 131 | 144, 8 |
| Course | 150 | 64, 37 |
| In-game | 129 | 80, 32 |

Other windows use 80,0. A changed viewport forces a complete C2P of its newly
visible area and drops the previous crop's synchronization rectangles. VBI
publishes the new bitmap, origin and mouse visibility together. The pointer is
allowed only in garage, opponent/difficulty and course windows; original cursor
hide/show calls still apply within those screens. It stays hidden in the intro,
driving and other windows in both display modes, while mouse input remains active.
Bytes outside the current crop retain their previous contents.

The mouse pointer uses interlaced even/odd images in HIRES and all sixteen rows
in lores, with coordinates offset by the crop. Crop changes preserve its physical
screen position while adjusting Macintosh coordinates and redirected mouse
globals together. The hotspot is clamped to the visible viewport. It updates each
field independently of game rendering. AGA uses matching HIRES/LORES SPRRES
settings. OCS/ECS hires cursors sample every second source column into eight
lores sprite pixels to preserve their proportions; ECS cannot force hires
sprites in a hires playfield. The logical hotspot is unchanged. The chipset is
identified through graphics.library before takeover. Unused sprite channels
point to empty sprites, and sprite priority keeps the pointer in front of the
playfield.

Source ColorTables and Palette Manager operations determine index translation.
Do not infer palette fixes from car identity or screenshots. The original
Macintosh gamma/display model is described in [mac-hardware.md](mac-hardware.md).

## Timing and input

The VBI advances `g_vbiCount` once per PAL field and Macintosh ticks at 60 Hz
(one extra tick every fifth field). CIA input updates the live KeyMap and mouse
state. Original VBL callbacks run at safe user-mode trap-return boundaries,
never directly from the hardware ISR.

Presentation does not itself stall original code: a pending buffer causes the
present call to return. Selected animation loops and the driving loop therefore
have explicit maximum-rate pacing. See [frame-pacing.md](frame-pacing.md);
slow rendering incurs no additional wait.

Cursor aliases coexist with original keyboard bindings. Do not consume physical
key state solely through an event queue: held steering/throttle keys are sampled
by original code independently of event delivery.

## Audio

Bogas is bridged to Paula rather than software-mixed. Three logical contexts
share four hardware voices. Source volume range 0..300 maps to Paula 0..64;
relative volume matters, not RMS normalization. Preserve voice ownership,
finite sample completion, looping semantics and clean channel retirement.

Paula restarts and idle-channel clearing must not move ahead of copper work.
Stopped channels output digital zero. Timed events continue while the main
thread waits for refresh.

## Lifecycle

Startup supports both Shell and Workbench. The Workbench startup message is
replied to using the protected final handback path. Resource files and score
state are loaded before takeover; pending score writes happen after OS restoration.
Allocation ledgers and shutdown release resident code/resources, pointer/handle
storage, display, sprite and audio buffers and input/OS resources.

Normal Control+left-mouse exit runs game cleanup and saves scores. WHDLoad F10
aborts immediately and cannot perform deferred game saves. The slave supplies
Kickstart/DOS and its own stack; see [whdload.md](whdload.md).

Framework modifications and upstream provenance remain documented in
[`framework/UPSTREAM.md`](../src/platform/amiga/framework/UPSTREAM.md).
