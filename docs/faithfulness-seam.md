# The faithfulness seam — what stays original 68000 code, and what the port authors

> **Read this before converting, rewriting or reimplementing a single routine.** ⚑ Postmortem §5:
> *write the seam rule down first*, because it is the decision you make hundreds of times, and both
> prior ports paid for having settled it late.
>
> ⚠⚠ **THIS FILE STATES THE QUESTION, NOT THE ANSWER.** The answer depends on the port strategy
> (PROJECT.md §Open decisions #1), which is not decided. Do not start converting routines before it
> is — that is precisely the mistake this file exists to prevent.

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

## The questions the rule has to answer, in the order they will come up

1. **What is the default?** A or B. A default of A makes the port fast and opaque; a default of B
   makes it a rewrite with no oracle. ⚠ Neither prior port's answer transfers, because neither had
   option A.
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
