# Vette! — Macintosh 68000 → Amiga port

Port Spectrum HoloByte's 1989 Macintosh driving simulation *Vette!* to the Amiga by
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
| Ground truth | **The original under a Macintosh emulator.** NEVER the dev-host backend, never the Amiga build. Which emulator is open — `docs/mac-reference-loop.md` |
| Repo | Commit directly to `main`, one logical change per commit |
| Source material | Kept **local only, never committed** — `tmp/` is local by policy, and `.gitignore` covers every shape a Mac application arrives in |
| **Port strategy** | ⭐⭐ **Option A: keep the original 68000 instructions, port the seams.** The segments are near-model, so there is nothing to relocate; the cost lands entirely in the trap layer. `docs/faithfulness-seam.md` §The rule |
| **The build** | ⭐ **`Color VETTE!`.** Not the B&W one. See below — 16 colours maps onto 4 Amiga bitplanes, so the colour build is not the expensive choice it would be at 8bpp |
| **Copy protection** | ⭐ **Patched out, not reproduced.** The one deliberate, named departure from 1:1 — see `docs/faithfulness-seam.md` §The copy protection |

## Open decisions

These are genuinely open and are the right things to settle before building. They are ordered by
how much else depends on them.

1. ⭐ **The reference emulator.** `docs/mac-reference-loop.md` §Candidates, evaluated against the
   capability list there rather than on accuracy reputation. The capability that decides it is
   scripted breakpoints + register reads, because that is what makes the trap inventory possible.
2. ⭐ **The display architecture.** 512×342 at ~60 Hz onto a PAL planar Amiga at 50 Hz, now with
   **colour**. Every part is still a decision — the width (512 is not a free Amiga mode), the height
   (342 vs 256 lines), the depth, and the 17% timing difference.
   ⭐⭐ **The depth question got a good answer:** the Color build ships 8 `pltt` palettes of
   **16 entries** each, so `[DERIVED]` the game is a **16-colour** program, not 256. 16 colours is
   **4 Amiga bitplanes** — an ordinary OCS configuration, and cheaper per pixel than the 5 bitplanes
   Revs needs. So choosing Color costs bitplane DMA and blit width, not a colour-reduction pass.
   ⚠ `[ASSUMED]` until confirmed from the binary: that the game's offscreen/window depth really is
   4bpp. The `pltt` count is evidence about palettes, not proof about the drawing surface — see
   `docs/open-work.md`. → `docs/mac-hardware.md` question 5.
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

⚠ `docs/mac-hardware.md` question 5 is referenced by #4 above; the numbering here shifted when the
build choice was added, so trust the titles rather than any number quoted elsewhere.

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

- [ ] **Phase 0 — Scaffolding.** ⚠ The repo structure, the vendored framework, the inherited docs
      and the FS-UAE scripts are in place; **no code is written and nothing has been run.** The
      inherited Amiga scripts are renamed but unverified. `docs/open-work.md` has the exit criteria.
- [ ] Phase 1 — The Macintosh reference loop
- [ ] Phase 2 — Complete static map (segments, the jump table, the trap map, the A5 world)
- [ ] Phase 3 — The trap layer
- [ ] Phase 4 — End-to-end skeleton on the target, then profile, then set a target
- [ ] Phase 5 — Render + input
- [ ] Phase 6 — Optimisation
- [ ] Phase 7 — Packaging

See `docs/phases.md` for exit criteria and the gating between phases.

## Immediate next step

**Unblock the source archive** (`docs/open-work.md` #1) and **settle the three open decisions that
gate everything else** — the port strategy, the reference emulator, and the display architecture.

⚠ Resist starting Phase 0 code around them. The postmortem's one-sentence lesson is *build the
discovery and validation infrastructure exhaustively up front instead of growing it reactively*, and
"write some platform code while the strategy is undecided" is exactly the reactive version.
