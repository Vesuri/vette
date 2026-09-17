# Stage C — live trap-layer bring-up

Stage C runs the original resident `CODE` segments and advances one loud stop at a time. The
acceptance boundary is still the game's own intro pixels; this document records the standalone
port's execution order, which is now known to differ from the earlier MAME first-use table.

## Current checkpoint

The Amiga run executes **23 distinct implemented traps** and halts loudly at:

```
$AA46  WINDOW MANAGER / GETNEWCWINDOW
caller: load+$046A
```

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

`amiga/stage_c.gdb` breaks on the loud-stop renderer and prints the depth, trap identity,
selector, and runtime `(segment, offset)`. The build's `muldiv-audit` and `probe-audit` are clean.

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

This preserves the original code flow without touching Amiga low memory. More shadows are added
only when execution reaches them; the inventory shows that most remaining references are `Ticks`,
mouse/key state, and repeated `GrayRgn` reads.

## Resource and handle boundary

The host converter packs both resource forks into the pointer-free, big-endian `VRS1` archive.
The target Resource Manager searches the selected fork and returns real double-indirect Handles.
Archive payloads are permanently resident: `MoveHHi` validates such a handle but needs no physical
relocation, while `HLock` records its lock state. `OpenResFile` performs classic case-insensitive
filename matching, which matters because the shipped Pascal name is `Vette!.DATA`.

## Correction to the MAME log

The 51-row MAME table is a measurement of that reference run, not fabricated data, but the live
standalone path has already called setup traps missing from or much later in its first-use order.
Therefore the table's 36-trap intro count is a **floor**, not the standalone implementation total.
The reason for the tracer omission remains to be audited; Stage C uses its own loud stop as the
authoritative work queue meanwhile.
