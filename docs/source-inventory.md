# Original source inventory

The port targets **Color VETTE! 1.02**, whose `vers`/`VETT` resources identify
© 1991 Sphere, Inc. The separate B&W application is not interchangeable code.

On the source HFS volume the Color application is under
`VETTE!/VETTE! Folder/(Folder) Color VETTE!`. The parenthesized text is part of
the archived folder name, not an instruction to create a folder.

| File | Resource-fork bytes | Contents |
| --- | ---: | --- |
| Color VETTE! | 1,587,389 | 11 CODE resources; pictures, palettes, windows and other application resources |
| VETTE!.Data | 577,498 | 231 resources across 23 custom types |
| B&W VETTE!/VETTE! | 523,089 | Separate B&W program; not used by the port |

The Color CODE resources total 118,892 bytes. See [static-map.md](static-map.md)
for segment sizes, export counts, low-memory accesses and address conventions.
Both applications contain 192 PICT resources; color pictures account for most of
the size difference. Their data files have byte-identical individual resources,
although whole-fork hashes differ because resource-map layout differs.

## Game-data resource families

| Type | Count | Role |
| --- | ---: | --- |
| INST | 16 | Sampled instruments/effects |
| BGAS | 1 | Bogas Driver v2.1 |
| OBJS | 160 | Model coordinates, primitives and orientation groups |
| MAPS | 5 | City/freeway, navigation and map-display grids |
| QUAD | 1 | Map-cell setup/object commands and collision selectors |
| COLL | 6 | Angle-indexed moving-object hulls |
| PERF | 8 | Initial player/opponent car state |
| CLST | 14 | Course-dependent command streams |
| FREE | 1 | Fixed-size signed-delta paths |
| FWTP / JHPF / FWTM | 1 each | Freeway placement and navigation-to-path tables |
| CURV | 1 | Direction-dependent coordinate deltas |
| TIME | 4 | Ten scores per course; persisted by the port |
| SINE / COSS / HEXS | 2 / 1 / 1 | Lookup tables used by original arithmetic |
| PATN | 2 | Map-display patterns |
| STRT | 1 | Street names |
| COPY | 1 | Original protection data; bypassed by the port |
| COMM | 1 | Unsupported head-to-head communications |
| TURN / PHAZ | 1 each | Shipped data with no active reader established |

Names above come from resource maps and code consumers. Exact decoded grammars
and dormant fields are in [data-formats.md](data-formats.md); do not assign
semantics to remaining words just because their values look familiar.

The 732-byte sound CODE segment exposes the Bogas interface. INST includes the
opening song, signature music, bell, metallic cue, engine, horn and traffic/
collision/recovery effects. Paula scheduling preserves three logical contexts
across four hardware channels, with used source volumes 0..300 mapped to 0..64.

## Inspection

`resource_fork.py` reads extracted forks; `hfs_extract.py` lists HFS contents,
resources and CODE segments. The `dump_perf/objs/maps/quad/coll/driving_data.py`
tools validate the decoded formats. `dump_inst_levels.py` audits sound levels.
All original bytes and generated listings remain local. The distributable
symbol and export maps are in `disasm/` and `ghidra_scripts/`.
