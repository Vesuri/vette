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
| `RndSeed` | `$0156` | `4(A5)` | `Main+$0570` |
| `WMgrPort` | `$09DE` | `8(A5)` | `Main+$08A6` |
| `GrayRgn` | `$09EE` | `12(A5)` | `Initialize+$08C4` |

Sixteen encoded instructions (ten reachable in the current control-flow inventory) read `GrayRgn`,
using both `MOVEA.L abs.w` and `MOVE.L abs.w,-(SP)`. They are all redirected to the same `12(A5)`
shadow by an exact-count scan.
The stack form was not covered by the first three explicit relocations and was only exposed once
`PaintBehind` became reachable.

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

## Window and palette state

The Window Manager now builds `CWindowRecord`s from the shipped `WIND` resources, maintains the
window chain, places and shows windows, switches the current port, and brackets updates. One early
address-error run caught a pool header that made `WindowRecord` addresses odd; records now begin at
offset zero in an even-aligned slot. `WMgrPort` is intentionally an old-style `GrafPort`: the game
reads its embedded `BitMap` bounds directly when centering windows.

`GetNewPalette` loads the shipped `pltt` resource as a Handle. `SetPalette` associates it with a
window, and `ActivatePalette` copies its 16 `RGBColor` entries into the active color table with a
fresh seed. Cursor resources likewise remain Handles until the game dereferences and installs one.

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

The trap-address table is stateful. The observed `GetTrapAddress`/`SetTrapAddress` pair now records
the game's replacement for `$A9F4 ExitToShell`; routing a later invocation through that replacement
remains part of completing the trap bridge.

## Correction to the MAME log

The 51-row MAME table is a measurement of that reference run, not fabricated data, but the live
standalone path has already called setup traps missing from or much later in its first-use order.
Therefore the table's 36-trap intro count is a **floor**, not the standalone implementation total.
The reason for the tracer omission remains to be audited; Stage C uses its own loud stop as the
authoritative work queue meanwhile.
