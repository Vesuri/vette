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

A variable-length record has three fixed header words. Its third word is a last index `N`, making
the complete record `N+5` words. A group begins with its reference last index and is followed by
that many-plus-one variable-record indices.

This is not merely a shape fit. `Initialize+$0678` obtains the resource data pointer and the code
then performs that exact walk: it retains the coordinate block, builds pointers to every
variable-length record, resolves each group index into one of those pointers, and finally resolves
the eight tail indices into group pointers stored in a 40-byte runtime model descriptor.
`Initialize+$068A` stores `C-4` as the runtime coordinate last index; the meaning of the five
excluded coordinate records still needs a renderer consumer before it is named.

`C`/`S` car pairs are structurally complex/simple candidates, but distance-based selection is not
yet proved. For example, `F40C` has 76 coordinate records and 30 variable records while `F40S1`
has 16 and 9; `Taxi` has 70 and 27 while `TaxiS` has 20 and 10. The size reduction is real. Calling
it near/far LOD still requires tracing which runtime condition chooses each model.

Validate all records and print their structural counts with:

```sh
python3 tools/dump_objs.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```
