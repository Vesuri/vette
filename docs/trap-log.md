# The A-trap log — what the game actually calls, measured

⭐⭐ **This is the port's work list, and it is a MEASUREMENT, not a static sweep.** Under option A the
game's own 68000 code runs, so the set of `$Axxx` traps it executes *is* the surface the port must
supply, and the order it first needs them in is the order to build them.

Produced by `tools/mac_traps.lua` (+ `tools/gen_trap_names.py`) against the unpatched original under
MAME, launch → title → intro → menu. Re-run it with the headless recipe in `CLAUDE.md`; it writes
`ref/mame/traps.txt`.

## ⭐⭐ THE TARGET: 18 traps paint the intro screen

`[MEASURED]`, by shooting the framebuffer every 240 frames alongside the log:

| frame | what is on screen |
|---|---|
| 1518 | the app is frontmost |
| 1698 | `CopyBits` — **row 18**, the last new trap before the picture exists |
| **1758** | ⭐ **the intro screen is fully painted** — the Golden Gate / San Francisco title art |
| 1781, 1813, 2479 | rows 19–21 (`ClipRect`, `Button`, `UseResFile`) — the **wait-for-click loop**, after the art is already up |
| 3438 | a blank white window: the intro is gone, the garage is being built |
| 3678 | the garage / car-selection screen with the menu bar |

So the boundary is sharp and it is not where I first guessed (I had assumed the `DisposeWindow` from
`Intro+0ADA` at frame 3558 marked the end; that is the intro *window* being disposed long after the
art came down).

- ⭐⭐ **Rows 1–18 = paint the intro screen.** That is Target 1.
- **Rows 19–21 = run it** until the user clicks (`Button` polling, 10 885 calls).
- **Rows 22–38 = teardown + the garage screen and its menu bar.** Not Target 1.

⚠ The intro art carries **"© 1991 SPHERE, INC"**, while `PROJECT.md` and `CLAUDE.md` describe the
game as 1989. The two have not been reconciled — do not quote either date as settled.

## 38 traps in the window, and how the callers split

**187 297 trap dispatches** in the measured window. **183 853** decoded. Of those, **96 188 came
from RAM** — but ⚠⚠ *"from RAM" is not "from the game"*, and conflating the two is the trap this
tool fell into first (see §The four ways this measurement lies). Attributed by caller PC:

| Caller region | What it is | Dispatches |
|---|---|---|
| The 10 mapped `CODE` segments | ⭐ **the game** | — **38 distinct traps** |
| `$7Cxxxx` (just under the top of the 8 MB) | the System's ROM **patch block** — Memory/Resource/Palette Manager patches | the bulk of the "RAM" count |
| `$00xxxx–$01xxxx` (low system heap) | System file code: Window/Dialog/Script Managers, drivers | incl. `EraseRect` ×8 961 |
| `$408xxxxx` | ROM | 87 665 |

The last three are **the Toolbox calling itself on the game's behalf**. The port implements
`DrawPicture` itself, so it never sees the `SetHandleSize` that Apple's `DrawPicture` makes.

## The work list, in measured first-use order

`base+off` is the caller, resolved to `(segment, offset)` in **`Color VETTE!`**. `from-RAM` /
`from-ROM` are call counts over the whole window, by where the *caller* was.

| # | word | name | flags | from-RAM | from-ROM | frame | caller |
|---|---|---|---|---|---|---|---|
| 1 | `A91F` | SelectWindow | | 1 | 0 | 1535 | `load+04D2` |
| 2 | `A922` | BeginUpDate | | 2 | 0 | 1535 | `load+04D8` |
| 3 | `A923` | EndUpDate | | 1 | 0 | 1535 | `load+04DE` |
| 4 | `A889` | TextMode | | 1 | 0 | 1535 | `load+04E2` |
| 5 | `A9B9` | GetCursor | | 1 | 0 | 1535 | `load+003E` |
| 6 | `A97C` | GetNewDialog | | 1 | 0 | 1536 | `load+0054` |
| 7 | `AB1D` | **QDExtensions** | | 11 | 0 | 1544 | `Initialize+0134` |
| 8 | `AA95` | SetPalette | | 12 | 0 | 1549 | `Initialize+0032` |
| 9 | `A9A0` | GetResource | | 34 | 28 | 1549 | `sound+0020` |
| 10 | `A047` | SetTrapAddress | | 1 | 0 | 1617 | `load+00B8` |
| 11 | `A983` | DisposeDialog | | 1 | 0 | 1635 | `load+00C6` |
| 12 | `A850` | InitCursor | | 1 | 0 | 1636 | `load+00C8` |
| 13 | `A873` | **SetPort** | | **16 006** | 184 | 1636 | `load+00CE` |
| 14 | `A994` | CurResFile | | 6 911 | 0 | 1637 | `Intro+000E` |
| 15 | `A9BC` | GetPicture | | 47 | 0 | 1637 | `Traffic+663C` |
| 16 | `A8F6` | ⭐ **DrawPicture** | | **16** | 0 | 1638 | `Intro+003E` |
| 17 | `A89B` | PenSize | | 2 | 0 | 1698 | `Intro+0048` |
| 18 | `A8EC` | ⭐ **CopyBits** | | 2 600 | 0 | 1698 | `Intro+0070` |
| 19 | `A87B` | ClipRect | | 14 428 | 7 | 1781 | `Intro+00FE` |
| 20 | `A974` | Button | | 10 885 | 0 | 1813 | `Intro+0224` |
| 21 | `A998` | UseResFile | | 6 936 | 0 | 2479 | `Intro+096C` |
| 22 | `A914` | DisposeWindow | | 1 | 0 | 3558 | `Intro+0ADA` |
| 23 | `AA32` | GetGDevice | | 1 | 0 | 3559 | `Intro+0ADE` |
| 24 | `A90D` | PaintBehind | | 1 | 4 | 3582 | `Intro+0B10` |
| 25 | `A91B` | MoveWindow | | 1 | 0 | 3583 | `Main+0954` |
| 26 | `AA28` | GetCTSeed | | 2 | 0 | 3590 | `Intro+0B28` |
| 27 | `A04D` | PurgeMem | | 2 | 0 | 3659 | `Intro+0B82` |
| 28 | `A04C` | CompactMem | | 2 | 0 | 3662 | `Intro+0B8A` |
| 29 | `A93A` | DisableItem | | 2 | 0 | 3808 | `Intro+0D3A` |
| 30 | `A931` | NewMenu | | 1 | 0 | 3808 | `load+050C` |
| 31 | `A933` | AppendMenu | | 1 | 0 | 3808 | `load+0524` |
| 32 | `A9BF` | GetRMenu | | 3 | 0 | 3818 | `load+05A4` |
| 33 | `A937` | DrawMenuBar | | 1 | 0 | 3820 | `load+0676` |
| 34 | `A31E` | NewPtrClear | sys+clear | 1 | 0 | 3827 | `Main+4968` |
| 35 | `A9F1` | UnLoadSeg | | 1 | 0 | 3832 | `Main+1F2E` |
| 36 | `A970` | ⭐ **GetNextEvent** | | 16 958 | 0 | 3832 | `Main+29F2` |
| 37 | `A9B4` | SystemTask | | 51 | 0 | 3832 | `Main+29E6` |
| 38 | `A874` | GetPort | | 1 | 16 946 | 3838 | `Main+05C6` |

### ⭐ Target 1's 18 traps, grouped by what they actually cost

Most are one-shot housekeeping. The load-bearing ones:

- **`DrawPicture` (16 calls) + `GetPicture` (47) + `CopyBits` (2 600)** — the presentation path.
  This is the PICT interpreter, and it is now sized: the intro draws **16 pictures**, not hundreds.
- **`SetPort` / `ClipRect` / `PenSize` / `TextMode`** — QuickDraw port state. Cheap, but stateful:
  see the option-A rule in `CLAUDE.md` about documented Toolbox semantics.
- **`QDExtensions` ($AB1D, 11 calls from `Initialize+0134`)** — the selector-based call that carries
  `NewGWorld` / `LockPixels`. ⚠ The **selector is not recorded yet**; it is pushed on the stack and
  this tool only reads the trap word. That is the next thing to measure, because it decides whether
  the offscreen surface is created before the intro or only for driving.
- **`GetResource` from `sound+0020`** — the sound segment is touched *before* the intro paints.
- **`GetNextEvent` (16 958) is NOT on the intro path at all** — it arrives only at the menu
  (frame 3832). ⭐ The intro runs on `Button` polling from `Intro+0224`, so **Target 1 needs no
  Event Manager**.

⚠⚠ **`SetTrapAddress` at `load+00B8` — the game patches a trap, and we do not know which one.**
One call, at frame 1617, i.e. *inside* Target 1. Under option A the game's own code runs, so
whatever it installs it will install on the Amiga too, and our trap layer has to route the patched
trap to the game's handler instead of to ours. ⭐ The trap number is in `d0` at the call site.
**Resolve it before writing any of Stage C** — a layer that silently ignores the patch is the
silent-wrong-value failure this project's hard rules exist to prevent. (The `GetTrapAddress` calls
in the window are all from the System's patch block, not the game, so the game does not appear to
chain the old handler — but that is an *absence* in one run, not a finding.)

⚠ Eight of the 18 are Window/Dialog Manager one-shots from `load` (`SelectWindow`, `BeginUpDate`,
`EndUpDate`, `GetNewDialog`, `DisposeDialog`, `GetCursor`, `InitCursor`, `TextMode`) — presumably a
splash or loading dialog. The port owns the whole screen and has no overlapping windows, so
`BeginUpDate`/`EndUpDate` can be minimal — ⚠ but that is a **seam decision** and belongs in
`docs/faithfulness-seam.md` with its reason, not an implementation shortcut taken quietly.

⭐ `Traffic+663C` calls `GetPicture` — so the `Traffic` segment is *not* purely the driving
rasteriser, and it is resident and drawing during the intro.

### Segments, and their measured placements

⭐ Each base was pinned by finding the unique address where the **extracted resource's own first 8
bytes** appear in memory, which also proves the near-model claim: the resident image is the resource
verbatim, nothing relocated.

| seg | name | base | len |
|---|---|---|---|
| 1 | `Main` | `$049F2C` | 24 994 |
| 2 | `Initialize` | `$05F698` | 7 032 |
| 4 | `load` | `$061218` | 1 668 |
| 6 | `Traffic` | `$0618A4` | 27 958 |
| 5 | `Score` | `$670D10` | 4 628 |
| 8 | `Intro` | `$71838C` | 3 442 |
| 9 | `sound` | `$719108` | 732 |

`CurrentA5 = $7869C4`. Of the 509 jump-table entries, **239 were resident at launch, 250 by the
menu**.

⚠ **`Communication` (3), `FRED` (7) and `%A5Init` (10) were never observed resident**, so any trap
they call is missing from the list above. `%A5Init` in particular *must* have run — it initialises
the A5 world — and was already gone when the app was first detected as frontmost, even with the
jump table polled **every frame** for 400 frames from launch. ⚠⚠ **So the traps `%A5Init` makes are
unmeasured, and Stage B runs `%A5Init`.** `FRED` exports 242 of the 509 entries and is presumably
the driving code, which this window never reaches.

⭐ **Every unattributed caller region was checked, and none of them is a game segment.** The regions
that called a trap from RAM were scanned for all ten segments' own first-8-byte signatures:

| region | calls | verdict |
|---|---|---|
| `$71xxxx` | 66 779 | `sound` + `Intro` (mapped) |
| `$04xxxx` | 17 029 | `Main` (mapped) |
| `$7Bxxxx` | 10 837 | no segment signature — System code |
| `$00xxxx` / `$01xxxx` / `$0Cxxxx` / `$7Cxxxx` | 1 441 | no segment signature — System code |
| `$78xxxx` | 3 | ⭐ **inside the jump table itself** — an *unloaded* JT stub executing its own `MOVE.W #seg,-(SP); _LoadSeg`. Exactly the mechanism `CLAUDE.md` says to pre-patch away |

⚠ The scan runs at the **end** of the window, so a segment that was resident earlier and purged
would not be found. It is evidence that the 38 are complete for callers still resident, not proof
that nothing was missed.

## ⚠⚠ The four ways this measurement lies, all of them found by it failing

Each of these produced a *plausible, quiet* wrong answer. They are recorded because the same tool
will be re-run, and three of the four look identical from the outside: **"the game takes no traps"**.

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
   `SetHandleSize` (9 088 calls, from the Memory Manager patch at `$7C8080`), `EraseRect` (8 961,
   system heap) and `SCSIDispatch` on the port's work list. The fix is the segment map above:
   ⭐ **a caller is the game only if a mapped segment claims it**, and an unmapped PC is printed as a
   bare address, never attributed to the nearest segment.

⚠ **No hand-written trap-name table.** A first pass had one and it was confidently wrong: `$A8B5`
was labelled a QuickDraw call and is `ScriptUtil`; `$A893` is `MoveTo`; `$A885` is `DrawText`. The
table is generated from cxmon's full 1 178-trap list. ⚠ It is keyed the way Apple's own `Traps.h` is
keyed — **by the word a compiler emits, flag bits included** (`_NewPtr` is `$A11E`, not `$A01E`) —
so the lookup indexes by trap *number* as well, or `NewPtr`/`NewHandle`/`GetTrapAddress`/
`PurgeSpace` come out as `?OS_xx`.

## ⛔ What this log is NOT

- **Not the driving surface.** The window ends at the menu. `FRED` and `Communication` never ran.
  ⚠ Treat the 38 as a **FLOOR**, per `CLAUDE.md` — Revs's inventory looked closed after a static
  sweep and running it found three more.
- **Not selector-resolved.** `QDExtensions` ($AB1D), `ScriptUtil`, `SCSIDispatch` and the `Pack`
  traps are selector-dispatched; the selector is on the stack and is not read yet.
- **Not a static cross-check.** Every call site in the binary is still unenumerated (Phase 2). A
  trap on a path this run did not take is invisible here. ⭐ The two methods are complements: the
  static sweep finds unexecuted paths, this finds what the System does on the game's behalf.
