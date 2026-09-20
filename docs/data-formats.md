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
facing test and bit 2 selects the outline/polyline raster path. Other observed flag bits remain
unnamed. The second word is proved to be a raster-pattern selector: the span writer multiplies it
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
following-word count and contains 192 variable-size map-cell descriptors. `Main+$2C64` builds a
direct pointer table to them. Each descriptor is:

```
word  traffic/road behavior type
word  second header field (meaning not yet proved)
repeat { word dispatch index; word argument 0; word argument 1; word argument 2; }
word  -1
repeat { word object-factory index; word x; word y; word z; }
word  -1
```

Two final `-1` words terminate the whole resource after the last descriptor. `Main+$43D0` indexes
the pointer table with the current map-cell type, copies the two header words, invokes every first
list entry through the game's dispatch table, and feeds every second-list entry plus its three
coordinates to `Main+$3E22`, the dynamic-object constructor. `Traffic+$3D7C` independently reads
the first header word and branches on proved values 0, 1, 2, 3, 4, 6, 7, and 8; names for those
individual road behaviors still require tracing the branches to effects. This establishes QUAD's
relationship to OBJS: QUAD does not contain model geometry; it describes a map cell and places
objects whose factories subsequently choose an OBJS distance-LOD table.

Validate the grammar, print all record sizes, and verify the Color/B&W resources with:

```sh
python3 tools/dump_quad.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```
