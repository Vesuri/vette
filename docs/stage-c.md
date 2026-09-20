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
first synchronized frame is consequently exact. Captures two through four differ by 18, 62, and
68 pixels respectively, all in the moving lower cockpit/driver area rather than the mirror; they
are beyond the single named-frame synchronization boundary. `amiga/driving_fred_state.gdb`,
`driving_raster_source.gdb`, and `driving_mirror_picture.gdb` retain the correction trail.

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
nonzero saved host stack, then state 4 in `vetteInputShutdown` with that stack cleared. This proves
the whole game-cleanup-to-Amiga-restoration chain; the old unreachable bare-left-button wait has
been removed.

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

The 26-record sightseeing table used by `Main+$3456` was also decoded as a possible source-native
shortcut. Record 4 is cell `(6,26)`, only six cells from the export-221 transition at `(6,32)`, but
the documented T command is conditional on Tour Mode. Five ordinary T down/up scans during the
race reached that handler with A5-$5318 clear; every call returned without advancing the tour
index or changing the player position. The separate Options-menu state must not be bypassed by
patching the guard. The bounded observation script `amiga/driving_freeway_movement.gdb` records
exports 207 and 221, retirement, `FWTM`/`FREE` movement, and the first natural `$2302` spawn without
altering game state.

## Correction to the MAME log

The 51-row MAME table is a measurement of that reference run, not fabricated data, but the live
standalone path has already called setup traps missing from or much later in its first-use order.
Therefore the table's 36-trap intro count is a **floor**, not the standalone implementation total.
The reason for the tracer omission remains to be audited; Stage C uses its own loud stop as the
authoritative work queue meanwhile.
