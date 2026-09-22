# The faithfulness seam — what stays original 68000 code, and what the port authors

> **Read this before converting, rewriting or reimplementing a single routine.** ⚑ Postmortem §5:
> *write the seam rule down first*, because it is the decision you make hundreds of times, and both
> prior ports paid for having settled it late.
>
> ⭐⭐ **THE ANSWER IS NOW DECIDED: option A is the default.** Keep the original instructions; port
> the seams. §The rule below states it and what it costs. The three-way framing is kept because it
> is what stops the decision being re-litigated, and because #2 — *what forces a routine off A* —
> is still answered one routine at a time.

## Why this is a genuinely different question from the prior ports'

In *Rescue on Fractalus!* and *Revs* the seam was **"faithful validated twin vs Amiga-only code"**,
and it had that shape because *everything faithful was generated*: a transpiler emitted a
transliteration of the 6502, a hand-written native twin was proven byte-identical to it, and the
only open question was which side of that line a routine lived on.

Here there is no transpiler and no oracle, and there is an option neither prior port had:

**You can keep the original bytes.** The Mac code is 68000 code, and the Amiga is a 68000. A routine
can be carried over as *the original instructions*, assembled into the Amiga binary, with no
conversion, no transliteration and nothing to validate — because it is not a reimplementation.

That makes the seam a **three-way** choice, not a two-way one:

| Option | What it is | What it costs | What it buys |
|---|---|---|---|
| **A. Original instructions** | the routine's own bytes, relocated and linked in | it is opaque — unnameable, unprofilable at source level, unoptimisable, and every register/stack/A5 assumption it makes becomes a contract the port must honour exactly | perfect faithfulness for free, and no validation burden at all |
| **B. Port-authored C/asm, faithful** | a reimplementation intended to behave identically | needs a differential against *something* to be believable, and this project has no byte-exact oracle by construction | legibility, optimisability, a name on the map |
| **C. Port-authored, Amiga-only** | code with no counterpart in the original (the display conversion, the input mapping, the copper work) | nothing to be faithful to; correctness is judged by eye and by the reference loop | it is where the port actually lives |

⭐ **Option A is the structural novelty of this project and the reason it is a good pilot.** If it
works well, a Mac 68k port is dramatically cheaper than a 6502 one, and the pilot's job is to find
out where it stops working.

## ⭐⭐ The rule: A by default, B by exception, and the exception must be argued

**Decision (locked): the port keeps the original 68000 instructions and services their traps.**
Option B is available but is the *exception*, and a routine moved to B needs a stated reason from the
list in #2 below. ⚠ A default of B would have been a rewrite with no oracle; neither prior port's
answer transfers, because neither had option A.

### Why A is cheaper here than it sounds — the segments need NO relocation at all

Verified against the Color build's own `CODE` resources:

| fact | consequence |
|---|---|
| **All 11 segments are NEAR MODEL** (header = `first-JT-entry-offset:w`, `entry-count:w`; no `0xFFFF` far header, no relocation tables) | ⭐⭐ **There is nothing to relocate.** Internal references are PC-relative, globals are A5-relative, and every inter-segment call goes through the jump table. "Linking" a segment is *place the bytes and fix the table* — strictly **less** work than an Amiga hunk `RELOC32` pass, which does have offsets to patch |
| `CODE 0` header: below-A5 **31 272 B** of application globals, above-A5 **4 104 B** = 32 B + a **4 072 B jump table of 509 entries**, at A5+32 | the A5 world is one 35 KB allocation with two known halves. `a5` points between them |
| All 509 JT entries are in **unloaded** form — `offset:w`, `MOVE.W #seg,-(SP)`, `_LoadSeg` ($A9F0) | the port's segment-loader stand-in can pre-patch every entry to loaded form (`offset:w`, `JMP abs.l`) once at startup and never service `_LoadSeg` at all |
| Per-segment entry counts sum to **exactly 509** (130 `Main`, 242 `FRED`, 80 `Traffic`, 16 `Initialize`, 16 `Communication`, 12 `sound`, 9 `Score`, 2 `Intro`, 1 `load`, 1 `%A5Init`) | ⭐ the jump table is **fully accounted for** — no hidden entries, and the postmortem's dispatch sweep is a closed set of 509 |

`[DERIVED]` from a self-tested recursive 68000-vs-68020 differential over all 508 distinct entry
points: **no 68020-only encoding on any reached path.** It follows direct branches and reports 609
computed/unresolved transfers instead of silently treating them as coverage. The independent
Ghidra/static classification and its explicit residue are in `docs/static-map.md`; linear-sweep
hits in the residue remain data-shaped false-positive candidates rather than being declared code.

### ⚠⚠ What A actually costs, and it is not zero

**A moves the entire job into the trap layer, and it removes your freedom to reinterpret.** Under B
you can decide what a Toolbox call *meant* and implement that; under A the original bytes make the
call exactly as Inside Macintosh documents it, and the port must honour the documented semantics:

- **Memory Manager handles MOVE.** `NewHandle`/`HLock`/`HUnlock` is not malloc; code that
  dereferences a handle twice across an allocation is *correct* Mac code and the port must make it
  correct here too.
- **QuickDraw's `GrafPort`, regions and the current-port global** are a stateful surface the code
  will assume, not a drawing call it makes once.
- **`%A5Init` must run, or be replaced by what it produces.** 28 732 B whose job is to initialise
  those 31 272 B of globals. Skipping it gives a game whose globals are zero instead of initialised
  — a silent wrong-value failure, not a crash.
- **The code is opaque by construction**: unnameable, unprofilable at source level, unoptimisable.
  The map is `disasm/symbols.csv` plus the 509 names the jump table hands us, and nothing more.

## The questions the rule has to answer, in the order they will come up

1. ~~**What is the default?**~~ **Settled: A.** See above.
2. **What forces a routine off A?** Candidates, to be confirmed against the binary: it makes a
   Toolbox call whose semantics the port changes; it touches the screen (1-bit 512×342 vs planar);
   it is hot enough to need optimising; it depends on a Mac hardware register or a low-memory global.
3. **What is the contract at an A↔B boundary?** This is where the prior ports' hardest-won rule
   applies with full force and no modification:
   ⭐⭐ **A seam must hand over every register the original has live there, and the set is derived
   from the SURROUNDING INSTRUCTIONS, never from what the callee happens to read.** Revs lost days
   to a stale register at a hook seam: the hook ran an indexed loop, so a wrong index did not fail —
   it addressed a neighbouring table and computed something plausible. On 68000 code the live set
   includes `d0-d7`/`a0-a6`, the condition codes, and `a5` (globals) and `a7` (stack) invariants.
4. **How is a B routine believed?** With no byte-exact oracle, the honest answers are: the reference
   loop (`docs/mac-reference-loop.md`), an A/B against option A for the same routine in the same
   build (which *is* available here and is the closest thing to a differential this project has —
   ⭐ note that this is strictly better than what either prior port could do for its Amiga-only
   code), and host-side algebra proofs over randomised inputs.
   ⚠ Inherited and load-bearing: **a differential whose control is not the OLD CODE measures the
   test, not the change**, and **a fixture-less pass runs zero comparisons and reports green**.
5. **What does a routine that cannot be expressed at all look like?** ⭐⭐ Inherited rule, and it is
   the one most likely to be needed early: **when a translation cannot represent something, make the
   gap LOUD at the earliest point that can name it.** A silent no-op is the most expensive
   translation choice — it looks exactly like working code from the outside, and the failure
   surfaces far from its cause. (There is already one in this tree: `BitmapAssembler.s`'s two
   non-interleaved arms, inherited as silent no-ops and retagged `[ASSUMED]`.)

## ⭐ The copy protection — the one named exception to 1:1

**Decision (locked): the protection is patched out, not reproduced.**

`readme.txt` says the shipped 1.02 build asks for a password **once, on first run**, with the answers
in the first pages of `Manual.pdf`. The data side of it is `VETTE!.Data`'s `COPY 1 "Protect"`
(1 991 B); the check itself is in the code, un-located as yet (`Initialize` is the obvious first
place to look, and `Main` the second).

Three reasons it is not a faithfulness question at all:

1. **A WHDLoad release cannot ask.** The port's delivery format launches the game directly, with no
   manual in the player's hands and nowhere to put a modal password prompt. Patching it is a
   *release requirement*, not a shortcut.
2. **It is not player-visible behaviour.** ⚑ This doc's own rule — *faithful means faithful from the
   PLAYER's point of view* — excludes a gate whose only correct outcome is "proceed".
3. **Left in, it poisons the reference loop.** Every fresh reference image would stop at the prompt,
   which is precisely where ground truth needs to be cheap. → `docs/mac-reference-loop.md`.

⚠⚠ **But patch it the way this project patches things, not the way a cracker would.**
- **Find the check before defeating it.** The `COPY` resource is 1 991 bytes, which is far more than
  a password list needs; until the routine is read, we do not know what *else* it gates. A protection
  check that also initialises state is a classic, and stubbing it would produce a game that runs and
  is subtly wrong — the failure shape `docs/method-lessons.md` calls the most expensive one.
- **The patch is a port-side seam with a name, not a silent edit**, and it is recorded here and in
  `disasm/symbols.csv`. A reader must be able to find the one place 1:1 was deliberately broken.
- **Keep the original path runnable under the reference loop.** Ground truth is the *unpatched*
  original; the patch belongs to the port, so never validate the port against a patched reference.

## Rules that apply whatever the answer to #1 is

- **Faithful means faithful from the PLAYER's point of view.** Validate *results*, not a three-register
  machine's spills. A scratch cell the original writes and nothing outside the routine reads is not a
  result, and reproducing it is pure cost.
- **Mark assumptions as assumptions** — `[ASSUMED]` / `[DERIVED]` / `[INFERRED]`, in `symbols.csv`
  notes and in the docs. The postmortem's central failure mode is an assumption calcifying into a
  documented fact; a measurement replaces the tag.
- **A `region_*` / `FUN_*` name is SHIPPING code until proven otherwise.** Never conclude a routine
  or a cell is dead from a static scan alone.
- **`[ASSUMED]` in a comment is not a test.** A hedge next to a claim does not license the claim.
