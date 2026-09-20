# Source inventory — what is actually in the shipped application

> **Read this before estimating anything, and before deciding what the port's data pipeline looks
> like.** Everything here is `[DERIVED]` from the resource maps with `tools/hfs_extract.py` —
> **nothing has been disassembled or run**, so every statement about what a resource *means* is
> `[INFERRED]` from its four-character type, its name and its size. Replace an inference with a
> measurement when you make one; do not build on one.
>
> How to regenerate any of it: `docs/toolchain.md` §From the archive to the segments.

## ⭐ What the build says about itself — `[MEASURED]`

`vers` 1 and `VETT` 0, **identical in both builds**:

```
VETTE! version 1.02
© 1991 Sphere, Inc.
```

So the game the port must match is **1991**, and Spectrum HoloByte is the division — Sphere, Inc.
is the copyright holder (the box rear says so too: *"Spectrum HoloByte, a division of Sphere,
Inc."*). ⚠ **The 1989 these docs used to carry was unsourced** and has been removed everywhere.

⭐ **`[ASSUMED]` — and this is the whole answer, not an open question:** *Vette!* came out on DOS in
**1989** and this Macintosh build is a **1991** port of it, so both dates were right about
different things and the docs simply attached the DOS one to the Mac binary. Nothing in the port
depends on which, so **do not spend a measurement on it** — note the two-platform reading and move
on. (The archive's own box, which is the IBM one, is consistent with that: *"Actual screens from
IBM EGA version"*. Its only year is the **1989 stock Corvette** in the feature list — a car model
year, and a second plausible source of the confusion.)

⚠⚠ **What the date DID cost, and the reason this is written down at all:**
`docs/mac-reference-loop.md` listed *"period-correct: VETTE! 1.02 is 1989; System 7 is 1991"* as
reason 2 of 3 for running System 6.0.8. That premise is false however the 1989 is explained — this
build is 1991 too — and a dead premise sitting in a numbered list of justifications reads as
support the next time the decision is questioned. **The lesson is about retiring an argument
loudly, not about the year.**

## The shape of it

Two applications and one data file, in `VETTE!/VETTE! Folder/` on the 8049 KiB volume.

| | resource fork | code | notes |
|---|---|---|---|
| `(Folder) B&W VETTE!/VETTE!` | 523 089 B | 11 `CODE`, **124 554 B** | `APPL`/`VETT` |
| `(Folder) Color VETTE!/Color VETTE!` | 1 587 389 B | 11 `CODE`, **118 892 B** | `APPL`/`VETT`; + `pltt`×8, `wctb`, 8 `WIND` |
| `VETTE!.Data` (one copy in each folder) | 577 498 B | — | `DATA`/`VETT` |

⭐⭐ **The two `VETTE!.Data` forks contain the SAME 231 resources, all 231 byte-for-byte identical**
(checked pairwise). The forks' whole-file hashes differ only in resource-map layout. So **the game
data is build-independent**: the build choice picked an *application*, not a data set, and every
table, object and sound below is common to both. ⭐ **The port follows `Color VETTE!`** (locked).

Both applications carry 192 `PICT`; almost the entire ~1 MB difference is those pictures in colour
rather than 1-bit (380 328 B of `PICT` in B&W vs 1 447 468 B in Color). The *code* is within 5%
either way.

### ⭐⭐ What the colour build says about depth — 16 colours, not 256

| evidence | reading |
|---|---|
| 8 `pltt` resources (128-131, 140, 150, 160, 170), **every one exactly 272 B** = 16 B header + 16 × 16 B entries | `[DERIVED]` the game's palettes hold **16 colours** → **4 Amiga bitplanes**, an ordinary OCS configuration and one plane *cheaper* than Revs's five |
| Color `PICT`s open with `0x0011` VersionOp at offset 10; B&W `PICT`s are v1 (byte opcode `0x11`, version `0x01`) | Color is **PICT v2 / Color QuickDraw**; the picture decoder the port needs is the v2 one |

⚠⚠ **`pltt` was evidence about PALETTES, not proof about the DRAWING SURFACE** — and the proof has
since been taken somewhere else entirely: **the running original says 4 bpp**, for both the screen
and the game's offscreen GWorlds, and it also says **512 × 320** for the painted area.
→ `docs/mac-hardware.md` §The display surface. The `pltt` reading above was right, but it was right
by luck: it is kept here as the resource fact, not as the depth authority.

⚠ Do not re-derive depth from `PICT` headers: a naive opcode scan of them produced nonsense here
(`0 bpp`, `49151 bpp`), which is exactly the kind of number that gets believed if it lands closer to
plausible.

## The 11 `CODE` segments — and they are NAMED

Same names and same order in both builds. ⭐ This is authored structure handed to us for free; the
prior two ports had to recover the equivalent by hand, which is what `docs/rename.md` exists for.

| seg | B&W | Color | name | ⚠ `[INFERRED]` from the name only |
|---|---|---|---|---|
| 0 | 4 072 | 4 088 | — | **the jump table** + Segment Loader header. Not code. Its 509 exports are now in `ghidra_scripts/entrypoints.csv`; generation and validation are documented in `docs/toolchain.md`. |
| 1 | 32 606 | 24 994 | `Main` | the main loop / event loop |
| 2 | 5 448 | 7 032 | `Initialize` | startup |
| 3 | 9 106 | 9 110 | `Communication` | ⭐ **explained by the manual:** head-to-head play over direct serial, Hayes-compatible modem, or AppleTalk; not required for the single-player milestone |
| 4 | 1 618 | 1 668 | `load` | resource loading; `VETTE!.Data` is the likely subject |
| 5 | 4 600 | 4 628 | `Score` | scoring / results |
| 6 | 27 862 | 27 958 | `Traffic` | traffic simulation — the second-largest segment, and identical in size across builds |
| 7 | 6 488 | 6 508 | `FRED` | ⚠ unexplained, and ~6.5 KB in both |
| 8 | 3 358 | 3 442 | `Intro` | opening sequence |
| 9 | 732 | 732 | `sound` | ⭐ **exactly 732 bytes in BOTH builds** — a thin shim, consistent with the audio work living in the `BGAS` driver below rather than in the application |
| 10 | 28 664 | 28 732 | `%A5Init` | the MPW/Lisa-Pascal **globals initialiser**, compiler-generated. Not game code |

⭐ **Net of `CODE 0` and `%A5Init`, the B&W game is ~91.8 KB of 68000 code** across 9 segments, the
largest being `Main` at 32.6 KB and `Traffic` at 27.9 KB. That is the size of the thing being ported.

## `VETTE!.Data` — 23 custom types, 231 resources, and nearly all of them named

| type | n | bytes | `[INFERRED]` |
|---|---|---|---|
| `INST` | 16 | **373 411** | sampled instruments/effects, all named — see Audio below |
| `OBJS` | 160 | 95 394 | the 3D object models, all named |
| `MAPS` | 5 | 39 004 | `Main_Map`, `Freeway_Map`, `NavigationMap` (9 778/9 778/9 776 B), `Real_world_Map_Data` 4 888, `Freeway_Map_Data` 4 784 |
| `BGAS` | 1 | 15 066 | `Bogas Driver v2.1` — the sound engine |
| `QUAD` | 1 | 11 366 | `Quad Discripter Data` [sic] |
| `SINE` | 2 | 8 712 | `Sine Table 360`, `Tangent Table` |
| `CLST` | 14 | 7 048 | the courses: `Course1a…c`, `Course2a…e`, `Course3a/b`, `Course4a/b` |
| `FREE` | 1 | 2 880 | `freeway deltas` |
| `COMM` | 1 | 2 490 | id 0, unnamed. Pairs with the documented head-to-head `Communication` segment |
| `PATN` | 2 | 2 048 | `Main_Map` ×2, 1 024 B each — QuickDraw patterns for the map display |
| `STRT` | 1 | 2 222 | `Street_Names` |
| `COLL` | 6 | 2 184 | named `4*11`, `10*20`, `13*29`, `18*80`, `18*90`, `22*92` — ⭐ the names look like **grid dimensions**, and 6 sizes suggests per-course or per-object-class collision grids |
| `COPY` | 1 | 1 991 | `Protect` — the copy protection, data-driven |
| `FWTP` | 1 | 1 794 | `freeway traffic placement` |
| `HEXS` | 1 | 1 446 | `HexSinCos Table` |
| `TIME` | 4 | 1 200 | ids 128-131, 300 B each, unnamed |
| `CURV` | 1 | 1 024 | `rw curve` (real-world curve?) |
| `PERF` | 8 | 880 | **110 B each**: `Stock`, `ZR1`, `TwinTurbo`, `Sledge`, `Porche`, `Testa`, `Lambo`, `F40` — count 54, then a proved 37-word live-car template and 17 words unreferenced by either v1.02 executable |
| `COSS` | 1 | 516 | `Cosine Table 360` |
| `JHPF` | 1 | 312 | `freeway traffic placement` (same name as `FWTP`) |
| `FWTM` | 1 | 290 | `freeway traffic movement` |
| `PHAZ` | 1 | 40 | id 128, unnamed |
| `TURN` | 1 | 58 | `slowing table` |

⭐⭐ **The trigonometry is table-driven, not computed** — `Sine Table 360`, `Cosine Table 360`,
`Tangent Table`, `HexSinCos Table`. That is the single most load-bearing fact in this file for the
Amiga side, because it means the hot path does **not** need the 32-bit multiply/divide the 68000
lacks (the `muldiv-audit` rule in `CLAUDE.md`), and the tables port across unchanged.

⭐ `PERF` is now partially decoded from its code consumers, not its numerical shape.
`Traffic+$06BE` skips the count and copies words 1..37 into the live-car structure; word 16 is
maximum forward gear and word 24 selects automatic shifting. Words 38..54 remain outside that
proved copy and have no reader in either v1.02 executable; they are deliberately unnamed dead
data. The B&W and colour records are byte-identical. → `docs/data-formats.md`,
`tools/dump_perf.py`.

## Audio — ⭐⭐ this corrects a documented assumption

`docs/amiga-arch.md` was written assuming the original drives the **Mac Sound Manager / Sound
Driver** directly. It does not appear to: the data file carries **`BGAS 128 "Bogas Driver v2.1"`**
(15 066 B) plus 16 named `INST` resources totalling **373 411 B — 72% of the whole data file**, and
the `sound` code segment is a mere **732 bytes in both builds**.

`[INFERRED]` reading: audio is a **third-party sampled-instrument driver shipped inside the game
data**, and the application only asks it for things. ⭐ That makes the audio seam structurally like
Revs's after all — Revs reproduced the *MOS sound scheduler* rather than the chip — rather than the
unlike-anything-before case `docs/amiga-arch.md` §Audio describes. The faithful surface to reproduce
is **the Bogas driver's entry points**, which are enumerable from that one resource, and the Amiga
side is a Paula sample player underneath it.

⚠ All of that is inference from names and sizes. **It needs the `sound` segment disassembled and the
driver's interface identified before anything is built on it.**

The 16 `INST` resources, which double as a list of what the game makes noises about:
`Opening song` (117 558 B — the largest single resource in the game), `Signature` (44 928),
`mic` (44 599), `splash` (36 569), `joel` (31 181), `skid` (17 496), `crash` (17 472),
`heli` (12 136), `cable car bell` (9 834), `beep1` (8 408), `kill` (7 299), `police` (6 928),
`Engine` (6 061), `horn` (5 614), `beep2` (4 616), `thud` (2 712).

## `OBJS` — 160 named models, and the world is real San Francisco

Sizes run 100 B to 1 848 B. `Initialize+$063A` and `Main+$2A9E` prove the complete render grammar:
four orientation-reference coordinates, geometry vertices, flagged primitives with one of 32
raster patterns, groups of primitive references, and eight view-selected groups. All 160 records
validate exactly, and the B&W and colour sets are byte-identical. The 257 `QUAD` records are map
cell descriptors: each carries two header words, setup calls, and positioned object-factory calls
which lead to the OBJS distance-LOD tables. Remaining flag/header/index meanings are explicitly
queued rather than guessed. → `docs/data-formats.md`, `tools/dump_objs.py`, `tools/dump_quad.py`.

- **Landmarks:** `GoldGate`, `BayBridge`, `Lombard`, `Marina`, `Broadway`, `SunsetBlvd`,
  `GreatHighway`, `Hwy1`, `Hwy280`, `Hwy480`, `Clay`, `Gough`, `Oak`, `Chinatown`, `Cliffhouse`,
  `FerrBldg`, `Gherdeli`, `Coithill`, `fishwhrf`, `JapanTwn`, `CityHall`, `BHall1`, `fairmont`,
  `StPeter`, `StMar`, `BofA`, `Palace`, `Pier`, `pier392`, `Windmill`, `Zoo`, `CityPark`, `Godess`,
  `Pyramid`, `HolidInn`/`HolidBri`/`HolidBril`/`Holidlwn`/`holidprk`, `Hiatt`
- **The eight cars** mirroring `PERF`: `Porche`, `Testa`, `Lambo`, `F40`, plus `NuVette`, `rx7`,
  `P928C`, `CountacS`, `RossaC` …
- **Traffic and people:** `Ambulanc`, `Bus`, `Taxi`, `Truck`, `Tanker`, `Police`, `Cop`, `motor`,
  `CableS`/`cablec2` (the cable cars), `Pedestrian3`, `jogger`, `juggler`, `lawyer`, `nun`,
  `blindman`, `oldlady`, `wino`, `trafficp`, `crossgua`/`Crossboy`/`crossgir`, `DrugDeal`
- **Road furniture and geometry:** `SignBoard`, `LeftArrow`/`RightArrow`/`StraightArrow`,
  `FinishFlag`, `lamppost`, `Wall896`, `SpecialWall1/2`, `barri128`/`barri256`,
  `BigCurve1…5`, `Lmbrd1…3`, `Split`, `QuadSplit`, `OPseg2/3`, `BTunnel1…3`, `booth`, `Hedge`,
  `Bldg1200`, `Bldg600`, `LombardBldg`, `building400x400x600`, `Block1…4`, `Tree`
- **Distance-selected model detail** — `F40C`/`F40S1`, `P928C`/`P928S`, `GenericC`/`GenericS`,
  `RossaC`/`RossaS`, `Police`/`PoliceS`, `Taxi`/`TaxiS`, `Truck`/`TruckS`, `Tanker`/`Tankers1`,
  `s55`/`s55BW` — the `C` records are now measured to be substantially more complex than their `S`
  partners (for example `F40C`: 76 coordinates/30 variable records; `F40S1`: 16/9).
  `Main+$4DCE` now proves 12-byte, metric-thresholded detailed/medium/fallback tables. The important
  correction is that suffixes alone do not define membership: the live F40 table is
  `1500:F40 -> 2500:F40S1 -> -1:Simplecar`, while `F40C` is not loaded. Generic, Police, Taxi and
  Tanker do use their measured complex/simple pairs. See `docs/data-formats.md` for the complete
  record and the 20 initialized tables. Note `s55BW` also hints some models are monochrome-specific.
- `GenericC`/`GenericS` come in `Gn`, `red`, `br`, `vlb` colour variants — recoloured traffic.

## The trap surface — a preliminary FLOOR, not an inventory

⚠⚠ **These are screening numbers and must not be quoted as the trap inventory.** The inventory is
Phase 2's flow-following sweep (`docs/open-work.md` §"Write `ghidra_scripts/DumpTraps.java`"), and ⚑ the postmortem's rule stands: treat
any static count as a **floor** — Revs's surface looked closed after a static sweep and three more
calls appeared only when it was *run*.

| method | result |
|---|---|
| whole-file linear sweep of all 10 code segments, counting `$Axxx` words | 1 686 sites, **220 distinct traps** — ⚠ inflated: a linear sweep decodes data as instructions |
| walk from each of the 508 distinct jump-table entries to its first terminator (2 734 instructions) | 141 sites, **61 distinct traps** — ⚠ deflated: 600 B per entry, no branch following |

⭐ The honest reading is only this: **the surface is in the low hundreds of distinct traps, and it is
the project.** Both numbers exist to bracket it, not to size the work.

⭐⭐ **Also from `CODE 0`, and these are solid:** 509 jump-table entries, per-segment counts summing
to exactly 509 (`Main` 130, `FRED` **242**, `Traffic` 80, `Initialize` 16, `Communication` 16,
`sound` 12, `Score` 9, `Intro` 2, `load` 1, `%A5Init` 1), 31 272 B of A5-relative globals, 4 104 B
above `a5`. `FRED`'s 242 entries in 6 508 bytes — ~27 bytes per externally-callable routine —
`[INFERRED]` make it a small-leaf-routine library rather than a subsystem.
