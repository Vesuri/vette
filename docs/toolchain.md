# Toolchain & how to run the pipeline

All paths relative to the project root (`Vette/`). Host is macOS (Apple Silicon).

⚠⚠ **THIS FILE IS PART PLAN.** Rows marked ✅ are verified present on this machine; rows marked
❓ are **candidates under discussion, not decisions** — see `docs/mac-reference-loop.md` for the
ground-truth-loop choice and PROJECT.md §Open decisions for the rest. Do not read a ❓ row as
"installed" or as "chosen".

## The pipeline (intended shape)

```
VETTE__1.02_and_extras.sit                       (tmp/, local only, never committed)
  └─ unpack (StuffIt 5) ──► the application's DATA + RESOURCE forks
        └─ tools/rsrc_map.py  ──► the resource catalogue (type, id, name, size)
        └─ tools/code_load.py ──► disasm/code/CODE_NNNN.bin + the jump table from CODE 0
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
| **a StuffIt 5 unpacker** | — | open the source archive — ⚠ **BLOCKING: nothing on this machine reads it** | ❓ |
| **a resource-fork reader** | — | `CODE`/`PICT`/`snd ` extraction | ❓ |
| **a Macintosh emulator** | — | the ground-truth reference loop (`docs/mac-reference-loop.md`) | ❓ |

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

## ⚠⚠ Ghidra has NO classic-Mac resource-fork loader — verified, not assumed

Checked against this install (12.1): the processor list has `68000`, and the file-format module has
an HFS**+** filesystem (for iOS) and nothing for a classic resource fork, MacBinary, AppleSingle or
HFS. So there is no "import the application and get its segments" path.

⇒ **Extract the `CODE` resources ourselves and import each as a raw binary** with processor
`68000:BE:32:default`, exactly the pattern both prior ports used (`xex_load.py`, `ssd_load.py`).
That is `tools/code_load.py`'s job. The upside is that the extraction is ours and scriptable; the
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
3. Append findings to `disasm/symbols.csv` (`segment,addr,name,type,note`).
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
| `MarkEntries.java` | needs `entrypoints.csv` filled from `CODE 0` | mark entry points + disassemble |
| `ExportListing.java` | reusable as-is | dump `listing.txt` |
| `ApplyNames.java` | reusable; ⚠ addresses are segment-relative | apply `symbols.csv` to the project |
| `DumpCallGraph.java` | reusable | call graph |
| **`DumpTraps.java`** | **does not exist — WRITE IT** | the A-line trap map. This is the abstraction boundary, and the direct replacement for Revs's `DumpHwAccesses.java` (not carried over: it hardcodes BBC I/O ranges) |

### The trap map IS the abstraction boundary
Its output tells you exactly what `src/mac/` must implement. Generate it early.

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

Details and traps: `docs/headless-fsuae.md`. ⚠ Those scripts are inherited and **unverified in this
repo** — there is no Amiga build yet.
