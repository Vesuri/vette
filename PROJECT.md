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
| **Amiga screen mode** | ⭐⭐ **4 bitplanes, hires INTERLACED** (user decision). 16 colours at 512 px wide with 342 lines available. ⚠ Free of bitplane-DMA penalty only on **AGA**; an OCS/68000 fallback is open decision #2 |
| **Copy protection** | ⭐ **Patched out, not reproduced.** The one deliberate, named departure from 1:1 — see `docs/faithfulness-seam.md` §The copy protection |

## Open decisions

These are genuinely open and are the right things to settle before building. They are ordered by
how much else depends on them.

1. ⭐⭐ **The OCS / 68000 fallback mode, if there is one.** The primary mode is locked (4bpp hires
   laced). ⭐ It is *reachable* on a 68000 — `[MEASURED]`, the game contains **zero 68020-only
   instructions** in either build (`docs/mac-hardware.md`) — but hires 4bpp bitplane DMA starves a
   68000 for most of the display window, so OCS needs a different mode or no support at all. The
   candidates, and none is free:
   - **lores + overscan, cropped.** ⚠ Lores overscan tops out around **368 px** against the game's
     512, so this is a ~28% width crop plus a vertical one, and it removes the player's periphery.
   - **lores + a 2:1 horizontal squeeze** folded into the chunky→planar merge. Nearly free there,
     but it is a resample and has to be judged against the reference loop.
   - **no OCS support.** Honest, and the one to pick if the frame rate is unusable anyway.
   ⚠ **Do not settle this before the in-game surface size is measured** (#2) — a 512 × 342 driving
   view makes every crop worse than the garage screen's 512 × 320 suggests.
2. ⚠⚠ **Is the in-game surface 512 × 320 or 512 × 342?** The garage screen paints **512 × 320**
   `[MEASURED]`, but a **512 × 342** window — the compact-Mac screen size — already exists behind it
   and the driving view is the likely occupant. One reference-loop probe of the front `portRect`
   past the garage screen settles it, and #1 depends on the answer.
   ⭐⭐ **The depth question is CLOSED and no longer an assumption:** `[MEASURED]` 4 bpp, chunky,
   `pixelType` 0, two palette indices per byte, **high nibble = left pixel**, 16-entry CLUT.
   ⚠ And the CLUT is not what the player saw — a **gamma table** sits between it and the DAC, so the
   Amiga palette is derived from the *displayed* colour. → `docs/mac-hardware.md` §The display surface.
3. **Machine target.** RoF needed 1 MB and did not fit a bare 512 KB A500. Unknown here and not
   guessable: it depends on whether the original segments stay resident and on how the display is
   arranged. **Decide when the first real measurement exists, not before.**
4. **Performance target.** Deliberately not set. → `docs/perf-method.md` §The target. ⭐ Unlike both
   prior ports there is a real reference: the Mac Plus's 7.83 MHz 68000 is within 12% of the A500's
   7.09 MHz, so the original's own framerate under the reference loop is a meaningful yardstick.
   Set the target from that plus a Phase 4 profile.
5. **Host build: does it exist, and what for?** RoF had an SDL backend and its approximation cost
   real time; Revs deliberately had **no renderer** and used the host only for differentials.
   ⚠ This port's differentials are different again (there is no transliteration oracle), so the
   question is open rather than answered by either precedent.

⚠ **Trust the titles above, not the numbers** — this list has been renumbered twice as decisions
locked, and other docs quote it by number.

## The source material

`tmp/VETTE__1.02_and_extras.sit` — the 1.02 release plus extras, 10.3 MB, **StuffIt 5**
(`StuffIt (c)1997-2002 Aladdin Systems`). Opened with `unar`; three nested layers, see
`docs/toolchain.md` §From the archive to the segments.

Inside: an **8049 KiB HFS volume** as an NDIF image, plus the extras — `scans/Manual.pdf` (5.2 MB),
`Map.jpg`, `MapInfo_1/2.jpg`, `KeyChart.jpg`, `Package.pdf`, and `web_docs/cheats.txt`. ⭐ Worth
reading *before* the binary; RoF's `docs/manual.md` earned its place. ⚠ `readme.txt` says the build
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
    host/               a host backend, if there is one (open decision #6)
    amiga/              PlatformAmiga + the scene + the vendored dA JoRMaS framework
amiga/                  Amiga build infrastructure: Makefile, env.sh, run.sh, debug.sh, *.gdb
```

## Status

- [ ] **Phase 0 — Scaffolding.** The Amiga build, display takeover, VERTB handler, copper list and
      frame pump are proven on the target, and every link runs the multiplication/division and probe
      audits. The phase remains open because the port-specific platform abstraction and several
      prescribed standing counters/debugger probes do not yet exist. → `docs/open-work.md`.
- [x] **Phase 1 — The Macintosh reference loop.** ⭐ It **drives**: MAME boots the reference volume
      and launches `Color VETTE!` unattended, completion read from the Mac's own low memory, and the
      game runs to its garage screen. Framebuffer + CLUT capture and host-side re-render are proven
      against MAME's own screenshots. ⭐⭐ **The A-trap log is done** → `docs/trap-log.md`: **51
      traps** called by the game's own `CODE` segments, first-use ordered, every caller resolved to
      `(segment, offset)` live at the moment of the call, segment bases pinned by matching each
      extracted resource's own bytes in memory *and* by requiring its resident jump-table exports to
      fall inside the pinned span. Arguments are read at the call site, so `SetTrapAddress`'s target,
      `%A5Init`'s trap set and the `QDExtensions` selectors are measured too. ⚠ It is a **FLOOR**:
      the window ends at the menu, so `FRED` and `Communication` never ran.
- [ ] **Phase 2 — Complete static map.** All 11 `CODE` resources are resident, the 509-entry jump
      table and A5 world run in place, and the low-memory access audit protects the unmapped first
      32 KiB. The exhaustive static map, entry-point CSV, naming pass and coverage accounting remain.
- [ ] **Phase 3 — The trap layer.** The Line-A bridge is live and unknown calls stop loudly with
      manager, routine, selector and caller. It now implements the path through the complete intro,
      garage, vehicle/course selection and sustained driving; the inventory is still a floor and
      later paths remain deliberately unimplemented.
- [ ] **Phase 4 — End-to-end skeleton on the target.** The original resident code reaches and
      repeatedly completes real moving driving frames on the A1200 acceptance configuration. A
      complete phase-share profile and the evidence-based performance target remain open.
- [ ] **Phase 5 — Render + input.** Game-produced 4-bit chunky surfaces are presented through the
      512×384, four-bitplane hires-interlaced display, with dirty conversion and physical keyboard
      state/event translation. Full control mapping, the driving reference differential and the
      remaining surface-height measurement are open.
- [ ] Phase 6 — Optimisation
- [ ] Phase 7 — Packaging

See `docs/phases.md` for exit criteria and the gating between phases.

## Immediate next step

### ⭐⭐ Drive a deliberate state transition and discover the next compatibility boundary

The complete game-owned intro passes its 163,840-pixel differential, the scripted garage path
enters driving, and a sustained A1200 run presents 143 complete moving frames over 6,422 Macintosh
ticks without a loud stop. More straight-line accelerator soaking is therefore closed as a
discovery method.

The shipped key chart labels Escape “Menu Options.” Correcting a byte-local KeyMap bit-order bug
makes physical Escape take that original transition at tick 1,864 after 32 complete frames. The
path exits driving, reaches implemented depth 94 and encounters no new loud stop. The next step is
confirmed with a diagnostic-only physical down/up pair through the ordinary edge queue: the settled
state remains supported and trap-free. F1 “Helicopter View Left” is also measured: a frame-matched
capture changes 53,940 of 81,920 packed bytes while driving remains trap-free at depth 93.
F5 “Front Dash” changes 31,214 packed bytes and remains trap-free through 70/70 frames. P reaches
the original pause/options transition and settles trap-free at depth 94; updating Page-0 KeyMap
on CIA keyboard edges makes its no-Toolbox wait observe physical key transitions. Continue the
documented control matrix with sound and transmission state, one bounded transition at a time,
until the next compatibility boundary. → `docs/open-work.md` §Blocking.

⭐⭐ **Stage A is done and measured: the Amiga display path works.** The port takes the machine
over, brings up 512×320 in 4 bitplanes hires interlaced and displays Target 1's captured Macintosh
frame out of chip RAM; the chip-RAM checksum matches the host-computed one byte for byte, the
long/short field ratio is 0.500, and the window on the glass measures **exactly 512×320**,
undistorted and centred in the standard PAL display window. ⛔ **That milestone was a display-path
proof and nothing more** — no Macintosh code ran in Stage A itself. `tools/mac_fb_to_amiga.py` is the pixel differential every later stage is
judged by, and it prices each transformation separately: chunky→planar is asserted **lossless**,
the CLUT→DAC gamma of 1.435 is re-measured against MAME on every run (worst channel 1/255), and
the OCS 4-bit quantisation floor is **8/255 worst channel, 1.52/255 mean**. ⚠ A finished Target 1
must differ from the Macintosh by *exactly* that and no more — **a smaller difference means the
palette that ran is not the one derived here.**

⭐ Every gate that stood in front of it is gone — the trap log is measured, arguments included
(`docs/trap-log.md`):

- **36 of the 51 traps** stand between launch and a painted intro screen. The art is up at frame
  1758; the last new traps before it are `CopyBits` and `EraseRect` at 1698–1699.
  ⚠⚠ **This is double the "18" previously recorded here**, and the 18 were blind rather than wrong:
  the earlier tracer cleared its accumulators when the app became frontmost, discarding the game's
  own first 230 frames — `%A5Init`, QuickDraw/Font/Window/Menu init, the `QUAD` + 160 `OBJS` loads,
  the GWorld creation. Nothing left the list; 18 more joined the front of it.
- **Rows 37–38 are the animation + wait-for-click loop and rows 39–51 are the garage screen** — both
  explicitly out of scope, listed as deferred in the queue so they are not implemented "while we are
  here".
- **`GetNextEvent` is not on the intro path at all.** The intro polls `Button` from `Intro+0224`, so
  Target 1 needs **no Event Manager** — nor Menu Manager, nor the `GDevice`/`Palette` calls.
- **`DrawPicture` is 16 calls and `GetPicture` 47**, so Stage D's PICT interpreter is sized and small.
  The first call draws 512×323 at (0,0); the other 15 are two small overlay rects.
- ⭐ **The trap the game patches is `_ExitToShell`, and it is the only one.** `SetTrapAddress` at
  `load+00B8`, frame 1617, handler `$786A96`. Option A means the port installs that patch too — but
  ⛔ no general trap-patching machinery is needed.
- ⭐ **`%A5Init` costs one trap:** `_BlockMove`, ×46. Stage B's prerequisite is that alone.
- ⭐ **`QDExtensions` dispatches on `D0`, not on a stack selector**, and Target 1 needs two:
  `NewGWorld` (0) and `LockPixels` (1), with `flags=$40000000` and `pixelDepth=0`.
- **`Traffic` calls `GetPicture`** (`Traffic+663C`) and is resident during the intro, so that
  segment is not purely the driving rasteriser.

⚠ Resist implementing traps by reading Inside Macintosh's index. The postmortem's one-sentence
lesson is *build the discovery and validation infrastructure exhaustively up front instead of
growing it reactively*, and "guess which QuickDraw calls the intro needs" is the reactive version.
