# The A-trap log — what the game actually calls, measured

⭐⭐ **This is the port's work list, and it is a MEASUREMENT, not a static sweep.** Under option A the
game's own 68000 code runs, so the set of `$Axxx` traps it executes *is* the surface the port must
supply, and the order it first needs them in is the order to build them.

Produced by `tools/mac_traps.lua` (+ `tools/gen_trap_names.py`) against the unpatched original under
MAME, launch → title → intro → garage → vehicle/course selectors → driving. Re-run it with
the headless recipe in `CLAUDE.md`; it writes
`ref/mame/traps.txt`.

⚠⚠ **Stage C correction:** this table accurately describes the captured MAME run, but it is not a
complete first-use script for the standalone port. The live Amiga loud-stop loop executes several
setup traps absent from, or later in, this ordering (`InitGraf`, `TEInit`, `InitDialogs`,
`OpenResFile`, `SysEnvirons`, and others). Its 63 total and 36-before-intro counts are therefore
**floors for implementation**, not exact totals. See `docs/stage-c.md`; the tracer omission still
needs explanation.

⚠⚠ **Read §The six ways this measurement lies before re-running or extending the tracer.** Five of
the six produced a plausible, quiet wrong answer that was believed for a while, and one of them put
**thirty extra traps** on this list.

## ⭐⭐ THE REFERENCE CAPTURE: its first 36 logged traps paint the intro screen

`[MEASURED]`, by shooting the framebuffer every 240 frames alongside the log:

| frame | what is on screen |
|---|---|
| 1288 | the jump table goes resident — ⭐ **the game's own code starts running here**, 230 frames before the Finder hands over the front window |
| 1518 | the app is frontmost (`CurApName`) |
| 1638 | `DrawPicture` #1 — 512×323, the title art, into the offscreen GWorld |
| 1698–1699 | `CopyBits`, `EraseRect` — **rows 35–36**, the last new traps before the art is on screen |
| **1758** | ⭐ **the intro screen is fully painted** — the Golden Gate / San Francisco title art |
| 1781–1813 | rows 37–38 (`ClipRect`, `Button`) — the **animation + wait-for-click loop**, after the art is already up |
| 3438 | a blank white window: the intro is gone, the garage is being built |
| 3678 | the garage / car-selection screen with the menu bar |

- ⭐⭐ **Rows 1–36 = paint the intro screen.** That is Target 1.
- **Rows 37–38 = run it** — the animated overlay and `Button` polling (10 887 calls).
- **Rows 39–51 = teardown + the garage screen and its menu bar.** Not Target 1.

⚠⚠ **This supersedes an earlier "18 traps" figure, which was wrong and wrong in the dangerous
direction.** That measurement cleared its accumulators when `CurApName` flipped at frame 1518, to
drop the Finder's boot noise — and in doing so it discarded **the game's own first 230 frames**:
`%A5Init`, QuickDraw/Font/Menu/Window init, the `QUAD` and 160 `OBJS` resource loads, the GWorld
creation. Target 1 is twice the size it appeared to be. Nothing is *removed* from the old 18; 18
more sit in front of them.

⭐ The intro art's **"© 1991 SPHERE, INC"** is the game's own date and it is now `[MEASURED]`
everywhere: `vers` 1 and `VETT` 0 in **both** builds read *"VETTE! version 1.02 / © 1991 Sphere,
Inc."*. The 1989 the docs used to carry was unsourced — see `docs/mac-reference-loop.md`.

## Two measured windows: 51 through the menu, 63 through driving

**243 056 dispatches** through the Line-A vector; **234 682** decoded to an `$Axxx` word;
**103 674 from ROM** and **131 008 from RAM**. ⚠⚠ *"From RAM" is not "from the game"*:

| Caller | What it is | Dispatches |
|---|---|---|
| ⭐ the mapped `CODE` segments, attributed **live** | **the game** — **51 distinct traps** | **84 876** |
| `$7Bxxxx` / `$7Cxxxx` / `$00xxxx`–`$03xxxx` / `$0Cxxxx` | the System's ROM patch block and the low system heap, calling traps *on the game's behalf* | 46 132 |
| `$77xxxx` | ⚠ **the Finder**, not the game — see lie #5 | (11 980, excluded) |
| `$408xxxxx` | ROM | 103 674 |

The port implements `DrawPicture` itself, so it never sees the `SetHandleSize` that Apple's
`DrawPicture` makes. That is why the split matters.

### Dispatches per segment, attributed live

| seg | name | dispatches | distinct trap sites |
|---|---|---|---|
| 8 | `Intro` | 66 744 | 103 |
| 1 | `Main` | 17 040 | 31 |
| 2 | `Initialize` | 914 | 34 |
| 4 | `load` | 51 | 46 |
| 6 | `Traffic` | 49 | 3 |
| 10 | `%A5Init` | 46 | **1** |
| 9 | `sound` | 32 | 1 |

⭐ `Intro` is 3 442 bytes and accounts for 79% of the game's trap traffic. `load` is the opposite
shape: 51 calls from 46 distinct sites — straight-line startup code.

The extended deterministic run skips the intro at its first `Button` poll, traverses the garage,
vehicle and course selectors, answers the unmodified copy-protection requester, and waits 1,200
frames in driving. It records **145,957 dispatches**, **63 distinct traps called by mapped game
segments**, and 15,896 game-owned dispatches. The lower traffic is expected because this window
does not play the full intro; the earlier complete-intro counts above remain the authority for
Target 1. The extended run adds the twelve rows below and changes none of the first 51 identities.

## The work list, in measured first-use order

`caller` is resolved to `(segment, offset)` in **`Color VETTE!`**, **at the moment of the call**.
`from-RAM` / `from-ROM` are call counts over the relevant capture window, by where the *caller* was.
Rows 1–51 retain the complete-intro/menu capture's counts; rows 52–63 carry the extended
garage-to-driving capture's counts.

| # | word | name | flags | from-RAM | from-ROM | frame | caller |
|---|---|---|---|---|---|---|---|
| 1 | `A02E` | ⭐ **BlockMove** | | 166 | 638 | 1291 | `%A5Init+00B4` |
| 2 | `A9F1` | UnLoadSeg | | 2 395 | 0 | 1294 | `Main+1EE6` |
| 3 | `A8FE` | InitFonts | | 2 | 0 | 1295 | `Main+055E` |
| 4 | `A912` | InitWindows | | 2 | 0 | 1295 | `Main+0560` |
| 5 | `A930` | InitMenus | | 2 | 0 | 1304 | `Main+0562` |
| 6 | `A746` | GetToolTrapAddress | trashA0+sys+clear | 30 | 0 | 1304 | `Main+0580` |
| 7 | `A31E` | NewPtrClear | sys+clear | 3 | 0 | 1306 | `Traffic+2616` |
| 8 | `AA32` | GetGDevice | | 2 | 0 | 1309 | `Initialize+0984` |
| 9 | `A9A0` | ⭐ **GetResource** | | 4 312 | 982 | 1309 | `Main+2C88` |
| 10 | `A064` | MoveHHi | | 12 | 0 | 1309 | `Main+2C9C` |
| 11 | `A029` | HLock | | 528 | 72 | 1309 | `Main+2CA0` |
| 12 | `A11E` | NewPtr | clear | 639 | 5 | 1316 | `Initialize+06D6` |
| 13 | `A998` | UseResFile | | 6 940 | 0 | 1464 | `Initialize+072E` |
| 14 | `A994` | CurResFile | | 6 912 | 0 | 1464 | `load+0450` |
| 15 | `AA46` | GetNewCWindow | | 1 | 0 | 1464 | `load+046A` |
| 16 | `A91B` | MoveWindow | | 5 | 0 | 1470 | `Main+0954` |
| 17 | `AA92` | GetNewPalette | | 5 | 0 | 1472 | `load+04A0` |
| 18 | `A873` | ⭐ **SetPort** | | **19 283** | 237 | 1472 | `load+04AA` |
| 19 | `AA28` | GetCTSeed | | 3 | 0 | 1472 | `load+04AE` |
| 20 | `A91F` | SelectWindow | | 1 | 0 | 1535 | `load+04D2` |
| 21 | `A922` | BeginUpDate | | 5 | 0 | 1535 | `load+04D8` |
| 22 | `A923` | EndUpDate | | 4 | 0 | 1535 | `load+04DE` |
| 23 | `A889` | TextMode | | 1 | 0 | 1535 | `load+04E2` |
| 24 | `A9B9` | GetCursor | | 9 | 0 | 1535 | `load+003E` |
| 25 | `A97C` | GetNewDialog | | 1 | 0 | 1536 | `load+0054` |
| 26 | `AB1D` | ⭐ **QDExtensions** | | 14 | 0 | 1544 | `Initialize+0134` |
| 27 | `AA95` | SetPalette | | 12 | 0 | 1549 | `Initialize+0032` |
| 28 | `A146` | GetTrapAddress | clear | 35 | 13 | 1617 | `load+00AA` |
| 29 | `A047` | ⚠ **SetTrapAddress** | | 16 | 0 | 1617 | `load+00B8` |
| 30 | `A983` | DisposeDialog | | 1 | 0 | 1635 | `load+00C6` |
| 31 | `A850` | InitCursor | | 1 | 0 | 1636 | `load+00C8` |
| 32 | `A9BC` | GetPicture | | 47 | 0 | 1637 | `Traffic+663C` |
| 33 | `A8F6` | ⭐ **DrawPicture** | | **16** | 0 | 1638 | `Intro+003E` |
| 34 | `A89B` | PenSize | | 2 | 0 | 1698 | `Intro+0048` |
| 35 | `A8EC` | ⭐ **CopyBits** | | 2 622 | 0 | 1698 | `Intro+0070` |
| 36 | `A8A3` | EraseRect | | 8 979 | 1 | 1699 | `Intro+007C` |
| 37 | `A87B` | ClipRect | | 14 438 | 14 | 1781 | `Intro+00FE` |
| 38 | `A974` | Button | | 10 887 | 0 | 1813 | `Intro+0224` |
| 39 | `A914` | DisposeWindow | | 1 | 0 | 3558 | `Intro+0ADA` |
| 40 | `A90D` | PaintBehind | | 1 | 11 | 3582 | `Intro+0B10` |
| 41 | `A04D` | PurgeMem | | 2 | 0 | 3659 | `Intro+0B82` |
| 42 | `A04C` | CompactMem | | 2 | 15 | 3662 | `Intro+0B8A` |
| 43 | `A93A` | DisableItem | | 2 | 0 | 3808 | `Intro+0D3A` |
| 44 | `A931` | NewMenu | | 1 | 0 | 3808 | `load+050C` |
| 45 | `A933` | AppendMenu | | 1 | 0 | 3808 | `load+0524` |
| 46 | `A9BF` | GetRMenu | | 6 | 0 | 3818 | `load+05A4` |
| 47 | `A937` | DrawMenuBar | | 4 | 3 | 3820 | `load+0676` |
| 48 | `A970` | ⭐ **GetNextEvent** | | 17 764 | 0 | 3832 | `Main+29F2` |
| 49 | `A9B4` | SystemTask | | 851 | 0 | 3832 | `Main+29E6` |
| 50 | `AA94` | ActivatePalette | | 21 | 0 | 3837 | `Initialize+0B30` |
| 51 | `A874` | GetPort | | 1 656 | 17 759 | 3838 | `Main+05C6` |
| 52 | `A924` | FrontWindow | | 2 466 | 33 | 2246 | `Initialize+0C9E` |
| 53 | `A871` | GlobalToLocal | | 60 | 13 | 2246 | `Initialize+0CB4` |
| 54 | `A8AD` | PtInRect | | 82 | 2 | 2246 | `Initialize+0A1C` |
| 55 | `A8A4` | InverRect | | 7 | 0 | 2246 | `Initialize+0A2E` |
| 56 | `A972` | GetMouse | | 59 | 14 148 | 2247 | `Initialize+0A38` |
| 57 | `A032` | FlushEvents | | 2 | 0 | 2772 | `Initialize+11CC` |
| 58 | `A02A` | HUnlock | | 1 064 | 190 | 2779 | `Initialize+129C` |
| 59 | `AA39` | MakeITable | | 1 | 0 | 2884 | `Initialize+132C` |
| 60 | `A915` | ShowWindow | | 1 | 0 | 2888 | `Initialize+1332` |
| 61 | `A939` | EnableItem | | 1 | 0 | 2973 | `Initialize+13BE` |
| 62 | `A92C` | FindWindow | | 806 | 0 | 3189 | `Initialize+0AAA` |
| 63 | `A925` | DragWindow | | 3 | 0 | 3190 | `Main+1BA8` |

### ⭐ What Target 1 actually costs

- ⭐⭐ **`%A5Init` calls exactly ONE trap: `_BlockMove`, from `%A5Init+00B4`** — and it is
  the game's very first trap, at frame 1291. It copies the initialised globals into the A5 world,
  which is precisely what `CLAUDE.md` says `%A5Init` is for. **Stage B's prerequisite is one trap.**
  ⚠ The MAME run attributed 46 calls; Stage B executed **49**, and the shipped initializer stream
  independently contains exactly 49 records selecting that `$A02E` path.  The 46 was therefore an
  attribution undercount.  See `docs/stage-b.md`; the trap identity and first-use order are unchanged.
- **`DrawPicture` (16) + `GetPicture` (47) + `CopyBits` (2 622)** — the presentation path, and the
  PICT interpreter is sized: the intro draws **16 pictures**, not hundreds.
- **`GetResource` (5 294)** — how all game data arrives. See §Arguments.
- **`SetPort` (19 520) / `ClipRect` (14 452) / `PenSize` / `TextMode`** — QuickDraw port state.
  Cheap per call, but stateful: see the option-A rule in `CLAUDE.md` about documented semantics.
- **`GetNextEvent` (17 764) is NOT on the intro path at all** — it arrives only at the menu (frame
  3832). ⭐ The intro runs on `Button` polling from `Intro+0224`, so **Target 1 needs no Event
  Manager**.
- ⭐ `Traffic+663C` calls `GetPicture` and `Traffic+2616` calls `NewPtrClear` — so `Traffic` is *not*
  purely the driving rasteriser; it is resident and working during startup and the intro.

## ⭐⭐ Arguments at the call site

`tools/mac_traps.lua` reads the parameters for a watch-list of traps. ⚠⚠ Two facts about *how* are
load-bearing and both are `[MEASURED]`:

- **There is only ONE stack.** Classic Mac OS runs the application itself in **supervisor mode** —
  every trap arrives with `SR = $2700` and `USP = 0`. Toolbox parameters are on the same stack as
  the exception frame. ⛔ Do not read parameters via `USP`: it is 0, and a read at 0 returns
  low-memory globals that decode as plausible garbage.
- **The frame is EIGHT bytes, not six.** A Mac II is a 68020 and pushes the "normal four word"
  frame: `SR:w`, `PC:l`, and a **format/vector-offset word**, which for the Line-A vector reads
  `$0028` (vector 10 × 4). Parameters start at `SP+8`. ⭐ The giveaway when this is wrong is a
  constant `$0028` at the head of every parameter list. ⚠ The Amiga's 68000 pushes six; nothing in
  the *game* reads the frame, but our own Line-A handler is the one place the difference is real.

### ⚠⚠ Which trap does the game patch? `_ExitToShell`, and only that

**`SetTrapAddress` from `load+00B8`, frame 1617, `D0 = $A9F4` (`_ExitToShell`), handler `$786A96`.**
One call, and it is the game's only trap patch. ⭐ This closes the gate on Stage C: the port does
**not** need general trap patching. It needs `SetTrapAddress($A9F4)` honoured — or, equivalently,
the game's own quit handler installed where our `ExitToShell` would go.

⚠ The other 15 `SetTrapAddress` calls in the window are all from `$7B1EF2` at frame 908, **before
the game is loaded** — some extension patching `SystemTask`, `InitGraf`, `StdLine`, `Line`,
`InverRect`, `PaintRect`, `InverRgn`, `CopyBits`, `HiliteWindow`, `SetPort`, `SetPBits`,
`GetOSEvent`, `OSEventAvail`, `GetKeys`, `Button`. ⛔ None of that is the game's, and the port
inherits none of it.

### ⭐ The `QDExtensions` selectors — and the selector is in `D0`

⚠⚠ **Not on the stack.** `[MEASURED]` from the call sites and confirmed by the push sequences:

| `D0` | routine | calls | where |
|---|---|---|---|
| 0 | **`NewGWorld`** | 3 | `Initialize+0134` (Target 1), `+02E8`, `+033A` |
| 1 | **`LockPixels`** | 6 | `Initialize+0154`, `+01A4` (Target 1), `+0304`, `+0356`, `+03A6`, `+0408` |
| 12 | **`NoPurgePixels`** | 2 | `Initialize+031E`, `+0422` — **not** in the MAME Target 1 path |

Selector 0 is `NewGWorld` beyond doubt: the push sequence at `Initialize+011C` is exactly its
signature —

```
clr.w   -(sp)                 ; QDErr result space
pea     -31254(a5)            ; VAR offscreenGWorld: GWorldPtr
clr.w   -(sp)                 ; pixelDepth = 0  (inherit the device's)
pea     -31226(a5)            ; boundsRect
clr.l   -(sp)                 ; cTable   = NIL
clr.l   -(sp)                 ; aGDevice = NIL
move.l  #$40000000,-(sp)      ; flags
moveq   #0,d0                 ; <== the selector
_QDExtensions
tst.w   (sp)+                 ; QDErr
```

Selector 1 takes one `PixMapHandle` and returns a `Boolean` (`clr.b -(sp)` … `tst.b (sp)+`) —
`LockPixels`. Selector 12 takes a `PixMapHandle` and returns nothing. The classic Macintosh glue
mapping explicitly assigns selector 12 to `NoPurgePixels`; the standalone run has now exercised
that selector as part of its copied support-code path.
⚠ Selector 20, three calls from `$00DAB8` before launch, is the System's, not the game's.

⭐ **Target 1 needs two selectors: `NewGWorld` ×1 and `LockPixels` ×2.** `flags = $40000000` and
`pixelDepth = 0` are the measured arguments — the GWorld inherits the screen's 4 bpp.

### ⭐ What the game loads, and what it draws

`GetResource` at `Main+2C88` and `Initialize+066C`:

| type | ids | what |
|---|---|---|
| `QUAD` | 1000 | one, first, from `Main+2C88` at frame 1309 |
| `OBJS` | 100, 200, … 2500 (and 8700 out of order) | ⭐ the 3-D object database — matches the **160 `OBJS`** in `VETTE!.Data` (`docs/source-inventory.md`), named `Porche`, `Testa`, `Lambo`, `F40`, `Bus`, `lamppost` … |

`DrawPicture`, all 16 calls, with the destination rects — ⚠ the rect pointers are into the A5 world
(`CurrentA5 = $7869C4`), i.e. the rects are the game's own globals:

| frame | caller | dstRect | size |
|---|---|---|---|
| 1638 | `Intro+003E` | (0,0)–(323,512) | ⭐ **512×323** — the title art |
| 1782 | `Intro+0132` | (150,0)–(217,80) | 80×67 |
| 2726–2865 | `Intro+0926` ×14 | (150,80)–(228,114) | 34×78 — the animated overlay, 3 alternating PicHandles |

The 512×323 target is the full title composition in a 512×512 offscreen GWorld; its active port,
PixMap, and clip region all retain those rows. The next original `_CopyBits` deliberately copies
only `(0,0)-(320,512)` into the 512×320 window displayed at Macintosh global `(64,91)`. Captured
offscreen rows 320–322 are nonempty and differ, so they are neither clipped during drawing nor part
of the visible viewport.

`GetPicture` — 47 calls, all from the one stub at `Traffic+663C`, and ⭐ **every ID it passes is a
real `PICT` in `Color VETTE!`** (24592, 21981, 25025, 29223, 6482, 16709, 30796, 198, 25396, 3499,
439, …), cross-checked against the app's 192-entry `PICT` list. That is an independent confirmation
that the parameter reads are correct — the IDs look like garbage because the game's PICT IDs are
scattered over 68…31884, not because the read is wrong. The stub retries on failure:

```
move.l  (sp)+,-11930(a5)      ; pop the return address into a global
move.w  (sp),-11926(a5)       ; the picID, which is also left as the parameter
_GetPicture
tst.l   (sp)                  ; NIL?
bne.s   ...
move.l  #1000000,d0
_PurgeMem                     ; free a megabyte and try again
```

## Segments, and their measured placements

⭐ Each base was pinned by finding the address where the **extracted resource's own first 8 bytes**
appear in memory **and** every one of that segment's resident jump-table exports falls inside
`[base, base+len)`. The first test alone is not enough (lie #6).

| seg | name | base | len | first mapped |
|---|---|---|---|---|
| 1 | `Main` | `$049F2C` | 24 994 | frame 1288 |
| 10 | `%A5Init` | `$0531A0` | 28 732 | frame 1290 |
| 6 | `Traffic` | `$0618A4` | 27 958 | frame 1305 |
| 4 | `load` | `$061218` | 1 668 | frame 1306 |
| 2 | `Initialize` | `$05F698` | 7 032 | frame 1308 |
| 9 | `sound` | `$719108` | 732 | frame 1549 |
| 8 | `Intro` | `$71838C` | 3 442 | frame 1637 |
| 5 | `Score` | `$670D10` | 4 628 | frame 3822 |

`CurrentA5 = $7869C4`. Of the 509 jump-table entries, **338 were resident at frame 1288, 250 by the
menu** (segments are unloaded as well as loaded). The extended run reaches driving with the same
eight segment identities mapped. The mapped ranges were checked for overlap: none.

⚠ **`%A5Init` and `Initialize` each had 2 candidate bases** matching the 8-byte signature; the
lowest was taken. For `%A5Init` the choice is not independently confirmed, so its `+00B4` offset is
`[DERIVED]`, not `[MEASURED]`.

⚠ **`Communication` (3) and `FRED` (7) were never observed resident**, even though the extended
window reaches active driving, so any trap on an untested path through either remains missing.
This kills the earlier inference that `FRED` must be the main driving code: the measured driving
path runs through the already-mapped segments without it.

⭐ **Every unattributed caller region was checked.** The regions that called a trap from RAM, with
the frame range of their calls — ⭐ the frame range is what identifies an owner, because the game's
code did not exist before frame 1288:

| region | calls | frames | verdict |
|---|---|---|---|
| `$71xxxx` | 66 779 | 1549–3808 | `Intro` + `sound` (mapped) |
| `$04xxxx` | 32 586 | 1013–4397 | `Main` (mapped) from 1288; ⚠ the 15 546 before that are **the Finder's**, in the same region |
| `$77xxxx` | 11 980 | **1015–1286** | ⚠ **the Finder** — every call precedes the game's first instruction |
| `$7Bxxxx` | 11 052 | 851–3822 | no segment — System code (the extension that patches 15 traps lives here) |
| `$00xxxx`–`$03xxxx`, `$0Cxxxx`, `$7Cxxxx`, `$7Exxxx`, `$7Fxxxx` | 7 500 | 82–3838 | no segment — System code |
| `$78xxxx` | 8 | 1014–3832 | ⭐ **inside the jump table itself** — an *unloaded* JT stub executing its own `MOVE.W #seg,-(SP); _LoadSeg`. Exactly the mechanism `CLAUDE.md` says to pre-patch away |

## ⚠⚠ The six ways this measurement lies, all of them found by it failing

Each produced a *plausible, quiet* wrong answer. They are recorded because the same tool will be
re-run, and several look identical from the outside: **"the game takes no traps"**.

1. **A tap on the Line-A vector `$28` never fires.** MAME's m68k core does not route CPU
   exception-vector fetches through a tapped accessor. Neither RAM data reads nor Lua's own
   `read_u32` fire a tap either — a control tap on `Ticks` counted **0** in 25 s. ⭐ ROM **opcode**
   fetches do fire. So tap where the vector *points*, never the vector.
2. **The dispatcher moves.** `$28` was re-pointed three times during boot
   (`$40802950` → `$4080210A` → `$408064BA`) as the ROM, the System and MacsBug each patched it. A
   tap armed once at boot goes deaf. The vector is polled every frame and the tap re-armed.
3. ⚠⚠ **The tap must be kept in a Lua variable or it dies.** `install_read_tap`'s return value
   *owns* the tap; discard it and the collector removes it at the next GC. `[MEASURED]`: dropping it
   counted 2 306 hits over 12 frames and then **exactly 0 for the next 1 900** — through the
   game's entire launch. Keeping the handle counted 58 419 and rising.
4. **"In RAM" ≠ "the game".** A first pass classified every non-ROM caller as game code and put
   `SetHandleSize` (9 659 calls, from the Memory Manager patch block), `EraseRect` (from the system
   heap) and `SCSIDispatch` on the port's work list. ⭐ A caller is the game only if a mapped
   segment claims it, and an unmapped PC prints as a bare address, never as the nearest segment.
5. ⚠⚠ **Attribute LIVE, never retroactively — or the FINDER's traps become the game's.** Resolving
   recorded PCs against the *final* segment map at report time put **~30 extra traps** on this list,
   attributed to `Main` at frames 1013–1286. They were the Finder's: the Finder is an application
   too, its `CODE` segments occupy the same heap addresses (`$04xxxx`, `$77xxxx`), and its trap
   profile — menus, windows, `GetNextEvent`, dialogs, resource files, `SetCursor` — is exactly what
   a game's looks like. ⭐ The giveaway was **`_Launch` from "Main+4200"**: only the Finder calls
   `_Launch`, and it called it to start this very game. A segment now enters the map only once its
   own bytes are found resident, and attribution happens at hit time.
6. ⚠ **The 8-byte `CODE` header chance-matches, so a signature hit is not an identification.** The
   header is a small offset and a small count — low entropy. A scan "found" `Initialize` at
   `$77D2FE`, inside the Finder. ⭐ The second test is the one that decides: every resident
   jump-table export for that segment number must fall inside `[base, base+len)`. Before the app is
   loaded `CurrentA5` is *another application's*, so its jump table is what gets scanned — with its
   own segment numbers 1…7, which collide with ours. The span test rejects all of it.

⚠ **No hand-written trap-name table.** A first pass had one and it was confidently wrong: `$A8B5`
was labelled a QuickDraw call and is `ScriptUtil`; `$A893` is `MoveTo`; `$A885` is `DrawText`. The
table is generated from cxmon's full 1 178-trap list. ⚠ It is keyed the way Apple's own `Traps.h` is
keyed — **by the word a compiler emits, flag bits included** (`_NewPtr` is `$A11E`, not `$A01E`) —
so the lookup indexes by trap *number* as well, or `NewPtr`/`NewHandle`/`GetTrapAddress`/
`PurgeSpace` come out as `?OS_xx`.

## ⛔ What this log is NOT

- **Not an exhaustive driving-path inventory.** This window reaches active driving, but only one
  vehicle/course path and a bounded wait. `FRED` and `Communication` never ran. Treat the 63 as a
  **FLOOR**, per `CLAUDE.md` — another course, collision, finish or multiplayer path can add calls.
- **Not fully selector-resolved.** `QDExtensions` now is (`D0`), but `ScriptUtil` (194 calls),
  `SCSIDispatch` and the `Pack` traps are selector-dispatched and unread. All three are
  System-called in this window, so none is on the work list — that could change.
- **Not a static cross-check.** Every call site in the binary is still unenumerated (Phase 2). A
  trap on a path this run did not take is invisible here. ⭐ The two methods are complements: the
  static sweep finds unexecuted paths, this finds what the System does on the game's behalf.
