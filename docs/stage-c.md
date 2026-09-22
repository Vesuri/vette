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
which source rows contain the game image.

The first intro `_DrawPicture` does request `(0,0)-(323,512)`, but it is not clipped to the visible
height. `amiga/intro_323_geometry.gdb` measures the current color port, PixMap, and clip region as
`(0,0)-(512,512)` with 260-byte rows, so all 323 requested rows are written into the offscreen
GWorld. The immediately following shipped `_CopyBits` uses `(0,0)-(320,512)` for both source and
destination and writes into the 512×320 window. A capture of offscreen rows 320–322 contains 230,
227, and 256 nonzero bytes respectively, proving they hold real, differing picture data; they are
simply outside the rectangle copied to the window. The port therefore correctly displays 320 rows
without changing or clipping the original 323-row composition surface.

Animation presentation uses a fixed list of ordinary dirty rectangles. `DrawPicture`, `CopyBits`,
`EraseRect`, and `FrameRect` add their destination bounds only when their resolved destination
pixels are the visible screen; GWorld composition must not dirty the display. Contained rectangles
and rectangles that form an exact larger rectangle are merged, but an arbitrary overlap is not
allowed to grow into untouched space. A capacity overflow conservatively falls back to their union,
and C2P expands each horizontal span to 16 pixels. Double-buffer coherence is maintained by copying
each preceding planar rectangle from front to back unless a new conversion completely replaces it.
The rolling `FILLWATCH` audit decoded all 163,840 pixels after this change with zero mismatches. No
framebuffer comparison, shadow buffer, or tile map participates in normal presentation.

Driving uses the same list with source-derived bounds. The final 512x342 `_CopyBits` is the game's
GWorld publication transport, not evidence that every destination pixel changed, and the intervening
`GrayRgn` over `(20,0)-(320,512)` is likewise construction rather than a completed frame. The 3D
renderer redraws the outside view `(0,0)-(198,512)`. Traffic's two packed rectangle writers receive
dashboard and mirror bounds in D4/D3/D1/D2; their original `ASL.L #2,D2` entry instructions are
replaced by a private Line-A hook. A short assembly branch in the exception handler records those
bounds, performs the displaced shift, and returns directly; it does not enter the general Toolbox
dispatcher. Sixty-four raw bounds fit before an overflow marker conservatively requests a full frame.
A typical completed frame is consequently the outside view plus thirteen small dashboard/mirror
rectangles, rather than one nearly full-screen union. The first completed driving frame is converted
in full to seed double-buffer history. The second partial conversion and its simultaneous chunky
source compared equal at all 163,840 pixels, and a 40-frame rolling audit checked every row with
zero bad pixels.

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
| system `RndSeed` | `$0156` | `4(A5)` | `Main+$0570` |
| `WMgrPort` | `$09DE` | `8(A5)` | `Main+$08A6` |
| `GrayRgn` | `$09EE` | `12(A5)` | `Initialize+$08C4` |
| `KeyMap` | `$0174` | `16(A5)` | `Main+$2B54` |
| `CurrentA5` | `$0904` | `-31292(A5)` | `Main+$1F34` / driving VBL callbacks |
| `MBState` | `$0172` | `-31288(A5)` | `Traffic+$6D00` |
| `MTemp` | `$0828` | `-31284(A5)` | mouse-mode initialization |
| `RawMouse` | `$082C` | `-31280(A5)` | mouse-mode initialization |
| `Mouse` | `$0830` | `-31276(A5)` | `Main+$2BC8` / `Traffic+$6CE6` |

Sixteen encoded instructions (ten reachable in the current control-flow inventory) read `GrayRgn`,
using both `MOVEA.L abs.w` and `MOVE.L abs.w,-(SP)`. They are all redirected to the same `12(A5)`
shadow by an exact-count scan.
The stack form was not covered by the first three explicit relocations and was only exposed once
`PaintBehind` became reachable.

All 87 direct `Ticks` reads use the same absolute-word encoding and are redirected to `0(A5)`.
The driving code contains three exact `LEA $0174,A1` sites: two VBL callbacks poll selected bytes
and `Main+$2D26` snapshots all 16 bytes. They therefore share a complete 16-byte KeyMap shadow at
`16(A5)`, immediately below the jump table at `32(A5)`. The CIA interrupt maintains a separate
non-consuming 128-key raw-state snapshot as well as its edge queue. At each exact driving-frame
boundary, the port translates that snapshot into all 16 KeyMap bytes without consuming the queued
EventRecords. The first version reversed the bits within every byte: it wrote virtual Escape `$35`
as byte 6 bit `$04`, which the game's ascending LSB-first scanner at `Main+$2DD2` reads as virtual
key `$32`. That explains why 6,436 ticks of “Escape” never left driving: the game never received
Escape. KeyMap bytes now use the classic low-bit-first representation, so Escape is byte 6 bit
`$20`; accelerator `$5B` is byte 11 bit `$08`. The physical-state and deterministic-accelerator
regressions cover both mappings. Corrected held Escape takes the original driving exit at tick
1,864 after 32 queued and presented frames: the driving global and bridge state both clear, depth
reaches 94 through the already-supported post-driving path, and no loud stop follows. This is a
direct KeyMap transition; `GetNextEvent` is not called until after the driving loop has exited.
`INPUT_PROBE_EVENT_RAW_KEY=$45` then repeats the test with an Escape down/up pair in the ordinary
edge queue: down is enqueued before the first driven iteration, release at the exact boundary where
the game has cleared its driving flag, and both remain available to `GetNextEvent`. The settled
capture 180 ticks after exit is byte-identical to the first event-loop capture
(`11e5b145…`): the upper 198-row viewport is clear, the dashboard remains, depth stays 94 and no
loud stop occurs. Escape has therefore reached a supported waiting state rather than another
compatibility requirement. `amiga/menu_options_capture.gdb` records that boundary.

The same queued-edge harness with raw Amiga F1 (`$50`, Macintosh virtual `$7A`) takes the key
chart's “Helicopter View Left” branch without leaving driving or encountering another trap. A
bounded run reaches 3,253 ticks and 65 queued/presented frames at depth 93. Frame-matched captures
at presentation 40 prove a real renderer-state change: the ordinary surface hashes to `b2020be4…`,
the F1 surface to `4ec4efc8…`, and 53,940 of their 81,920 packed bytes differ. The paired
`driving_baseline_capture.gdb` and `driving_f1_capture.gdb` scripts make that coverage repeatable.

The cross-machine F1 differential now goes beyond that target-only view change. Holding F1 from
race entry is not a valid moving fixture: Vette's ascending scanner services the view key before
top-row `+`, leaving the car in neutral. Both harnesses therefore perform the original upshift,
hold F1 through one verified `Main+$1FD2` iteration, release it, and only then arm their source
captures. `VETTE_DRIVING_VIEW=F1` gives the Macintosh oracle independent artifact names, while
`VIEW_CAPTURE_F1=1` supplies the equivalent physical edge on Amiga. At the shared moving state
RPM 19, gear 1, speed 15, position `(12407,6116)`, heading 12288, the 512x255 principal-view region
is exact across all 130,560 pixels. The only full-surface differences occupy rows 255–256, a lower
composition strip whose Traffic phase is not part of the player-state key. `make
driving-f1-compare` consequently gates the renderer-owned principal view without laundering that
separate synchronization debt.

Raw Amiga F5 (`$54`, Macintosh virtual `$60`) likewise takes the documented “Front Dash” branch
without a new trap. The run remains in driving at depth 93 through 3,444 ticks and 70/70 frames.
At matched presentation 40, `driving_f5_capture.gdb` records hash `3441bd48…`, differing from the
baseline in 31,214 packed bytes; the game removes the cockpit/dashboard overlay while retaining the
forward road and mirror. This closes a second materially different renderer state by pixels rather
than merely by survival.

Raw Amiga P (`$19`, Macintosh virtual `$23`) resolves through the game's live 128-key table to
`Initialize+$1862`. It takes the original pause/options transition, stops new presentations at a
complete-frame boundary, blanks the upper viewport while retaining the dashboard, and settles at
depth 94 without a loud stop. This path exposed a stricter Page-0 requirement than ordinary driving:
after the transition, original code waits on KeyMap without making another Toolbox call. A classic
Mac keyboard interrupt updates those 16 bytes asynchronously. The port now translates each Amiga
CIA keyboard edge directly into the A5-relative KeyMap shadow, while the same queued down/up edge
remains available to `GetNextEvent`. `amiga/driving_p_key_dispatch.gdb` resolves the shipped key
table and handler; there is no P-specific runtime behavior.

Raw Amiga S (`$21`, Macintosh virtual `$01`) resolves through the same shipped table to
`Main+$3134`; there is no port-side S special case. The handler tests and changes the game's own
A5-relative sound flag, then calls the resident `sound` segment through the original A5 jump
table. The off and on services resolve to `sound+$021C` and `sound+$024C` respectively (their
command records contain 17 and 19). A bounded down/up probe starts with the flag at 1, reaches 0,
and continues active driving through 50 queued and 50 presented frames at depth 93 without a loud
stop. `amiga/driving_s_key_dispatch.gdb` records the dispatch and service targets;
`amiga/driving_s_state.gdb` records the settled state.

The key chart's Automatic Shift command is A, not Z: raw Amiga `$20` translates to Macintosh
virtual `$00` and resolves through the live table to `Main+$31AA`. The handler operates on the
current car record rather than a port-owned surrogate. Before dispatch, its word at offset 46 is
1 and the A5-relative transmission gate is 0; after the ordinary down/up pair they are 0 and 1.
Driving continues through 50/50 frames at depth 93 without a loud stop.
`amiga/driving_a_key_dispatch.gdb` and `amiga/driving_a_state.gdb` preserve both sides of the
transition.

The key chart's D command reaches the original Damage Indicator rather than a Toolbox dialog. Raw
Amiga `$22` becomes Macintosh virtual `$02` and resolves to `Main+$37B4`. The handler changes the
A5-relative indicator flag from 0 to 1 and stores `Ticks + 6000` as its expiry. It remains in active
driving at depth 93 with no loud stop. At the matched 40th presentation, the result differs from
the no-key baseline in 4,637 of 81,920 packed bytes, bounded to byte columns 153–255 and rows
214–319; the palette is unchanged. `amiga/driving_d_key_dispatch.gdb`, `driving_d_state.gdb`, and
`driving_d_capture.gdb` retain the dispatch, state, and pixel evidence.

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
`amiga/driving_keymap.gdb` stops after the driving callback sees correctly encoded keypad 8, while
`amiga/driving_key_dispatch.gdb` proves that the original full-map scanner dispatches it as virtual
key `$5B` rather than the adjacent `$5C` produced by the earlier reversed representation.

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
| 150 | 0, 2, 15, 4, 14, 13, 6, 8, 9, 10, 11, 12, 7, 5, 3, 1 |
| 131 | 0, 9, 3, 2, 15, 14, 13, 12, 4, 11, 6, 10, 7, 8, 5, 1 |

The port applies these measured layouts in Palette Manager emulation, while every RGB value still
comes from its shipped `pltt` resource. This is centralized device state: there is no Porsche/F40
detection, model-pixel scan, grid-pen rewrite, or screenshot-derived color substitution.

`NewGWorld` with null color-table and device arguments owns a creation-time snapshot of the current
device CLUT; it does not keep sharing the mutable active-window table. The rotating-car worlds are
created while the game's blue-shaded color environment is active, after which the window palette
changes. Sharing that later table made the same stored indices appear pink. Each GWorld now retains
its snapshot, while `srcCopy` uses a packed color-map lookup whenever source and destination
PixMaps describe different color environments.

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
renderer-authored physical indices. RGB colors drawn by indexed and direct PICT opcodes are a
separate operation: Color QuickDraw realizes them through the current GDevice's inverse table, not
the retained ColorTable of the destination PixMap. This is observable during road construction,
where a palette-131 PICT is drawn into a GWorld that still contains palette 130 with a different
seed. Looking up those colors in the private palette-130 table produced every remaining wrong pen;
the untouched System 6 GWorld instead contains the palette-131 device pens. This is device state,
not scene-specific color substitution.

The road transition exposed one more stateful allocation. The game realizes `pltt 150` before it
constructs the driving artwork, then installs `pltt 131` for the completed driving window. A
System 6.0.8 MAME capture through the original copy-protection requester records palette 150's
physical order above and the final road device table as the same palette-131 order already measured
for the selector. Falling back to sequential allocation for palette 150 therefore left the final
palette apparently correct while the already-authored four-bit indices were wrong: sky and road
looked exchanged and the middle distance became pink. `tools/mac_probe_model_indices.lua` now
continues through the vehicle and course controls, answers a fresh reference disk's requester from
the shipped manual table, and dumps both the driving device table and the activated port tables.

The populated 512×512 source GWorld then isolates the remaining road-color fault. Its retained RGB
table is palette 130 on both machines, and its pixels already contain the intended physical indices
(`4` sky, `6` water, `14` road). On System 6 the final `SetPalette` association gives that GWorld the
same `ctSeed` as the palette-131 screen even though no later `ActivatePalette` follows; the 512×342
`CopyBits` therefore copies indices unchanged. The port formerly synchronized an offscreen seed
only in `ActivatePalette`, leaving the source one seed behind and provoking a color translation
that turned sky gray and road brown. `SetPalette` now performs the measured courteous GWorld seed
synchronization immediately, while still retaining the GWorld's creation-time RGB snapshot.

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

`GARAGE_COURSE=1..4` extends that development harness with one ordinary click on the requested
course button before ACCEPT. Course Three exposed application `PICT 27402`, a version-1 picture
whose text stream includes opcode `$2C` FontName: a byte count, old font ID, and Pascal font name
(`Monaco` in the measured record). The compact picture-text fallback is font-independent, so it
validates and skips that state record while retaining the existing loud stop for unseen drawing
operations. Course Three then passes the former `Initialize+$17D2` DrawPicture boundary.

That synchronous `GetVolInfo` caller reads only `ioVCrDate` at parameter-block offset 30. The
bridge returns `$D51CFD76`, measured directly from the master directory block of the shipped
`VETTE!` HFS image, and `ioResult = noErr`; it does not fabricate the unused volume fields. This
preserves the game's derivation of its `DATE` resource key. Execution then reaches QuickDraw
`Random` (`$A861`) in road setup.

The application has two distinct random-seed locations. `InitGraf` initializes the first field of
the application's QuickDraw globals, `randSeed` at `thePort-126`, while Page 0 `$0156` is the
system `RndSeed`. Vette's `Main+$0570` deliberately copies the latter into the former immediately
after `InitCursor`, following the assembly-language seeding pattern documented by Inside
Macintosh. The redirected Page-0 shadow therefore receives a live tick-derived value at that exact
boundary; the VBI keeps it at `Ticks-1`, matching the System 6 oracle. It is not the state advanced
by subsequent `Random` calls.

`Random` uses the original QuickDraw recurrence (`randSeed * 16807 mod $7FFFFFFF`), returns its
signed low word with `$8000` mapped to zero, and updates only the application QuickDraw seed. An
earlier bridge version incorrectly advanced the Page-0 shadow instead, leaving the seed actually
owned by QuickDraw unchanged. A probe-only GDB trace and the MAME oracle now report both seed
locations independently. The next call is `GetDItem` for item 2 of the copy-protection dialog;
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
the two 81,920-byte surfaces differ (`f9eb1e3e…` versus `8e540ac2…`). After correcting KeyMap's
byte-local bit order, the held word is `$0008` and the original scanner reports virtual key `$5B`,
the documented keypad-8 accelerator. The earlier `$0010` value was virtual `$5C`; its change to the
two callback-control globals was therefore not evidence about acceleration and is withdrawn. The
unchanged surface hashes remain evidence of a moving road renderer rather than two samples of the
setup canvas.

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

Static tracing locates the completion edge: while driving is active, `Main+$29C6` branches directly
back to the loop entry at `Main+$1FD2`; `SystemTask` at `Main+$29E6` is reached only after that loop
exits. The earlier claim that `MaxMem` at `$1FEA` occurred on every pass was false: the branch at
`$1FE0` commonly skips it. Repeated debugger stops there also leaked trace state through Line-A
dispatch and eventually surfaced as a spurious `SIGTRAP` at the ordinary `Traffic+$3DC4`
instruction. Neither event was a game fault or a frame boundary.

No original Macintosh trap is common to the real edge, so the port byte-verifies the eight-byte
`TST.W -21316(A5)` / `BEQ.W $29DA` pair at `Main+$1FD2`, replaces its first word with private
Line-A `$AFFF`, and emulates both branches by changing only the saved return PC. The branch targets
immediately overwrite condition codes, so the removed `TST` flags have no downstream consumer.
The first active pass arms presentation; every later pass marks the completed 512×320 surface dirty
and presents it, covering direct 68k stores as well as QuickDraw calls. No surface scan or partial
dirty rectangle is used to infer completion. `SystemTask` still disarms the state on exit. The
established intro differential remains exact across all 163,840 pixels, both planar buffers, and
the copper palette.

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
the first bounded run, the 33-picture batch finishes 177 ticks after the former `$1FEA` marker, all
38 pictures finish at 384 ticks, and execution reaches the dynamic-renderer gate at `Main+$286A` after 773
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
and performs one full conversion only at the exact `Main+$1FD2` loop entry. Non-driving scenes keep
their existing trap-return cadence. The milestone times improve again, from 155/346/503 to
112/301/428 ticks, while the exact intro differential remains unchanged. A repeat of the dynamic
sampler contains no presentation samples: most stops are now in `CopyBits`, with the rest in the
original Main and Traffic segments.

`amiga/driving_dynamic_copybits.gdb` shows that remaining compatibility work is twelve repeated
`srcCopy` operations between the same two PixMaps, each covering the complete
`(0,0)-(342,512)` rectangle. The earlier probe compared stale setup state and incorrectly reported
different color-table seeds. Extending it to identify the destination window proves the live source
GWorld and destination window have the same seed, both on System 6 (`$527`) and on the port (`21`),
so these calls preserve their four-bit indices. The source RGB tables match between machines entry
for entry, as do the destination/device tables. Rendering each captured packed source through its
captured destination table produces the same color roles: light-blue sky, blue horizon band, dark
road, gray dashboard, and the same mirror colors. This rules out active palette realization,
chunky-to-planar bit order, and seed-driven `CopyBits` remapping as explanations for any remaining
driving-scene difference. `tools/render_mac_chunky.py` makes the binary-ColorTable rendering
repeatable. The next differential must synchronize vehicle, input, and frame boundary and compare
the renderer-authored packed indices.

That synchronized differential now selects Corvette ZR-1 in both harnesses, holds keypad 8 before
the first driving iteration, and captures the first populated full-window copy. A geometry-aware
comparison ignores the four unused padding bytes in each 260-byte PixMap row and compares all
175,104 pixels in the live 512×342 rectangle. **All 175,104 now match.**
`tools/compare_mac_chunky.py` makes that packed-pixel proof repeatable.

Four consecutive full-window captures reject callback skew as the explanation. Corresponding
frames retain the same 774-pixel mirror signature while road and traffic pixels change normally.
An aligned MAME write tap shows the Macintosh first filling the row and then overwriting it through
the original Traffic raster path. `Traffic+$6790` selects the backing buffer and `Traffic+$67A4`
copies the 78×168 intermediate rear-view source. `VETTE_MIRROR_WRITER=1` enables that otherwise
noisy reference write trace.

The first interpretation of the Traffic helper inventory was wrong. At `FRED+$00FC`, both machines
carry height 100, subtract flag 1, and viewport bottom 196, and both enter the full-row fill with
80 rows. The reference write tap's `d1=78` was observed only after the loop had completed two rows.
The actual differential is one stage earlier: `Traffic+$5C20` copies a 78×168 image from the unused
lower portion of the 512×512 GWorld into the mirror. Its source differs in rows 1–8.

The producer is the game's own `_DrawPicture` call with destination `(388,0)-(466,168)`. The PICT
frame is `(0,0)-(77,168)`, split into 60-row and 17-row indexed PackBits rasters. System 6 maps the
77 source rows into 78 destination rows by sampling pixel centres. The port instead used leading-
edge integer division, duplicating row zero at destination row one and shifting the visible top
edge. `drawIndexedPictureBits` now applies centre sampling to scaled indexed PICT coordinates. The
first synchronized frame is consequently exact. The initial ordinal captures two through four
showed small changes in the lower dashboard, but had no game-state record and therefore could not
establish another fidelity boundary. `amiga/driving_fred_state.gdb`,
`driving_raster_source.gdb`, and `driving_mirror_picture.gdb` retain the mirror correction trail.

`make driving-sequence-compare` now turns the paired captures into one state-aware sequence report
rather than four manual invocations. Both harnesses emit ticks, engine RPM, gear, speed, position,
and heading beside every surface. With `--match-state`, the comparison pairs the complete six-field
state tuple rather than capture ordinal, ignores each PixMap's four padding bytes, reports states
seen on only one machine, identifies the first state-aligned divergence, and accepts
`REQUIRE_EXACT=1` as a regression gate. `make driving-sequence-capture` rebuilds the deterministic
Amiga entry with the reference keypad-8 input and captures the corresponding states.

That safeguard corrected the earlier interpretation. The saved Macintosh captures have RPM states
11, 15, 18, and 23. On the port, completed publications jump from 11 to 23; states 15 and 18 occur
inside the Macintosh frame's repeated publication construction but are not separate completed Amiga
frames. Static and live traces identify the small changing dashboard shape as digits drawn from the
current car's `+$44` engine-RPM word by the shipped `Traffic+$67A4` byte raster—not a driver
animation and not compatibility rendering. The two complete states shared by both machines, RPM 11
and RPM 23 with identical gear, speed, position and heading, each match all 175,104 active pixels:
350,208 compared pixels and zero differences. The comparator reports RPM 15 and 18 explicitly as
reference-only coverage rather than pretending their ordinals are comparable.

Resolving the remaining resident-code samples shows that they are not compatibility overhead:
`Main+$5208/$5246/$5266` are perspective division and clipping, `Main+$5A34/$5A92/$5D6A` are
line/polygon construction, and `Traffic+$68B4..$68BA` enters an original byte raster loop while
`Traffic+$6A62` is original transform math. Those paths remain byte-for-byte shipped code. The
remaining compatible hotspot is therefore the full-surface packed-byte palette translation.

That translation now has a separately callable clean-C oracle and a row-aware 68000 twin. The twin
keeps the 256-byte map in `A2`, performs four independent table lookups per `DBF`, handles the final
zero to three bytes separately, and applies source and destination modulos between rows;
`MAPPED_COPY_C=1` retains the oracle build. An isolated Amiga executable exercises a contiguous
87,551-byte span, a 342-row strided copy with different source and destination padding, and a
zero-height call; it passes under the local 68000 runner. `VERIFY=1 PROBES=1` additionally runs C
and assembly into the same destination for every eligible real `CopyBits`, preserves the C result,
byte-compares it after assembly, and accumulates Macintosh ticks for both arms. The event-driven
target-A1200 run compared 245,760 bytes over three calls with zero failures and measured 20 ticks
for C versus 15 for assembly, a 25 percent reduction in the isolated translation cost. The normal
build still passes the complete 163,840-pixel intro differential. The corrected hardware-watchpoint
probe measures the first active loop from its true entry: picture milestones at 106/297 ticks,
dynamic rendering at 420, and a completed presentation at 459. The next completed frame arrives
40 ticks later, with both queued and presented counts advancing by one.

The ordinary Stage C loud-stop probe now reports bounded progress as well as trap depth. A
60-second warped target-A1200 run reaches 6,422 Macintosh ticks and 143 queued / 143 presented
frames with driving still armed, depth still 93, and no loud stop. This closes straight-line
accelerator soaking as a discovery method; the next coverage step must deliberately take another
driving control or transition path.

The later deliberate straight-to-Lake-Merced work corrects a misleading record interpretation.
The first 900-frame run never moved: the current car stayed at `(12608,-6,6112)`, `car+26` speed and
`car+28` gear stayed zero, while keypad 8 correctly reached `Main+$2F1A` and set only the throttle
word at `car+32`. Words 66/68 are engine RPM state, not position. `Traffic+$3720` uses word 68 to
derive the per-frame Bogas engine pitch, caps it at 85,000, and calls `BogasPlay`. The visible `000`
dashboard speed was therefore accurate.

The car begins with Automatic Shift enabled (`car+46 = 1`), but still requires an initial shift
out of neutral. A remains the wrong command: `Main+$31AA` changes that field to zero, and Traffic's
gear routine at `$3766` then restores automatically computed gear changes. Top-row `1` is also the
wrong deterministic command in the active control mode: it reaches `Main+$32CC`, whose mode branch
treats it as steering. Top-row `+` reaches the shipped upshift handler at `Main+$328E`.
`Traffic+$51FE` rejects gear changes before start state 3, so the harness waits through BUCKLE UP /
GET READY, presents `+` to one KeyMap scan, releases it after `car+28` becomes 1, and only then holds
keypad 8. At presented frame 80 the original record now proves motion: X is 12521 rather than
12608, speed is 14, gear 1, throttle 1, brake 0, and first-gear ratio 8. The next event-driven probe
can consequently follow an actually moving car to the first `BogasLoad` or loud stop and retain
the exact Traffic caller, instrument, and framebuffer. `amiga/driving_accelerator_dispatch.gdb`,
`driving_gear1_dispatch.gdb`, `driving_drivetrain.gdb`, `driving_sound_event.gdb`, and the noisier
`driving_sound_trace.gdb` preserve the evidence.

The gameplay-audio trace now breaks directly on the resident `sound+$0174` `BogasPlay` wrapper;
its older nested callback breakpoint stopped inside the safe-point trampoline before the sound
hook could be armed. In a short moving A1200 run the wrapper is called 76 times from
`Traffic+$3762`, approximately once per completed frame. Its long stack argument begins at 27,000
and rises through 40,000 with engine RPM, while the word argument remains zero. This is the first
source-measured Paula contract for gameplay audio: reproduce the already-loaded Bogas engine
context and apply this original pitch stream. Instrument/context identity must come from the
preceding `BogasOpen`/`BogasLoad` calls, not from a car- or sample-name special case.

`amiga/driving_bogas_contexts.gdb` now records that lifecycle at the original sound-module
boundary. Before driving, Initialize opens contexts 0, 1, and 2, then applies the context words
0, 2, and 1 through `BogasPitch`. The moving route loads context 0 with arguments
`($7fffffff,$8000,4)` and every measured engine `BogasPlay` targets context 0. Effects are loaded
independently into context 2: the first bounded run observed argument tuples
`($96,$1,10)`, `($96,$1,10)`, `($96,$1,11)`, and `($78,$1,8)`. This proves that the port must
model contexts and loaded instruments, rather than infer sounds from a screen or car. The probe
also prints the resident Main, Traffic, and sound bases so every caller address can be reduced to
a stable segment offset; its engine caller is `Traffic+$3762`.

The wrapper ABI is source-derived from `CODE 9`, not guessed from playback. `BogasOpen` consumes
one word; `BogasKill` consumes a word and long; `BogasLoad` consumes word, long, long, word;
`BogasPlay` consumes long and word; and `BogasPitch`/`BogasPurge` consume one word. Their Pascal
epilogues leave long results in the caller's reserved result slot where applicable. This is the
boundary the Paula implementation will replace. Instrument ordinals still need to be joined to
the original named-resource initialization order before effect names are assigned.

The same trace reads the Pascal names passed by Initialize to all sixteen `BogasKill` calls. The
returned ordinals are therefore fully source-mapped: 0 `opening song`, 1 `mic`, 2 `signature`,
3 `cable car bell`, 4 `engine`, 5 `heli`, 6 `horn`, 7 `skid`, 8 `crash`, 9 `kill`, 10 `beep1`,
11 `beep2`, 12 `police`, 13 `thud`, 14 `joel`, and 15 `splash`. The first bounded driving effects
are consequently `beep1`, `beep2`, and `crash`. No visual state, vehicle identity, or guessed
color/sample association is involved. In that same run there were 68 engine `BogasPlay` calls and
no nonzero-context `BogasPlay` calls: the context-2 effects begin at `BogasLoad`, while the engine's
repeated context-0 `BogasPlay` updates its running pitch.

The first gameplay backend now replaces all twelve verified CODE 9 wrapper prologues with private
Line-A calls. The dispatcher emulates each wrapper's Pascal return address, argument cleanup, and
reserved long-result slot, so callers remain original code. `BogasKill` resolves the actual Pascal
name through the Resource Manager and returns the resulting ordinal; `BogasOpen`, `BogasLoad`,
`BogasPlay`, `BogasPitch`, `BogasPurge`, Set/Start/Stop, Close/Dispose, and Deactivate all have their
measured entry contracts. The indefinitely loaded context 0 starts `Engine` on a centred Paula pair;
each original context-0 Play changes only its period. Context-2 Load starts beep/crash effects on
AUD2, replacing the previous direct effect in that fixed context; context 1 independently owns
AUD3. Along with the centred AUD0/1 engine, this preserves all three Bogas inputs simultaneously
using Paula DMA and deliberately gives incidental effects fixed left/right placement.

Disassembly of BGAS's mixer at resource offset `$1F4A` establishes the channel model rather than
leaving it to an audible guess. It advances three fixed sample pointers from three phase increments,
adds their bytes through the driver's mix table, and writes the same result to both output bytes.
That explains the Macintosh result, but porting this loop would waste the Amiga's four DMA voices.
Three independently centred sources would require six Paula channels. The bridge instead keeps the
important continuous engine centred and assigns the two remaining fixed inputs one hardware voice
each; no audio sample is mixed by the 68020.

The apparent `BogasPurge(300)` lifecycle call is also audio state, not a disposable administrative
no-op. BGAS command `$08` passes its word to resource offset `$2738`, which rebuilds the 768-entry
mix table. For each possible sum it applies `floor(level/3)/128` to the distance from unsigned
silence at 384, then clamps to one output byte. Vette's level 300 therefore gives every input a
100/128 gain in the original software mixer. More importantly for the hardware backend, a complete
reference sweep of all 11 resident CODE segments finds only this one call, at `Initialize+$009C`:
300 is the maximum Bogas level the game uses. The Paula boundary consequently maps the used range
0..300 linearly onto 0..64, clamping above it. Every shipped sound therefore runs at volume 64 while
hypothetical lower levels retain their relative proportion. Sample-byte RMS and peak values do not
enter this mapping; the unchanged sample data already carries the same authored amplitude on both
systems.

`make driving-audio-regression` makes this boundary executable rather than documentary. Given the
separately captured Macintosh oracle trace, it rebuilds and runs the bounded normal-road event
workload and requires the oracle's exact Bogas Load signatures plus a source-ordered engine-pitch
progression.
Because completed-frame cadence can expose an additional authentic map/traffic cue on one machine,
the invariant is that every oracle Load occurs with exact arguments and in source order; additional
target Loads are counted rather than mistaken for a backend failure.
It then rebuilds the traffic-dense Course Two workload, injects the established physical Z-key horn
edge, and requires simultaneous engine/horn/crash,
the fixed context-to-Paula assignment `0 -> AUD0/1`, `1 -> AUD3`, `2 -> AUD2`, all four commanded
voice volumes at 64 for Bogas level 300, and an effect-context replacement that leaves the other two
contexts playing. A loud stop, missing checkpoint, changed signature, or changed register contract
makes the target fail. The indefinite horn makes context 1 deterministic; the traffic workload uses
the established `$3BD90000` fidelity seed so context-2 spawn and replacement, rather than the host
clock, define the repeatable checkpoint.
Paula's `AUDxVOL` registers are write-only, so the backend records each commanded value beside its
existing reload/deadline state; the regression reads that state rather than treating zero-valued
hardware readback as meaningful.

Short INST resources are parsed structurally as four header words (loop start, loop end, source
sample rate, PCM byte count). This corrects the earlier zero-loop-only test, which left the Engine
header in its PCM stream. Direct gameplay effects use the header's 6.4 or 9.472 kHz source rate.
The context-0 engine is different: Bogas software-mixes it into the fixed 11.127 kHz output and
uses Load/Play's long value as a 16.16 source phase step. The Paula period is consequently
`319 * $10000 / step`, converted with the 68000's hardware `DIVU`; the mandatory link audit
confirms that no software 32-bit divide entered
the build. A bounded target-A1200 run reached 120 presented driving frames with no loud stop,
registered all 16 named instruments, retained engine ordinal 4 in a playing context 0, followed the
original pitch from `$6978` through `$88B8`, and started/expired the observed beep1, beep2, and crash
loads. A separate ordinary-build intro run reached tick 2,638 / 295 presented frames at Stage C
depth 64 with its original ordinal globals 0..4 and no loud stop.

The shipped BGAS 128 code removes the remaining Load ambiguity. Command `$18` copies record long
`+20` into the selected voice's countdown at driver-state `+952`; its three service branches at
`$25BA`, `$2616`, and `$2648` decrement that value once per pass and stop at zero. Record long `+24`
is copied into the context-0 phase-increment array consumed by the software mixer at `$1F60`.
Thus `$7fffffff/$8000` is an effectively indefinite engine at half-rate initially, later replaced
by the measured 27,000-and-rising Play stream; 150 and 120 are the exact lifetimes of the beep and
crash loads. These semantics now come from the shipped driver, not timing inference.

The loop metadata is honored as well. When an INST supplies nonempty loop bounds, Paula first
starts from the complete PCM body; at the next safe trap boundary the bridge changes only the DMA
reload location and length. The attack therefore plays once and subsequent hardware reloads repeat
the source-declared sustain region. The Engine resource verifies as bytes 370..5682; its INST rate
would be Paula period 554 for a direct context, while context 0 correctly uses the 11.127 kHz mixer
base before applying the phase step. Instruments with zero loop bounds play their complete body
only once, then reload a reserved silent word until the original Bogas context is replaced or
its Load duration expires. This matters for calls such as `splash`, whose context can outlive the
visible scene: whole-body Paula reload would otherwise loop the splash after returning to the
garage.

`amiga/bogas_lifecycle.gdb` covers the administrative wrappers separately. An ordinary, unskipped
intro reaches `BogasClose` and `BogasPurge(300)` together at tick 90 during initialization, then
`BogasStart` followed by `BogasSet` on the transition out of the intro. The deterministic real-key
harness now also covers both ways out of live driving. P reaches the shipped
`Initialize+$1862` pause/options transition and Escape reaches the ordinary menu transition; both
clear the driving state at tick 1,708 in the matched diagnostic build and settle at depth 94. For
the following 120 Macintosh ticks neither path calls Stop, Deactivate, Dispose, or Close, and the
Bogas started state remains set. Audio continuing into this waiting state is therefore original
game behavior, not a missing port-side pause hook. Stop and Deactivate remain unused by these real
paths. The shipped BGAS dispatcher nevertheless establishes an important distinction: commands 3
and 1 only inhibit output and leave the three 120-byte voice records allocated, whereas command 2
runs the disposal path. The Paula bridge now makes the same ownership distinction. Stop and
Deactivate silence DMA while retaining each context, loaded instrument, pitch and finite lifetime;
Start resumes those retained voices and shifts finite deadlines by the suspended interval. Close
and Dispose remain the destructive teardown operations. Paula has no readable current-DMA source
pointer, so a future real suspend/resume caller would restart a retained sample at its declared
attack rather than the BGAS software mixer's exact byte phase; neither measured P nor Escape path
uses that unverified edge.

The Macintosh audio oracle is now reproducible with `make driving-audio-reference`. It runs the
same synchronized moving workload with the normal-road input, asks MAME to write its mixer output
directly, and reports waveform activity without treating the sound device's constant DC level as
audio. The current capture is 89.320 seconds at 48 kHz, 16-bit: Macintosh mono is duplicated in
MAME channels 1 and 2 while channels 3 and 4 are silent. The moving-driving passage begins at
75.500 seconds and continues through the end of the capture. The WAV and verbose emulator log stay
under `tmp/`; `tools/audio_reference_report.py` makes the channel and activity measurement
repeatable. This establishes the reference half of the audio differential; the next comparison
must capture or reconstruct the Paula voices over the same Bogas-call interval.

`make driving-audio-capture` establishes that target interval at the same original wrapper
boundary. It performs a clean A1200 diagnostic build, follows the bounded Course One road workload
for 100 original driving iterations, and retains the complete event log in
`tmp/amiga-driving-audio.log`. The measured run contains one Start, six Loads and 99 engine Play
updates with no Stop, Deactivate or loud stop. Context 0 loads the indefinite Engine at tick 1,678;
context 2 then loads beep1 twice, beep2 once and thud twice. At the tick-2,661 ceiling the
engine is still playing on the centred channel pair at pitch `$9858`, while the last finite effect
has expired. `amiga/driving_audio_events.gdb` records every tick, context, duration, options word,
instrument ordinal and Play pitch in a machine-readable form suitable for Paula reconstruction.

`tools/render_paula_audio.py` now performs that reconstruction outside the game. It reads the VRS1
archive and wrapper-event log, models each hardware voice's integer period, phase continuity,
initial full-sample attack, declared reload loop and finite tick deadline, and writes a diagnostic
48 kHz stereo WAV. This is verification tooling, not a software mixer in the Amiga executable.
The measured interval is 16.383 seconds from ticks 1,678..2,661. AUD0/1 keep the engine centred;
the context-2 AUD2 effects appear only on the right output. Across all 99 engine Play calls, Paula
period quantization differs from Bogas's fixed 11.127 kHz phase-step target by -3.100..+0.710
cents. The worst direct-effect rate error is +2.133 cents for thud. The earlier incorrect-pitch
class is therefore closed for this workload; cue timing, authored level and overlap remain to be
compared against the Macintosh PCM.

The Macintosh oracle now traces the same wrapper events directly. It obtains `CurrentA5`, follows
CODE 0 entries 500/501/505..507, and verifies the Segment Manager's actual loaded form
`[segment:w][$4EF9][target:l]` before installing observation taps. The synchronized reference has
the same six Load signatures byte-for-byte: engine, beep1, beep1, beep2, thud, thud with identical
contexts, durations and options. `tools/compare_audio_events.py` makes this an automated gate. The
target's 99 engine Play calls / 33 distinct pitch steps form a source-ordered subsequence of the
faster Macintosh's 118 calls / 43 steps; no pitch is invented or reordered. Relative Load ticks
for the first four events are Mac `0,6,152,297` and target `0,4,153,302`. The later thuds occur at
Mac `364,371` versus target `417,447`, after road/traffic progression has diverged. Elapsed ticks
are therefore reported but deliberately not required to match: completed-frame cadence is a
machine-speed effect, while event identity, duration, ordering and pitch progression are fidelity
contracts. Run `make driving-audio-compare` after the two capture targets.

The separate straight-to-water fixture remains useful for one bounded adverse cue. With
`FOLLOW_ROAD` omitted, `amiga/driving_audio_next_effect.gdb` stops at the first context-2 Load
outside beep1/beep2/thud. It reaches instrument 8 (`crash`) at tick 2,137 / driving iteration 48
with the source arguments duration 120 and options 1, and no loud stop. This verifies the ordinary
collision path drives the already-generic Paula backend; it is not a port-authored collision sound
trigger. Broader traffic-effect coverage should use Course Two's bridge/freeway traffic rather than
repeatedly forcing the lake outcome.

That Course Two workload is now a bounded audio regression in
`amiga/driving_audio_bridge.gdb`. `GARAGE_COURSE=2 FREEWAY_ROUTE=1` selects and drives the route
through ordinary UI and keypad input. The route harness no longer toggles buildings, sound, engine
sound, or the F5 view off: those old tracing shortcuts hid the picture from the user and invalidated
audio-fidelity observation. In the full-view/full-sound run, crash first loads on context 2 at
iteration 147 and skid loads on context 1 at iteration 148. Thus original traffic/collision code
simultaneously owns two independent effects: skid reaches AUD3, crash reaches AUD2, and the centred
engine remains on AUD0/1. The 900-iteration ceiling records instruments 7, 8, 10, and 11, 405
effect Loads, no loud stop, and eventual collision-bound motion at speed 8. The probe now reports
only each first-seen ordinal plus the final counts/mask, avoiding hundreds of repeated crash lines.

`amiga/driving_audio_overlap.gdb` turns that workload into an explicit hardware-state assertion.
At driving iteration 151 the original engine/skid/crash calls are simultaneously active as
instruments `4/7/8` on contexts 0/1/2 and Paula channels `0/3/2`; AUD0/1 have no deadline while
AUD2 and AUD3 retain independent finite deadlines. Traffic then reloads crash into context 2 while
skid is still live. On the following presentation all three contexts remain active, only AUD2's
deadline has advanced (2406 to 2455), AUD3 remains 2536, and DMACONR remains `$03DF`. Replacing one
Bogas input therefore neither restarts nor silences either of the other two hardware-backed inputs.

`amiga/driving_audio_horn.gdb` covers the documented Z horn without confusing selector/countdown
input with a racing control. Its diagnostic physical-key edge waits for the game's own start state
3 and 30 completed driving iterations, holds Z across one original KeyMap scan, then releases it
through the ordinary CIA input path. At iteration 32 the source loads instrument 6 on context 1
with duration `$7FFFFFFF` and options 2. The release produces no Bogas Play, Pitch, Stop,
Deactivate, Set, or Purge call. This is consistent with the `horn` INST's authored sustain loop
1428..4989: the original call requests a continuing horn voice until another context-1 effect
replaces it. A current rerun leaves the horn active through its 80-iteration ceiling; no
port-authored horn trigger or release-time stop is required.

`amiga/driving_audio_heli.gdb` covers a complete principal-view audio transition through physical
keys rather than changing Bogas state directly. The diagnostic presses the documented F4 control;
the shipped handler at `Main+$2F5A` replaces context 0's engine with indefinite instrument 5
(`heli`) at 16.16 pitch `$00020000`. It then presses F2; `Main+$2F76` loads indefinite instrument 4
(`engine`) at pitch `$00006978`. On return from that original wrapper, context 0 is playing the
engine on its centred AUD0/1 pair at the corresponding Paula period 774. Thus helicopter ambience
and engine sound are mutually exclusive users of the source's context 0, while contexts 1 and 2
remain available for overlapping effects. The regression reaches both calls by driving iterations
2 and 4 and does not patch a view, instrument, or audio context.

The bounded straight-to-lake recovery now has its own result-audio regression in
`amiga/driving_audio_splash.gdb`. The original caller at `Traffic+$5B06` loads instrument 15
(`splash`) into context 0 for 360 ticks at nominal pitch `$00010000`, replacing the engine. This
exposed a distinction hidden by the earlier silent-reload fix: the sample no longer repeated
audibly, but finite deadlines were only serviced for effect contexts 1 and 2, so context 0 remained
logically active forever. Context 0 now schedules the same deadline on both centred channels and
retires AUD0/1 and its playing flag together. `FINITE_AUDIO_PROBE=1` preserves and records the real
wrapper arguments, then shortens only the resulting finite countdown to two ticks; the regression
proves both deadlines become zero and context 0 becomes inactive. Indefinite engine and helicopter
loads retain their existing zero deadline.

`amiga/driving_audio_recovery.gdb` follows that same cue through the enclosing lake-result
transition instead of stopping at expiry. It reuses the already-verified two-tick deadline fixture
only to keep wall time bounded, then waits for the original PICT-140 click-through and VBL removal.
At tick 2805 driving is disarmed, context 0 is inactive, both centred voice deadlines are zero, and
no post-splash context-0 Load occurred. The source therefore does not restore the engine while
leaving this race; silence is the correct recovery/garage-side state until a later race setup makes
its own original engine Load.

The last two named driving effects now have a bounded original-caller regression in
`amiga/driving_audio_remaining.gdb`. Static code first fixes their meaning instead of assigning
them from their names. `Main+$3EF2` tests an inactive map trigger against the player's two in-cell
coordinates; with effects enabled, its original caller at `$3F5A` loads instrument 9 (`kill`) on
context 1 for 120 ticks with options 1. `Traffic+$1844` dispatches the other response only for a
`COP!` traffic object, and `Traffic+$0E5A` rejects it at Trainee difficulty. On a higher difficulty
and on the high-memory path that registered the optional sample, the original caller at `$0F68`
loads instrument 14 (`joel`) on context 1 for 300 ticks with options 1, replacing the indefinite
instrument-12 police cue loaded immediately before it. `REMAINING_AUDIO_PROBE=1` is diagnostic
only: it byte-verifies and bypasses these decoded tag, state, difficulty and distance predicates;
it neither invokes Bogas nor chooses an instrument or context. The bounded run reaches `joel` at
driving iteration 1 and `kill` at iteration 26 without a loud stop.

There is no second, gameplay-side cable-car-bell call to cover. Initialize stores that returned
ordinal at A5-$5A84, and an exhaustive reference sweep of all ten resident CODE segments finds
exactly one later load: `Intro+$0480`, the already-working hilltop bell callback. The similar
countdown selection at `Main+$26D4` loads A5-$5A7C, which the initialization order proves is
instrument 10 (`beep1`), not the bell. The bell is therefore intro-only in the shipped program;
adding a road or cable-car trigger in the port would be invented behavior.

The protection-failure police path is covered without restoring the deliberately unsupported modal
requester. The diagnostic `FAIL_PROTECTION=1` replacement reproduces the two words left by the
original second-wrong-answer branch at `Main+$0868`: both the processed flag at A5-$58FE and failed
flag at A5-$5900 are `-1`. Static Traffic disassembly then explains why the unaccelerated 400-
iteration attempt saw no police cue: `Traffic+$0E40` requires `$1C20` ticks—exactly two minutes—
since Main's race-start timestamp. `POLICE_PROBE=1` waits for start state 3 and 30 completed driving
iterations, then ages only that timestamp to the original threshold. It does not call Bogas or
create a traffic object. On the next original update Traffic loads instrument 12 (`police`) on
context 1 with duration `$7FFFFFFF` and options 1 at iteration 32, while both protection result
words remain `-1`. The `police` INST's authored 2384..6344 sustain loop then maps normally to AUD3.
Production builds retain the verified successful-protection patch and never define either fixture.

Letting that diagnostic path continue first exposed `$AA93 DisposePalette` at `Main+$0F22`.
This is Palette Manager ownership cleanup, not requester UI: the bridge now detaches the disposed
palette from windows and GWorlds, clears the active association, and releases the `pltt` resource
master. The next trace reaches the original `ExitToShell` at tick 2472 with exit state 3 and then
returns to Amiga teardown with state 4, implemented depth 96. It makes zero post-cue PICT requests.
The visible Macintosh message (“caught driving a stolen Vette”) is the protection-failure modal
requester and remains intentionally unimplemented under the project's unnecessary-UI rule; this
diagnostic exists to cover the real police sound and cleanup/exit logic, not to recreate the gate.

The corrected route reaches the Lake Merced water collision and displays the game's own tow-truck
recovery artwork. A probe on the actual `_GetPicture` trap records PICT 140 at the resident wrapper
`Traffic+$663C`; that wrapper's saved return identifies the dynamic request at `Main+$0FD6`, with
the picture ID supplied in `D7`. The surrounding shipped routine creates and shows its window,
draws the picture, then waits at `Main+$0FE2` on `_Button` before restoring the graphics state and
returning. This is not a host framebuffer or a port-authored requester.

`GARAGE_CLICK=1` now answers that one recovery-screen `Button` poll after PICT 140 has actually
loaded, leaving production and ordinary `SKIP_INTRO=1` input unchanged. The first click-through
reached `$A034 VRemove` at `Main+$1FC6`: the original code passes its driving VBL record in `A0`
before returning to the outer loop. The Vertical Retrace bridge now removes that caller-owned
record, repairs its queue links and rotating scheduler index, and cancels the same record if it was
selected but not yet dispatched. On the target A1200 configuration the repeated route reaches
implemented depth 95, leaves driving disarmed, and continues without a loud stop through Macintosh
tick 8,773. This closes the first deterministic collision/transition target.

`amiga/driving_collision_picture.gdb` retains the low-overhead PICT/caller measurement. Its
probe-only capture avoids a conditional debugger breakpoint on every Toolbox trap, which slowed
the game enough to miss the event at the previous wall-time ceiling.

The corresponding static-impact source is now measured too. A probe-only private Line-A hook at
`Traffic+$3FFE` records the already-selected rectangle and nearest side, emulates the replaced
`CLR.W D3`, and returns without running the ordinary trap scheduling/presentation path. On the
same deterministic route, the last hit before PICT 140 is MAPS cell `(5,2)`, QUAD 1, collision-list
selector 63, record 0, nearest side 3 (`max-u`). It is special response-table entry 14 and invokes
jump-table export 229, `Traffic+$5AC2`, at tick 3459/frame 78. The `_GetPicture` request follows at
tick 3499/frame 79.

The shipped code closes the causal gap: `Traffic+$5AC2` sets the stop/recovery state, loads
`D6=900` and `D7=140`, and calls export 18 (`Main+$0F82`), whose dynamic `_GetPicture` call is at
`Main+$0FD6`. `amiga/driving_lake_static_collision.gdb` preserves this complete measurement. The
Lake Merced collision is therefore QUAD static-bounds behavior, not a moving-object `COLL` hit or a
host-generated transition.

The trap-address table is now active as well as stateful. Control+left-mouse is sampled only after
an original event-pump, `Button`, `StillDown`, or driving-boundary trap has completed; ordinary
mouse clicks retain their one-button Macintosh meaning. The safe return is redirected through a
user-mode `$A9F4 ExitToShell` request. The trap bridge routes that invocation to the address the
game installed with `SetTrapAddress`, preserving registers and USP.

The installed handler is the original cleanup at `Main+$2A5C`. It removes VBL work, closes the
built-in serial driver references `-6/-7`, shuts down the copied sound helper and disposes its
pointer, restores the old `$A9F4` address, then invokes `_ExitToShell` again. The port implements
those reached `Close` and `DisposePtr` operations rather than bypassing the handler. The second
trap enters a user-mode unwind trampoline at the stack saved immediately before the application
entry JSR, returning to `PlatformAmiga`, which restores input, interrupts, DMA, the OS view, and
the graphics library in the established reverse order.

`make PROBES=1 QUIT_PROBE=1` plus `amiga/quit_path.gdb` exercises the same deferred request without
headless input. On the target A1200 configuration it prints state 3 at the original trap with a
nonzero saved host stack, then state 4 in `vetteInputShutdown` with that stack cleared. It finally
stops after the restored OS copper/view have run for two fields and reports saved versus actual
DMA/interrupt masks plus the active-View match. This proves the whole
game-cleanup-to-Amiga-restoration chain; the old unreachable bare-left-button wait has been removed.

### Physical garage clicks use `FindWindow`

The deterministic `GARAGE_CLICK=1` route initially hid a user-path gap: a real mouse-down event
passes through `Initialize+$0AAA` and calls `_FindWindow` (`$A92C`), while the scripted events are
consumed by the selectors' already-active modal tracking loops. The missing trap therefore stopped
a normal build when the player clicked ACCEPT even though the diagnostic build could enter the
game.

The bridge now performs the Window Manager query. It consumes the event's global Point, walks the
visible window chain front-to-back, returns the matching `WindowPtr`, and distinguishes
`inContent`, `inMenuBar`, and `inDesk`. All shipped `WIND` resources use WDEF 2
(`plainDBoxProc`), so their structure and content regions coincide; no garage-control coordinates
or screen recognition are involved. `$A92C` is also present in the loud-stop name table, so any
future failure at that trap is identified correctly.

The following physical attempt reached `_DragWindow` (`$A925`) from `Main+$1BA8`. The live A5
dispatch table proves that this is the generic `inContent` fallback, not a request made by the
garage: the garage's mode-specific tracker had already failed to consume the click. Implementing
window dragging would therefore hide an input-position failure behind unnecessary UI.

The cause was the cursor half of the input bridge. `GetNextEvent` integrated the Amiga mouse
counters into a Macintosh-local point, but the tracked QuickDraw cursor was never composited into
the displayed pixels. A player was consequently aiming with the host pointer while the game tested
an invisible pointer that began at `(256,160)`. The presentation path now composites the installed
16x16 Cursor at that actual point, including its hot spot, black/white mask and XOR pixels, then
restores the chunky framebuffer after the dirty rectangle has been converted. Mouse movement dirties
only the union of the old and new cursor bounds; `HideCursor`, `ShowCursor`, and `SetCursor` likewise
restore or redraw that small area. `_DragWindow` is also named in the loud stop, so this path could
be identified rather than reported as an unknown trap.

A second physical test then clicked the still-visible ACCEPT artwork after the difficulty choices
appeared. The game's three active mode-1 rectangles cover only TRAINEE, ROOKIE, and PRO, so the
click legitimately fell through to `_DragWindow`. Crashing is nevertheless not acceptable player
behaviour. The standalone Amiga target has one fixed game surface and no movable desktop windows;
`DragWindow` therefore consumes its twelve parameter bytes and otherwise does nothing. This is a
platform-level fixed-window policy, not an ACCEPT-coordinate exception, and leaves the original
difficulty choices and their hit regions untouched.

### Modern keyboard aliases and original Mouse steering

The original key chart assigns Keyboard-mode steering/acceleration/braking to `J`/`L`, `I`, and
`M`, and Numeric-keypad mode to `4`/`6`, `8`, and `2`, but assigns no driving action to the
Macintosh cursor keys. The shipped default proved to be Numeric keypad: a live driving trace had
A5-$5310 set and A5-$5312/$5316/$5314 clear. The earlier cursor alias supplied only `J/L/I/M`, so
the selected numeric callback correctly ignored it. The Amiga bridge now sets both corresponding
virtual-key bits for each cursor direction; only the selected original mode consumes one set.
EventRecords still carry genuine Macintosh cursor-key codes, so the alias does not corrupt
non-driving keyboard input.

The first live test still failed before reaching this bridge: FS-UAE's keyboard-joystick fallback
was consuming the host cursor cluster. The launch script attempted to disable both ports with the
undocumented value `none`; the supported empty-device value is `nothing`. Production and debugger
launchers now use `joystick_port_0=mouse` and `joystick_port_1=nothing`, preserving the physical
mouse. Because FS-UAE has repeatedly reassigned the supposedly empty port across these projects,
the launchers additionally enable `full_keyboard` and install explicit host-arrow to Amiga-cursor
input mappings. FS-UAE defines custom mappings as overriding both defaults and `joystick_port_n`,
so cursor delivery no longer depends on its startup device assignment.

The manual and `MENU` 126 establish that Mouse is a shipped steering mode, separate from both
Keyboard and Joystick. Its menu handler sets A5-$5316; Main+$2BC8 reads `Mouse.h` at Page-0 $0832
for steering, while `Traffic+$6D24` reads `MBState` at $0172 and uses a pressed button as the
accelerator. The game installs one steering routine at a time, so the modes retain their original
mutually exclusive semantics. The standalone port leaves the shipped Numeric-keypad default active;
the dual cursor aliases make it usable on a modern keyboard while also surviving an explicit switch
to Keyboard mode. Unrelated keyboard commands remain live if Mouse is selected from the menu.

`Main+$2BC8` is the executable offset after the segment header. The resident `CODE 1` blob retains
that four-byte header, so the corresponding raw patch address is `$2BCC`. Using `$2BC8` made the
byte verification reject every clean build before `%A5Init`; correcting it restored the intro with
live animation, audio, and frame presentation.

Enabling it exposed more Page-0 dependencies rather than licensing direct access to Amiga low
memory. Six original centre-coordinate writes, the four reached Mouse/MBState reads, and the
`CurrentA5` store plus three callback reloads are byte-verified and rewritten, at identical
instruction width, to a private twenty-byte prefix below the shipped 31,272-byte A5 world. The
Amiga VBL trampoline already enters with the application A5, while the new shadow preserves the
shipped callback contract without touching Amiga address `$0904`. Amiga quadrature deltas maintain the redirected `MTemp`,
`RawMouse`, and `Mouse` points asynchronously at every safe trap boundary; the physical left
button maintains active-low `MBState`. The ordinary keyboard `KeyMap` remains independently live.

The later end-to-end trace found that the earlier “default Mouse” experiment never had Mouse mode
active: at callback selection A5-$5310 was `$0100` and A5-$5316 was zero, so Main correctly installed
the shipped numeric-keypad routine. Changing one conditional loader-default branch was insufficient
because the live A5 state is authoritative. `MOUSE_CONTROL_PROBE=1` is therefore diagnostic only;
it establishes the same mutually exclusive live flags as the Options-menu Mouse item at safe trap
boundaries without changing either consumer.

With A5-$5316 genuinely `$0100`, the original Mouse callback was selected with the redirected
`CurrentA5` intact. Real FS-UAE quadrature changed the host position and `Mouse.h`; the measured
callback produced right steering 2 and signed steering 2. After the countdown, Main's shipped
Mouse branch reached jump-table export 251 and its resolved address exactly matched
`Traffic+$6D24`. That routine tests active-low `MBState` and its zero fall-through writes -1 to
the car throttle word +$20. macOS denied automated pointer-click delivery in this run, so the
physical pressed byte was not claimed as dynamically observed; the released byte `$80`, live
dispatch, steering result, and exact throttle branch are independently recorded by
`amiga/driving_mouse_control.gdb` and `amiga/driving_mouse_button.gdb`. Production remains in the
shipped numeric-keypad mode, usable through the cursor aliases; Mouse remains a real menu choice.

### Natural traffic retirement and the freeway-mode gate

The Course Two input-only route reaches Main Map cell `(2,23)`, which has an `FWTP` key, but that
coordinate alone does not switch maps. A5-$3764 remains zero and `Traffic+$24DE` consequently
continues through the city-spawn branch. The earlier full-pool diagnosis was incomplete: the
shipped 35-tick scan at `Traffic+$252C` naturally selects traffic farther than `$1400` at `$257A`,
and `$1FB6` removes it and decrements the live count. Ordinary city spawning then fills the slot
again. The retirement path is working; it is not what prevents `$2302` from running.

Static MAPS/QUAD/collision-response tracing identifies the actual gate. Special collision handlers
set or clear A5-$3764 and switch the active map. Main Map cell `(2,6)`, for example, uses QUAD 21,
collision selector 16, and its first rectangle dispatches export 212 (`Traffic+$5632`), which sets
freeway mode. `amiga/driving_course_start.gdb` proves the original UI selections: Courses One,
Three, and Four all start at world `(0x3140,0x17e0)`, cell `(6,2)`, heading `$3000`; Course Two
starts at `(0x11c0,0xc0a0)`, cell `(2,24)`, with the same heading. The apparent proximity of
`(2,6)` to the shared start is false route guidance: the decoded full-cell bounds separate that
lane from the start's connected static-collision component. No route is claimed until ordinary
controls cross a response rectangle.

Course Two has a direct source-defined route to that response. Cells `(2,7)..(2,22)` leave an open
local-X corridor `0..383`; steering around its centre with the game's ordinary keypad controls
crosses `(2,6)` without modifying position, heading, collision, or mode state. On the measured run,
export 212 entered at tick 8514 with world `($1085,$3204)` and mode 0, then returned in the same tick
at `($1400,$15800)` with mode 1. `Traffic+$2302` ran naturally at tick 8517 with the pool still
`15/15` and the player updated to freeway cell `(2,42)`. The focused observer is
`amiga/driving_freeway_activation.gdb`.

The created-object trace closes the next link without confusing it with the other fourteen traffic
records. The first post-transition object was JHPF id 126 at cell `(2,40)`, world
`($13D5,$14800)`, heading 180. `Traffic+$0C78` projected it into NavigationMap key `$0078`;
`Traffic+$0D1C` matched FWTM ids `(125,125,126,126)`, selected FREE id 126 / selector 10, and
installed its path pointer. `Traffic+$1564` consumed the first `(0,-64)` byte pair and changed the
object's target to `($13D5,$147C0)` in the same tick. `amiga/driving_freeway_object.gdb` follows
that exact object pointer from construction through movement.

A probe-width mistake briefly obscured this result: A5-$3764 is a big-endian word, not a byte.
Reading the byte at `A5-$3764` observes the high byte of `0x0001` and therefore falsely reports
zero. The disassembly at `Traffic+$5654` and the corrected word-width runtime probe both establish
the transition. All freeway-mode GDB observers now read a signed short.

Long input-only diagnostic routes may compile with `FREEWAY_ROUTE=1`; that build acknowledges a
completed Mac draw at the Amiga presentation boundary without performing C2P or a buffer swap.
The original Mac drawing, physics, input, collision, and traffic code still execute. This reduces
the one-minute Course Two run from 260 to roughly 919 completed game frames. Production builds do
not define that flag and retain the complete display path.

The route now derives both steering bands from decoded collision data. Main-map cells
`(2,7)..(2,22)` leave local X `0..383` open; Freeway Map QUAD 120 selects list 71, whose two solid
rectangles leave local X `768..1280` open. A circular `$0000..$7FFF` heading error avoids the old
wraparound dead zone. The first nominal city line locked against the live `2BRN` object in cell
`(2,8)`: the player was at `($10B8,$47C8)` while `2BRN` was at `($109E,$47CB)` with collision state
`FF/14/02`, and the static-bounds probe had seen no hit since tick 1159. The route therefore moves
to the still-valid right half only through cells 9..7, then returns to its ordinary line. It uses
only original keypad bits and never edits position, traffic, collision, heading, or mode state.

With that local pass, an unmodified run crosses export 212 and reaches Freeway Map cell `(2,38)`
at world `($1482,$136D1)`, mode 1, after 3,404 completed game frames. The ordinary QUAD 221 /
selector-107 response 197 is a connected bend, not a missing Toolbox call or a dead end. It first
reduced local Z from 1745 to 742 and then 129 while increasing the heading from 8686 to 8806. A
longer observation proved the hand-off: response 197 carried the player diagonally into cell
`(3,37)`, world `($18CC,$12EA7)`, local `(204,1703)`, heading 7118, where QUAD 220 selects the same
selector and response. No game state was patched and no loud stop occurred. The focused read-only
observer is `amiga/driving_freeway_bend.gdb`.

`stage_c.gdb` reports full player state, the last static collision and the active object array when
a bounded run ends without a loud stop, so a slow source-defined turn is no longer mistaken for a
compatibility failure. The next route boundary begins from the proved `(3,37)` exit rather than
guessing a heading inside `(2,38)`.

Continuing the same input-only trajectory proves which connected branch follows. In `(3,37)` the
player advanced from local `(204,1703)` to `(1775,178)` and then `(1952,53)` while heading settled
at 8678 and speed remained 8. It therefore approached the north edge before the east edge. At tick
26056 the next response-197 call occurred in cell `(3,36)`, QUAD 249, at world
`($1FEB,$127FE)`, local `(2027,2046)`, heading 8438 and speed 9. This is a genuine cell transition,
not a coordinate prediction. `amiga/driving_freeway_after_bend.gdb` distinguishes a real
breakpoint from the runner's wall-time interrupt with an explicit hit flag and reports player
state through the stable A5 global; `amiga/driving_freeway_bend.gdb` uses the same scheme.

The first freeway diagnostic controller incorrectly treated QUAD 220 as another vertical lane. It
therefore fought response 197 and took 7,815 ticks to crawl diagonally from `(3,37)` into the
QUAD-249 branch. The decoded map proves that `(3,37)` is a northeast curve with a second connected
exit through QUAD 251 at `(4,37)`. Holding only the ordinary keypad steering toward heading
`$1000` in that cell reaches QUAD 251 at tick 24,514, world `($2000,$12A20)`, heading 4074 and
speed 10. That is 1,542 ticks earlier than the old route reached QUAD 249. On row 36 the controller
then uses selector 81's shipped solid bands—V `0..768` and `1280..2048`—to centre the open
`768..1280` east/west lane while steering east. No gameplay field is written directly.

QUAD 251 is itself the final response-197 curve cell, not the point at which steering should
already unwind east. Keeping the same ordinary `$1000` keypad target through both `(3,37)` and
`(4,37)` carried the player across the north edge into `(4,36)`. A bounded run measured world
`($2361,$127FA)`, local `(865,2042)`, heading 3010 and speed 8 at tick 36,603. An earlier full
Stage C snapshot caught the approach at `(4,37)`, local `(859,0)`, with selector 107/export 197
as the last static response; active traffic was already ahead in `(6,36)` rather than pinning the
player. `amiga/driving_freeway_row36.gdb` observes the original cell fields from the garage
transition and proves this hand-off without a target-side probe.

The apparent straight on row 36 does not begin immediately after that crossing. QUAD 219 at
`(4,36)` and QUAD 218 at `(5,36)` also select response 197; turning east in QUAD 219 repeatedly
held the player near local `(857,2042)`. Keeping the ordinary northeast steering through both
descriptors and enabling the selector-81 lane controller only at x=6 reaches `(6,36)` at tick
32,475, world `($2FFC,$124A0)`, local V 1184, heading 4123 and speed 32. V=1184 lies inside the
source-defined 768..1280 opening. The read-only `amiga/driving_freeway_straight.gdb` stops on the
original cell transition.

The same run also closes a timing-dependent city-route failure. Keeping the right-side `2BRN`
pass active through cell `(2,7)` could pin the rotated player hull at local `(259,933)` against
selector 8's solid bound beginning at U=384. Ending the pass after cell 8 lets the ordinary
southwest correction move the hull off that wall; the successful run then reached the freeway
and selector 81 without altering traffic or collision state.

The first repeatable stop inside selector 81 is a moving-object collision, not another static
edge. `amiga/driving_freeway_x6_collision.gdb` breaks on the shipped player response at
`Traffic+$0202` and preserves A3/A2 from the bilateral `COLL` test. At tick 30,825 it captured the
class-2 player at world `($3099,$124E1)`, local `(153,1249)`, and class-2 traffic tag `GGRY` at
`($30CB,$1242B)`, local `(203,1067)`: only 50 units ahead and 182 units across. The collision
vertex was zero and both objects were in their ordinary zero state before the original response.
This is inside `Traffic+$0600`'s 170-unit Manhattan prefilter once the centres converge; no static
response or missing Toolbox operation is involved.

Two tempting workarounds are disproved. Braking on traffic proximity stopped the player at x=6
with speed zero, but the obstruction did not clear. Steering the row-36 approach toward heading
`$1400` instead overshot to local V=771 in QUAD 218, against the opposite selector-81 band. Both
experiments were removed; the collision observer is read-only and the route still uses only
ordinary keypad input.

Long downstream compatibility runs no longer need to replay that complete route. A diagnostic
build may set `FREEWAY_START=<x-cell>`. After the ordinary garage and countdown, it first relocates
the player beside Main Map `(2,6)`, so the game's real export 212 still performs the freeway map
and traffic transition. Only after A5-$3764 confirms freeway mode does it relocate the player to
the centre of row 36 at the requested X cell. The relocation updates the rendered and physics
coordinates, swept-collision endpoints, four hull-history samples, the cached cell, the player
heading accumulator and its authoritative A5-$4FEC source; leaving any one of those owners stale
causes the original code to reconstruct the pre-relocation trajectory.

`FREEWAY_START=11` reached world `($5C00,$12400)`, cell `(11,36)`, local `(1024,1024)`, heading
zero and freeway mode 1 at tick 1,954. `amiga/driving_freeway_selector90.gdb` observes that handoff.
This is explicitly a diagnostic checkpoint, not evidence that the natural route cleared the
confirmed x=6 `VETT`/`GGRY` collision; production builds define neither `FREEWAY_START` nor the
input-only `FREEWAY_ROUTE` controller.

The checkpoint also makes the far freeway exit directly testable. Freeway cell `(30,36)` is QUAD
125, selector 72. Its third shipped rectangle is V `0..2048`, U `1536..2048`, and runtime response
table entry 11 maps that exact rectangle to jump-table export 230 (`Traffic+$5B26`). A diagnostic
start at cell 30, local `(1600,1024)`, entered export 230 at tick 1,957 with freeway mode 1. In the
same tick the original handler changed the physics coordinates to `($6080,$13C07)` and cleared
freeway mode. `Traffic+$69BE` then derived and stored Main Map cell `(12,39)`; that cell is QUAD 121,
selector 81. The rendered/current coordinate pair intentionally lagged the physics pair at that
instant, so `amiga/driving_freeway_exit.gdb` reports both instead of presenting the old pair as the
landing position. No missing Toolbox operation or host-side map switch is involved.

For work beyond that boundary, `MAIN_START=<x-cell>` optionally completes the diagnostic handoff
after export 230 has selected and entered Main Map. It discards the response approach's retained
heading and momentum, synchronizes the same complete player position history at row 39, and leaves
all subsequent game code running normally. With `MAIN_START=17`, the focused run reached world and
physics position `($8C00,$13C00)`, cell `(17,39)`, local `(1024,1024)`, heading zero and mode zero at
tick 1,960. That cell is the shipped QUAD 136 / selector 106 descriptor. The read-only observer is
`amiga/driving_main_return.gdb`; ordinary builds do not define `MAIN_START`.

The first no-stop phase profiler now brackets a fixed 300-field moving-driving window entirely in
the target program. On the target A1200 it accounts for exactly 100% of 24,031,875 beam ticks: C2P,
back-buffer synchronization and palette publication consume 80.353%; resident game/callback work
13.603%; drawing traps 5.671%; and all remaining exclusive categories below 0.4% together. The
nested VBI diagnostic is 0.322% and the same-rate empty bracket only 0.035%, so presentation—not
road logic or PICT decoding—is the first measured optimization target. The reproducible entry point
is `make driving-profile`; detailed numbers and measurement rules are in `docs/perf-method.md`.

The first presentation split found that the back-buffer synchronization copy alone occupied
39.711% of a focused 100-field window. Driving's next dirty rectangle covers the complete previous
one, so the port now skips synchronization only under that general containment condition; partial
dirty rectangles still copy forward untouched pixels. The synchronization row falls to zero and a
post-change capture of the second driving update round-trips all 163,840 chunky pixels through the
actual planar back buffer without one mismatch. This removes 81,920 redundant chip-RAM byte copies
per full driving update without a scene-specific condition.

The remaining conversion loop has a 68000 assembly twin that preserves the existing 4 KiB
pixel-pair representation while keeping its four table bases resident in address registers. Its
first byte-write form compared 2,874,776 bytes over 12,123 row spans with zero failures and reached
a 1.302 C/assembly beam-time ratio on the target A1200. Inspection of Mikael Kalms' public-domain
C2P collection then identified its OCS/ECS word-write strategy as the applicable part: the stock
routine requires one byte per pixel, and a verified per-row unpack made it 4.7% slower than C.
Instead, the packed kernel now combines two eight-pixel results in registers and writes four words
per 16 pixels. Its differential compared another 257,528 bytes with zero failures and improved the
C/assembly ratio to 1.462, about 11% less kernel time normalized through the same oracle. The
supporting full-conversion cost falls from 708,861 to 657,557 beam ticks per call (7.2%). Only the
back-to-back ratio is a controlled comparison. `C2P_C=1` remains the clean-C fallback and
`amiga/c2p_verify.gdb` is the regression reader.

The packed kernel then extends the same batching to 32 pixels and four longword plane writes,
retaining an exact 16-pixel word tail rather than widening dirty rectangles. The in-process
differential covers 722,008 more plane bytes with zero failures and raises the C/assembly ratio
from 1.462 to 1.718, a further 14.9% kernel reduction normalized through the oracle. The matching
supporting profile uses 4,474,820 ticks for eight full conversions, or 559,353 per call (also 14.9%
below 657,557), and attributes 55.945% of the 100-field window to C2P plus palette.

A nested profile split then identified the full-frame combined row precisely: C2P itself was
4,443,105 ticks (55.955% of the fixed 100-field window), palette construction 19,084 (0.240%), and
remaining presentation overhead 3,249 (0.041%); synchronization and back-pressure were both zero.

The renderer-derived driving dirty list reduced one warmed 100-field window to 3,779,452 C2P ticks
for nine calls, about 419,939 per call versus roughly 555,388 in the preceding eight-call full-frame
profile (24.4% less per call). Back-buffer synchronization is 7,933 ticks (0.100%). The added raster
hooks initially appeared in the broader compatibility row, which was 364,116 ticks for 457 calls.

The `$AFFD` hook now has an assembly fast path before the general Line-A register save and C++
dispatch. It appends the raw register bounds to a 64-entry fast-RAM buffer and the ordinary driving
boundary coalesces them once per frame. The same representative rectangle capture remains exactly
fourteen entries. In the matching 100-field profile this removes 432 general dispatches and reduces
the compatibility row to 192,036 ticks for 25 calls. C2P varied with the advancing scene, so the
whole-window difference is not presented as a controlled speed ratio. The exclusive rows still
total exactly 100%. Further presentation work therefore targets conversion, not palette caching or
the now-lightweight bound capture.

The next representation step combines four packed pixels per fast-RAM lookup instead of two. A
256 KiB table halves lookup traffic while retaining the packed chunky source, the interleaved
four-plane destination, 16-pixel dirty alignment, and the four longword chip writes per 32 pixels.
The assembly/C differential compares 2,748,000 bytes with zero failures; its controlled C/assembly
ratio rises from 1.718 to 1.976, about 13.1% less kernel time. A warmed 100-field A1200 profile uses
3,685,815 C2P ticks over ten calls (about 368,582 each), 12.2% below the preceding 419,939-per-call
dirty-list measurement. C2P now accounts for 46.297% of that window.

On the supported A1200 target, the table lookup now uses the 68020's scaled long-index effective
address rather than a manual shift, base copy, and add. Only `C2P.s` is assembled for 68020; the
resident Macintosh code and other port assembly retain their broader settings. The verifier covers
3,243,112 bytes with zero failures and improves the controlled C/assembly ratio from 1.976 to 2.521
(21.6% less kernel time). A warmed 100-field profile records 3,326,465 C2P ticks over eleven calls,
about 302,406 each and 18.0% below the preceding version. C2P falls to 41.532% of that window.

The same kernel now traverses all rows of one normalized dirty rectangle in a single assembly call.
This keeps the dirty-list representation, interleaved destination, exact 16-pixel horizontal
bounds, 256-byte source/destination row strides, and the established inner transpose unchanged; it
removes the per-scanline call and register-save cost. The assembly/C differential covers another
3,068,576 plane bytes with zero failures. In the corrected-scheduler 300-field A1200 profile, C2P
uses 9,185,732 ticks over 32 calls, about 287,054 per update versus 303,395 immediately before the
change—a 5.4% reduction. The exclusive profile is now 38.266% C2P, 45.562% resident game/callbacks,
12.297% drawing traps, and less than 2.8% for every other row. The next measured port-owned target
is therefore the drawing-trap row, not palette, synchronization, or presentation bookkeeping.

The drawing row is now split at the implemented `_CopyBits` core. In a 300-field A1200 run it owns
2,914,419 of 2,957,204 drawing ticks over 32 calls—98.6% of the category, about 91,076 ticks per
publish. The remaining trap dispatch and bookkeeping is only 42,785 ticks. Vette's source GWorld
has a 260-byte row stride while the 512-pixel logical screen has a 256-byte stride, so the generic
path performs 320 exact row copies rather than one contiguous 81,920-byte move.

A source-derived dirty-publish experiment copied the full 512×198 exterior plus the same coalesced
dashboard/mirror bounds used by C2P. It was byte- and pixel-exact across 40 frames/all 320 rows and
transferred about 63.3 KiB in 14 rectangles per update, but its row walks cost about 106,323 ticks
per call—16.7% more than the generic full copy. It was removed. Dirty rectangles remain the right
representation for the expensive C2P into chip RAM, not for this fast-RAM-to-fast-RAM publish.

The production publisher therefore keeps the full 512×320 transfer but specializes its proven
shape. A 68000 assembly routine copies 256 bytes with unrolled longword moves, skips the source
GWorld's four padding bytes, and repeats for 320 rows. Strict dispatch guards preserve the generic
CopyBits path for every other shape, mode, mask, stride, destination, or ColorTable relationship.
The in-process C/assembly differential compared 2,048,000 bytes over 25 moving calls with zero
failures and measured a 2.366 speed ratio. The display guard then verified 40 frames and every one
of their 320 rows with zero bad pixels. In the next 300-field profile the CopyBits core is 1,293,230
ticks over 34 calls, about 38,036 per publish, and the complete drawing row is 5.554% rather than
12.342%. C2P is now the largest remaining port-owned row at 41.385%.

A diagnostic destination split then ran each normalized C2P rectangle through the identical
assembly routine into the real chip-RAM back buffer and an equivalent fast-RAM buffer. Across 106
moving frames and 952 rectangles, chip RAM used 25,459,010 ticks versus 16,977,889 for fast RAM, a
1.500 ratio. The transpose/table path therefore represents roughly two-thirds of current C2P time;
the additional chip-write penalty is about one-third. Post-alignment and lossless coalescing cover
104,792 pixels per frame, 63.960% of the surface, in 8.981 rectangles per frame. This rules out
dirty coverage as the first lever and directs the next work back into the transpose/lookup kernel.

That lookup pair formerly required a longword shift for every eight pixels. A second 256 KiB copy
of the four-pixel table now stores the already-shifted result, so the assembly kernel replaces the
shift with a lookup at a fixed table offset. This keeps the source, dirty-list geometry, interleaved
bitplanes, and chip-write pattern unchanged. The C/assembly differential compares 2,685,680 bytes
with zero failures and improves the controlled ratio from 2.521 to 2.798, equivalent to 9.9% less
kernel time. The display guard checks 40 consecutive frames and all 320 rows with zero bad pixels.
In the standard 300-field A1200 profile C2P uses 9,766,871 ticks over 35 updates, about 279,053 per
update versus 292,221 immediately before the change, and occupies 40.647% of the accounted window.
The additional table costs 256 KiB of the configured 8 MiB fast RAM.

The next instruction-count reduction needs no additional table memory. Both lookup tables are
physically rotated by 32,768 entries and their assembly bases point at the physical midpoint. The
68020's sign-extended scaled word index can then address every logical entry directly, eliminating
eight index-register clears per 32 converted pixels. The oracle compares 2,685,632 bytes with zero
failures and the controlled C/assembly ratio rises from 2.798 to 2.927, another 4.4% less kernel
time. The 40-frame/all-row display guard remains exact. In the standard 300-field profile C2P uses
9,384,319 ticks over 36 updates, about 260,675 each versus 279,053 before the change, and falls to
39.097% of the fully accounted window.

The differential now has a real moving checkpoint rather than a neutral car with a held
accelerator. `VETTE_DRIVING_MOTION=1` makes the Macintosh harness wait for a valid full-window
CopyBits from Vette, latch the application A5 at that trap boundary, wait for countdown state 3,
hold top-row `+` until the original scanner reports gear 1, and assert keypad 8 at the same input
boundary used by the Amiga harness. It records distinct 512-row source GWorlds and player state.
`make driving-motion-capture` records the Amiga side at the identical CopyBits boundary;
`make driving-motion-compare` pairs them by RPM, gear, speed, position and heading.

The first run produced 37 Macintosh and 40 Amiga moving states, with several shared rendered-player
tuples. This found the next synchronization requirement rather than a palette guess: the first
shared tuple differed in only 46 lower-right pixels, while later tuples differed in dashboard and
scene regions. The key now also includes the separate physics position at car+$6E/+$72, and the
harness saves the complete 31,272-byte A5-global block beside every frame for source-state diagnosis.

At a state where RPM, gear, speed, rendered position, physics position and heading all agree, the
remaining delta is 970 pixels at `(385,227)-(479,275)`. The A5 blocks identify the actual input:
the Macintosh has zero at A5-$2EA4..-$2E9E while the Amiga has `$01,$01,$00,$01,$01,$00`.
`Traffic+$5F04/$5F70` derives those six traffic-control flags and `Traffic+$6282` selects the
right-dashboard raster from them. The two naturally sampled runs therefore have different traffic
signal state; this is not evidence of a CopyBits, palette, or C2P defect.

Relative callback positions originally differed for a concrete compatibility reason: the PAL VBI
advanced `Ticks` at the Macintosh 60 Hz rate, but the scheduler bulk-aged each record and could
dispatch a one-tick task only once per 50 Hz field. Every fifth field therefore represented two
Macintosh ticks while losing the second callback. The scheduler now queues elapsed virtual ticks
and executes each as a separate Vertical Retrace Manager pass: all records age once, all due tasks
run in queue order, and a task rearmed to one tick may correctly run again in the second pass.
Callbacks remain user-mode and are still delivered one at a time at safe trap boundaries.

The corrected moving capture reaches 40 distinct states and three naturally identical complete
player tuples. The later of those differs by only 13 pixels, but all three originally had different
active traffic objects. The initial roster was therefore already divergent before the moving VBL
loop, rather than being caused solely by its former 50/60 Hz callback loss. The pre-driving trace
then exposed the system/QuickDraw seed ownership error above. It also showed why merely sharing the
application's initial seed was insufficient: MAME consumes three values while the selector model
rotates, whereas the accelerated Amiga click harness deliberately skips those animation frames.

The motion differential now applies the same `$3BD90000` seed at the first road-setup `Random`
call on both machines. This is a diagnostic-only input fixture selected by the original route
state (`stage == driving` in MAME, final ACCEPT phase on Amiga); normal builds remain clock-seeded.
Both first captured active lists are consequently `VETT`, `OPPO`, `TAXI`. Their records have
already advanced by different amounts because completed frames originally occurred about every
seven Macintosh ticks and every thirteen Amiga ticks. After the two C2P optimizations the Amiga
interval falls to roughly ten or eleven ticks, and three complete player tuples align naturally
again. The best pair differs by only 13 dashboard pixels, but its active objects have advanced and
spawned at different phases. The next gate must therefore establish an equivalent simulation-phase
checkpoint independently of presentation cadence. The stationary RPM-11 checkpoint remains
pixel-exact after the scheduler change.

One input discrepancy was then removed at its source boundary. The Macintosh harness already holds
keypad 8 before pulsing top-row `+`, but the Amiga harness had waited until the car record showed
Gear 1 before asserting the accelerator. It now presents both documented inputs in the same
`GetKeys` sample while still allowing the shipped scanner and drivetrain to perform the shift.
Both sides consequently reach RPM 13, Gear 1, speed 10, position `(12589,6112)`, heading 12288, with
identical rendered and physics coordinates. At that state all six traffic-control flags agree and
the complete 512x198 exterior viewport is pixel-exact. The only 46 differences in the 512x342
composition surface lie at `(394,298)-(490,341)`, in the time-dependent lower-right dashboard.
This proves moving 3D scene fidelity at a real shared state without transplanting game state or
patching renderer data; dashboard phase and additional traffic/view coverage remain open.

The capture saves the current 200-byte car record and every 200-byte record in Traffic's active
object list. That list is source-derived. The routine at Traffic+$2002 increments the pool cursor,
links the zeroed record through A5-$367C, and returns it; it is not by itself an active-object
initializer. Its Traffic+$24DE caller then assigns the type at record+$28 and conditionally runs
one of the position initializers before converging at Traffic+$2528. The active count at A5-$3696
only rises for records accepted by that later work. Before the road-seed fixture, a naturally shared
player state had three Macintosh objects (`VETT`, `OPPO`, `TAXI`) but four Amiga objects (`VETT`,
`OPPO`, `AMBU`, `LOVE`), which explained the lower-dashboard delta. The synchronized road seed now
proves that the two original Traffic initializers select the same three-object roster. `make
driving-motion-reference` and `driving-motion-capture` supply that fixture only to their diagnostic
builds. `driving-motion-compare` now keys completed frames by the full player state and the complete
captured Traffic roster, including every object's type, position, speed, and heading. The current
37 Macintosh and 40 Amiga frames contain no equivalent complete game state, so the comparator
correctly refuses to turn their timing difference into a pixel-fidelity result. A self-comparison
finds all 37 reference states and reports 6,478,848 exact pixels, proving the complete-state key and
comparison path. The next differential needs a short equivalent-phase checkpoint rather than a
faster presentation path.

The phase investigation now records two source-level ordinals beside every moving frame. The
Macintosh harness locates `Main+$1FD2` from the unique, byte-verified original TST/BEQ sequence in
the relocatable CODE image; the port increments the corresponding counter in its existing private
boundary handler. Both also count the driving VBL task (the third task installed on the Mac after
intro and sound, and the second live queue record after intro retires). These counters are
diagnostic observations only. The sequence comparator can pair on an explicit manifest field and
can pair repeated values in capture order, which matters when two main-loop frames complete during
one traffic callback.

That measurement rejects the driving-task callback as the only missing Traffic phase clock. The
first exact player state follows callback 333 / absolute driving iteration 45 on the Macintosh and
callback 109 / iteration 27 on the Amiga because original road construction consumes very
different emulated time. Experimental equal-callback captures still did not align the traffic
records. The clean unmodified captures retain the same `VETT`, `OPPO`, `TAXI` roster and exact
player/opponent records at their first shared player state, while TAXI is at `(12384,9026)` on the
Macintosh and `(12384,9639)` on Amiga. The 46 changed pixels remain confined to the lower-right
dashboard. No timing freeze or state transplant is retained; the next trace follows the original
write which establishes TAXI's first coordinate to its real time/phase input.

That write trace separates cached rendering position from authoritative motion state. The first
post-capture writer at Macintosh `$06301C` maps byte-for-byte to `Traffic+$1778`, immediately after
`MOVE.L $72(A3),$08(A3)`: it only publishes physics Y to the renderer's cached Y. Watching the
unaligned long at object `+$72` then maps the update chain to `Traffic+$18EC` (copy cached Y back to
physics Y at the beginning of an object pass) and `Traffic+$0BB2` (add the current motion delta in
D1). The measured TAXI delta is normally -39 per update. The other writes reported by the aligned
68020 bus watch are adjacent hull/history fields sharing its two longword bus lanes, not additional
Y updates.

The manifest now retains the absolute `Main+$1FD2` count rather than normalizing it at the first
capture. The Macintosh first moving frame is iteration 45; the A1200's is iteration 27. A
diagnostic-only experiment left the target car neutral until iteration 45 and brought TAXI to
within one 39-unit update, confirming that the accumulated coordinate difference is main-loop
phase. It did not synchronize Traffic as a whole: LOVE and then GRED had already spawned on the
target while the Macintosh roster was still shorter. The long input delay is therefore not
retained. Object motion and spawn/deadline scheduling are separate phase inputs.

The paired initialization trace now observes both Traffic+$2018 (immediately after the link) and
Traffic+$2528 (after the caller's initializer). It filters out two earlier users of the same pool
allocator (`VETT` and `OPPO`) by the verified return address Traffic+$2508. On both machines the
candidate sequence begins `COP!`, `GGRY`, `TAXI`, and the first accepted TAXI has type 6 with both
cached and physics coordinates exactly `(0x3060,0x2800)`. The Mac reaches those candidates at ticks
4105, 4145, and 4185; the target reaches them at 1735, 1773, and 1816. Thus the 35-tick gate at
Traffic+$25CC is behaving faithfully, and neither the resource data, random choice, nor position
initializer causes the later discrepancy.

The trace exposed a real scheduling defect. From the first candidate through TAXI—80 or 81 ticks
on either machine—the Macintosh driving task advanced by 26 callbacks, while the Amiga task
advanced by only six. The target scheduler accumulated every elapsed virtual VBL tick correctly,
but released only one due callback at a trap safe point before resuming application code. When
more than one task/pass was pending, work remained queued behind rendering.

Long fidelity and audio observations now have a separate normal-road input workload. Defining
`FOLLOW_ROAD=1` with the deterministic garage harness holds the game's own keypad-9
accelerate/right control after the original shift scanner reaches first gear. Course One begins at
about heading `$3000` on the game's `$0000..$3FFF` heading circle, and that control increases the
heading; it is released near `$3E00`, before the wrap, and keypad 8 remains held for straight acceleration. The target checkpoint
continues for 100 original driving iterations after startup rather than ending the emulator as soon
as steering is released. `amiga/driving_follow_road.gdb` preserves the bounded proof. This
does not replace the straight-to-water route, which remains the collision/recovery fixture when
`FOLLOW_ROAD` is omitted.

The user-mode trampoline now leaves the interrupted application's register image parked and drains
all due VBL queue work before returning. It reloads that image for every callback, installs the
record's A0 and saved A5, and asks the same queue scheduler for the next task after each return, so
callback order and task self-removal retain their original contracts. The dispatcher also tracks
the tick represented by each queued VBL pass. Direct `Ticks` reads see that historical value during
the callback and the live value is restored before application code resumes; a backlog is no
longer collapsed onto one present-day time sample. The first 76 target ticks now deliver 25 driving
callbacks versus 26 in the first 80 Macintosh ticks.

This repair reduces the three state-paired motion captures from 6,948 differing pixels to 105.
It does not erase the traffic-coordinate difference, which is now proven to be frame cadence rather
than VBL cadence: TAXI's `$18EC`/`$0BB2` physics path runs from the ordinary Traffic pass in each
completed main-loop iteration. The Macintosh reaches the first moving player state at iteration 45
after roughly 6–7 ticks per frame; the target reaches it at iteration 26 after roughly 11–12 ticks
per frame. Both have allowed about the same wall-clock interval since TAXI was initialized, but the
Macintosh has executed about fourteen more TAXI updates. This is the expected completed-frame
cadence difference between machines of different effective speed, not a clock, random, resource,
initializer, or rendering compatibility failure. Further C2P tuning is deferred; fidelity work
continues from an equivalent complete-state checkpoint instead.

The 26-record sightseeing table used by `Main+$3456` was also decoded as a possible source-native
shortcut. Record 4 is cell `(6,26)`, only six cells from the export-221 transition at `(6,32)`, but
the documented T command is conditional on Tour Mode. Five ordinary T down/up scans during the
race reached that handler with A5-$5318 clear; every call returned without advancing the tour
index or changing the player position. The separate Options-menu state must not be bypassed by
patching the guard. The bounded observation script `amiga/driving_freeway_movement.gdb` records
exports 207 and 221, retirement, `FWTM`/`FREE` movement, and the first natural `$2302` spawn without
altering game state.

The moving visual regression no longer pays for a software breakpoint on every startup CopyBits.
A diagnostic-only no-op boundary is compiled immediately after the original full-window driving
CopyBits succeeds, while its source GWorld is still live. GDB stops only there and saves the same
512-row, 260-byte-row indexed source surface as the Macintosh trap tap. This observation boundary
does not copy pixels, patch state, or exist in production builds.

`make driving-motion-viewport-compare` pairs captures by RPM, gear, speed, rendered and physics
position, and heading, then compares only the 512x198 exterior. It requires at least one paired
region to be pixel-exact. The current independent captures share the moving state RPM 18, gear 1,
speed 14, position `(12531,6112)`, heading 12288; all 101,376 exterior pixels are exact. This is a
bounded renderer-fidelity result, not a claim that differently paced traffic is synchronized. The
existing `driving-motion-compare` still includes every active Traffic record in its key and still
refuses to compare when no complete shared roster exists.

The Macintosh audio oracle formerly reused `VETTE_DRIVING_MOTION=1` merely to obtain moving input.
That mode also owns and cleans the visual motion artifacts, so a right-turn audio run silently
replaced the straight-driving framebuffer oracle. Audio now uses `VETTE_DRIVING_AUDIO=1`: it keeps
the identical garage, shift, acceleration, and road-following workload without arming, deleting,
or writing any visual capture. Visual and audio regressions consequently have independent inputs
and artifact lifetimes.

## Correction to the MAME log

The 51-row MAME table is a measurement of that reference run, not fabricated data, but the live
standalone path has already called setup traps missing from or much later in its first-use order.
Therefore the table's 36-trap intro count is a **floor**, not the standalone implementation total.
The reason for the tracer omission remains to be audited; Stage C uses its own loud stop as the
authoritative work queue meanwhile.
