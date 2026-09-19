# Stage C — live trap-layer bring-up

Stage C runs the original resident `CODE` segments and advances one loud stop at a time. The
acceptance boundary now includes the game's complete animated and audible intro; this document
records the standalone port's execution order, which is now known to differ from the earlier MAME
first-use table.

## Current checkpoint

With the opt-in first-poll intro skip, the Amiga run disposes the intro window, paints the exposed
desktop, completes post-intro memory and menu setup, and remains in the game's event loop with no
loud stop. The production `Button` implementation reads the Amiga CIA left-button bit; the
synthetic click exists only in `SKIP_INTRO=1` development builds.

The full-sequence acceptance run passes on both A4000/040 and the target A1200 with 2 MiB chip and
8 MiB fast RAM. Both end with every tracked phase flag set, the tram at `(310,0)-(440,134)`, one
completed logo composite, and byte-identical final chunky framebuffers. The audio probe reaches
state 2 after `Signature` finishes, confirming that the opening loop has been replaced and the
centred Paula music pair has stopped before the loud stop.

For post-intro trap work, `make SKIP_INTRO=1` makes exactly the first `Button()` poll report a press
and then returns permanently to the real CIA mouse state. This is an opt-in development build; the
default remains the full intro used by the acceptance probes. Because the Makefile does not track
flag changes, switch configurations with a clean rebuild.

An earlier run appeared to advance through `GetDItem`, `SetIText`, `InsetRect`, and
`FrameRoundRect`. That was a false branch: the fixed four-entry `GWorldSlot` table filled while
Exec still had ample memory, so the fifth `NewGWorld` returned `memFullErr`. The game translated
that into error ID 04, "NewGWorld error, Offscreen allocation error," and opened dialog 700. The
table now has capacity for all six simultaneously live offscreen worlds. Those four error-dialog-
only traps are deliberately unimplemented again, so a regression stops at `GetDItem` and exposes
the upstream failure instead of teaching the port to render it.

Target 1 now passes its pixel boundary. At the first `Button` poll, `amiga/stage_c_capture.gdb`
captures the game-produced chunky surface, the converted chip-RAM back buffer, and the copper
colors before and after the next VBI swap. `tools/verify_stage_c_intro.py` proves:

- all **163,840 displayed pixels** match the Macintosh frame (the game's physical CLUT slot
  numbers differ, so the comparison is by the OCS color each index selects);
- all **98,304 display bytes** match an independent host conversion: 32 black rows,
  81,920 bytes of centred game image, then 32 black rows;
- the post-VBI front buffer is exactly that planar image; and
- the copper contains those 16 colors in `COLOR00` through `COLOR15` order.

The exact framebuffer match uses Macintosh screen crop `(64,91,512,320)`. The production binary
no longer embeds the old Stage A framebuffer capture: it starts with a black 512×384 display, and
the first visible artwork is the game-produced QuickDraw surface centred vertically. That settles
which source rows contain the game image but
does not by itself explain the original 323-row destination rectangle; that geometry question
remains separately queued.

Animation presentation uses a bounds-only dirty rectangle. `DrawPicture`, `CopyBits`, `EraseRect`,
and `FrameRect` union their destination bounds only when their resolved destination pixels are the
visible screen; GWorld composition must not dirty the display. C2P expands the horizontal bounds to
16 pixels and converts only that area. Double-buffer coherence is maintained by copying the
previous frame's dirty planar rectangle from front to back before applying the next one. The hot
path no longer computes a whole-frame diagnostic checksum.

The intro's aligned `srcCopy`, `srcOr`, and `srcBic` operations stay in packed 4-bpp form. The
clipped path intersects both source and destination bounds before copying and retains memmove
ordering for overlapping GWorld rectangles; boolean transfers combine packed bytes directly even
when a sprite crosses the left or bottom clip edge. The general scaling/odd-alignment path remains
the correctness fallback.

The complete intro sound cue set is now driven by the original code's own Bogas one-shot flags.
`Opening song` loops, centred on two Paula voices, while `cable car bell`, `Engine`, and `mic` use
the two effects voices and therefore layer over rather than terminating the piano. At the logo cue,
`Signature` replaces the opening loop on the centred pair, stops the engine, and plays once.
Instrument bytes come from the converted `INST` resources; short instruments
have their eight-byte Bogas header removed before DMA. All five play at PAL period 319, the closest
Paula rate to the measured Macintosh 11.127 kHz playback.

The cable-car callback has no terminal branch and assumes the remaining intro work completes by the
time its downhill pass reaches the lower-left edge. That assumption fails on the slower compatibility
path: it keeps consuming frames and walks the tram completely offscreen. Once its destination crosses
left zero, the port restores the exact `(310,0)-(440,134)` endpoint and retires only that callback.
This both preserves the intended stopped tram and lets the car/singer/logo callbacks make progress.
The logo originally has an absolute tick deadline while the Corvette approach and singer/mic motion
advance per completed draw; on an A1200 the former can overtake the latter, even within one slow
callback pass. The compatibility layer therefore parks the logo deadline until the Mac code raises
its own mic-hit flag, then releases it ten ticks later. The first logo pass builds the complete
VETTE composite with five `CopyBits` calls. Its later ten-tick callbacks repeat those same rectangles
without changing their geometry, so the compatibility layer retires the redundant redraw only after
that first pass completes and starts the original 600-tick hold from there. The exit timer therefore
cannot strand a slow target on an intermediate Corvette frame.

The successful first-use order is:

1. `BlockMove`
2. `UnLoadSeg`
3. `GetResource`
4. `InitGraf`
5. `InitFonts`
6. `InitWindows`
7. `InitMenus`
8. `TEInit`
9. `InitDialogs`
10. `InitCursor`
11. `GetToolTrapAddress`
12. `NewPtrSysClear`
13. `OpenResFile`
14. `MaxApplZone`
15. `FreeMem`
16. `GetPort`
17. `SysEnvirons`
18. `GetGDevice`
19. `MoveHHi`
20. `HLock`
21. `CurResFile`
22. `UseResFile`
23. `NewPtrClear`
24. `GetNewCWindow`
25. `MoveWindow`
26. `SetPort`
27. `GetNewPalette`
28. `GetCTSeed`
29. `SetPalette`
30. `ActivatePalette`
31. `ShowWindow`
32. `SelectWindow`
33. `BeginUpdate`
34. `EndUpdate`
35. `TextMode`
36. `GetCursor`
37. `SetCursor`
38. `GetNewDialog`
39. `DrawDialog`
40. `QDExtensions` (`NewGWorld`, `LockPixels`, and `NoPurgePixels` selectors now exercised)
41. `RecoverHandle`
42. `Delay`
43. `NewPtrSys`
44. `VInstall`
45. `NewHandle`
46. `HUnlock`
47. `GetTrapAddress`
48. `SetTrapAddress`
49. `GetHandleSize`
50. `PtrAndHand`
51. `GetNamedResource`
52. `HNoPurge`
53. `CmpString` / `EqualString`
54. `SetHandleSize`
55. `DisposeDialog`
56. `GetPicture`
57. `DrawPicture`
58. `PenSize`
59. `PenMode`
60. `FrameRect`
61. `CopyBits`
62. `EraseRect`
63. `ClipRect`
64. `Button`
65. `HPurge`
66. `DisposeWindow`

`InitGDevice` is also exercised before the current stop; its late discovery is recorded as depth
67 rather than inserted into this historical first-use list without a fresh trace. The measured
post-intro continuation is:

68. `PaintBehind`
69. `PurgeMem`
70. `CompactMem`
71. `DisableItem`
72. `NewMenu`
73. `AppendMenu`

74. `AddResMenu` (the requested `DRVR` type has no entries in either packaged resource fork)

75. `InsertMenu` (ordered menu-bar entries; `beforeID == -1` retains hierarchical menus off-bar)

76. `GetMenu` (validated packed `MENU` resource cloned into a mutable movable handle)

77. `DrawMenuBar` (visible inserted titles and separator; hierarchical menus remain off-bar)

The menu bar uses an explicit compact compatibility alphabet because the two shipped resource forks
do not contain the Macintosh System file's Chicago bitmap font; it does not claim font-level pixel
identity. The current loud stop is `ReleaseResource`, confirmed in `Score+$0A74` by the depth-77
run.

78. `ReleaseResource` (invalidate the archive-backed master pointer; permit a later reload)

The next loud stop is `FlushEvents` at `Main+$1F36`. A later `UnLoadSeg` originally made this report
depth 2 by assigning its historical row; the handler now advances monotonically like every other
implemented trap.

79. `FlushEvents` (empty Macintosh event queue; live hardware input remains separate)

The current loud stop is `SystemTask` at `Main+$29E6`, immediately before `GetNextEvent`, confirmed
by the depth-79 run.

80. `SystemTask` (service compatibility VBL work and present accumulated dirty pixels)

The current loud stop is `GetNextEvent` at `Main+$29F2`, confirmed by the depth-80 run. Because
`SystemTask` now presents dirty pixels, the post-intro screen is no longer left black while the main
loop starts.

81. `GetNextEvent` (complete `nullEvent` record for the measured empty-queue poll)

After this call there is no next loud stop in a 45-second event-driven run: the game remains in its
main loop polling the event queue. `GetNextEvent` samples `JOY0DAT` as wrapping signed deltas,
accumulates and clamps them to the 512×320 Macintosh surface, returns the live point and `btnState`
in every record, and emits masked `mouseDown`/`mouseUp` transitions.

The CIA-A serial-port interrupt is also owned by a 32-entry keyboard edge queue installed before
Exec is forbidden. Each edge records the modifier state at interrupt time, avoiding a lost Shift
or Command when a complete press/release happens between Macintosh polls. `GetNextEvent` translates
Amiga matrix positions into Macintosh ADB virtual-key codes and character codes for letters,
number-row punctuation, editing/navigation keys, F1–F10, Help, and the four modifiers; key-down and
key-up respect the requested event mask. A 20-second skip-intro run reached the stable depth-81
loop with the keyboard vector installed and no loud stop. The next test is a real garage
interaction rather than another idle soak.

`make SKIP_INTRO=1 GARAGE_CLICK=1` provides that repeatable interaction without changing a
production build. It emits one ordinary mouse-down/up pair at the reference run's Macintosh global
point `(357,252)`, the garage screen's ACCEPT button. Live Amiga coordinates are relative to the
displayed crop, whose Macintosh origin is `(64,91)`; `EventRecord.where` now adds that origin and
therefore reports the global coordinates the original Window Manager expects. The first scripted
click reached `$A924` (`FrontWindow`) in `Main+$0C9E`.

82. `FrontWindow` (first visible window in the maintained front-to-back chain)

The next loud stop is `$A871` (`GlobalToLocal`) at `Main+$0CB4`, immediately after the game installs
the front window's port. That ordering confirms this is the normal click hit-testing path rather
than an error dialog.

83. `GlobalToLocal` (subtract the displayed Macintosh crop origin `(64,91)` from the event point)

The game then enters its garage control hit-test loop and stops at `$A8AD` (`PtInRect`) in
`Main+$0A1C`.

84. `PtInRect` (signed QuickDraw coordinates with exclusive bottom/right edges)

The ACCEPT point is inside its control rectangle. The next loud stop is `$A8A4` (`InvertRect`) at
`Main+$0A2E`; the following shipped instruction sequence calls `StillDown`, identifying this as
pressed-button feedback rather than unrelated screen decoration.

85. `InvertRect` (clipped packed-4-bpp complement, dirtying only the affected display bounds)

The next loud stop is `$A972` (`GetMouse`) at `Main+$0A38`. It is inside the pressed-button tracking
loop and requests a current local point; the earlier `$A871` call transforms the event record's
already-captured global point.

86. `GetMouse` (current crop-relative point in the active graphics port)

The next loud stop is `$A973` (`StillDown`) at `Main+$0A60`, after the game retests the current
point against the same ACCEPT rectangle and restores the pressed visual state.

87. `StillDown` (live CIA left-button state; the scripted press observes the real released state)

After `StillDown` returns false, the garage control tracker completes and the game returns to its
`GetNextEvent` loop. A 20-second skip-intro/scripted-click run produced no further loud stop and
ended at depth 87. The next check is a framebuffer/state capture: absence of a trap establishes
control-flow health, but does not by itself identify which front-end state ACCEPT selected.

`amiga/garage_capture.gdb` now performs that settled-state capture, and
`tools/render_amiga_chunky.py` renders the packed surface with the live OCS palette. The captured
image remains the same garage/car-selection screen: ACCEPT is no longer inverted, and no later
screen has replaced it. That visual result did not mean the caller missed the click.

`amiga/garage_control.gdb` breaks immediately after the shipped six-rectangle tracker returns.
The deterministic point is `(v=161,h=293)`, the hit rectangle is exactly
`(top=150,left=266,bottom=169,right=313)`, and the tracker returns zero-based index 5. The caller's
index-5 branch draws PICT 17619, changes its state word from mode 0 to mode 1, and returns to the
event loop. Mode 1 dispatches a separate table of three rectangles. The apparently unchanged
capture is therefore an intermediate garage state; the next deterministic step is to measure and
select the forward control from that second table.

The three mode-1 rectangles are `(50,373)-(88,453)`, `(94,373)-(131,453)`, and
`(137,373)-(175,453)`, exactly covering the three license plates drawn on the right side of the
garage. `GARAGE_CLICK=1` now emits a second ordinary mouse-down/up pair at local `(413,69)`, inside
the top plate. The original tracker returns index 0 and enters the common post-garage branch at
`Main+$0FC8`. `amiga/garage_control.gdb` verifies both indices and both rectangle tables. A
20-second warped `stage_c.gdb` run produced no loud stop after this transition and remained at
depth 87, so the next diagnostic is a code-boundary progress probe rather than a longer blind run.

`amiga/garage_transition.gdb` now marks one-shot boundaries through that branch. It proves the
handler enters its plate animation at `Main+$10AA`; the delay is composition, not a parked event
loop. The moving image uses a 512×84 background source, a 290×84 plate and a 290×84 mask, with the
plate destination initially at `(252,105)-(336,395)`. Because source x=0 and destination x=105
have opposite nibble alignment, both same-PixMap `srcOr` and `srcBic` missed the aligned packed
path and performed 48,720 pixel operations per frame. `CopyBits` now assembles those shifted
sources one packed destination byte at a time and chooses horizontal and vertical memmove order
when the moving destination overlaps its source. The build audits pass. The animation itself
still intentionally polls `Button`, giving deterministic bring-up a faithful, bounded way to skip
it after proving this path.

For `GARAGE_CLICK=1` only, `Button` now reports one press after the two garage selections. This is
not a control-flow patch: it takes the exact user-skip branch already present in the shipped plate
animation. Production and plain `SKIP_INTRO=1` builds are unchanged. The next 20-second A1200 run
exits immediately through the loud-stop breakpoint at `$AA39`, `Main+$132C`, still at implemented
depth 87. Its caller has reserved two long result slots and pushed a zero word before the trap;
the operation and ABI are the next measured implementation task.

The classic trap table identifies `$AA39` as Color Manager `MakeITable`, whose signature is
`MakeITable(CTabHandle, ITabHandle, short)`. The caller's stack is exactly
`(cTabH=NIL, iTabH=NIL, resolution=0)`: use the current graphics device's CLUT and inverse table at
its preferred resolution. The emulated screen GDevice now owns a permanent 4-bit inverse-table
handle, advertises `gdResPref=4`, and `MakeITable` fills its 4096 byte RGB cube with the closest
live CLUT index while copying the CLUT seed. Because each inverse-table axis is itself only four
bits, the builder compares the already-quantized RGB nibbles and caches the CLUT components before walking
the cube; it does not repeatedly perform 16-bit component reads and 32-bit distance arithmetic on
the 68020. The build audits pass and a short A1200 run clears the table construction, reaches depth
88, and enters the following picture renderer. It does not reach another trap within 20 seconds;
the interrupt lands in
`drawPackedPictureBits` while decoding byte 25,010 of a 58,484-byte PICT for the driving setup.

A pre-decode probe corrected that incomplete timeout snapshot: the picture resource is 63,940
bytes and its first packed opcode is a 4-bit, 256-byte-row strip with source and destination
`(0,0)-(20,512)`. The picture frame and requested target are both `(0,0)-(323,512)`. The generic
renderer had therefore walked a 512×323 target for every strip and evaluated two scale divisions
for every touched pixel, even though both mappings were one-to-one. A guarded path now clips and
copies byte-aligned, unscaled 4-bit rows directly. The build audits pass, the picture completes in
the next short A1200 run, and the loud stop advances to a mode-6 `CopyBits` at `Main+$199A`.

That transfer is the Boolean QuickDraw `notSrcXor` operation: each destination bit is XORed with
the inverse of its source bit. `CopyBits` now applies it in the aligned packed-byte path and in
the clipped, odd-nibble, overlap-safe, and scaled fallbacks. Both standing audits pass. The next
short A1200 run clears the drawing call and stops at `EnableItem(menu, 7)` (`$A939`,
`Main+$13BE`), immediately before the game's existing `DisableItem(menu, 5)` call.

That pair is the normal post-garage menu-state transition, not an error path: both calls use
the same live menu handle, enabling item 7 and then disabling item 5. `EnableItem` now mirrors the
existing `DisableItem` implementation by changing only the menu record's enable bitfield; it does
not draw or synthesize menu UI. The next short A1200 run produces no loud stop and reaches
`presentMacFrame` with a live dirty rectangle `(165,177)-(316,505)`, so execution has advanced into
active game graphics. The next boundary is a one-shot capture of that first presented frame.

That capture exposed the vehicle/performance selector and the rotating car had the characteristic
cyclic corruption documented by M.A.C.E.'s
[VetteHack investigation](https://mace.home.blog/vettehack/). Color VETTE! assumes the pre-System
7.1 `NewGWorld` row stride: round the pixel width to a four-byte boundary and add four bytes of
slop. The port had rounded correctly but omitted the slop, advertising 256 bytes for a 512-wide
4-bit GWorld where the game advances by 260. `NewGWorld` now uses the original formula and allocates
the corresponding buffer. `amiga/driving_capture.gdb` captures the first measured selector update;
the rendered chunky surface shows a coherent Porsche model and identifies the state as the vehicle
selector, not yet the road-driving loop.

The selector's five measured local rectangles are Porsche `(71,291)-(81,350)`, Lamborghini
`(71,409)-(81,482)`, Testarossa `(151,285)-(161,356)`, Corvette ZR-1
`(151,429)-(161,460)`, and ACCEPT `(148,184)-(161,241)`. `GARAGE_CLICK=1` now adds a Corvette
click/release and ACCEPT click/release after the two existing garage selections; normal builds are
unchanged. A bounded run verifies that the Corvette selection is dispatched and reaches the next
loud stop, an existing `DrawPicture` call at `Main+$1728` whose PICT resource is not yet accepted by
the decoder.

`amiga/pict_failure.gdb` identifies that resource as application-fork `PICT 6398`, 2,120 bytes,
drawn at `(10,300)-(110,493)`. It begins with version-1 long picture comments (`$A1`); the
version-2 decoder already understood their kind/length/payload framing, but the version-1 decoder
did not. Version 1 now skips the measured comments with bounds checks, and the failure probe records
the exact unsupported opcode and byte offset. The next boundary is `$09` (`PenPat`) at byte `$29`.
Enumerating the resource shows it is the visible course-description panel: pen pattern/size, short
lines, rounded rectangles, and three text records rather than another packed bitmap.

The version-1 renderer now executes exactly that enumerated subset. It tracks pen pattern and size,
draws short lines, paints and frames the measured rounded rectangle, and renders the three text
records with the same explicit compact-font fallback used for menu titles because the Macintosh
System font is not present in the game resources. Scaling remains a loud failure; `PICT 6398` has
identical 193×100 source and destination extents and needs only translation. Both build audits pass,
and the next bounded run completes `DrawPicture` before stopping at the following `$A8A2`
(`PaintRect`) call at `Main+$173A`.

`amiga/stage_c.gdb` breaks on `VetteScreen::showLoudStop`, after the report is complete, and prints
the depth, trap identity, selector, runtime `(segment, offset)`, absolute PC, USP and its first
words, all data/address registers, and nearby instructions. It then exits, so `diag_run.sh` stops
FS-UAE immediately instead of waiting out its wall-time ceiling. The expanded report matters now
that Macintosh support code copied into movable memory is calling traps outside the 11 resident
`CODE` ranges. If the runner instead interrupts a healthy long-running loop at its safety ceiling,
the script reports that no loud stop was observed and does not print zeroed trap fields as a false
stop. The build's `muldiv-audit` and `probe-audit` are clean.

## Page 0 is not mapped

Macintosh low-memory globals overlap the Amiga's exception vectors and Exec state, so mapping or
copying the lowest 32 KiB is not an option. `tools/m68k_lowmem.py` follows all 509 `CODE 0`
entries and currently finds **108 reachable absolute references to 17 distinct Page-0 locations**.

The port handles them as semantic globals. Each executed absolute-short instruction is first
validated against its shipped opcode, then rewritten at the same width to an A5-relative shadow:

| Mac global | Macintosh address | shadow | first consumer |
|---|---:|---:|---|
| `Ticks` | `$016A` | `0(A5)` | `Main+$1EEC` |
| `RndSeed` | `$0156` | `4(A5)` | `Main+$0570` |
| `WMgrPort` | `$09DE` | `8(A5)` | `Main+$08A6` |
| `GrayRgn` | `$09EE` | `12(A5)` | `Initialize+$08C4` |
| `KeyMap` | `$0174` | `16(A5)` | `Main+$2B54` |

Sixteen encoded instructions (ten reachable in the current control-flow inventory) read `GrayRgn`,
using both `MOVEA.L abs.w` and `MOVE.L abs.w,-(SP)`. They are all redirected to the same `12(A5)`
shadow by an exact-count scan.
The stack form was not covered by the first three explicit relocations and was only exposed once
`PaintBehind` became reachable.

All 87 direct `Ticks` reads use the same absolute-word encoding and are redirected to `0(A5)`.
The driving code contains three exact `LEA $0174,A1` sites: two VBL callbacks poll selected bytes
and `Main+$2D26` snapshots all 16 bytes. They therefore share a complete 16-byte KeyMap shadow at
`16(A5)`, immediately below the jump table at `32(A5)`. Amiga raw-key transitions update this
shadow independently of whether the Event Manager accepts a corresponding key event.

This preserves the original code flow without touching Amiga low memory. More shadows are added
only when execution reaches them; the inventory shows that most remaining references are `Ticks`,
mouse/key state, and repeated `GrayRgn` reads.

## Resource and handle boundary

The host converter packs both resource forks into the pointer-free, big-endian `VRS1` archive.
The target Resource Manager searches the selected fork and returns real double-indirect Handles.
Archive payloads are permanently resident: `MoveHHi` validates such a handle but needs no physical
relocation, while `HLock`/`HUnlock` record lock state. The emulated heap now also owns real movable
Handles: `NewHandle` creates a stable master pointer, `GetHandleSize` reports the logical payload,
and `PtrAndHand` grows and appends while updating that master pointer. `RecoverHandle` covers both
heap allocations and resident resource payloads. `OpenResFile` performs classic case-insensitive
filename matching, which matters because the shipped Pascal name is `Vette!.DATA`.

The copied support code also installs a `VBLTask`. `VInstall` maintains the classic linked task
records. The callback cannot be invoked directly from Amiga's supervisor-mode VERTB ISR: a Line-A
trap made there has a different exception/USP context from the user-mode frame expected by the
bridge. Delivery therefore belongs at a later user-mode scheduling point, not inside the hardware
interrupt.

The scheduler ages every installed task before selecting a callback, then rotates its selection
point after delivering at most one callback at the next user-mode trap return. Every handled
Line-A return is a safe point, not only `SystemTask`: the road renderer can spend a long interval
making only QuickDraw and `BlockMove` calls. An explicit active-callback flag prevents a trap nested
inside a callback from scheduling another callback recursively. The earlier return-on-first-due
loop let the one-tick sound task permanently starve the three-tick driving task.
`amiga/driving_keymap.gdb` stops after the driving callback sees held keypad 8 and verifies that it
increments the original steering/throttle global through the user-mode trampoline.

## Window and palette state

The Window Manager now builds `CWindowRecord`s from the shipped `WIND` resources, maintains the
window chain, places and shows windows, switches the current port, and brackets updates. One early
address-error run caught a pool header that made `WindowRecord` addresses odd; records now begin at
offset zero in an even-aligned slot. `WMgrPort` is intentionally an old-style `GrafPort`: the game
reads its embedded `BitMap` bounds directly when centering windows.

`GetNewPalette` loads the shipped `pltt` resource as a Handle. `SetPalette` associates it with a
window, and `ActivatePalette` realizes its 16 `RGBColor` entries into the active device table with a
fresh seed. Cursor resources likewise remain Handles until the game dereferences and installs one.

The vehicle selector exposed several Palette Manager details hidden by the intro. `SetPalette`
activates a palette immediately when its window is frontmost, and `SelectWindow` likewise activates
the selected window's palette. An earlier same-ID `WIND`/`pltt` association was removed after the
original trap trace showed no such palette-160 request or device realization. Finally, indexed
4-bit PICT pixels are mapped through their embedded color table just like 8-bit PICT pixels. A
packed-byte lookup keeps the unscaled path fast while replacing the former identity copy that made
the selector use the intro's green/yellow color assignments.

The Palette Manager chapter of *Inside Macintosh: Advanced Color Imaging* specifies the public
rules: white and black are protected, tolerant colors are considered by priority, and a requested
color may take a device entry when the existing match exceeds its tolerance. It also explicitly
declares a device `ColorSpec.value` private to Color Manager. On a device color table (`ctFlags` bit
15), the physical pixel value is therefore the array position, not the `value` field. System 6 uses
that field for flags such as protected (`$0800`) and tolerant (`$2000`). `MakeITable` now observes
that distinction instead of interpreting those flags as a pen number.

The documentation does not specify Color Manager's complete slot arbitration. We recorded it from
the unmodified game on a System 6.0.8 Macintosh in MAME rather than inferring it from screenshots.
For each physical pen 0--15, the resulting resource-entry order is:

| `pltt` | resource entries in physical-pen order |
|---|---|
| 130 | 0, 2, 15, 3, 14, 13, 7, 8, 9, 10, 11, 12, 6, 5, 4, 1 |
| 140 | 0, 2, 4, 5, 15, 14, 7, 8, 13, 10, 11, 12, 3, 9, 6, 1 |
| 131 | 0, 9, 3, 2, 15, 14, 13, 12, 4, 11, 6, 10, 7, 8, 5, 1 |

The port applies these measured layouts in Palette Manager emulation, while every RGB value still
comes from its shipped `pltt` resource. This is centralized device state: there is no Porsche/F40
detection, model-pixel scan, grid-pen rewrite, or screenshot-derived color substitution.

`NewGWorld` with null color-table and device arguments owns a creation-time snapshot of the current
device CLUT; it does not keep sharing the mutable active-window table. The rotating-car worlds are
created while the game's blue-shaded color environment is active, after which the window palette
changes. Sharing that later table made the same stored indices appear pink. Each GWorld now retains
its snapshot, PICT rendering targets its destination PixMap's table, and `srcCopy` uses a packed
color-map lookup whenever the source and destination PixMaps differ.

Distinct ColorTable handles with the same `ctSeed` describe the same color environment and copy
indices directly. This preserves the selector's initial full-surface copy. Comparing table addresses
instead remapped both phases and turned the F40 thumbnail brown.

Color matching follows the main GDevice's four-bit inverse-table resolution, comparing the high
nibble of each RGB component and retaining the first palette entry on a tie. Comparing full 16-bit
components looked more accurate but incorrectly made the selector's red-orange F40 closer to its
brown pen; Color QuickDraw's actual quantized comparison ties those candidates and selects red.

Vette also passes its offscreen GWorld ports to `SetPalette` and `ActivatePalette`. The measured
selector transition loads palettes 130, 140, then 131 and associates each with the main window and
the live worlds. These ports are not Window Manager records. Palette Manager treats tolerant colors
on an offscreen GWorld as courteous: the original System 6 run retains the GWorld's RGB entries but
synchronizes its `ctSeed` to the active device environment. Consequently `CopyBits` preserves the
renderer-authored physical indices. The same rule applies while drawing: when an offscreen table's
seed matches the screen table, indexed and direct PICT colors are realized through the active device
environment, not through the GWorld's stale RGB snapshot. This reproduces the original selector
PICT's exact logical-to-physical pen map and keeps the wood, thumbnails, green grid, and red F40
correct together. Reproducing that behavior removed the former car-specific source-table selection
and grid-pixel rewrite.

`GetNewDialog` now builds the `DialogRecord` from the shipped `DLOG`/`DITL` pair and `DrawDialog`
validates the item stream, selects the dialog port, and paints its background. `GetDItem` walks that
stream and materializes movable text handles for static-text items; `SetIText` resizes and fills them.
Offscreen QuickDraw allocates a real 4-bit `GWorld`/`PixMap` and pixel store; selectors 0, 1, and 12
are respectively `NewGWorld`, `LockPixels`, and `NoPurgePixels`.

The scoped PICT interpreter now handles the measured v2 4-bit and 8-bit indexed `PackBitsRect`, v1
1-bit `PackBitsRect`, and component-packed 32-bit `DirectBitsRect` paths. It maps embedded/direct RGB
through the active 16-color table. `CopyBits` supports the measured `srcCopy` and `srcBic` transfers,
including scaling, overlap safety, and the current rectangular clip; unsupported opcodes and modes
still fall through to the loud stop.

The first `PaintRect` after the course-description PICT is not a visible fill. At `Main+$173A`
the game passes the adjacent PICT-ID table (`6398, 5383, ...`) as a rectangle; all of it lies
outside the current 512×512 port. Classic QuickDraw clips that to an empty operation. The bridge
does the same, but deliberately leaves non-empty `PaintRect` drawing unimplemented so a later
real use still raises the loud stop.

The deterministic `GARAGE_CLICK=1` bring-up path now continues through the course selector. It
chooses the already-active Course One by sending an ordinary press/release pair to the visible
`ACCEPT` control. The resulting screen is entirely game-rendered: Bay Area map, route, four course
buttons, and the decoded course-description panel. Road setup then reaches File Manager trap
`$A007` from segment 1 + `$6074`.

That synchronous `GetVolInfo` caller reads only `ioVCrDate` at parameter-block offset 30. The
bridge returns `$D51CFD76`, measured directly from the master directory block of the shipped
`VETTE!` HFS image, and `ioResult = noErr`; it does not fabricate the unused volume fields. This
preserves the game's derivation of its `DATE` resource key. Execution then reaches QuickDraw
`Random` (`$A861`) in road setup.

`Random` uses the original QuickDraw recurrence (`RndSeed * 16807 mod $7FFFFFFF`), returns its
signed low word with `$8000` mapped to zero, and updates the Page-0 `RndSeed` shadow. No host
entropy enters the sequence. The next call is `GetDItem` for item 2 of the copy-protection dialog;
that UI intentionally remains unsupported while the registered `DATE` resource state is resolved.

The port deliberately removes that manual challenge at its application-code boundary. After an
exact check of the six original words at `Main+$05FE`, the loader substitutes the success state
(`-22782(A5) = -1`, `-22786(A5) = 0`) and returns. Those are the same globals left by a correct
answer. The requester is never allocated, while all unrelated dialog traps remain loud-stop
boundaries. Execution proceeds to `$A916 HideWindow` at segment 1 + `$2150`.

`HideWindow` changes only the measured `WindowRecord` visibility flag; it does not synthesize a
desktop repaint. That is enough for the game to retire the selector and enter segment 6, where the
next loud stop is Menu Manager `$A945 CheckItem` at `+$08CC`.

`CheckItem` traverses the classic variable-length menu item records and updates only the mark byte
(`$12` for checked, zero for clear). It performs no menu rendering. The measured clear of item 1
advances road setup to `DrawPicture` at segment 1 + `$2328`.

That call draws application-fork `PICT 146`, a 12×13 version-2 icon whose raster opcode is
uncompressed indexed `BitsRect` (`$0090`). The interpreter now shares PixMap, color-table,
rectangle mapping, scaling, and destination logic between `$0090` raw rows and `$0098` PackBits
rows. The icon completes and execution begins decoding a larger packed road asset.

The indexed-raster fast path now accepts equal-size target rectangles translated away from the
PICT frame origin. It translates each raster destination rectangle once, clips it, and copies
aligned 4-bit packed rows directly. The same geometry test also covers 8-bit indexed sources:
their bytes are palette-mapped straight into the destination's packed 4-bit pixels without running
the coordinate scaler for every pixel. This completes both the 384×48 `PICT 29556` and the unscaled
512×24 application-fork `PICT 506`. A 24-second Stage C run advances into subsequent resource
loading without reaching a loud stop; implemented trap depth remains 92.

The resource converter emits 572 directory entries sorted by `(fork,type,id)`, but exact
`GetResource` calls were still walking and decoding the directory from the beginning for each fork
in the search chain. Archive opening now verifies that ordering, and exact ID lookups use a binary
lower-bound search while preserving the current-fork-first semantics and the resource's original
master-pointer slot. The next 20-second run clears the resource scan and reaches the following
monochrome PICT raster mapper without a loud stop.

That mapper receives two `srcOr` masks. The first has a 289×92 frame, source and raster rectangle,
is translated to `(92,0)-(184,289)`, and is stored in 38-byte padded 1-bit rows. The second is
346×161, translated to `(30,160)-(191,506)`, with 44-byte rows. Both mappings are one-to-one. A
clipped unscaled path now expands each source bit directly into the destination nibble and applies
`srcCopy` or `srcOr` without four coordinate divisions per pixel. The next bounded run completes
both images and loud-stops at `$A852 HideCursor`, `Main+$268A`; implemented depth remains 92.

`HideCursor` now clears the compatibility layer's existing cursor visibility state; the Amiga
display still does not synthesize a software cursor. The verified run reaches implemented depth 93
and next stops at the matching parameterless `$A853 ShowCursor`, `Initialize+$18FA`, immediately before
that caller invokes the already implemented `FlushEvents`.

`ShowCursor` restores the same tracked visibility flag, again without synthesizing cursor pixels.
The verified run reaches implemented depth 94 and continues through the 30-second safety ceiling
without another loud stop. The call is at `Initialize+$18FA`, not FRED, and is followed by
`FlushEvents`, register restoration and `RTS` back to the event loop.

The first 30-second chunky capture appeared to be the completed driving setup canvas: the lower
portion contained the game-drawn cockpit, while approximately the upper 198 rows remained white.
That was an intermediate frame, not a stable waiting state.

`amiga/driving_gworld_capture.gdb` establishes that this is waiting for driving input rather than
missing assets. Five live GWorlds are 512×512 with the game's measured 260-byte stride. A sixth is
a deliberate 3904×144 surface with 1956-byte rows and contains the complete repeating skyline and
roadside panorama. The stride-aware `tools/render_amiga_chunky.py` renders all six without stripping
their row padding. The next deterministic input is keypad `8`, the game's acceleration control.

For `GARAGE_CLICK=1`, accepting Course One advances the deterministic UI path to phase 9 and
immediately enters road setup; there is no guaranteed subsequent UI event poll before driving.
The harness therefore holds Macintosh keypad 8 in the independent KeyMap shadow at that measured
transition. Physical keys still update both KeyMap and ordinary EventRecords. This also corrects
the earlier assumption that `ShowCursor` at depth 94 was the start-of-driving boundary: the
game-produced road renderer is already active at depth 93.

With all VBL records aged fairly, the driving callback runs instead of remaining frozen behind the
sound task. A bounded `driving_input_capture.gdb` run now catches the game copying road data into
the upper chunky surface and captures the first entirely game-drawn driving frame: skyline,
roadside panorama, traffic, rear-view mirror and cockpit are all present. No new trap was needed to
produce it; the blocker was callback scheduling, not an unimplemented drawing primitive.

`amiga/driving_motion.gdb` captures the chunky surface at two consecutive driving-task returns.
Its regression interval is 30 Macintosh ticks rather than adjacent callbacks, because several
three-tick callbacks can occur inside one renderer update. On the A1200 acceptance configuration
the held KeyMap word is `$0010`, the original throttle global advances from 3 to 21, and the two
81,920-byte surfaces differ (`f9eb1e3e…` versus `8e540ac2…`). This is a measured moving road
renderer, not two samples of the same setup canvas.

The driving renderer also uses `_BlockMove` as a direct packed-pixel primitive, bypassing
QuickDraw's rectangle calls. The bridge now intersects each destination span with `s_colorScreen`
and converts that byte range into a conservative pixel dirty rectangle. Presentation is attempted
at every handled Line-A safe point, while `VetteScreen`'s pending-frame guard limits conversion to
what the VBI can consume. At the second callback the motion probe measures 34 setup frames queued
and all 34 presented; the direct-store check below is what covers subsequent road pixels.

Most 3D pixels are written by direct 68k stores rather than `_BlockMove`, but a changed byte is not
a frame-complete signal: captures show the renderer incrementally constructing its next image.
`amiga/driving_cadence.gdb` takes two stops 300 requested Macintosh ticks apart. Without speculative
direct-store presentation, the first A1200 measurement spans 303 ticks, completes the one frame
already pending at the start, queues no new one, and advances the throttle callback to 162.

A full 81,920-byte shadow comparison at the driving task's three-tick cadence was measured and
rejected. It queued two partial updates over 336 ticks but reduced throttle progress to 48; a VBI
stack sample caught execution inside the comparison itself. Besides being expensive, it exposed
in-progress rendering as if it were complete. The correct next boundary is the original renderer's
frame-completion path, not polling the chunky surface.

A 180-second A1200 sustained-driving run reaches no loud stop at implemented depth 93, but an
exception-frame PC profile corrects the initial interpretation of where that time is spent.
`amiga/driving_pc_samples.gdb` samples the interrupted PC from the 68020 exception frame every 30
Macintosh ticks, avoiding the bias of consecutive VBI samples. Ten of its first 16 samples resolve
to `drawIndexedPictureBits` or PackBits expansion in the compatibility PICT interpreter, two to
chunky-to-planar conversion, and none to a resident game CODE segment. The long wait is therefore
still construction of the first road frame, not sustained execution of the game's 3D renderer.

The common unscaled 8-bit indexed PICT path now maps and packs two source pixels into each
destination byte rather than doing two nibble read-modify-writes. PackBits literal and repeat runs
copy or fill aligned words where possible. Both transformations preserve the decoded bytes. On the
same bounded A1200 cadence probe, callback progress rises from 162 over 303 ticks (0.535/tick) to
183 over 316 ticks (0.579/tick), about eight percent. A precomputed scaling-map experiment was
slower and was removed. The first complete-frame boundary is still the next target; partial surface
scans remain explicitly rejected.

`amiga/driving_pict_calls.gdb` records the actual first-frame raster geometry. The road canvas is
assembled from consecutive unscaled 4-bit PackBits strips with 16-entry color tables: eight strips
cover `(0,0)-(146,512)`, followed by three covering `(0,0)-(198,144)`, then dashboard and roadside
pieces. The decoder now applies the packed-byte palette table while expanding those 4-bit rows.
Repeated PackBits runs therefore translate their value once, and the later aligned raster copy is
a plain byte copy instead of a second palette walk. The cadence probe advances 183 callbacks over
302 ticks (0.606/tick), about 13 percent above the original 0.535/tick baseline. The established
intro regression still matches all 163,840 displayed Macintosh pixels and both planar buffers and
copper colors exactly.

Static tracing corrects the original completion-boundary hypothesis. While driving is active,
`Main+$29C6` branches directly back to the loop entry at `Main+$1FD2`; the `SystemTask` at
`Main+$29E6` is reached only after that driving loop exits. The first `MaxMem` at `Main+$1FEA`
therefore begins frame 1, and every subsequent hit begins a new frame only after the preceding
iteration has completed. `amiga/driving_setup_boundary.gdb` now measures between those consecutive
hits. This is a genuine complete-frame boundary, unlike a queued conversion of an intermediate
surface. Replacing the translated-row byte copy with aligned word transfers produced inconsistent
cadence and a lower repeatable control result, so that experiment was removed.

The trap bridge now uses that control-flow boundary rather than guessing from pixel activity. The
first `MaxMem` at `Main+$1FEA` arms driving presentation; later hits mark the completed 512x320
surface dirty before normal presentation runs, covering the renderer's direct 68k stores as well
as QuickDraw calls. `SystemTask` at `Main+$29E6` disarms it on exit so a later driving session again
treats its first loop entry as frame start. No surface scan or intermediate-frame presentation is
used to infer completion. The established intro differential remains exact across all 163,840
pixels, both planar buffers, and the copper palette.

Four further local PICT shortcuts were measured and rejected against the repeatable 183-callback /
302-tick fused-buffer control. Decompressing eligible rows directly into their final surface fell
to 141 callbacks over 353 ticks; testing for an identity packed palette reached 177/306; unrolling
mapped PackBits literals repeated exactly at 180/304; and an exact byte-compared single-entry
palette cache reached 177/303. Hoisting source-color reads out of the nearest-color inner loop
returned exactly 183/302 because the compiler already performs that invariant motion. These are
not viable next levers; further work belongs at the PICT-call/resource level.

`amiga/driving_pict_progress.gdb` counts raster opcodes without printing every call. Over 308
ticks, first-frame setup processes 55 4-bit opcodes / 149,312 decoded bytes and 46 8-bit opcodes /
552,936 decoded bytes. The heavy-call trace identifies 38 of the latter as 512×24 strips, each
expanding to 12,288 bytes, tiled across a 3,392-pixel-wide by 144-pixel roadside panorama; the
first strip of several rows repeats at the far edge for wrapping. A specialized decoder that
packed those rows directly from 8-bit PackBits into mapped 4-bit temporary storage regressed to
153 callbacks over 380 ticks and was removed. The resource-level repetition, not another nibble
loop variant, is now the measured optimization seam.

Host-side PICT expansion was tested at that seam and rejected. A private archive sidecar first
cached all 91 eligible 8-bit/16-color rasters (1,083,812 bytes); two identical cadence runs fell
to 123 callbacks over 322 ticks. Restricting it to the 35 unique 512×24 panorama strips and packing
two verified 4-bit source indices per byte reduced the sidecar to 215,040 bytes, but fell farther
to 108 callbacks over 315 ticks. Both variants left all 572 Macintosh resource payloads byte-exact,
and the broad version still passed the complete 163,840-pixel intro differential, so correctness
was not the cause. The measurements do not isolate archive-memory locality from the altered mapping
loop, but they do reject embedded decoded rasters as a combined strategy. The sidecar implementation
was removed; future resource-level work must preserve the control's fresh-working-memory behavior.

A target-side call cache for the three repeated wrap strips was also rejected. It remembered the
first palette-mapped draw of application PICTs 500–535 and copied a later disjoint 512×24 draw
within the same PixMap. The extra resource, destination, and palette validation on every picture
call outweighed only three avoided decodes: cadence fell to 177 callbacks over 395 ticks. That code
was removed as well. Any call-level optimization must amortize its dispatch cost across the whole
panorama rather than special-case its few repeated edge strips.

The indexed decoder formerly built its 256-entry packed-nibble palette map for every raster even
though only 4-bit PICTs can consume it. Restricting that construction to 4-bit sources removes
11,776 unused table entries from the measured 46-opcode 8-bit workload. The bounded cadence remains
183 callbacks and tightens from 302 to 301 ticks; the exact intro differential still passes all
163,840 pixels, both planar buffers, and the copper palette.

The 35 panorama resources contain only two distinct embedded color tables (29 share one, six the
other), but caching their translated 256-byte maps by destination table pointer and seed regressed
to 153 callbacks over 373 ticks. The resource classification and state path outweighed the avoided
nearest-color searches, so this cache was removed.

The 38 panorama strips now share one 12,288-byte target-side decode workspace. This retains the
decoder and resource bytes exactly as shipped, but removes one Exec allocation and free from every
512x24 PICT call. An A/B/A cadence measurement repeated the ordinary allocator control at 171
callbacks over 304 ticks on both sides; the resident workspace reached 183 callbacks over 312
ticks, improving callback progress per tick from 0.563 to 0.587 (about 4.3 percent). Pictures larger
than one panorama strip keep the ordinary allocation path, avoiding the poor locality of the
rejected megabyte-scale decoded-resource caches.

`amiga/driving_frame_phases.gdb` timestamps the original frame's control-flow milestones instead
of attributing the entire wait to whichever routine an asynchronous sample happens to catch. In
the first bounded run, the 33-picture batch finishes 177 ticks after `Main+$1FEA`, all 38 pictures
finish at 384 ticks, and execution reaches the dynamic-renderer gate at `Main+$286A` only after 773
ticks. The frame does not complete within that run. PICT expansion is therefore no longer the
whole straight-line setup cost: progress from `Main+$256C` to `Main+$286A` takes another 389 ticks,
before the still-unfinished dynamic renderer begins.

`amiga/driving_post_picture_samples.gdb` explains that apparent 389-tick gap. Sixteen of 19 samples
are still in `drawIndexedPictureBits` or its PackBits expansion, two are in complete-frame
chunky-to-planar conversion, and one is in `memset`. A repeated run recording the live callback
state shows `g_macVBLCallbackActive == 0` for all 19 samples. The callback counter advances during
the interval, but the sampled PICTs belong to later routines called synchronously by the main frame
path, not to VBL callback execution. `amiga/driving_post_picture_picts.gdb` therefore activates
after `Main+$256C` and records those later rasters directly; callback scheduling is not an
optimization target on this evidence.

That geometry probe finds six small unscaled 8-bit tiles followed by a 4-bit, 512-pixel-wide image
split into 20-row strips. Its horizontal mapping is exactly 1:1, but the enclosing vertical frame
maps 157 source rows to 156 destination rows. The former fast path required both axes to be
unscaled, so this one-row vertical adjustment sent every pixel through two horizontal coordinate
divisions. The indexed decoder now preserves the exact per-row vertical mapping while copying each
already palette-mapped horizontal row as packed bytes. On the identical milestone probe, the first
picture batch falls from 177 to 155 ticks, all initial pictures from 384 to 346, and entry to the
dynamic renderer from 773 to 503 ticks: 270 ticks, or about 35 percent of the measured time to that
gate, removed. The exact intro differential still passes all 163,840 pixels, both planar buffers,
and the copper palette.

`amiga/driving_dynamic_samples.gdb` begins at `Main+$286A` and samples only the remaining dynamic
phase. Before presentation was gated, 14 of 24 samples were in `VetteScreen::presentMacFrame`, nine
were in `CopyBits`, and only one was in resident game code. QuickDraw traps were therefore causing
dirty rectangles from an incomplete driving iteration to be converted at ordinary trap returns,
despite the newly proven frame boundary. Driving now accumulates those bounds without presenting
and performs one full conversion only at the next `Main+$1FEA` loop entry. Non-driving scenes keep
their existing trap-return cadence. The milestone times improve again, from 155/346/503 to
112/301/428 ticks, while the exact intro differential remains unchanged. A repeat of the dynamic
sampler contains no presentation samples: most stops are now in `CopyBits`, with the rest in the
original Main and Traffic segments.

`amiga/driving_dynamic_copybits.gdb` shows that remaining compatibility work is twelve repeated
`srcCopy` operations between the same two PixMaps, each covering the complete
`(0,0)-(342,512)` rectangle. Their color-table seeds differ and the resulting packed-byte map is
not identity, so a raw copy would be incorrect. `blockMove` now transfers aligned data as
longwords in both overlap directions, and the full-row `CopyBits` path treats equal-stride mapped
rectangles as one contiguous span rather than restarting address calculation for 342 rows. The
same twelve calls fall from 138 to 126 ticks, about nine percent. Dynamic samples now land in the
contiguous palette-map loop itself; row setup and partial-frame C2P are no longer the explanation.
Explicitly mapping four bytes per iteration repeats at exactly 126 ticks and is removed; the
compiler's existing loop is already equivalent for this workload. The exact intro differential
remains unchanged.

Resolving the remaining resident-code samples shows that they are not compatibility overhead:
`Main+$5208/$5246/$5266` are perspective division and clipping, `Main+$5A34/$5A92/$5D6A` are
line/polygon construction, and `Traffic+$68B4..$68BA` enters an original byte raster loop while
`Traffic+$6A62` is original transform math. Those paths remain byte-for-byte shipped code. The
remaining compatible hotspot is therefore the full-surface packed-byte palette translation.

That translation now has a separately callable clean-C oracle and a 68000 twin. The twin keeps
the 256-byte map in `A2`, performs four independent table lookups per `DBF`, and handles the final
zero to three bytes separately; `MAPPED_COPY_C=1` retains the oracle build. An isolated Amiga
executable exercises 87,551 bytes (the maximum surface span minus one, deliberately selecting the
three-byte tail) plus a zero-length call and traps on any mismatch; it passes under the local
68000 runner. `VERIFY=1 PROBES=1` additionally runs C and assembly into the same destination for
every eligible real `CopyBits`, preserves the C result, byte-compares it after assembly, and
accumulates Macintosh ticks for both arms. `amiga/mapped_copy_verify.gdb` stops after twelve such
calls. The current workstation no longer has an `fs-uae` executable, so that in-game differential
and any performance claim remain pending; do not infer a speedup from instruction shape alone.

The trap-address table is stateful. The observed `GetTrapAddress`/`SetTrapAddress` pair now records
the game's replacement for `$A9F4 ExitToShell`; routing a later invocation through that replacement
remains part of completing the trap bridge.

## Correction to the MAME log

The 51-row MAME table is a measurement of that reference run, not fabricated data, but the live
standalone path has already called setup traps missing from or much later in its first-use order.
Therefore the table's 36-trap intro count is a **floor**, not the standalone implementation total.
The reason for the tracer omission remains to be audited; Stage C uses its own loud stop as the
authoritative work queue meanwhile.
