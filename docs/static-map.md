# Static map

This is the distributable map of the Color 1.02 executable. The copyrighted
resource bytes, generated Ghidra listings, and generated trap CSV files remain
local under `tmp/`; `make static-map-check` binds those local inputs to the
curated facts below and to `disasm/symbols.csv`.

## Address convention

A code address is always `(segment, offset)`. Offsets include the four-byte
near-model segment header, matching Ghidra, the runtime loud stop, and the
documentation. An application global is a signed A5 offset. A Macintosh system
global is an absolute Page-0 address below `$0C00`. These spaces are never
silently mixed.

## Complete segment and entry map

All eleven `CODE` resources are present and total 118,892 bytes. CODE 0 is a
16-byte loader header plus the complete 4,072-byte table. Its header requires
31,272 bytes below A5, 4,104 bytes above A5, and places the table at A5+32.
Every one of its 509 unloaded eight-byte entries validates as
`offset / MOVE.W #segment,-(SP) / _LoadSeg`.

| seg | name | bytes | exports |
|---:|---|---:|---:|
| 0 | jump table | 4,088 | 509 total |
| 1 | Main | 24,994 | 130 |
| 2 | Initialize | 7,032 | 16 |
| 3 | Communication | 9,110 | 16 |
| 4 | load | 1,668 | 1 |
| 5 | Score | 4,628 | 9 |
| 6 | Traffic | 27,958 | 80 |
| 7 | FRED | 6,508 | 242 |
| 8 | Intro | 3,442 | 2 |
| 9 | sound | 732 | 12 |
| 10 | %A5Init | 28,732 | 1 |

The independently generated `ghidra_scripts/entrypoints.csv` has 509 rows and
508 distinct targets (Initialize deliberately exports one target twice). Each
segment's near header independently states its first table byte and export
count; all ten headers partition the 4,072-byte table exactly. This is the
second method used by the gate rather than another reading of the CSV.

## Trap map

The flow-following Ghidra map contains 1,430 A-line sites. It starts from all
509 exports, resumes after unresolved inter-segment calls, and admits stored
callback roots only where code writes their addresses. The full-intro live
trace contributes 227 distinct sites; every live `(segment, offset, word)` is
present in the static map with no mismatch.

| segment | static sites | full-intro live sites |
|---|---:|---:|
| Main | 537 | 33 |
| Initialize | 290 | 40 |
| Communication | 184 | 0 |
| load | 118 | 46 |
| Score | 113 | 0 |
| Traffic | 40 | 3 |
| FRED | 0 | 0 |
| Intro | 146 | 103 |
| sound | 1 | 1 |
| %A5Init | 1 | 1 |

This is static coverage, not a claim that all optional paths were executed.
Communication is excluded from the single-player port, and optional High
Screen and Preferences UI remains loud by policy.

## Low memory

Recursive descent from every export finds 108 references to 17 Page-0
locations. A second pass over all Ghidra-defined instructions finds 114
references to the same 17 locations. The startup patcher's byte-verified,
same-width opcode scan additionally accounts for code hidden behind computed
dispatch: 87 `$016A` Ticks sites, 16 `$09EE` GrayRgn sites, and three `$0174`
KeyMap address loads. The fixed inventory is:

| address | meaning | disposition |
|---:|---|---|
| `$0156` | RndSeed | A5+4 semantic shadow |
| `$016A` | Ticks | A5+0 semantic shadow, all 87 exact sites |
| `$0172` | MBState | private shadow below the shipped A5 world |
| `$0174` | KeyMap | A5+16, maintained by the CIA keyboard path |
| `$01D4`, `$0220` | system state used by optional/outer UI paths | mapped; a real caller remains loud if semantics are demanded |
| `$01FB`, `$0291` | serial/communications state | deliberately unsupported with network play |
| `$0828..$0833` | MTemp, RawMouse, Mouse points | private same-width shadows |
| `$0904` | CurrentA5 | private shadow below the shipped A5 world |
| `$09DE` | WMgrPort | A5+8 semantic shadow |
| `$09EE` | GrayRgn | A5+12 semantic shadow, all 16 exact sites |

Mac Page 0 is never mapped over the Amiga's vectors or Exec state. Every
production redirection checks the original opcode and operand before changing
it, so a different executable fails before takeover.

## A5 world and naming pass

`%A5Init` runs unchanged and constructs the shipped 31,272 bytes of application
globals. The port reserves a separate 20-byte prefix for the mouse and
CurrentA5 shadows; it is not presented as part of the original world. The
positive parameter area A5+0..31 holds Ticks, RndSeed, WMgrPort, GrayRgn and the
16-byte KeyMap before the jump table at A5+32.

`disasm/symbols.csv` is the source of truth for the concentrated naming pass.
It separates `code`, `a5`, and `lowmem` spaces, carries an evidence class on
every row, and currently names 68 high-value routines and globals. Names are
limited to behavior established by code, resource grammar, or a measured live
transition; generic jump-table names remain generic rather than acquiring
speculative meanings.

## Static byte coverage

Ghidra defines 80,114 instruction bytes. CODE 10 has a 276-byte decoder and a
28,452-byte packed `%A5Init` data stream. CODE 0 and all ten near headers are
structural. Across the other nine segments, 79,838 of 86,036 payload bytes are
defined instructions. Therefore 112,694 of all 118,892 CODE bytes are
classified (94.8%); 6,198 bytes (5.2%) remain mixed inline data, strings,
alignment, or unreachable code.

That residue is reported, not guessed away. The independent recursive 68000
sweep reaches 77,900 bytes (67.9% including the initializer stream), reports
609 computed/unresolved transfers, and finds no 68020-only instruction on a
reached path. A linear scan of the residue has a high false-positive density
and is explicitly not used to inflate code coverage.

Reproduce the gate with:

```sh
make static-map-check
python3 tools/m68k_sweep.py --selftest
python3 tools/m68k_sweep.py tmp/seg_color
python3 tools/check_trap_map.py ref/mame/traps.txt --static-dir tmp
```
