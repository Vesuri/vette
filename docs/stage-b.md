# Stage B — resident loader and first loud stop

Stage B is complete.  The Amiga build executes the shipped Color-build 68000 instructions and
halts visibly at the first trap that the port deliberately does not implement.

## Measured acceptance result

`amiga/stage_b.gdb`, under FS-UAE's A500+ configuration:

| check | result |
|---|---:|
| resident `CODE` resources | 11 (including `CODE 0` metadata) |
| validated and patched jump-table entries | **509** |
| A5 world | 31,272 bytes below A5; 4,104 above; jump table at A5+32 |
| `%A5Init` `_BlockMove` calls | **49** |
| resource archive | 2 forks, **572 resources**, 2,168,882 bytes |
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

`tools/rsrc_pack.py` converts one or more classic resource forks into a single pointer-free,
big-endian archive.  The build packs the Color application fork and `VETTE!.Data`; the runtime
reader validates every directory, name and payload span before the game runs.  The generated
archive and original forks stay local under the repository's copyright rules.
