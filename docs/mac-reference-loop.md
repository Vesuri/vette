# The Macintosh reference loop — ground truth

> **Read this before trusting any claim about what the original does, and before writing the first
> line of the trap layer.** ⚑ The rule it exists to serve is inherited and non-negotiable:
> **ground truth is the original on an emulator of the original machine, NEVER the dev-host
> backend and NEVER the Amiga build.** Both prior ports paid for the alternative.
>
> ⚠⚠ **THIS FILE IS A PLAN. Nothing in it is built.** Standing it up is Phase 1 and it gates
> Phase 2 (see `docs/phases.md`).

## Why this loop matters MORE here than in either prior port

- **The Mac Plus is a 7.83 MHz 68000 and the A500 is 7.09 MHz.** For the first time there is a real
  *performance* reference, not just a behavioural one: the same instructions ran ~12% faster on the
  original machine. That makes a large Amiga shortfall **diagnosable** — it is the port's seam, the
  display conversion or the trap layer, not "the algorithm" — which is a lever neither prior port
  had. ⚠ It does not make a Mac number an Amiga measurement (`docs/perf-method.md` §The target
  machine).
- **The trap surface is an inventory we cannot close statically.** Revs's MOS layer was proven a
  *floor* by running it — three calls were found that way. A Mac game's surface is an order of
  magnitude larger, so "run it and watch what it asks for" is not a nice-to-have, it is how the
  inventory gets finished.
- **The display is 1-bit 512×342 and the Amiga's is planar.** Every "is this drift a bug or
  faithful?" question about a pixel needs a reference frame to diff against. Revs's `make viewdiff`
  (every circuit's race view against a real BBC, byte for byte) was the single most useful gate it
  built; the equivalent here is a framebuffer diff against the emulator.

## What the loop must be able to do

Ranked by how much each capability bought in the prior ports. **A candidate emulator should be
judged against this list, not against its accuracy reputation alone.**

1. **Run headless and scripted**, so a capture is a `make` target and not a person driving a GUI.
   (Revs: `make refloop`, `make viewdiff`, `make mode7`.)
2. **Dump the framebuffer at a named moment** — the visual ground truth. A frame *number* is not
   enough; "at this PC" is what turns a pixel diff into a cause.
3. **Breakpoints + register reads + single step.** This is what makes a trap inventory possible:
   break on the trap dispatcher, read the trap word and the register arguments, log, continue.
4. **Memory peek/poke over a scriptable interface**, for reading A5 globals and the heap.
5. **Attribute a store to the PC that made it** (a watchpoint). Revs's `make fbwrites` settled what
   several unidentified routines actually drew; it is the instrument that replaces frame-staring.
6. **Deterministic replay** of a scripted input sequence, so two captures are comparable.
7. **Cycle counts**, ideally. Nice to have; the Amiga side is where performance is measured.

⚠ **Item 3 is the one to check hardest**, because it is the capability emulators most often expose
only in a GUI. Revs's postmortem chose jsbeeb over b2 largely on this: b2's HTTP API had
peek/poke/reset/run/mount/paste but breakpoints and registers appeared GUI-only.

## Candidates — NOT YET EVALUATED

Listed with what to check, so the evaluation is a measurement and not a preference. None is
installed on this machine.

| Candidate | Machine | Why it might be the oracle | What to verify first |
|---|---|---|---|
| **MAME** (`macplus`, `macse`, …) | the real target | Full Lua-scriptable debugger with breakpoints, registers, single-step and watchpoints, and genuinely headless (`-video none`). This is the shape of instrument the capability list above describes, and Revs kept MAME "in reserve" only because its BBC accuracy was less trusted than the dedicated emulators. **For the Mac there is no comparably-accurate dedicated emulator with a scripting surface**, which inverts that reasoning. | That the Mac drivers boot a real System + the game at all; the Lua API's watchpoint and framebuffer-dump surface |
| **Mini vMac** | Mac Plus, very accurate | The closest thing to a "dedicated, trusted" emulator for this exact machine, and it has a debug/`dbglog` build | Whether anything resembling scripted breakpoints/registers exists outside the GUI. If not, it is a **visual** reference only — still useful, but it cannot do item 3 |
| **Basilisk II / SheepShaver** | Mac II-class (68040) | Widely available | ⚠ Wrong CPU class and wrong speed, so it is not a performance reference at all, and a 68040 can hide 68000-only behaviour |
| **QEMU** (`q800`) | Quadra 800 | gdb stub — which would give items 3 and 4 for free, in exactly the idiom this project already uses for the Amiga | Same caveat as Basilisk: wrong machine class. But the **gdb stub** is worth a lot, and a gdb-driven loop would share tooling and habits with `amiga/debug.sh` |

⭐ **The decision is the user's** (PROJECT.md §Open decisions). The note to carry into it: the prior
ports ended up wanting **two** reference tools — a scriptable oracle and an interactive accurate
one — and that turned out to be the right shape rather than indecision.

## Traps to inherit from the prior ports' reference loops

All measured, all cost real time there:

- ⭐ **Every "not observed" probe needs a positive control in the same run** — a landmark on the path
  proving the run got as far as the thing being tested. Three Revs probes reported "zero executions,
  consistent with unreachable" for code in the engine's main loop; none had checked whether the run
  reached the surrounding code, and none had.
- ⚠⚠ **When an input harness has a name-keyed table, assert the names resolve before using it.**
  jsbeeb calls the Return key `ENTER`, so every `keyCodes.RETURN` press was `keyDown(undefined)` — a
  silent no-op, indistinguishable from the program ignoring you. Applies directly to any scripted
  Mac keyboard/mouse table.
- ⚠ **Do not press keys "just in case"** into something that buffers; speculative presses jammed a
  two-character input field and wedged a run with its own input.
- **An image built from the media does not model REGISTERS or what the OS left resident.** Here that
  generalises to: the application's heap, its A5 world and low memory are all *populated by the
  system before the game runs*, and a reconstruction that starts from the resource fork models none
  of it.
- **A reconstruction is provisional until diffed against the real thing.** Revs's Phase 2 found its
  memory image had been the wrong input all along (the engine unpacked itself first). ⚠ The Mac
  analogue is the Segment Loader: what runs is relocated, and the jump table is patched.
