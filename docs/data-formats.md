# VETTE!.Data formats

Only fields tied to code that reads them are named here. Repeated values, apparent scales and
plausible physical quantities remain unknown until a consumer proves them.

## `PERF`: car template plus an unreferenced tail

There are eight resources, IDs 100 through 800 in steps of 100: `Stock`, `ZR1`, `TwinTurbo`,
`Sledge`, `Porche` [sic], `Testa`, `Lambo`, and `F40`. Every body is 110 bytes and starts with the
big-endian word 54: a count followed by 54 signed words. The colour and B&W data files' eight
records are byte-identical.

### Proven loader

`Traffic+$06BE` is the only code site containing the literal type `PERF`. It:

1. calls `GetResource('PERF', D0)`;
2. dereferences the handle and skips the first count word;
3. selects the player or opponent live-car structure from `D1`;
4. executes `D3 = 36; MOVE.W (A3)+,(A0)+; DBF D3`, copying exactly **37 words / 74 bytes**;
5. calls `HUnlock`/`ReleaseResource`.

The two callers at `Traffic+$09D8` and `+$09EE` form IDs `(playerIndex+1)*100` and
`(opponentIndex+1)*100 + 400`. Thus resource words 1..37 are a template for bytes 0..73 of each
live car structure. Resource words 38..54 are outside the measured copy and must not be called
physics fields.

### Named template fields

| resource word | resource byte | live-car byte | meaning | evidence |
|---:|---:|---:|---|---|
| 0 | 0 | - | following-word count = 54 | size and all eight values |
| 16 | 32 | 30 | maximum forward gear | shift code compares current gear at car+28 with car+30; `Traffic+$530E` writes 4 for Stock, 5 for Sledgehammer and 6 for the other player cars, matching the resource |
| 24 | 48 | 46 | automatic-shift flag | manual shift path is taken when car+46 is zero; Stock and all computer opponents contain 1, while the three tuned player cars contain 0, matching the manual's transmission descriptions |

Resource word 30 is not stable configuration despite being 4 in every record: initialization at
`Traffic+$0812..+$081A` overwrites its two destination bytes (live car +58/+59) from another table.
The other copied words are mostly zero initial state and remain unnamed until their consumers are
mapped.

### Words 38..54 are dead data in version 1.02

The final 17 words differ systematically by car; words 40 onward contain conspicuous increasing
sequences and resemble garage-graph or performance data. That resemblance is not a decode.

An exhaustive source check finds no consumer:

- each application resource fork contains exactly one byte occurrence of `PERF`, the immediate
  type argument at this loader (`Traffic+$06C6` in the colour build);
- the loader copies only words 1..37, does not store or return the resource handle or data pointer,
  then calls `HUnlock` and `ReleaseResource`;
- the all-segment static trap map contains no game call to `GetIndResource`, `GetNamedResource`,
  `Get1Resource` or `RGetResource`, eliminating an indirect Resource Manager lookup of this type;
- neither copied live-car structure contains the tail bytes.

Therefore the last 17 words are **unreferenced shipped data in the colour and B&W version 1.02
executables**. They may describe an abandoned performance-display design, but this game does not
read them. Preserve them in extraction; do not use them to explain current behaviour or attach
units to them.

Reproduce the inventory and the exact B&W/colour equality check with:

```sh
python3 tools/dump_perf.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```

## `OBJS`: proved outer model grammar

All 160 `OBJS` resources parse exactly with the walk performed by `Initialize+$063A`; the parser
lands on the declared end of every record, and every stored index is in range. The colour and B&W
data files' complete `OBJS` sets are byte-identical.

The on-disk sequence is:

1. one signed word giving the exact number of following words;
2. a last index `C`, followed by `C+1` coordinate records of four signed words each;
3. a last index `R`, followed by `R+1` variable-length records;
4. a last index `G`, followed by `G+1` groups of indices into the variable-record table;
5. exactly eight indices into the group table.

A variable-length record is a render primitive:

```
word  flags
word  raster-pattern selector (0..31)
word  edge count N
word  N+1 byte offsets into the transformed 16-byte vertex records
word  -1 terminator
```

The offsets are always multiples of 16, never name the first four coordinate records, and stay
inside the model's coordinate array. Filled primitives explicitly repeat their first vertex at the
end; the outline/polyline path may remain open. A group begins with its reference last index and is
followed by that many-plus-one primitive indices.

This is not merely a shape fit. `Initialize+$0678` obtains the resource data pointer and the code
then performs that exact walk: it retains the coordinate block, builds pointers to every
variable-length record, resolves each group index into one of those pointers, and finally resolves
the eight tail indices into group pointers stored in a 40-byte runtime model descriptor.
`Initialize+$068A` stores `C-4` as the runtime coordinate last index. `Main+$2A9E/$50B0` consumes
the first four coordinate records separately, transforms their `(x,y,z)` words, and performs three
sign tests to produce the 3-bit (0..7) group selector. `Main+$50FC` then transforms the remaining
`C-3` coordinate records. Thus no coordinates are discarded: the first four are orientation
reference vertices and the rest are render geometry. Each eight-byte source coordinate is an
ignored word followed by signed `x`, `y`, and `z`; 4,933 of 4,934 ignored words are `-1` (the lone
`Truck` value is 6), and this renderer never reads them.

`Main+$2A9E` uses that 3-bit selector to choose one of the eight resolved group pointers and walks
its primitive pointers to `-1`. In each primitive, flag bit 0 enables `Main+$4550`'s geometric
facing test and bit 2 selects the outline/polyline raster path. The shipped flag values also use
bit 1 and bit 13, but the complete `Main+$2A9E` path does not consume either: after testing bits 0
and 2, both the outline and fill branches overwrite the flags register before rasterisation. They
are preserved but dead metadata in this v1.02 renderer, not semantics to invent. The second word is
proved to be a raster-pattern selector: the span writer multiplies it
by 32 to select a packed-nibble pattern table; values span the exact range 0..31. This is why some
car panels are dithered rather than assigned a single palette colour.

### Runtime model LOD tables

The distance-based model selection is now proved at `Main+$4DCE`. The object template points at a
sequence of 12-byte records:

```
word  maximum metric (inclusive; -1 is the final fallback)
word  flags
long  shared renderer/method descriptor
long  OBJS runtime descriptor
```

The routine reads the object's unsigned long metric at object offset `$1E`, takes the first entry
whose maximum is at least that metric, and advances 12 bytes between entries. Metrics above 65535
go directly to the `-1` fallback. The live trace in `amiga/objs_lod_runtime.gdb` independently
records the same table, metric and chosen-model inputs at the routine boundary.

The initialized A5 world contains 20 such tables. Car examples are `1500:Porche -> 2500:P928S ->
-1:Simplecar`, `1500:F40 -> 2500:F40S1 -> -1:Simplecar`, `1500:GenericC -> 2500:GenericS ->
-1:Simplecar`, and `1500:Taxi -> 2500:TaxiS -> -1:Simplecar`. Truck-sized objects use 2000/3000
thresholds and `Simpletruck` as the fallback. This confirms real detailed/medium/simple distance
LOD, but also corrects the earlier blanket suffix inference: the player-car tables use the full
`Porche`, `Testa`, `Lambo`, and `F40` resources as their detailed models; unloaded `P928C`,
`RossaC`, and `F40C` are not selected by these tables. The truck table deliberately names `Truck`
for both its 2000 and 3000 entries despite loading `TruckS`.

Validate all records and print their structural counts with:

```sh
python3 tools/dump_objs.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```

Add `--runtime-globals tmp/objs_runtime_globals.raw --runtime-a5 0x4861f4` (using the A5 printed
by `amiga/objs_runtime.gdb`) to enumerate the initialized LOD tables by resource name.

## `QUAD` map-cell descriptors

The single 11,366-byte `QUAD` resource (`1000`, `Quad Discripter Data`) begins with an exact
following-word count and contains 257 variable-size map-cell descriptors. `Main+$2C64` builds a
direct pointer table by reproducing this exact wordwise grammar:

```
word  traffic/road behavior type
word  static collision-bounds selector
word[] setup words
word  -1
word[] object words
word  -1
```

Three final `-1` words terminate the whole resource after the last descriptor. `Main+$43D0` indexes
the pointer table with the current map-cell type, copies the two header words, invokes every first
list entry as four words (`dispatch index`, three arguments), and feeds every four-word second-list
entry (`object-factory index`, `x`, `y`, `z`) to `Main+$3E22`, the dynamic-object constructor.
All second lists and all but descriptor 191's first list have the required four-word alignment.
Descriptor 191 has 11 setup words after its header; it is retained and reported as shipped, but is
not evidence for a different command grammar until reachability proves the game selects it.
`Traffic+$3D7C` independently reads
the first header word and uses it as the road-surface interpolation selector described below. The
second header word is also written to A5-$2500 by `Main+$43FC`; that cached copy has no reader, but
`Traffic+$4064` reads the field directly from the selected QUAD descriptor and uses it as the
static collision-bounds selector described below. The two command-list indices are direct indices into the
game's callable table rather than another encoded schema. This establishes QUAD's
relationship to OBJS: QUAD does not contain model geometry; it describes a map cell and places
objects whose factories subsequently choose an OBJS distance-LOD table.

### QUAD dispatch and the `FRED` segment

The previously unexplained `FRED` segment is now closed from both callers and initialized runtime
data. `Main+$43D0` uses the same 270-long callback table at A5-$409E for both QUAD lists:

- each aligned setup quartet is `dispatch index, D0, D1, D2`; `Main+$4412..+$4430` loads the
  indexed callback and invokes it directly. These callbacks set the fixed-scene renderer's model
  and variant globals and submit one or more stationary pieces;
- each object quartet is `factory index, x, y, z`; `Main+$4440..+$44C0` resolves the callback,
  converts the coordinates and passes it to `Main+$3E22`. The constructor calls it with the new
  object at A1. The small callback may adjust position/orientation fields and returns in A0 the
  initialized model/LOD descriptor used by the object.

All 270 table entries are valid above-A5 jump stubs. They contain 243 distinct exports: 268 slots
refer to 241 distinct `FRED` exports, while slots 68 and 70 refer respectively to `Main` export 98
(a fixed-object render helper) and export 25 (a no-op). Across every aligned shipped list, 241
dispatch indices are used and 29 are dormant. This also explains the generated-looking runs of
six- to twenty-byte FRED routines: most are data-specific object initializers differing only in a
model/LOD pointer, heading, or small coordinate adjustment; another family is a compact wrapper
around the fixed-scene renderer.

The callback table covers every FRED export except 255 (`FRED+$00FC`). That last routine has the
only direct cross-segment caller, `Main+$28CE`, in the active driving frame. It emits the
full-width patterned background bands through `Traffic+$6686` according to the current viewport
height and flags. Thus all 242 FRED exports now have a proved caller family; the code-resource name
is not being expanded into an invented acronym.

Reproduce the runtime table classification with:

```sh
python3 tools/dump_quad.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --runtime-globals tmp/objs_runtime_globals.raw --runtime-a5 0x4861f4 \
  --entrypoints ghidra_scripts/entrypoints.csv
```

Validate the grammar, print all record sizes, and verify the Color/B&W resources with:

```sh
python3 tools/dump_quad.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```

Add `--runtime-globals tmp/objs_runtime_globals.raw --runtime-a5 0x4861f4` (using the A5 printed
by `amiga/objs_runtime.gdb`) to validate the 108 initialized static-collision bounds lists.

## `MAPS`: world, navigation and map-display grids

The five `MAPS` resources are byte-identical between the colour and B&W data files, but they do
not all share one record format. `load+$024E` loads all five and establishes their roles by storing
separate pointers. The two world maps are:

```
word  exact following-word count = 4888
repeat 52 * 47 times, row-major:
    word  QUAD descriptor index
    word  packed road word
```

The second word has several independent, code-proved projections. `Main+$4394..+$43CC` stores the
raw word at A5-$251C and derives the signed 16-bit cell vertical offset at A5-$2518 as the low word
of `raw * -224`. `Traffic+$3D7C` performs the same derivation when updating another object's map
cell. The drawing paths then extract these fields from the retained raw word:

| bits | shipped use |
|---:|---|
| 15..13 | three-bit upper drawing selector; `Traffic+$6426` and `$63D0` use it to select 12-byte asset-table records |
| 12..10 | three-bit middle drawing selector; `FRED+$005C` converts it to a 24-byte raster-table offset |
| 9 | independently gates the `$63D0` asset-table path |
| 9..8 | two-bit variant; `Traffic+$6554` combines it with bits 15..13 as `(variant << 3) + upper` |
| 7..0 | retained as the fine portion of the raw word; the shipped main map uses values 0..3 and the freeway map uses 0 |

The combined five-bit drawing index addresses another 12-byte asset table. These are renderer
selectors because their consumers prove table selection, but the data alone does not justify
names such as road colour, shoulder type, or scenery class. The vertical calculation consumes the
whole raw word exactly as shipped; it must not be replaced with a guessed mask.

Resource 1000 `Main_Map` and resource 1100 `Freeway_Map` are both 9,778 bytes. The loader skips
their count words and stores their data pointers separately; normal/freeway transitions switch
the active pointer rather than copying or converting the map. `Main+$437A` and
`Traffic+$3D7C` independently compute `4 * (y*52+x)`. The first cell word indexes the 257-entry
QUAD pointer table, which closes the data chain from MAPS cell to QUAD setup/object commands to
OBJS model geometry.

The second cell word is a packed road word, not a scalar height. The complete currently proved
uses are deliberately recorded as bit operations rather than guessed road names:

- its signed 16-bit value is multiplied by `-224`, with the low word retained as the cell's
  vertical origin used by road and placed-object rendering;
- bits `$1C00`, shifted down, select one of eight six-byte records (`FRED+$005C`);
- bit `$0200` enables a Traffic selection, whose bits 13..15 select a 12-byte record
  (`Traffic+$63C4`);
- bits `$E000` select another 12-byte Traffic record (`Traffic+$6426`);
- bits `$E000` and `$0300` are combined for a further Traffic selection (`Traffic+$654A`).

Those consumers prove overlapping fields and derived indices, but not yet human meanings such as
surface, slope or intersection type. The QUAD first header supplies a separate road-behaviour
dispatch at `Traffic+$3D7C`; it must not be conflated with this packed word.

### QUAD header 0 is the cell-surface interpolation selector

`Traffic+$3D7C` computes the current vehicle/object's vertical coordinate within its MAPS cell.
Let `u = object+$6E & $7FF` and `v = object+$72 & $7FF`, so both are local coordinates within a
2048x2048 cell. The packed road word supplies the base described above. QUAD header 0 then selects
the following exact piecewise adjustment to that base (all divisions are arithmetic shifts by 3):

| header | selected surface adjustment |
|---:|---|
| 0 | flat; also clears object motion word `+$10` |
| 1 | boundary dispatch: flat for `u <= 256`; otherwise chooses the header-4 or header-2 formula from `v`, `u`, and the far edge |
| 2 | subtract `v/8`, capped at 224 beyond `v=1792` |
| 3 | diagonal split between the header-2 and header-6 formulas using `u+v < 2048`, with the near/far edge guards |
| 4 | subtract `(u-256)/8` after the near edge; the near-edge region is flat |
| 6 | subtract 224 through the near edge, then subtract `(1792-(u-256)) / 8` |
| 7 | diagonal split between the header-4 and header-8 formulas using `u+v < 2048`, with both edge guards |
| 8 | subtract `(1792-v)/8` before the far edge; the far-edge region is flat |
| all other values | diagonal split between the header-6 and header-8 formulas using `v < u-256`, with both edge guards |

The shipped header values are 0, 1, 2, 3, 4, 6, 7, 8, 9, and 29; therefore 9 and 29 deliberately
take the final/default interpolation class. Four helpers at `Traffic+$3C94..+$3D42` additionally
set object motion word `+$10` near the corresponding cell edge from one of four signed byte tables,
indexed by object heading divided by 11. This is road-surface and edge-response code, not the
object-impact detector. Static-world collision continues at the later QUAD-selected bounds lookup
around `Traffic+$4064`; the separate moving-object path uses the `COLL` resources below.

### QUAD header 1 selects static collision rectangles

`Traffic+$4064` receives one world-space corner of the moving object's rotated hull. It derives
the 52-column MAPS cell, obtains that cell's QUAD descriptor, skips header 0, and uses header 1 as
an index into a 108-pointer table at A5-$424E. Every pointer names a list of signed-word rectangles:

```
repeat:
    word  minimum local v
    word  minimum local u
    word  maximum local v
    word  maximum local u
word -1
```

The point is inside only when all four inclusive comparisons pass. For a hit, the routine computes
the distance to all four sides, identifies the nearest side (0=min-v, 1=min-u, 2=max-v, 3=max-u),
and passes that side plus the exact matching rectangle pointer to `Traffic+$3FEE`. That routine
maps rectangle identity through parallel pointer/handler tables and invokes the corresponding
response. More precisely, the table contains 44 pointers to individual rectangle records
(including records inside multi-rectangle lists), paired with 35 distinct above-A5 jump-table exports, all targeting
`Traffic` response routines. Rectangles absent from this special table still report the nearest
edge through the common collision flags. The main driving loop calls this test for all four corners
at `Traffic+$461E..+$4696`.

The reproducible straight-ahead Lake Merced route identifies one special entry without relying on
the rectangles' geometry or on a guessed resource name. At the collision, the current MAPS cell is
`(5,2)`, its QUAD index is 1, QUAD header 1 selects bounds list 63, and record 0 is hit on side 3
(`max-u`). The exact record is special-table entry 14, whose handler is jump-table export 229,
`Traffic+$5AC2`.

That handler is the recovery path itself. Once race state A5-$33F0 is at least 3, it calls the
communication response at export 160, clears driving state, sets A5-$341A, performs the reached
sound operations, loads `D6=900` and `D7=140`, and calls export 18 (`Main+$0F82`). That routine
uses D6 for the recovery window and D7 as the `_GetPicture` ID at `Main+$0FD6`; the live run reaches
PICT 140 40 Macintosh ticks after the recorded bounds hit. Thus selector 63 / record 0 is the Lake
Merced water recovery, not an ordinary solid-edge response.

Static disassembly groups the complete contiguous export range without guessing place names:

| exports | proved response family |
|---:|---|
| 197 | derives a correction vector from the current MAPS/QUAD cell and marks the common displacement response |
| 198..205 | fixed-coordinate or fixed-offset relocation; 202/203 also select `Main_Map` |
| 206 | sets only the common collision-side override flag |
| 207..210 | fixed relocation, with 207 selecting `Freeway_Map` and 208/209 selecting `Main_Map` |
| 211 | changes driving/event state and conditionally enters the shared event response at `Traffic+$52A6` |
| 212..213 | fixed relocation selecting `Freeway_Map` |
| 214 | gas-station response: while parked, starts timed repair from the eight-cell damage sum, clears damage/motion/control fields, and plays the reached sound |
| 215..217 | conditional boundary crossings between `Main_Map` and `Freeway_Map` |
| 218..219 | install fixed five-unit correction vectors while on `Main_Map` |
| 220..222 | fixed or conditional map-boundary relocation |
| 223..224 | conditionally change event state through `Traffic+$52A6` |
| 225 | conditional map-boundary relocation |
| 226..227 | clamp A5-$268E to a minimum of -60 under their respective conditions |
| 228 | local-coordinate gate which calls export 229 only beyond `u+v > 2048` |
| 229 | stop driving and show the PICT-140 recovery window |
| 230..231 | fixed relocation to `Main_Map` / `Freeway_Map` respectively |

Export 197's data path is fully decoded rather than inferred from one bend. `Traffic+$5338` reads
the active map's QUAD id, maps ids 208..227 directly to indices 0..19 and ids 241..256 to indices
20..35, then selects an eight-byte record at A5-$3236. Each record is four signed words: a
cell-relative `(u,v)` reference point and a two-component correction step. The routine adds the
reference point to the current 2048-unit cell origin, computes the angular relation to the
vehicle, conditionally reverses both correction components, and marks the common displacement
response. The captured initialized globals contain exactly 36 indices for the 36 shipped QUADs
using collision selector 107. `tools/dump_quad.py --runtime-globals ...` prints the complete
QUAD-to-index-to-vector mapping; for the first proved freeway bend it gives QUAD 221
`(8192,4096,-3,-2)` and QUAD 220 `(6144,6144,-3,-3)`.

This is deliberately a behavior-family map, not a geographic-name table. Only export 229 has a
reproducible place-specific identification so far. `dump_quad.py --runtime-globals ...` prints all
44 special-table slots as `selector:ordinal -> export`, including the repeated uses of exports
200, 201, 214, 218, 227, and 228.

This corrects an earlier false negative: searching for reads of the A5-$2500 cached header copy
proved only that the copy is dead, not that QUAD header 1 is dead. The real consumer deliberately
rereads the descriptor. Runtime capture shows all 108 selectors are valid initialized lists; the
shipped QUAD records use 102 of them. The lists contain 296 records. Three have a lower bound
greater than their corresponding upper bound and therefore can never pass the routine's inclusive
comparisons; they are retained as shipped disabled bounds rather than normalised.

`make SKIP_INTRO=1 GARAGE_CLICK=1 PROBES=1` with
`amiga/driving_lake_static_collision.gdb` reproduces the selector, record, side, table slot, export,
and PICT timing. Its probe replaces only `Traffic+$3FFE`'s `CLR.W D3`, emulates that instruction,
and returns before ordinary trap scheduling, so it does not impose a debugger stop on each impact.

The auxiliary resources have code-proved fixed grids with no leading count:

| id | name | grammar | consumer evidence |
|---:|---|---|---|
| 3333 | `NavigationMap` | 52x47, two big-endian words/cell | `Traffic+$5FEC` uses row stride 208 and column stride 4, then reads the current and adjacent cell words for navigation/traffic decisions |
| 4444 | `Real_world_Map_Data` | 52x47, two bytes/cell | `Traffic+$48C6` uses row stride 104 and reads the two bytes as map-display coordinates |
| 4445 | `Freeway_Map_Data` | 52x46, two bytes/cell | the same routine selects this pointer in freeway mode; the one-row-short extent is shipped data, not padding inferred away |

Validate all five dimensions and the Color/B&W equality with:

```sh
python3 tools/dump_maps.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```

## `COLL`: angle-indexed object collision hulls

All six `COLL` resources (IDs 100..105) are exactly 364 bytes: 91 records of four signed bytes,
covering headings 0 through 360 degrees in four-degree steps. Record 90 duplicates record 0 in
every resource. The colour and B&W data files' complete sets are byte-identical.

`load+$0410` loads the six resources in ID order into a direct pointer array. `Traffic+$02B6`
selects one with object byte `+$6D`, rounds object heading word `+$0E` down to a multiple of four,
and uses that value directly as the byte offset. Thus the resource index is proved to be
`floor(heading/4)` and each four-byte record is one pre-rotated collision hull, not a grid inferred
from the resource names.

For record bytes `(a,b,c,d)` and object centre `(x,z)` from `+$AE/+$B2`, the routine materialises
the four vertices in this order:

```
(x+a, z+b)
(x-c, z-d)
(x-a, z-b)
(x+c, z+d)
```

The zero-degree samples make the intent especially clear: resources 101..105 begin
`(-10,20,10,20)`, `(-13,29,13,29)`, `(-18,80,18,80)`, `(-18,90,18,90)`, and
`(-22,92,22,92)`. Resource 100 (`4*11`) begins `(-2,11,2,11)`. These are oriented convex object
bounds. `Traffic+$033A` performs the signed cross-product edge tests, and `Traffic+$037E` tests the
four vertices of one object against the other's hull. This is the moving-object collision path;
it is separate from the QUAD road-surface solver and from the QUAD-selected static bounds around
`Traffic+$4064`.

Validate the complete set with:

```sh
python3 tools/dump_coll.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```

### Moving-object collision pipeline

`Traffic+$0600` walks the active object-pointer array and is the response dispatcher, not merely a
hull test. It first rejects pairs whose Manhattan centre distance exceeds 170 world units. Objects
whose four-byte tag at `+$54` is `VETT` use `Traffic+$04B6`; ordinary traffic uses `$04EE` after
the shipped collision-group/status filters. Both leave the other object in A2 and return zero for
a hit.

The player path is swept. `Traffic+$0408` derives per-step x/z increments from the object's current
and previous centres, caps the step count at eight, advances a scratch object from the previous
position, rebuilds its `COLL` hull, and tests both vertex-in-hull directions at every step. The
ordinary-traffic path tests the two current hulls in both directions. In each direction,
`Traffic+$037E` tries all four vertices; `$033A` performs the four signed cross-product edge tests
for one vertex. The bilateral test catches either hull contributing a contained vertex.

After a hit, `$0600` dispatches independently for both objects:

| object tag/state | shipped response |
|---|---|
| `VETT` | `$0202`: marks impact bit `$10` in byte `+$32`, snapshots the centre, steers by `±$07E9` according to the recorded collision vertex, halves word `+$42`, changes word `+$68` by five times word `+$1A`, calls the shared speed-dependent impact routine at `$4C86`, and plays the reached impact sound |
| `OPPO` | `$02AA`: intentionally performs no mutation in this dispatcher; it only reads the global mode flag and returns |
| other active traffic | `$012A`: combines both objects' motion into a new heading/velocity, refreshes current/previous centres, then sets byte `+$6A=-1`, duration byte `+$6B=20`, turn-step byte `+$6C=2`, and requests sound/event selector 3 |

This proves separation and traffic-state response fields directly from their writers. The meaning
of the player words beyond their arithmetic effects remains open until the shared `$4C86` path is
traced through its speed thresholds and terminal branches.

### Player impact damage and terminal recovery

`Traffic+$4C86` consumes difficulty A5-$542C and the player speed word at `+$1A`. Its entry
thresholds exactly implement the manual's difficulty-dependent damage rule:

| difficulty | no damage | ordinary damage | additional rotating cell | immediate terminal recovery |
|---:|---:|---:|---:|---:|
| 0 (TRAINEE) | all impacts | — | — | — |
| 1 (ROOKIE) | speed < 30 | 30..99 | 100..200 | > 200 |
| 2 (PRO) | speed < 15 | 15..49 | 50..160 | > 160 |

The routine maintains eight damage cells at A5-$346A..-$345C. This identity is proved by two
independent consumers: `$4E06..$50AC` draws a separate severity-dependent dashboard patch for every
nonzero cell, while the gas-station path at `$5688` sums all eight, schedules repair time from that
sum, and clears them as repair progresses. Each displayed cell has levels 0..3.

An accepted impact starts a 60-tick dashboard-damage display interval. Medium/high impacts advance
cell 2 modulo four. The recorded collision side selects cell 0 or 1; each rises to level 3 and also
changes A5-$4FF6 by one in the corresponding direction. `Main+$277C` copies that signed value into
the steering calculation, proving it is persistent collision-induced steering pull. Once the
selected side cell is saturated, damage advances cells 4 and 5 in sequence. Cells 6/7 receive the
average of side cells 0/1 for the two display states selected by D7. Other reached driving paths
advance cell 3, so `$4C86` is one writer of shared damage state rather than its sole owner.
The low two Macintosh tick bits rate-limit repeated writes: ROOKIE accepts residue 0, while PRO
accepts residues 1..3.

The terminal test is also explicit: `(cell0 + cell1) / 2 + cell2 + cell3 + cell5 >= 8` branches to
the same endpoint as an over-threshold impact. It stops driving, performs the reached sound
shutdown/play sequence, loads `D6=900` and `D7=147`, and calls `Main+$0F82` to display PICT 147.
This is the shipped beyond-repair recovery described by the manual, distinct from Lake Merced's
PICT 140 water recovery.

The runtime closures use short source-derived checkpoints rather than a long drive. At the
naturally reached Course One impact, a private diagnostic hook replaces only the initial
`CMPI.W #1,-$542C(A5)`, supplies a real Rookie/Pro selection and speed 40, and resumes at the exact
original higher-difficulty arm. Rookie is selected for tick residue zero and Pro for residues
one..three, so the shipped rate limiter—not the port—accepts the impact. The ordinary run raises
one side cell and its signed steering pull. At the next safe frame boundary it moves the complete
player coordinate/history set into Main Map cell `(49,5)`, QUAD 3, selector 26, record 2: the
decoded rectangle `(v=1100..1290,u=1178..1378)` whose special table entry dispatches export 214.
The original response clears all eight cells plus the steering pull, sets the repair-active word,
and schedules repair time from the original damage sum.

The terminal arm supplies the valid eight-cell state `{3,3,1,1,0,3,3,3}` at that same natural
impact. Traffic's own formula evaluates it to exactly eight, stops driving, sets the terminal
state, and requests PICT 147. The recovery screen is acknowledged through its shipped `Button`
wait, after which Main reaches its driving exit and outer return and settles at the garage handoff.
`amiga/driving_damage_repair.gdb` and `amiga/driving_terminal_tow.gdb` retain these bounded
regressions. Production defines neither checkpoint and retains the original difficulty comparison.

## Remaining driving-data consumer map

The remaining custom types are not one undifferentiated collection of physics tables. Static
cross-references in the colour and B&W v1.02 executables prove four active families and two shipped
but inactive resources. All nine resource sets are byte-identical between the two data forks.

| type | proved outer grammar | loader / live consumer |
|---|---|---|
| `CLST` | 14 variable-length streams | `Traffic+$0758` selects id `(course+1)*100+variant`; `$10A8` advances an A5-$3740 cursor over signed-long coordinate records and `(-1, selector)` control records. Selectors 0..5 change traffic state, positions, saved coordinates, or attach a `FREE` path. |
| `FREE` | 45 records x 64 bytes | `load+$0362` retains the raw pointer. `Traffic+$0CDC` and `$0D74` select record `(id-90)*64`; `$1564/$15BE` consume successive signed-byte `(dx,dz)` pairs. |
| `FWTP` | big-endian count 224, then 224 records x 8 bytes | `load+$01DC` derives inclusive start/end pointers. `Traffic+$22E0` linearly finds word-0 keys; `$2302` chooses bytes 2..4 or 5..7 according to heading. |
| `JHPF` | 39 records x 8 bytes, no count | `load+$01B0` retains the raw pointer. `Traffic+$2370` indexes `(id-90)*8`; nonzero word 0 may redirect once to another record. Words 1/2 supply world-coordinate offsets and byte 6 supplies a heading quadrant. |
| `FWTM` | big-endian count 48, then 48 records x 6 bytes | `load+$0216` derives inclusive start/end pointers. `Traffic+$0CFA` linearly finds word-0 keys; `$0D1C` selects one of bytes 2..5 by heading quadrant, then attaches the corresponding `FREE` record. |
| `CURV` | four 256-byte direction blocks | `load+$03E6` retains the raw pointer. `Traffic+$14EE` selects direction offsets 0/$100/$200/$300, selects a 128-byte subtable from object byte +$3B, starts at +$40 within it, and consumes signed-word `(dx,dz)` pairs. |
| `TIME` | ids 128..131, each 10 records x 30 bytes | `Score+$0004` clears all four tables for reset. `$0286` inserts a result into the first record whose long at +$1A is zero or slower, shifts lower records, and writes the new long; `$04F8` renders the ten fixed-size entries. This is persistent score data, not a driving-physics input. |
| `TURN` | 29 big-endian words | `load+$03BA` retains its pointer at A5-$373C, but no instruction in either executable reads that global. |
| `PHAZ` | 20 big-endian words | neither executable contains a `PHAZ` Resource Manager request; there is consequently no application-side consumer to infer. |

The active course path is therefore `CLST` -> (`FWTM` -> `FREE`) for scripted traffic movement,
with `FWTP` -> `JHPF` for freeway spawning and `CURV` for the separate word-delta path. `TURN` and
`PHAZ` are deliberately excluded from the next decoding target: their names are not evidence of a
runtime role.

### `CLST`: stateful course command streams

`Traffic+$070A` proves exactly which 12 `CLST` resources are reachable. Course 0 chooses variants
0..2, course 1 chooses 0..4, and courses 2/3 choose 0..1, producing IDs 100..102, 200..204,
300..301 and 400..401. IDs 104 and 1200 are shipped but cannot be selected by this code. They also
use a different two-byte alignment, so treating every resource of the type as one guessed grammar
would be wrong.

The live streams are big-endian signed-long sequences interpreted according to object byte +$59:

| record | inactive interpretation | active interpretation |
|---|---|---|
| two nonnegative longs | target `(x,z)`; the cursor advances by both longs | the first long is a `FREE` path id; the cursor rewinds one long so the second becomes the next id |
| `-1,0,x,z,ids...` | installs `(x,z)`, marks the object active, and immediately attaches the first following `FREE` id | resets the active position and begins a new run of `FREE` ids |
| `-1,2,x,z` | installs and snapshots `(x,z)`, clears active byte +$59, then continues interpreting the stream in the same call | ends the current `FREE`-id run, clears active state, and continues with inactive coordinate pairs |
| `-1,4,x,z` | saves `(x,z)` in the shared target pair and returns movement selector 3 | same operation |
| `-1,3` | clears motion, marks object state byte +$3A as -1, snapshots its position/timing, and deliberately does not commit the advanced cursor | same terminal operation; every reachable stream ends with it |

Selectors 1 and 5 exist in `Traffic+$10A8` but do not occur in any reachable stream. Selector 1
has a coordinate payload plus a second saved coordinate pair. Selector 5 attaches fixed `FREE`
record 44 (the record selected by id 134). Keeping those branches documented as dormant is more
accurate than folding them into the live grammar.

Across the reachable resources the stream contains 28 selector-0 activations, 25 selector-2
deactivations, 96 selector-4 target updates, and exactly 12 terminal selector-3 records. The 899
active-path ids are all in 90..129. `FREE` contains 45 records selected as `(id-90)*64`, leaving
130..134 available to dormant or other code paths. This state-dependent one-long rewind explains
why a conventional fixed-record parse loses alignment even though the runtime remains aligned.

### `FWTP` and `JHPF`: freeway traffic spawning

`Traffic+$2302` builds the `FWTP` lookup key as `(player cell X << 8) | player cell Z`: word +$3E
provides X and the low byte at +$41 provides Z. `$22E0` scans the 224 records from the start and
returns the first matching 8-byte record. There are 223 unique keys. Key `$2412` occurs twice, at
records 139 and 140; because the scan always starts at record 0, the latter is shipped shadowed
data.

An `FWTP` record is:

```
word  packed player-cell key
byte  spawn cell X, first direction case
byte  spawn cell Z, first direction case
byte  JHPF id, first direction case
byte  spawn cell X, opposite direction case
byte  spawn cell Z, opposite direction case
byte  JHPF id, opposite direction case
```

The second triplet is selected only when the player's heading is strictly between 45 and 315
degrees; it also seeds the new object's heading field +$0C with 180 before JHPF replaces it. The
first triplet is used at the endpoints and outside that interval. The selected JHPF id is retained
in object byte +$BE.

JHPF has no count word. IDs 90..128 map directly to its 39 8-byte records:

```
word  optional alternate JHPF id (zero means no alternate)
word  unsigned within-cell X
word  unsigned within-cell Z
byte  heading quadrant, 0..3
byte  zero in every shipped record
```

A global toggle changes on every spawn. On alternate calls only, a nonzero link replaces the
selected record once; the code does not follow a chain. Four records link to IDs 123..126. World
coordinates are then `(spawnCellX << 11) + localX` and `(spawnCellZ << 11) + localZ`. The heading
quadrant is multiplied by 90 and copied to the new object's current heading +$0C, target heading
+$A2 and saved heading +$BA. This proves both the fixed-point cell size and that byte 6 is a cardinal
direction, not a speed value.

`amiga/driving_freeway_spawn.gdb` records the selected key/triplet, optional link and constructed
object for the first two naturally reached spawns. The deterministic UI harness selects Course Two
and steers with ordinary KeyMap input down the source-defined local-X `0..383` corridor. Crossing
the selector-16 rectangle in Main Map cell `(2,6)` naturally dispatches export 212. The measured
tick-8514 call moved the player from `($1085,$3204)` to `($1400,$15800)` and changed A5-$3764 from
0 to 1; at tick 8517 `Traffic+$2302` then ran naturally with a full `15/15` pool and freeway player
cell `(2,42)`. `amiga/driving_freeway_activation.gdb` is the focused observer for this chain.

The full `15/15` pool is transient, not the blocker. Every 35 ticks `Traffic+$252C` scans active
objects, computes Manhattan distance from the player, and selects objects beyond `$1400` at
`$257A`; `$1FB6` removes the selected object and decrements the count. A natural Course Two run
repeatedly exercised that path, after which the ordinary city branch immediately restored the
pool. `amiga/driving_freeway_movement.gdb` records the bounded retirement and movement evidence.

The mode word is established by shipped special-collision responses selected through MAPS/QUAD
data. For example, Main Map cell `(2,6)` uses QUAD 21 and collision selector 16; its first rectangle
selects response-table export 212 (`Traffic+$5632`), which sets freeway mode. Other statically
proved true-mode cells include `(3,44)`, `(6,32)`, `(13,31)`, `(24,1)`, and `(7..9,39)`. Because
the 68000 is big-endian, a byte read at A5-$3764 sees the high byte of word value 1 and misleadingly
returns zero; runtime observers must read the full word.

### `FWTM` and `FREE`: navigation-directed traffic paths

`Traffic+$0C78` first projects the traffic object's current world position by 512 units in its
heading direction. It divides the projected X/Z by 2048, indexes the 52-column `NavigationMap`
with the already-proved 208-byte row and four-byte cell strides, and returns that cell. `$0D1C`
uses the cell's first word as the `FWTM` lookup key. Thus the record key joins directly to the
navigation grid; it is not a traffic-object index inferred from the resource name.

The 48 unique-key records are:

```
word  NavigationMap cell word
byte  FREE path id for heading <=45 or >315 degrees
byte  FREE path id for heading 46..135 degrees
byte  FREE path id for heading 136..225 degrees
byte  FREE path id for heading 226..315 degrees
```

Zero means that no route exists for that cell/direction and takes the ordinary traffic-removal
path. Every nonzero shipped value is a `FREE` id in 90..130. IDs 90..121 return movement selector
9; IDs 122..130 return selector 10. The selected resource address is exactly
`FREE + (id-90)*64`.

`FREE` is therefore 45 paths for logical IDs 90..134. Each path is 32 consecutive signed-byte
`(dx,dz)` pairs with no count or header. `Traffic+$1564` and `$15BE` consume one pair, advance the
object's saved pointer by two, sign-extend both components, add them to world X/Z, and run the
shared position/update calls. The active `CLST` streams reference IDs 90..129, `FWTM` reaches
90..130, and dormant selector 5 at `$1226` selects ID 134 directly. No active consumer found so far
selects 131..133.

The natural Course Two transition validates this entire join dynamically. The first post-transition
object was JHPF id 126 at cell `(2,40)`, world `($13D5,$14800)`, heading 180. Projecting it selected
NavigationMap key `$0078`; the matching FWTM record contained direction ids
`(125,125,126,126)`, and heading 180 selected FREE id 126 with movement selector 10. Its first
signed pair `(0,-64)` advanced the saved cursor by two and set the target from
`($13D5,$14800)` to `($13D5,$147C0)`. `amiga/driving_freeway_object.gdb` binds the created pointer
and preserves the identity across every one of those calls.

Validate the outer shapes and Color/B&W equality with:

```sh
python3 tools/dump_driving_data.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```
