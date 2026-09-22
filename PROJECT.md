# Vette! — Macintosh 68000 → Amiga port

Port Spectrum HoloByte's Macintosh driving simulation *Vette!* (v1.02, © 1991 Sphere, Inc.) to the Amiga by
reverse-engineering the Mac application, keeping its 68000 code where that is the right answer,
abstracting every OS/Toolbox call behind a platform layer, and implementing that layer for the
Amiga.

*Vette!* — a free-roaming 3D San Francisco with real Corvette dynamics — **never received an Amiga
port**, so this is genuine preservation rather than a re-release.

## ⭐ Why this project exists, and what it is a pilot for

This is the **third** port on the same pipeline, and the **first of a new kind**. *Attack of the
PETSCII Robots* (C64), *Rescue on Fractalus!* (Atari 8-bit) and *Revs* (BBC Micro) all converted
**6502** machine code to C and then to 68000 — a translation across processor families, with a
transpiler, a 6502 CPU model, a `mem[]` memory bus and a byte-exact differential against a
transliteration.

**None of that is needed here.** The Mac is a 68000 machine and so is the Amiga: the instructions
can stay instructions. What has to change is the *seams* — the OS calls, the display, the input, the
sound — and the port is that work rather than a translation.

So this is a **pilot for a series of Mac 68k → Amiga ports**, and the pilot's real deliverable is an
answer to: *how much cheaper is a same-processor port, and where does "keep the original code" stop
working?* `docs/faithfulness-seam.md` is where that answer gets written down.

⚠ **The cost is not zero and it is not where the 6502 ports' cost was.** A Mac application reaches a
*large* operating system — QuickDraw, the Event Manager, the Memory Manager, the Resource Manager,
the Segment Loader, the Sound Manager — through the A-line trap table. RoF replaced the Atari OS
wholesale; Revs serviced a closed MOS surface of 4 entries at 17 sites. **Here the OS layer is the
centre of gravity**, and it is the thing to size before anything else.

## Decisions (locked)

| Question | Decision |
|---|---|
| Disassembly/analysis workflow | **Claude drives Ghidra headless**; user reviews text artifacts in-repo |
| Fidelity | **Faithful 1:1 port** — replicate behaviour exactly, parity before any improvement |
| Ground truth | **The original under a Macintosh emulator.** NEVER the dev-host backend, never the Amiga build. The emulator is decided (below) — `docs/mac-reference-loop.md` |
| Repo | Commit directly to `main`, one logical change per commit |
| Source material | Kept **local only, never committed** — `tmp/` is local by policy, and `.gitignore` covers every shape a Mac application arrives in |
| **Port strategy** | ⭐⭐ **Option A: keep the original 68000 instructions, port the seams.** The segments are near-model, so there is nothing to relocate; the cost lands entirely in the trap layer. `docs/faithfulness-seam.md` §The rule |
| **The build** | ⭐ **`Color VETTE!`.** Not the B&W one. See below — 16 colours maps onto 4 Amiga bitplanes, so the colour build is not the expensive choice it would be at 8bpp |
| **Reference emulator** | ⭐ **MAME 0.289, driver `mac2fdhd`** (Mac II FDHD, `-nb9 mdc48`, `-ramsize 8M`). Chosen on the capability list, not reputation — it has watchpoints, a Lua API *and* an m68k gdb stub. `docs/mac-reference-loop.md` |
| **Amiga screen mode** | ⭐⭐ **4 bitplanes, hires INTERLACED** (user decision). 16 colours at 512 px wide; the 512×320 Mac image is centred in a 512×384 display whose data fetch is exactly 512 px wide |
| **Amiga machine** | ⭐⭐ **A1200, 2 MiB chip + 8 MiB fast** (user decision). No separate OCS display mode; the code remains 68000-compatible where practical, but OCS is not a supported package target |
| **Copy protection** | ⭐ **Patched out, not reproduced.** The one deliberate, named departure from 1:1 — see `docs/faithfulness-seam.md` §The copy protection |

## Closed implementation decisions

- **Performance target.** The moving-driving fidelity workload must stay within a median of 12
  Macintosh ticks, a 95th-percentile interval of 15 ticks, and twice the captured Macintosh median.
  The current production path passes. C2P remains the measured dominant cost and further work is
  optional rather than a release gate. → `docs/perf-method.md` §The target.
- **No host game build.** Host tools install and inspect original data and perform differentials;
  the game itself runs on the Amiga target. A second renderer would add a new approximation without
  supplying an independent gameplay oracle.

### Closed: no separate OCS display fallback

The earlier crop/squeeze/no-support choice was based on a false premise: the exact display is
already expressible by OCS. Its legacy high-bit rules turn `DIWSTRT=$4CA1`, `DIWSTOP=$0CA1` into
the same `(161,76)`–`(417,268)` field window that ECS/AGA receives through `DIWHIGH=$2100`.
`DDFSTRT=$4C` / `DDFSTOP=$C4` fetch exactly 32 words, hence exactly 512 hires pixels—no hidden
overscan DMA. Cropping or squeezing would therefore trade away fidelity without buying
compatibility.

The package target is nevertheless the user-selected A1200 with 2 MiB chip and 8 MiB fast. The
two 512×384×4 planar buffers alone occupy 196,608 bytes of chip RAM. The production executable is
about 97 KiB because original resources are disk-loaded, but the runtime still needs the two
resource forks totalling about 2.1 MiB, aligned resident CODE copies, Macintosh state, and
display/audio allocations. Four hires bitplanes
also consume every bitplane fetch slot inside the active 512-pixel DDF interval; an A1200 can
execute the game and trap layer from fast RAM while those fetches proceed. There is consequently
**no lower-quality OCS mode and no OCS support promise**. The build deliberately retains `-m68000`
code generation and OCS-correct display arithmetic because neither costs the A1200 target and both
keep future expanded-machine experiments honest.

⚠ **Trust the titles above, not the numbers** — this list has been renumbered twice as decisions
locked, and other docs quote it by number.

## The source material

`tmp/VETTE__1.02_and_extras.sit` — the 1.02 release plus extras, 10.3 MB, **StuffIt 5**
(`StuffIt (c)1997-2002 Aladdin Systems`). Opened with `unar`; three nested layers, see
`docs/toolchain.md` §From the archive to the segments.

Inside: an **8049 KiB HFS volume** as an NDIF image, plus the extras — `scans/Manual.pdf` (5.2 MB),
`Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`, `Package.pdf`, and `web_docs/cheats.txt`. ⭐ Read and
distilled into `docs/manual.md`; it supplies the game's state/input vocabulary and proves that
`Communication` is the optional head-to-head subsystem. The Amiga port is single-player only and
will not implement direct serial, modem, AppleTalk, multiplayer chat, or remote-car synchronization;
the segment remains resident solely because the complete original CODE image is resident. ⚠
`readme.txt` says the build
asks for a copy-protection password **once, on first run**, and the answers are in the first pages of
`Manual.pdf` — so a reference-loop image must be set up past that, and a fresh one will stop there.
⚠ That constraint is about **ground truth**, and the protection decision does not retire it: the
*port* patches the check out, the *reference* keeps it.

On the volume, `VETTE! Folder/` holds **two separate builds**:

| | code | data | notes |
|---|---|---|---|
| `(Folder) B&W VETTE!/VETTE!` | `APPL`/`VETT`, 523 089 B rsrc, **11 `CODE`, 124 554 B** | `VETTE!.Data` `DATA`/`VETT`, 577 498 B | plus `Start VETTE!` (`APPL`/`SVET`, 3 393 B) |
| ⭐ `(Folder) Color VETTE!/Color VETTE!` — **the one this port follows** | `APPL`/`VETT`, 1 587 389 B rsrc, **11 `CODE`, 118 892 B** | its own 577 498 B `VETTE!.Data` | adds `pltt` ×8, `wctb`, 8 `WIND` |

⭐ **Same 11 named segments in both** — `Main`, `Initialize`, `Communication`, `load`, `Score`,
`Traffic`, `FRED`, `Intro`, `sound`, `%A5Init`, over `CODE 0`'s jump table — and the *code* is
roughly the same size. Almost all of the Color build's extra megabyte is `PICT` (192 resources in
both, colour versus 1-bit). So the two differ mainly in artwork and the colour Toolbox calls, and
**net of `CODE 0` (4 072 B, the jump table) and `%A5Init` (28 664 B, the MPW globals initialiser)
the B&W game is ~91.8 KB of 68000 code** (Color ~86.1 KB by the same subtraction). That is the
actual size of the thing being ported.

⭐⭐ **Both `VETTE!.Data` forks hold the same 231 resources, all byte-for-byte identical** (checked
pairwise; the forks' own hashes differ only in resource-map layout). The game data is
build-independent. And the data is **self-describing** — 23 four-character types with named
resources: `Sine Table 360`, `Bogas Driver v2.1`, 160 named 3D objects, the eight cars, the courses,
`Protect`. ⇒ **`docs/source-inventory.md`**, which is where all of that lives and which corrects a
documented assumption about audio.

⚠ Everything in that inventory is `[INFERRED]` from types, names and sizes; nothing has been
disassembled or run, and which Mac 1.02 requires is still unknown.

⚠ **Kept local, never committed**, and the `.gitignore` is deliberately broad about it: a Mac
application arrives as a `.sit`, then a MacBinary/BinHex file, then a data fork plus a resource fork,
and on a non-HFS filesystem that resource fork is an **AppleDouble `._Vette` sidecar** — which looks
like macOS noise and *is the executable code*. That is the accident the ignore rules exist to
prevent.

## Approach / pipeline

```
VETTE__1.02_and_extras.sit
  └─ unar ──────────────────► VETTE!.img          (NDIF, block map in its RESOURCE FORK)
        └─ tools/ndif2raw.py  ──► VETTE_1_02.raw  (8049 KiB raw HFS; ADC-decompressed)
              └─ tools/hfs_extract.py             (list / extract / resources / segments)
        └─ tools/hfs_extract.py segments ──► CODE_NN_<name>.bin + the CODE 0 jump table
              └─ Ghidra headless (68000:BE:32) ──► disasm/listing.txt, the TRAP map, the A5 map
                    └─ disasm/symbols.csv  ◄── curated, grows over time
                          └─ src/mac/       the Toolbox/OS trap layer  ⭐ the centre of gravity
                          └─ src/platform/  the abstraction + the Amiga backend
```

⚠ **Three things about a Mac binary that change what "an address" means**, and they are why this
pipeline is not just the prior one with a different processor:

1. The code is in **numbered `CODE` resources**, one per segment — not one flat image. So the flat
   "memory image" both prior ports disassembled **does not exist**, and an address is
   `(segment, offset)`.
2. `CODE 0` is the **jump table**. Every inter-segment call goes through it, which makes the
   postmortem's highest-leverage item — the exhaustive dispatch sweep — *enumerable* instead of a
   search. Take that win.
3. Application globals are **A5-relative**, not absolute. A named cell in both prior ports had a
   fixed address; here it is an A5 offset whose meaning has to be recovered from its users.

Details and the verified Ghidra facts: `docs/toolchain.md`.

## What transfers from the prior ports, and what does not

**Transfers unchanged** — these are properties of the target and the toolchain, not of those games:
- The whole Amiga side: the vendored dA JoRMaS framework (`src/platform/amiga/framework/`, see its
  `UPSTREAM.md`), the display-takeover and VBI architecture (`docs/amiga-arch.md`), OCS hardware
  lessons (`docs/amiga-lessons.md`), 68000/GCC optimisation (`docs/m68k-optimisation.md`), the
  headless FS-UAE measurement loop (`docs/headless-fsuae.md`) and its scripts.
- How to work: `docs/method-lessons.md`, `docs/perf-method.md`'s rules, `docs/postmortem.md`'s
  checklist. Everything marked ⚑ is inherited; **don't soften an inherited rule without a
  measurement that contradicts it, and don't re-derive one from scratch either.**

**Does not transfer:**
- The transpiler, the 6502 CPU model, `mem[]`, the byte-exact `make validate` differential — there
  is no transliteration to validate. ⭐ This retires the postmortem's **#2** finding (transpiler
  output quality) entirely, and with it the single biggest front-end investment either prior port
  made.
- The little-endian-`mem[]`-on-a-big-endian-target hazard, which let `make validate` pass green
  while the Amiga rendered garbage. Mac and Amiga are both big-endian. ⭐ A whole defect class gone.
- Both prior ports' `platform.h`: each is shaped around a 6502 memory bus and an OS-call
  marshalling ABI this port does not have. Write this one from the trap map.
- `docs/perf-method.md`'s and `docs/static-map.md`'s **numbers**. Rule 3: every old number is wrong.

## Repository layout

```
tmp/                    LOCAL ONLY, never committed — the source archive, captures, scratch
CLAUDE.md               always-loaded working instructions
PROJECT.md              this file
docs/                   the reference docs (see CLAUDE.md's index)
tools/
  ghidra                symlink to the shared Ghidra install (git-ignored)
  ghidra-proj/          the Ghidra annotation database (git-ignored, per-repo, never shared)
ghidra_scripts/         headless Ghidra scripts + entrypoints.csv
disasm/                 generated listings + extracted segments (git-ignored)
                        except the curated symbols.csv
src/
  m68k_math.h           68000 16-bit mul/div helpers (the 68000 has no 32-bit mul/div)
  mac/                  the Toolbox/OS trap layer
  platform/             platform.h abstraction
    host/               host-side test/differential support; no host game renderer
    amiga/              PlatformAmiga + the scene + the vendored dA JoRMaS framework
amiga/                  Amiga build infrastructure: Makefile, env.sh, run.sh, debug.sh, *.gdb
```

## Status

- [x] **Phase 0 — Scaffolding.** The platform abstraction, Amiga build, display takeover, VERTB
      handler, copper list and
      frame pump are proven on the target, and every link runs the multiplication/division and probe
      audits. The beam-publication and complete chunky-to-planar standing checks now pass on the
      target A1200. Vette's bitmap API now makes its interleaved layout a construction invariant,
      and the inherited impossible-layout arms trap instead of silently succeeding.
- [x] **Phase 1 — The Macintosh reference loop.** ⭐ It **drives**: MAME boots the reference volume
      and launches `Color VETTE!` unattended, completion read from the Mac's own low memory, and the
      game runs through its front end into live driving. Framebuffer + CLUT capture and host-side
      re-render are proven against MAME's own screenshots. ⭐⭐ **The A-trap log is done** →
      `docs/trap-log.md`: **63
      traps** called by the game's own `CODE` segments, first-use ordered, every caller resolved to
      `(segment, offset)` live at the moment of the call, segment bases pinned by matching each
      extracted resource's own bytes in memory *and* by requiring its resident jump-table exports to
      fall inside the pinned span. Arguments are read at the call site, so `SetTrapAddress`'s target,
      `%A5Init`'s trap set and the `QDExtensions` selectors are measured too. ⚠ It is a **FLOOR**:
      only one bounded driving path ran, and `FRED` and `Communication` still never became resident.
- [x] **Phase 2 — Complete static map.** All 11 `CODE` resources, 509 entries, 1,430 static trap
      sites, 17 Page-0 locations, the A5 world, 68 curated symbols, and honest 94.8% byte
      classification are gated by `make static-map-check` → `docs/static-map.md`.
- [x] **Phase 3 — The trap layer.** The Line-A bridge services every reached required
      single-player call and unknown calls stop loudly with manager, routine, selector and caller.
      Optional desktop UI and communications remain explicit loud boundaries.
- [x] **Phase 4 — End-to-end skeleton on the target.** The original resident code reaches and
      repeatedly completes real moving driving frames on the A1200 acceptance configuration. The
      phase-share profile accounts for 100% of the measured window and the cadence target is set
      from matched Macintosh and A1200 captures.
- [x] **Phase 5 — Render + input.** Game-produced 4-bit chunky surfaces are presented through the
      512×384, four-bitplane hires-interlaced display. The named driving-frame differential is
      pixel exact, and keyboard, keypad aliases, mouse, menus, and driving controls are mapped.
- [x] **Phase 6 — Fidelity and performance.** Palette, PICT, driving raster, audio, dirty-list, C2P,
      timing, recovery, and shutdown paths are measured on target. Further C2P work is explicitly
      deferred because it no longer blocks fidelity or the accepted cadence ceiling.
- [x] **Phase 7 — Structural verification and release.** Production loads the two unchanged original
      resource forks from disk. The deterministic copyright-clean archive supplies the Amiga HUNK
      executable, installer, FS-UAE configuration, checksums, requirements, and no game data.

See `docs/phases.md` for exit criteria and the gating between phases.

## Current state

The scoped single-player port and structural/release phase are complete. `docs/open-work.md` has no
required queue item. `make release-check` is the final gate: it verifies the static map and gameplay
coverage, boots a production disk-loaded build, enters driving, builds twice byte-identically, and
audits the release ZIP for its exact manifest, checksums, HUNK executable, and absence of original
resource forks. Further work is optional and starts from the deferred measurements in
`docs/open-work.md`, not from an unfinished compatibility milestone.
