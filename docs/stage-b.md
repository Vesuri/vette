# Stage B — resident loader and first loud stop

Stage B is complete.  The Amiga build executes the shipped Color-build 68000 instructions and
halts visibly at the first trap that the port deliberately does not implement.

## Measured acceptance result

`amiga/stage_b.gdb`, under the A1200 / 2 MiB chip / 8 MiB fast configuration:

| check | result |
|---|---:|
| resident `CODE` resources | 11 (including `CODE 0` metadata) |
| validated and patched jump-table entries | **509** |
| A5 world | 31,272 bytes below A5; 4,104 above; jump table at A5+32 |
| `%A5Init` `_BlockMove` calls | **49** |
| native resource files | 2 forks, **572 resources**, read from disk before takeover |
| first unimplemented trap | `$A9F1` `_UnLoadSeg` |
| manager | Segment Manager |
| selector | not selector-dispatched (`N/A`) |
| caller | **`Main+$1EE6`** |

The loud stop is both visible and probeable.  The exception path replaces the captured Stage A
frame with text drawn directly into the live four-plane chip-RAM surface; the same facts live in
the `g_trap*` globals audited by the build.  It cannot fail as a plausible frozen intro frame.

## Loader contract

- All segment bodies remain linked and resident.  Near-model segment offsets need no relocation.
- `CODE 0`'s 509 unloaded entries are validated, then rewritten as
  `[segment:w][$4EF9][absolute target:l]` in the A5 world.
- The application entry is the first export, `Main+$1EDA`.  That stub calls the final jump-table
  export (`%A5Init`) itself, then reaches `_UnLoadSeg` at `Main+$1EE6`.  Calling `%A5Init`
  separately before the entry stub would initialize the world twice.
- The port owns Line-A vector `$28`.  Its 68000 exception wrapper preserves all game registers,
  implements `_BlockMove` using `A0`/`A1`/`D0`, advances the stacked PC, and returns with `RTE`.
  Every other trap goes through the loud-stop path until Stage C implements it.

## Correction to the Macintosh trap trace

The earlier MAME trace attributed 46 `_BlockMove` calls to `%A5Init`.  Stage B records **49**, and
an independent parse of the shipped initializer stream settles the discrepancy: it has 2,229
records and exactly **49** records whose copy length is at least 50, which is the branch that emits
the single `$A02E` instruction at `%A5Init+$00B4`.  All 49 execute on the Amiga before the entry
stub returns.  Therefore 46 is an attribution undercount in that reference run; the first-use
ordering and trap identity remain correct.

## Resource transport

The release executable contains no original data. Before hardware takeover it reads the raw
resource forks `Color VETTE!` and `VETTE!.Data` from files beside the executable, validates their
native Macintosh maps, and indexes all 572 resources without repacking them. The eleven CODE
payloads are byte-packed at odd offsets in the source fork, so the loader reproduces Resource
Manager handle behavior by copying them to aligned resident allocations before patching. The
original file images remain unchanged and can be released after the game returns.
