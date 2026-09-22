# Toolchain & how to run the pipeline

All paths relative to the project root (`Vette/`). Host is macOS (Apple Silicon).

⚠⚠ **THIS FILE IS PART PLAN.** Rows marked ✅ are verified present on this machine; rows marked
❓ are **candidates under discussion, not decisions** — see `docs/mac-reference-loop.md` for the
ground-truth-loop choice and PROJECT.md §Open decisions for the rest. Do not read a ❓ row as
"installed" or as "chosen".

## The pipeline (intended shape)

```
VETTE__1.02_and_extras.sit                       (tmp/, local only, never committed)
  └─ unar ─────────────────────► VETTE!.img + the extras (manual, map, key chart)
        └─ tools/ndif2raw.py ──► VETTE_1_02.raw    NDIF -> raw; block map is in the RESOURCE FORK
              └─ tools/hfs_extract.py list|extract|resources|segments
                    ──► CODE_NN_<name>.bin, one file per segment, + the jump table from CODE 0
              └─ Ghidra headless (ghidra_scripts/) ──► disasm/listing.txt, xrefs, TRAP map
                    └─ disasm/symbols.csv  ◄── curated, grows over time (addr → name/type/note)
                          └─ src/mac/     the Toolbox/OS trap layer (the hardware boundary)
                          └─ src/platform/  platform.h abstraction
                                └─ src/platform/{host,amiga}/  concrete backends
```

⭐ **Note what is NOT in that diagram: a transpiler.** The code is already 68000, so the prior
ports' highest-leverage front-end investment has no counterpart here. What replaces it as the
centre of gravity is the **trap layer** — see `docs/postmortem.md` §How this maps onto a Mac 68k
port.

## Installed / needed

| Tool | Where | Purpose | State |
|---|---|---|---|
| Python 3.11 | `python3` | resource/segment tools | ✅ |
| clang / make | system | the host build | ✅ |
| `m68k-amiga-elf-gcc`, `vasm`, `elf2hunk` | `~/.local` (`. amiga/env.sh`) | Amiga cross-build | ✅ |
| FS-UAE + `m68k-amiga-elf-gdb` | `~/.local/fs-uae` (same `env.sh`) | Amiga measurement loop | ✅ |
| Kickstart 3.1 | `$KICKSTART` (`~/Documents/RetroPie/BIOS/kick31.rom`) | FS-UAE boot | ✅ |
| Ghidra 12.1 + JDK 21 | `tools/ghidra` → `~/.local/share/ghidra` | disassembly | ✅ |
| `unar` / `lsar` 1.10.7 | `brew install unar` | the StuffIt 5 archive — **the only tool that reads SIT5** | ✅ |
| `tools/ndif2raw.py` | ours | NDIF disk image → raw sectors (nothing off the shelf does this) | ✅ |
| `tools/hfs_extract.py` | ours | read the HFS volume; extract forks; `CODE`/`PICT`/`snd ` resources | ✅ |
| `tools/mac_fb_to_amiga.py` | ours | ⭐ a framebuffer dump → **Amiga interleaved bitplanes + a 16-entry `COLORxx` palette**, with every lossy step priced. **This is the Stage A pixel differential.** Pass `--reference <MAME.png>` and it re-measures the CLUT→DAC gamma against the emulator's own output on every run. Writes `.planes`, `.pal` (text, for reading) and `.palbin` (binary, for `.incbin`) | ✅ |
| `tools/planes_checksum.py` | ours | the **host half of the Stage A acceptance test**: the checksum of a `.planes` blob, to compare against the one the Amiga computes over its own chip RAM (`amiga/stage_a.gdb`). ⚠ Rotate-then-xor, not a sum — a sum is blind to byte order, which is how every plausible failure of this path goes wrong | ✅ |
| `tools/m68k_lowmem.py` | ours | flow-follow all `CODE 0` roots and inventory reachable absolute references to Mac Page 0; self-tests both absolute-short and absolute-long decoding | ✅ |
| **a Macintosh emulator** | — | the ground-truth reference loop (`docs/mac-reference-loop.md`) | ❓ |

### ⭐ Regenerating Stage A's assets (they are NOT committed — derived from the game)

```
VETTE_FB_AT=1770 <the MAME headless recipe with -autoboot_script tools/mac_probe_fb.lua>
python3 tools/mac_fb_to_amiga.py ref/mame/snap/intro/fb_screen.raw \
    ref/mame/snap/intro/fb_screen.clut 320 480 amiga/assets/intro \
    --crop 64,92,512,320 --reference ref/mame/snap/intro/mac2fdhd/<LAST>.png
```

⚠⚠ **`<LAST>` IS NOT `0000.png`.** MAME numbers snapshots from the highest file already in the
directory, so the run's own brackets are the *newest* pair, and passing `0000.png` silently diffs
the fresh dump against **a previous run's screenshot**. That failure reads as
`GAMMA NOT CONFIRMED: worst channel error 255/255` — i.e. as a broken palette derivation, not as
the wrong file. `ls -t ref/mame/snap/intro/mac2fdhd/ | head -3` and take the first bracket of the
newest three.
⚠⚠ **The Macintosh mouse cursor is IN THE PIXELS.** On a Mac II the Cursor Manager's VBL task
composites it into the framebuffer, so a dump contains the arrow wherever the pointer happens to be
— the first intro asset had it baked in at `(32,8)` of the window and it looked like an Amiga
sprite bug on the port. `tools/mac_probe_fb.lua` parks the pointer at `(620,460)`, outside the
crop, before the capture frame, and prints where and when it parked.

`VETTE_FB_AT` is an **absolute frame number**, not a delay: ⭐ **1770** is the intro art complete
and before the first overlay `DrawPicture` at 1782 (Target 1's reference), **4218** is the garage
screen, which is static and was the pixel-format proof. ⚠ A guessed wait instead of an absolute
frame is the mistake `CLAUDE.md` forbids for every MAME driver.
⚠ The crop is the game window inside the 640×480 screen, `(64,92)`–`(575,411)`, and it must be
word-aligned — the tool rejects it otherwise, because the copper and the blitter address bitplanes
in words.
⚠⚠ **Each scene reloads the CLUT**, so the intro's 16 colours are NOT the garage's. Capture the
frame you are matching; do not reuse a palette across scenes.

`tools/ghidra` is a **symlink to the shared install at `~/.local/share/ghidra`** — the same one the
*Rescue on Fractalus* and *Revs* repos point at, so the ~874 MB extracted distribution exists once
on disk rather than once per port. (No trailing slash on the `tools/ghidra` gitignore entry — a
trailing-slash pattern doesn't match a symlink to a directory, only a real one.) `tools/ghidra-proj/`
stays per-repo: that project *is* the annotation database and must not be shared.

Ghidra needs JDK 21 on `PATH`:

```sh
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```

> `brew install` on this machine triggers a privilege-elevation prompt, so kick installs off
> yourself or approve the prompt when one appears.
>
> ⚠ **Verify a fresh Ghidra extraction has `support/analyzeHeadless` before trusting it.** A pruned
> copy silently breaks headless use while looking like a normal install at a glance.

## ⭐ From the archive to the segments — three nested layers, and two need our own code

Verified end to end on this machine. Each layer defeats a *different* tool, which is why this is
written down rather than left as "just unpack it".

```sh
brew install unar                                              # once
unar -o tmp/unpacked tmp/VETTE__1.02_and_extras.sit
python3 tools/ndif2raw.py "tmp/unpacked/VETTE! 1.02 Folder-1/VETTE!.img" tmp/VETTE_1_02.raw
python3 tools/hfs_extract.py tmp/VETTE_1_02.raw list
python3 tools/hfs_extract.py tmp/VETTE_1_02.raw segments \
        "VETTE!/VETTE! Folder/(Folder) B&W VETTE!/VETTE!" tmp/seg_bw
```

### Resource forks on the Amiga

The executable embeds no game data and uses no custom bundle. At process
startup it reads two ordinary files beside itself: `Color VETTE!` and
`VETTE!.Data`. Each file is the unmodified raw resource fork extracted from the
corresponding original Macintosh file. `src/mac/ResourceForks.*` validates and
indexes the native maps; the eleven byte-packed CODE payloads are copied to
aligned resident allocations before patching and execution. Development launch
scripts stage the local extracts with `amiga/stage_original_data.sh`.

**1. StuffIt 5 → `unar`, and there is no second option.** `7z`/p7zip handles no SIT at all; the
`macutils` `macunpack` lineage stops at StuffIt 1.5.1; Aladdin's own StuffIt Expander was 32-bit and
cannot run on a 64-bit-only macOS. `unar` (the XADMaster engine behind The Unarchiver) is the only
maintained SIT5 implementation, and it also **preserves the resource fork**, which layer 2 needs.
⭐ It verifies StuffIt's per-file CRC16 and prints `OK` per entry — so its `OK` is a real check, not
a "no exception was thrown". Trust it, and note the archive *declares* each entry's size, which is
how a suspicious-looking size can be cleared without a second extractor.

**2. `VETTE!.img` is NDIF (Disk Copy 6.x), and nothing on the host reads it.** `hdiutil imageinfo`,
`convert` and `attach` all answer `image not recognised` — Apple dropped NDIF. `unar` does not parse
it either (`Couldn't recognize the archive format`). `dmg2img` and `libdmg-hfsplus` are UDIF-only.
Hence `tools/ndif2raw.py`.

⚠⚠ **The block map is in the image's RESOURCE FORK, as `bcem` 128.** A copy that lost its fork
cannot be converted, and the loss looks like nothing: the data fork's first 7 sectors are stored
**raw**, so `file` still says `Macintosh HFS data ... volume name: VETTE!` and the MDB parses
perfectly — while everything after it is undecodable compressed chunks. **The convincing part is
the part that survives.** (This cost a detour here: the MDB's own geometry said 8 241 152 bytes
against a 1 867 894-byte file, which reads exactly like a truncated extraction.)

`bcem` layout, `[DERIVED]` by inspection and confirmed by the result:

| off | field |
|---|---|
| 0 | version (`0x000B` here) |
| 4 | volume name, `Str63` |
| 68 | total sectors (uint32; ×512 = image size) |
| 80 | checksum — see the warning below |
| 124 | chunk count (uint32) |
| 128 | chunk entries, 12 bytes each |

Each entry is `uint32 (startSector << 8) | type`, `uint32 offsetInDataFork`, `uint32 length`.
Types seen: **`0x02` stored raw**, **`0x83` ADC** (Apple Data Compression — byte-oriented LZSS,
three opcodes; ~15 lines). Entries with `length == 0` are free-space/terminator entries and are
skipped; sectors no chunk covers are zero filled. An **unknown type aborts loudly** rather than
leaving a hole, per CLAUDE.md.

⚠ **Do not gate anything on the `bcem` checksum.** `vers` labels it `CRC: $0580C874`; the Disk Copy
add-then-rotate-right over big-endian words, its byte / 32-bit / little-endian variants, and CRC-32
all disagree. The algorithm is unidentified, so **a mismatch is not a corruption signal.** Note also
that a whole zero sector is a *no-op* for the add-then-ROR family (256 rotations is the identity on
32 bits), so that family could not distinguish our zero fill from the original free space anyway.

⭐ **Validate structurally instead** — it is the stronger proof and `hfs_extract.py` does it as a
side effect. Here five independent structures agreed: the MDB, both B-trees (the extents header node
decoded with `nodeSize=512, maxKeyLen=7`), the catalog's 4 directories and 12 files, every file's
extents lying inside the image, and both applications' resource maps parsing with 68000 prologues
(`4E56 0000` = `LINK A6,#0`) and readable segment names. Wrong decompression cannot produce that.
Independently, the covered sector count agreed with the volume's own `drFreeBks`.

**3. HFS-standard volumes cannot be mounted on macOS** (support was removed in 10.15), so
`tools/hfs_extract.py` reads the MDB, the catalog and extents B-trees, and the extents-overflow tree
directly. It **fails loudly on a short fork** rather than returning one, because a truncated
resource fork still parses as a merely-odd resource map.

## ⚠⚠ Ghidra has NO classic-Mac resource-fork loader — verified, not assumed

Checked against this install (12.1): the processor list has `68000`, and the file-format module has
an HFS**+** filesystem (for iOS) and nothing for a classic resource fork, MacBinary, AppleSingle or
HFS. So there is no "import the application and get its segments" path.

⇒ **Extract the `CODE` resources ourselves and import each as a raw binary** with processor
`68000:BE:32:default`, exactly the pattern both prior ports used (`xex_load.py`, `ssd_load.py`).
That is `tools/hfs_extract.py segments`'s job. The upside is that the extraction is ours and scriptable; the
cost is that **segment relocation and the jump table are our problem** — see below.

## ⭐ What makes a Mac application different from the prior two binaries

Read this before the first Ghidra import; three of the four items change what "an address" means.

1. **The code lives in the RESOURCE fork, in numbered `CODE` resources** — one per segment, not one
   flat image. `CODE 0` is special: it is the **jump table** plus the segment-loader header (above-A5
   size, below-A5 size, jump-table size and offset). Every inter-segment call goes through a
   jump-table entry, so **`CODE 0` is the dispatch table the postmortem's §1.1 sweep is about**, and
   it is enumerable statically rather than having to be discovered.
2. **There are no fixed addresses.** The Segment Loader `AllocMem`s each segment at load time and
   the jump table is patched as segments are loaded and unloaded. So an address is
   `(segment, offset)`, and a single flat "memory image" — the thing both prior ports disassembled —
   **does not exist**. ⚠ Every address in `symbols.csv` and the docs must say which segment it is in,
   and `ApplyNames.java` carries a warning to that effect.
3. **Globals are A5-relative, not absolute.** `-nnnn(a5)` is the application's own global; low memory
   (`$0000-$0BFF`) is the system's. Both prior ports could name a memory cell by its address; here a
   global is an A5 offset and its meaning has to be recovered from the code that uses it.
4. **Every OS/Toolbox call is an A-line trap** — a `$Axxx` opcode, which is an illegal instruction the
   Mac's trap dispatcher services. That is the abstraction boundary, and it is the direct analogue of
   RoF's hardware-access map and Revs's MOS inventory. ⚠ Ghidra's 68000 disassembler has no reason to
   know what `$Axxx` means, so expect it to break the flow there; marking the sites and naming them
   is `ghidra_scripts/DumpTraps.java`'s job, and it needs the trap-number → name table.

⭐ **Item 4 is the project.** RoF replaced the Atari OS wholesale; Revs serviced 4 MOS entries at 17
sites. A Mac game's trap set spans QuickDraw, the Event Manager, the Memory Manager, the Resource
Manager, the Segment Loader and the Sound Manager. **Inventory it from the binary before estimating
anything**, and treat the inventory as a FLOOR — Revs found three MOS calls by running it.

## Disassembly (headless Ghidra)

⚠ **`analyzeHeadless` needs `JAVA_HOME` set** or it dies with "Unable to locate a Java Runtime" and,
headless, "no TTY detected" rather than prompting.

The invocation, once `disasm/code/` exists (mirrors the two prior ports'):

```sh
GH="tools/ghidra/ghidra_12.1_PUBLIC"
ABS="$(pwd)"
"$GH/support/analyzeHeadless" tools/ghidra-proj Vette \
  -import disasm/code/CODE_0001.bin \
  -processor "68000:BE:32:default" \
  -loader BinaryLoader \
  -scriptPath ghidra_scripts \
  -preScript  MarkEntries.java \
  -postScript ExportListing.java "$ABS/disasm/listing.txt"
```

Re-seed entry points and re-export — the loop to run after adding a row to
`ghidra_scripts/entrypoints.csv`. **`MarkEntries` must be a `-preScript`** so a new entry is
disassembled by the analysis that follows it; with `-noanalysis` the seed is recorded and nothing
decodes:

```sh
"$GH/support/analyzeHeadless" tools/ghidra-proj Vette -process CODE_0001.bin \
  -scriptPath ghidra_scripts \
  -preScript  MarkEntries.java \
  -postScript ExportListing.java "$ABS/disasm/listing.txt"
```

Export only, no re-analysis: add `-noanalysis` and drop the `-preScript`.

⚠ **Do not open the project in the Ghidra GUI and headless at the same time** — Ghidra locks
projects.

### The iteration loop

1. Export current state → `disasm/listing.txt` (+ trap / xref dumps).
2. Read the text; work out what routines and globals do.
3. Append findings to `disasm/symbols.csv`
   (`space,segment,offset,name,type,evidence,note`).
4. Run `ApplyNames` → names/comments persist into `tools/ghidra-proj`.
5. Re-export and continue, subsystem by subsystem.

`tools/ghidra-proj/` is the durable annotation database; the repo holds the text exports,
`symbols.csv`, and the port's own code.

### ⭐ Before the FIRST export is trusted
Do the **entry-point sweep**: every `CODE 0` jump-table entry, every trap site, every stored
procedure pointer (a `WindowPtr`'s `defProc`, a control's `CDEF`, a filter proc, a completion
routine). Postmortem §1.1 — it is the single highest-leverage item carried over from both prior
ports, and a Mac binary's indirection makes it more important, not less.

### Then: one concentrated naming pass
Postmortem §1.2. **On a reverse-engineering project the function names are your map**, and every
wrong name taxes every later reasoning step. Give rough-but-directionally-correct names in one
focused pass before deep work — not as a trickle. `symbols.csv` makes a later batch rename cheap, so
the cost of being roughly right early is near zero.

## Ghidra scripts (`ghidra_scripts/`)

Copied from the *Revs* port; each needs a Vette pass.

| Script | Status | Purpose |
|---|---|---|
| `MarkEntries.java` | 509 `CODE 0` exports present | select rows for the current segment, promote heuristic functions to trusted USER_DEFINED roots, then disassemble |
| `ExportListing.java` | reusable as-is | dump `listing.txt` |
| `ApplyNames.java` | reusable; ⚠ addresses are segment-relative | apply `symbols.csv` to the project |
| `DumpCallGraph.java` | reusable | call graph |
| `DumpTraps.java` | implemented; Intro callbacks proved and followed | flow-following A-line trap map; the direct replacement for Revs's BBC-specific `DumpHwAccesses.java` |

### The trap map IS the abstraction boundary
Its output tells you exactly what `src/mac/` must implement. Generate it early.

`DumpTraps.java` does **not** scan every aligned `$Axxx`-looking word: CODE resources contain inline
data, so that would manufacture traps. It starts at the segment entry and the USER_DEFINED
functions installed by `MarkEntries.java`, follows Ghidra's real fall-through/branch edges, treats
an A-line word as a returning two-byte boundary, and resumes after it. The CSV records segment,
offset, emitted word, flag-stripped base, OS/Toolbox class, published routine name, flag bits and
containing function. Names come from the same generated `tmp/trap_names.lua` used by the live MAME
probe; missing names remain explicit `?OS_xx` / `?TB_xxx` values.

Stored procedure roots are admitted only with store evidence. The currently proved compiler pattern
is `LEA d16(PC),An` immediately followed by `MOVE.L An,(Am)+`: a local code address is taken and
written into a table. Arbitrary PC-relative `LEA`s are not followed because they normally address
rectangles and other inline data.

```sh
python3 tools/gen_trap_names.py     # once; generated table is local and uncommitted
"$GH/support/analyzeHeadless" tools/ghidra-proj Vette -process CODE_08_Intro.bin \
  -scriptPath ghidra_scripts \
  -preScript MarkEntries.java \
  -postScript DumpTraps.java "$ABS/disasm/CODE_08_traps.csv" "$ABS/tmp/trap_names.lua"
```

⭐ **Measured script control:** on the Color Intro resource, seeding only its resource entry at
offset 4 recovers 25 trap sites. That includes the live log's first sequence at `+003E`, `+0048`,
`+0070`, `+007C`, and `+00FE`. An earlier implementation that trusted every Ghidra ANALYSIS
function found 139 sites yet missed required roots—a larger number was less complete.

### The `CODE 0` export roots

`ghidra_scripts/entrypoints.csv` is generated from the Color build's intact unloaded table, not
transcribed. Its 509 rows describe 508 distinct `(segment,address)` roots: Initialize deliberately
exports the same routine twice. Addresses include the target resource's four-byte near-model header;
the original routine offset remains in the note. Reproduce or verify it with:

```sh
python3 tools/code0_entrypoints.py tmp/seg_color/CODE_00.bin \
  --check ghidra_scripts/entrypoints.csv
```

The verified per-segment counts are Main 130, Initialize 16, Communication 16, load 1, Score 9,
Traffic 80, FRED 242, Intro 2, sound 12 and `%A5Init` 1. `MarkEntries.java` reads the segment number
from each Ghidra program's `CODE_NN...` name and ignores the other rows. If auto-analysis already
created a function at a root, the script promotes and names it USER_DEFINED; leaving it ANALYSIS
would make `DumpTraps` correctly refuse to trust it.

The first two-export Intro run stopped at an unresolved `JSR d(A5)` and found only 68 sites. That
was not a missing callback root: disassembly shows `Button` at `Intro+$0224` in the first export,
after `JSR 1946(A5)`. Two Ghidra details hid it: the unresolved call supplied no fall-through, and
Data Reference Analysis had defined the Macintosh low-memory target `$016A` on top of code at the
same raw segment offset. `DumpTraps` now resumes after unresolved calls and lets a trusted flow edge
replace analyzer-created data. That recovered 75 sites including `+$0224`.

The apparent remaining “28” was itself wrong: only 40 of those 75 sites overlapped the 103-site
full-intro trace. The 63 live omissions lay in four local routines. The exported routine proves
their roots at `+$01EE..+$0204`: it stores `+$02D0`, `+$041E`, `+$0540` and `+$097C` into a
four-entry table and invokes entries with `JSR (A4)` at `+$0276`. Following that evidenced stored
callback pattern produces **146 static Intro sites**. It contains **all 103 full-intro live sites**,
with zero offset or trap-word mismatches; the other 43 sites are valid alternate/setup paths not
exercised by that run.

### All-segment static/live gate — complete

Generate `tmp/CODE_01_traps.csv` through `tmp/CODE_10_traps.csv` by importing each extracted
segment as raw `68000:BE:32:default`, then running `MarkEntries.java` followed by `DumpTraps.java`.
After a `VETTE_FULL_INTRO=1` MAME trace, the checked result is:

| segment | static sites | live sites | missing | word mismatch |
|---|---:|---:|---:|---:|
| Main | 537 | 33 | 0 | 0 |
| Initialize | 290 | 40 | 0 | 0 |
| Communication | 184 | 0 | 0 | 0 |
| load | 118 | 46 | 0 | 0 |
| Score | 113 | 0 | 0 | 0 |
| Traffic | 40 | 3 | 0 | 0 |
| FRED | 0 | 0 | 0 | 0 |
| Intro | 146 | 103 | 0 | 0 |
| sound | 1 | 1 | 0 | 0 |
| `%A5Init` | 1 | 1 | 0 | 0 |

That is **1,430 static sites** and **227 distinct live sites**, with every live `(segment,offset)`
present and every emitted word identical. `Communication` and `Score` were not resident/exercised
in this trace, so their maps are static coverage rather than dynamic proof. FRED's zero traps are
consistent with the independent evidence that it is a small leaf-routine library.

Re-run the exact comparison with:

```sh
python3 tools/check_trap_map.py ref/mame/traps.txt --static-dir tmp
```

## The builds

```
make                     # build/vette (host) — scope TBD, see PROJECT.md
```

```
cd amiga && . ./env.sh
make                     # out/Vette.exe (+ Vette.elf for debug, and a muldiv audit on every link)
make clean               # ⚠ mandatory before a PROBES build / after a header edit
./run.sh                 # boot in FS-UAE (CTRL + left mouse quits)
./debug.sh               # source-level debug via the FS-UAE gdb stub
./diag_run.sh [secs]     # headless probe run (needs PROBES=1)
```

Details and traps: `docs/headless-fsuae.md`. The scripts and A1200 configuration are verified in
this repo; the standing beam and pixel-integrity runs are recorded in `docs/amiga-lessons.md`.
