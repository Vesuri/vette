# Method lessons — how to work on a binary-only port

> ⚑ **Carried over from the *Rescue on Fractalus!* and *Revs* ports** (⚑ Revs marks the ones Revs
> added).  These are workflow lessons, not facts about hardware or about a 6502, and every one of
> them replaced a habit that had already cost time.  They apply to this port unchanged.
>
> ⚠ The worked examples name those projects' code, files and `make` targets — `make validate`, the
> transpiler, `mem[]`, `symbols.csv`, jsbeeb.  **None of that machinery exists here yet**, and some
> of it never will (there is no transliteration to validate against a 6502 oracle).  Read an example
> as evidence for its rule and translate the mechanism: "the reference loop", "the differential",
> "the instrument" are roles this port has to fill, not files it has.
>
> The two that are worth re-reading before any session: *Measure, don't theorise* and *A known
> failure mode you have not TESTED for is a conclusion you have not earned*.

## Measure, don't theorise

The headless emulator + gdb loop repeatedly diagnosed timing and render bugs **precisely where
static reasoning kept failing**.  Both loops (`docs/headless-fsuae.md` for the Amiga side,
`docs/mac-reference-loop.md` for the Macintosh reference) exist so that "measure" is cheaper than
"argue".  Use them.  ⚠ In this repo the Amiga one is inherited-and-unverified and the Mac one is
still a PLAN — standing both up is Phase 0/1, and until then every "measure" below is an
instruction to build the instrument.

Corollaries:

- **Measure the baseline before reasoning from it.**  A stale "~6 FPS" figure — really 14.4 —
  was the premise behind "only architectural changes matter" *for months*.  Re-measure; never
  quote an old number.
- **Bisect works great here — USE IT.**  Never assert a bug is "pre-existing" without bisecting.
  That claim was wrong three times, and right once (proven by A/B-ing a baseline build) —
  it is cheap either way, so just do it.
- **A probe that reads the same source as the code under test is vacuous.**  If a probe has
  never fired, suspect the probe first.
- ⭐ **A DROPPED probe counter does not read zero — it reads garbage that looks like data.**
  Measured in this repo while scaffolding: `-fdata-sections` + `--gc-sections` dropped
  `g_fpsFrames` in a build where nothing referenced it, gdb resolved the name into `.text`, and
  the harness reported `painted=1223110688` — m68k instruction bytes inside
  `processBlitterQueue`.  A zero would have read as "not counting"; garbage reads as a
  measurement, which is strictly worse.
  `__attribute__((used, retain))` does **not** fix it (`retain` is ignored on this target;
  `used` only binds the compiler).  The fix is a linker gc root — `PROBE_SYMS` in
  `amiga/Makefile` becomes `-Wl,--undefined=<sym>` — plus `make probe-audit`, which fails the
  link if any listed symbol is missing from the ELF.  **Add every new counter to `PROBE_SYMS`.**
  Generalisation: when a number looks wrong by orders of magnitude, check that the symbol you
  read is the symbol you meant, before theorising about the value.
- **A gdb script ABORTS THE WHOLE FILE at the first unknown symbol**, from that line onward.
  When you delete or rename a probe global, grep every `.gdb` for it — and read "the trace
  stopped after the header" as a stale script, not a dead probe.
- **Quote the DURATION, not the hit count.**  A beam-overlap counter read 29 and 46 on two runs
  of the *same binary*.

## Prove a pure REORDERING on the HOST, not on target

Compile the old and new bodies side by side over randomised inputs (160k cases, seconds).  It is
the only check that reaches **Amiga-only framework code, which `make validate` cannot see at
all**, and it rules a routine out as the cause of a visual change far faster than an emulator
round trip.

⚠ **And re-measure after:** reordering a loop for correctness cost 2× until the hot shape was
unrolled.  Byte-identical does not mean cost-identical.

## How a "structural, faithfulness-bound" ceiling actually fell

The −36% win on RoF's hot rasterizer, as a repeatable recipe:

1. **Shape-probe the algorithm's own input distribution** with dedicated counters — not a PC
   profile.  (It found that two cases covered 47.7% of all calls.)
2. **Prove the algebra on the host** over millions of randomised cases.
3. **Then** write the asm.
4. **Then** run the on-target in-process differential, A/B'd against the same C oracle.

Two generalisable questions from it:
- Does a "serial" accumulator really *have* to be serial?
- After special-casing a recursion's leaves, **re-price their parents**.

## Clean-C twin rewrite loop

The proven byte-identical loop for de-transliterating a routine: disasm-verify → splice by line
→ `make validate FN=<name>` → one commit each.  Small steps, each independently green.

Gotchas that pass `make validate` yet break at runtime — all three are now designed out of the
harness (Revs's `docs/validation-harness.md`), but know the shapes:
- a twin that takes an argument in a CPU register the fixture never varied;
- the wrong gating byte, so a whole branch was never exercised;
- a live exit register filed as an "incidental" difference.

## Register-ABI handoff between asm twins

Two adjacent asm twins can pass values in registers instead of round-tripping through `mem[]` —
but keep the **shim seam** so the differential stays valid (the C oracle must still be reachable
through the `mem[]` path), and write down the **zero-extension precondition** the callee
inherits.

## "Is this drift a bug or faithful?" — look for the ORIGINAL's own compensation table

If the original binary carries a table that *equals* the formula the hardware model implies, that
confirms the model **and** the faithfulness, from the binary alone — no emulator round trip.
Worked on RoF: GTIA anchors a wide player at its left edge, so keeping its centre fixed needs a
shift of exactly `4(s−1)`, and the game's own two tables ARE that.  So the placement was provably
exact and the residual wobble was the original's own shape data.

## Audit the ADDRESS width, then its value range

In any hand-written asm twin.  A wild write hunt on RoF ended at a `.w` address hazard.  The
method that found it: hardware watchpoints, a checksum canary, and runtime-address→symbol
lookup.

## Grep every reader before narrowing a render signal

Narrowing "what counts as dirty" is a normal optimisation, and it silently breaks the *other*
consumer you did not know about.  Survey the readers first.

## A gate that works may be the bug

If a guard "works" but the behaviour is still wrong, consider that the guard itself is
suppressing the corrective action.  (Same family as "don't cache a write-only register".)

## Read the BOUND from the instruction, never from the first example ⚑ Revs

Learned twice in one Phase 2 session, both times *after* the wrong answer looked convincing:

- The unpack's block-move tables must be read from the stub's self-copy at `$79xx`, not from
  `$12xx`, because one of the moves overwrites the tables mid-sequence.  Reading them in place gave
  a correct first move and then garbage, and reported a confident engine entry of `$919D`.
- `ModifyGameCode`'s patch count is `LDX #n` at `$5701`, and **n differs per track** — 19 for Brands
  and Oulton, 20 for Donington and Snetterton.  Hardcoding 19 (from the first track examined) made
  the other two report two bytes as unexplained, which read like a gap in the *measurement* rather
  than an off-by-one in the checker.

The general form: when a loop's trip count, table length or pointer source is *in the code*, take
it from there and `assert` the instruction shape you are relying on.  A constant copied from the
first instance is a guess that will hold long enough to be trusted.  Revs's `docs/static-map.md` has both
cases in full.

## A number that improves because the tool got looser is worse than no number ⚑ Revs

The static-coverage report had 5327 unexplained bytes.  Widening one heuristic — the look-back
window for finding what writes a zero-page pointer, from one instruction to four — took it to
**zero**.  It was wrong: the wider window matched unrelated instructions and the resolver then
fabricated a pointer target at nearly every page boundary, so every unexplained run came back
"explained".

Reverted, with the reason in the code, and the honest figure (685) is what ships.  This is the same
family as the validation harness's fixture-or-fail rule (Revs's `docs/validation-harness.md`): **when a
metric moves in the direction you want, check whether the thing being measured changed or only the
measuring.**  Loosening a classifier is indistinguishable from progress if you only read the total.

## An A/B control that is not the OLD CODE measures the test, not the change ⚑ Revs

The dirty-region decode (2026-08-16) shipped with two honest numbers that disagree by 24 points.
`make DIRTY=0` — the same new loop with the dirty test switched off — read **1.46 FPS**, so the test
looked worth **+34%**. But the code it replaced read **1.77**: enabling the test meant restructuring
the pass from line-major to cell-major (a display line is 40 sequential destination stores; a cell
column is 8 strided by `kRowBytes`), and **the restructure cost ~18% on its own**. The change was
worth **+10.7%**.

Both figures are real and they answer different questions: the flag's control prices *the test*, and
the previous commit prices *the change*. ⚠ **Only the second one is a baseline**, and quoting the
first would have banked a win against a build that never existed. So whenever an optimisation needs
an enabling restructure, measure **three** builds — old code, new code with the feature off, new
code — and say which number is which. A single A/B flag silently prices only the last step.

## Before a representation change, ask what the cost is PROPORTIONAL TO ⚑ Revs

Direct-to-bitplane plotting for the view rasteriser (2026-08-16) was designed, built, proven
byte-exact against an oracle, measured — and was **9% slower**. The plan's own sentence contained
the error: *"~2100 iterations become ~150"*. What collapsed into 150 was the **store count**. The
2100 **iterations** were a scan — each unit reads its own source byte out of a strided block — and
no layout on either side of the seam changes how many source bytes there are.

So the routine's cost was proportional to *source reads*, and the change was aimed at *stores*.
Removing one byte store from a thirty-instruction, instruction-fetch-bound unit, and adding run
bookkeeping to it, is negative before anything is gained.

Two habits come out of it:

1. **Name the quantity first.** Write down "this routine costs N × (the thing it does per unit)"
   and check that the change reduces N, not something correlated with it. A store count and an
   iteration count look interchangeable in a profile and are not.
2. **Check whether a cheaper change already took the prize.** The second half of the win was meant
   to be the deleted decode — but the dirty-region decode had shipped three commits earlier and was
   already skipping exactly those cells. Measured: the plot-only build reads *identically* with and
   without the decode skip. Two optimisations can compete for one prize, and the second one to
   arrive finds it spent.

⭐ None of this was visible from reasoning, and all of it was cheap to measure: the whole experiment
was three FPS runs against a build kept behind a flag. Build it behind the switch, measure it, and
let the number decide — then keep the machinery if its oracle is reusable, and say plainly that it
did not ship.

## Instrument the state, not the event, when the event has already happened

Counting executions of five menu call sites reported "none reached" while the engine was demonstrably
sitting inside one of them — the counter was installed after the call was already outstanding, and a
call-site counter cannot see a call in progress.  Reading the **6502 stack** and decoding it as
return addresses answered it immediately.

Generalise: for "where is it stuck", prefer state that persists (stack, flags, a wait variable) over
events you have to be present for.

## A known failure mode you have not TESTED for is a conclusion you have not earned ⚑ Revs

The Phase 4 profile named the physics core as the hot path and called it "the headline difference
from the Atari port".  It was wrong end to end: re-measured, the top three are the dashboard
(34.7%), the road rasteriser (27.3%) and an unnamed compute routine (18.6%), and the old #1 is
6.5%.  The hot path is rasterisation, exactly as it was on the Atari port.

The instrument timed with the beam position, which wraps once per **display** frame, and dropped
negative deltas.  Sound while a bracket is shorter than 20 ms; at 1.4 FPS a game frame spans ~37
display frames and the long phases each spanned several, so **the longest phases lost the most
time** — the precise inversion a profile must not have.  It accounted for 4% of the frame.

What makes this a method lesson rather than a bug report: **the failure mode was already written
down, in the same document, under the table it invalidated.**  One phase read exactly zero and
the note said *"either it is genuinely trivial or its bracket is losing deltas to the frame wrap;
do not treat 0 as measured."*  Correct, and filed as a caveat beneath a headline that depended on
it being false.

- **A hedge is not a control.**  Writing "this might be broken" next to a number does not license
  quoting the number.  Either test the hypothesis or do not publish the conclusion.
- **Every instrument needs a cheap total-accounting check, and it must be printed every run.**
  Here it was one division — bracketed ticks vs elapsed ticks — and it would have failed loudly
  from the very first run, two phases before anyone acted on the table.  `phase4_prof.gdb` now
  prints it as its first line, with "MUST be ~100" next to it.
- **Suspect the instrument hardest when it agrees with what you expected.**  "Physics is the hot
  path" was the predicted answer (`docs/phases.md` Phase 6 had already assumed it), so the table
  confirming it drew no scrutiny.  The zeros were right there.

## A "zero" from a probe is only evidence if the run REACHED the code ⚑ Revs

Three probes in a row reported **zero executions** of the seven `$7Bxx` call sites and the reading
was "consistent with unreachable".  It was nothing of the kind: none of the three checked whether
the run had reached the *surrounding* code, and none had.  Generating and running the corpus
settled it in seconds — three of those sites are in the engine's **main loop**, called every
frame.  The probes had been measuring a scripted BBC session that stalled in the front end.

Two rules fall out, and the second is the expensive one:

1. **Every "not observed" probe needs a positive control in the same run** — a landmark on the
   path that proves the run got as far as the thing being tested.  `tools/bbc_probe_frontend.mjs`
   is that shape: it counts the whole path in order, so a zero is attributable to a *place*.
2. **Bisect the explanation with counters, not with guesses.**  "Stuck in the line editor" had two
   causes needing opposite fixes: input not arriving, or the value rejected.  Counting the
   validator (`$32D0`) and the reject arm (`$3EEE`) *separately* answered it in one run — both
   zero means the line was never completed.  Four earlier runs were spent guessing at the value.

And the sting: the harness itself was wrong in a way that produced no error at all.
`utils.keyCodes.RETURN` does not exist in jsbeeb — that table calls it `ENTER` — so every RETURN
press was `keyDown(undefined)`, a silent no-op, in the probes AND in the pre-existing one they
were copied from.  **When an input harness has a name-keyed table, assert the names resolve
before using them**; an undefined key press fails silently and looks exactly like the program
ignoring you.  (Separately: speculative key presses jammed a two-character input field, wedging
the run with its own input.  Do not press keys "just in case" into something that buffers.)

## Being conservative is not free — it manufactures machinery whose preconditions can rot ⚑ Revs

The per-circuit SMC `extent` class emits one arm per instruction shape, and the first cut read
**every** patchable operand from `mem[]` in **every** arm.  The argument was sound-sounding: a guard
tests opcodes, so it cannot prove which circuit is running, so baking Silverstone's operand into the
arm its opcodes happen to match would be the plausible-looking wrong game.

It was half right, and the wrong half cost a working game.  A guard often *does* pin the circuit:
`$248B`'s unpatched arm needs `BCS` at offset 0, and all five expansion circuits write `$4C` over
offset 0, so only Silverstone can be in that arm.  Reading its branch offset from `mem[]` turned a
constant branch into a **runtime-computed** one — which then needs a dispatch over the enclosing
function's labels.  Two commits later, an unrelated change (hook exits becoming callable mid-function
entries) split that function, `$24B8` dropped out of the dispatch set, and a plain **Silverstone**
race — a circuit with no patches at all — died with `SMC UNHANDLED: site $248B holds $24B8`.

⭐ **The rule:** "read it at run time, to be safe" adds a mechanism, and a mechanism has
preconditions that some later change can break. When the evidence lets you narrow what actually
varies, narrow it — the tighter emission has fewer things that can stop being true. Here the
narrowing was derivable and stayed provenance-clean: record, per arm, which offsets are patched by
circuits **whose bytes satisfy that arm's guard** — offsets only, never values.

Two more that generalise:
- **A derived table needs a staleness guard, not just a regeneration command.** This one is derived
  from whichever circuit discs are present, and a stale version is *silently* wrong rather than
  loudly missing: the new circuit's patch addresses would still be in the union the coverage check
  publishes, so the installer would accept it and an arm would bake somebody else's operand.
  `make gen` now re-derives and fails on any difference.
- **Run the base case after every change to the general mechanism.** The regression was in
  Silverstone, the one circuit the change was not about. It surfaced only because the check races
  *every* circuit including the passive one.

## A wrong loop detector still emits a ranked table ⚑ Revs

Scanning every hot function's objdump for the defect that was worth +8.1% in the framebuffer
decode (a loop invariant re-read from the frame per iteration) needed a loop finder. Two were
written and **both were wrong, in opposite directions, and each produced a confident ranking of
candidates before the error surfaced**:

1. *Any backward branch is a loop.* It collects every shared exit tail and every cold landing pad.
   The top-ranked candidate this produced was a function's `rts` sequence, and its "loop-invariant
   reads" were struct fields correctly reloaded after a call.
2. *A natural loop's header must dominate its back edge — so nothing outside may branch into the
   body.* True of natural loops, false of what GCC emits: it rotates loops and enters them
   mid-body. This reported **zero loops** in two functions that plainly walk byte arrays.

What works is an SCC decomposition that strips each component's header set and recurses, reporting
the leaves. ⭐ But the transferable half is the failure shape: **a static analysis that is wrong
still produces a table, and a table of numbers reads as a measurement** — there is no error
message, no empty output, nothing that feels like a failed run. Sabotage a new *analysis* the way
CLAUDE.md already requires for a new *instrument*: point it at a known-good case (here, a loop
whose shape is already documented) and require it to agree before believing a new ranking.

⚠ And the ranking metric was wrong independently of the detector: on a register-poor target a
stack slot is a legitimate home for an invariant, so "operands touching the frame" cannot separate
a hoist from a reload. `docs/perf-method.md` §the frame-slot defect class is exhausted.

## Emit the mechanism, not a snapshot of it ⚑ Revs

Revs has 24 self-modifying instructions, all inside the road rasteriser.  The inherited rule was
"hand-stub a self-modifying routine", which would have bought 10 hand-written, unvalidated,
non-regenerable routines in the hottest and least-understood code in the binary.

Reading the *writers* first showed all 24 are three mechanical classes — patched operand bytes,
a patched 1-byte opcode slot, a patched branch offset — and each has an exactly faithful runtime
form: read the patched byte from `mem[]` and dispatch on it.  The generated code is then
patchable in the same way the 6502 code is, so it keeps working for whatever the writers actually
poke, including a hook only two of the five circuits install.

Generalise: before hand-writing around a dynamic mechanism, check whether the mechanism itself is
small enough to *emit*.  "The transliteration can't express this" is often "the transliteration
can't express one FROZEN reading of this".

### …and the tool's COUNT of a mechanism is not its SHAPE ⚑ Revs

The same rule applied to the `$7B00` overlay a phase later, and the inventory it inherited was
misleading in a way worth naming.  `make sweep` reports "17 patched target addresses" — a correct
static answer to the wrong question.  A store whose *own operand byte* is patched writes to a
computed address, so what the scan records is the **static operand base**, not the target.  Five
of the 17 were bases; the real site count was 42, and reading them out turned "17 sites, same
three classes, inventory work" into two chains of 40 unrolled units, a fourth SMC class, and a
guard the other three did not need.

Two transferable pieces:

- **A static scan of a dynamic mechanism under-counts by exactly the dynamism.**  When a table
  says *N* sites, check whether any of the *N* are addresses the code computes rather than uses.
  Budget from the mechanism, not from the count.
- ⭐ **The operand ENCODING is evidence, and it is the strongest kind available.**  Every writer
  here patches only the LOW byte, so a writer based at `$7C0F` can reach page `$7C` and nothing
  else.  That made the legal target set a *proof* rather than an assumption, and it is what kept
  the 40-slot expansion from becoming 40 guesses.  Before enumerating a patched target set by
  observation, ask what the addressing mode makes impossible.

## A silent no-op is the most expensive translation choice ⚑ Revs

Four separate places in one generation pass could have quietly produced code that runs and does
nothing: `BRK` translated as a comment, an unmapped call target emitted as an empty function, a
self-modifying slot holding an unlisted value, and a `VALIDATE_FUNCS` entry with no fixture.
Each looks *exactly* like working code from the outside — the failure surfaces later, far from
its cause, as "the rasteriser draws nothing" or "validation is green".

Every one of them is now either a generation-time failure or a run-time report with a name
attached.  The rule that falls out: **when a translation cannot represent something, make the
gap loud at the earliest point that can name it.**  A `TODO` comment in generated output is not
loud; nobody reads 16 000 lines nobody wrote.

Corollary from the same pass: **the C compiler is part of this pipeline's error detection.**  A
`JSR` mis-emitted as a local `goto` became an undeclared-function error rather than a subtle
control-flow bug.  Do not paper over generated-code warnings.

## The boundary rule you inherited may encode the previous binary's shape ⚑ Revs

Orphan instruction runs were attached to a function only when they FELL THROUGH into it.  That
was right for the Atari binary, where the one live case was a clipped loop body.  In Revs three
runs end in a terminator, and one of them is `JMP ($4F1D)` — the IRQ1V chain-on that hands a
foreign interrupt back to the handler Revs displaced.  The rule dropped all three, and the
generated interrupt handler let a foreign IRQ fall off its end.

Ending in a terminator was never evidence of not belonging; it was a proxy that happened to hold
once.  When porting a heuristic, ask what it is actually *evidence of* — here, ownership, for
which "the function branches into it" is the direct test.

## A MODE the port never exercises is a whole subsystem you have never tested ⚑ Revs

Revs has two session types.  Five phases of green measurements were **all** practice sessions, and
`$2637`'s `LDA $5F3B / BMI $262D` makes the consequence exact: with the practice flag set the
engine *skips the entire multi-car path*.  Practice runs the player alone, so a clean practice
frame is not weak evidence about competitor cars — it is **no** evidence, structurally.

The first competition race hung immediately, on a bug that had been latent the whole time
(`docs/phases.md` Phase 5 item 4b: `cpu.S` never initialised).

The lesson is not "test more".  It is that a *coverage* question hides behind an apparently
complete one: "does the port render?" was answered honestly and repeatedly, for the only mode
anyone ran.  When a target has modes, difficulty levels, or session types, enumerate them and ask
which code each one *excludes* — the exclusion is where the untested subsystem is.  A one-line grep
for the flag that gates the branch (`$5F3B` here) finds it faster than any amount of frame-staring.

## Page 1 is not all stack — and a register can be un-modelled state ⚑ Revs

Two lessons in one bug, both cheap to state and expensive to find.

**First: an image built from the disc does not model REGISTERS.**  Revs's `docs/bbc-reference-loop.md`
already warns that zero page and workspace are provisional because the real MOS/BASIC leaves them
populated.  The stack POINTER is the same class and is easy to miss because it lives in `cpu`, not
in `mem[]`.  Nothing in REVS2 ever loads `S`: `engine_init` does `TSX / STX $6B` — it *inherits*
whatever the OS handed it (measured `$F8`).  A zero-initialised global gave it 0.

**Second, and the reason it cost time: the symptom was in a different subsystem entirely.**  Revs
puts eight 20-entry per-car arrays in the BOTTOM of page 1 (`$0100 $0114 $0128 $013C $0150 $0164
$0178 $018C`), because a real BBC's `S` never descends past `$019F`.  So a low `S` does not
overflow or crash — it quietly scribbles pushed bytes into the field.  The observable was
`car_order` full of ASCII, then an infinite loop in a routine three call levels away that merely
*read* a derived index.

Generalise: **before assuming a memory region belongs to the machine, check whether the game has
claimed it.** And when a data structure is corrupt with values that look like they came from
somewhere else — ASCII in an index array, digits in a coordinate — ask what else writes that
address range, not what is wrong with the code that reads it.  The tell here was `48 49 50` =
`'0' '1' '2'`: those are characters, so a character-emitting path reached an array it has no
business touching.

⭐ The fix that matters beyond the bug is the counter: `g_stackLow` / `g_stackTrespass` in
`PUSH()`.  An invariant the hardware maintains for free (`S` stays high) becomes something the port
must *assert*, or the next drift is silent again.

**Third, added the day after, because the SAME corruption arrived from the opposite direction.**
A one-sided invariant is half an invariant.  `S` was being leaked *upward* — two bytes per
road-span exit at the two-level-RTS site (`docs/perf-method.md`) — so it walked to `$FF`, **wrapped
to `$00`**, and pushes landed on `car_order` exactly as before.  `g_stackLow` reported it faithfully
and misleadingly: "`S` fell to `$00`", which reads as a runaway push depth.

⭐ Two generalisations, both cheap:
- **On a wrapping register, a watermark that appears WITHOUT ITS PREDECESSORS was arrived at, not
  reached.**  `S` descends one push at a time, so a low watermark of `$00` with `$DF` never seen is
  proof the value came from the other side.  That one observation named the direction; before it,
  an hour went into looking for phantom pushes.
- **Assert both ends of a bounded quantity.**  `g_stackHigh` costs the same one comparison
  `g_stackLow` does and covers the half that was open.  The healthy window is now stated as a
  window (`$F3..$F8`), not a floor.

## An unidentified drawing routine has an ADDRESS, and an address has a PLACE on the screen ⚑ Revs

`$52A4` sat as `body_tick_xor_anim` with "[INFERRED] — the identity of the element drawn is not
measured" for a month, and the missing step took ten minutes: run its six store addresses through
`bbc_screen.h`'s `offset = charRow*320 + cell*8 + lineInRow`, notice they are three **symmetric
left/right pairs** (cells 0/1 and 38/39, display lines 133-140), then crop exactly that region out
of a real-BBC frame (`tmp/bbcref/ref_000211.png`) and look at it.  It is the dither at the top of
each front-wheel arch, XORed at a rate proportional to `road_speed`: the wheels turning.

- **Fixed store addresses are stronger evidence than any dynamic trace** — they need no run at all,
  and `make fbwrites`' PC attribution cannot separate two callers of a shared plotter anyway.
- **Symmetry is a semantic clue.**  Two mirrored address pairs mean a left/right pair of objects,
  which rules out most of the candidate list before any picture is opened.
- The visual ground truth is already on disk from an earlier `make refloop`; opening it is cheaper
  than another measurement.

### …and a rename is a re-read of the SENTENCES, not just of the identifier ⚑ Revs

Renaming that one routine touched eight hand-written files including a twin and
`tools/validate_native.c`.  A word-boundary substitution left three prose claims that the *old*
misnomer had made read plausibly — "`tick_wheel_spin`, the 50 Hz simulation" — which are now
obviously false and were false before.  A rename that fixes a wrong name will expose the sentences
that were built on it: re-read each hit in context, and fix the claim, not the token.

## Record findings the moment you find them

Two conventions that exist because deferring cost real time:
- **A function whose name contradicts its behaviour** → append to `docs/rename.md` immediately.
  Do not rename piecemeal in generated files; `disasm/symbols.csv` is the source of truth and a
  batch rename via the transpiler is cheap.  **On a binary-only project the function names are
  your map**, and every wrong name taxes every later reasoning step.
- **A newly-found interrupt handler / dispatch target** → add it to
  `ghidra_scripts/entrypoints.csv` the moment you find it.  Handlers reachable only via indirect
  vectors are invisible to Ghidra's own analysis.  (See Revs's `docs/entrypoint-sweep.md`, which is the
  attempt to make this convention unnecessary by front-loading the whole sweep.)

## Housekeeping

- **No redundant waiter shells** — backgrounded tasks self-notify.
- **Run `validate` targeted** (`FN=<substr>`); a full suite run gets slow fast.
- **Judge rendering only from a real run with a wiped emulator state** — the remote debugger
  greys the display, so a headless run can prove cost and state but never appearance.
- **Screenshot pixel forensics beats eyeballing**: decode the shot into lines/pens and match it
  against a gdb memory dump.
