# VETTE!.Data formats

Only fields tied to code that reads them are named here. Repeated values, apparent scales and
plausible physical quantities remain unknown until a consumer proves them.

## `PERF`: car template plus an unresolved tail

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
live car structure. Resource words 38..54 are outside the measured copy and must not yet be called
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

### Unresolved words 38..54

The final 17 words differ systematically by car; words 40 onward contain conspicuous increasing
sequences and are likely related to the garage graph or performance. That is an observation, not a
decode. The proved race loader neither copies nor reads them. Their consumer must be found before
attaching units or manual specification names.

Reproduce the inventory and the exact B&W/colour equality check with:

```sh
python3 tools/dump_perf.py \
  'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc' \
  --compare 'tmp/rsrc_VETTE!_VETTE!_Folder_Folder_B&W_VETTE!_VETTE!.Data.rsrc'
```
