# The A-trap log — what the game actually calls, measured

⭐⭐ **This is the port's work list, and it is a MEASUREMENT, not a static sweep.** Under option A the
game's own 68000 code runs, so the set of `$Axxx` traps it executes *is* the surface the port must
supply, and the order it first needs them in is the order to build them.

Produced by `tools/mac_traps.lua` (+ `tools/gen_trap_names.py`) against the unpatched original under
MAME, launch → title → intro → menu. Re-run it with the headless recipe in `CLAUDE.md`; it writes
`ref/mame/traps.txt`.

## ⭐⭐ The headline: 38 traps, and only 6 of them matter for the intro screen

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

### ⭐ What this says about the goal — the intro screen

**Rows 1–18 are the whole cost of a painted intro screen**, and most of them are one-shot
housekeeping. The load-bearing ones are:

- **`DrawPicture` (16 calls) + `GetPicture` (47) + `CopyBits` (2 600)** — the presentation path.
  This is the PICT interpreter, and it is now sized: the intro draws **16 pictures**, not hundreds.
- **`SetPort` / `ClipRect` / `PenSize` / `TextMode`** — QuickDraw port state. Cheap, but stateful:
  see the option-A rule in `CLAUDE.md` about documented Toolbox semantics.
- **`QDExtensions` ($AB1D, 11 calls from `Initialize+0134`)** — the selector-based call that carries
  `NewGWorld` / `LockPixels`. ⚠ The **selector is not recorded yet**; it is pushed on the stack and
  this tool only reads the trap word. That is the next thing to measure, because it decides whether
  the offscreen surface is created before the intro or only for driving.
- **`GetResource` from `sound+0020`** — the sound segment is touched *before* the intro paints.
- **`GetNextEvent` (16 958)** is the main loop and arrives only at the **menu** (frame 3832), i.e.
  ⭐ the intro runs on `Button` polling (`Intro+0224`), not on the Event Manager.

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
the A5 world — and was purged before the first map. `FRED` exports 242 of the 509 entries and is
presumably the driving code, which this window never reaches.

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
