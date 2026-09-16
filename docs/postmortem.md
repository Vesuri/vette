# Postmortem — the binary-only port process, retrospective

Retrospective on the *Rescue on Fractalus!* port pipeline (Ghidra → transliterate 6502 → C →
abstract hardware → platform backends), written to carry forward into **future binary-only ports**.
It is not a to-do for this project — it is a "what I'd do differently next time" distilled from that
project's decision trail and git history. *Revs* was built deliberately in the order this document
argues for, and the ⚑ docs in this repo are what that produced.

> **⭐ Read §"How this maps onto a Mac 68k port" at the end FIRST if you are short of time** — three
> of the items below are about a 6502 transpiler this project does not have, and the mapping section
> says which ones survive and what replaces the rest.

> One-sentence version: **the biggest wins are all "build the discovery and validation
> infrastructure exhaustively up front instead of growing it reactively."** Complete
> entry-point seeding, a harness that cannot pass vacuously or hide endianness, and
> real-hardware measurement from frame one. Transpiler-output quality is a close second
> because it compounds across every regen.

Findings are ordered by leverage. The front end (Ghidra + transpiler) is where the leverage is.

---

## 1. Ghidra / control-flow discovery

### 1.1 Do an exhaustive indirect-dispatch sweep BEFORE generating any C  ★ highest leverage
The single most recurring pain was Ghidra silently missing code that is reachable only through
indirect jumps. The DLI chains (`$6DBB`, `$6DCF`), the event dispatcher, and the RTS-trick
dispatch tables were **discovered piecemeal over the life of the project**. The
`ghidra_scripts/entrypoints.csv` convention ("seed each DLI addr as a Ghidra entry point so it
persists in `listing.txt`") and the working-convention rule "record a newly-found DLI the moment
you find it" are both *scars* from getting burned repeatedly.

The set of dispatch patterns in a binary is finite and enumerable. Next time, write a one-time
analysis pass **before** the first C is generated that finds and seeds as entry points:
- every `JMP ($xxxx)` / computed-jump / RTS-dispatch idiom and the word tables they index;
- all hardware/OS vectors as roots — NMI/IRQ/RESET (`$FFFA-$FFFF`) plus platform shadow vectors
  (Atari: VDSLST `$0200`, VVBLKI/VVBLKD, VIMIRQ, etc.).

Front-loading this makes `listing.txt` complete on day one instead of a moving target, and
prevents the failure mode "I reasoned statically about a handler Ghidra never disassembled."

### 1.2 First-pass behavioral naming as a dedicated phase, not a trickle
`docs/rename.md` accumulated a backlog because many functions carried wrong/auto names for a long
time. On a binary-only RE project **the function names are your map** — every wrong name taxes
every subsequent reasoning step. `symbols.csv` → transpiler already made renames cheap, so the
infrastructure was right; the timing was reactive. Next time, spend a concentrated early pass
giving rough-but-directionally-correct names (`dli_colpf_writer`, `terrain_*`, …) before deep
work begins.

---

## 2. Transpiler quality

### 2.1 Make the transpiler emit clean, near-idiomatic C BEFORE mass-generating
The liveness-gated peephole folding (direct assignments, N/Z-flag elision, the `−1490` line
shrink of `rof_gen.c`) landed *late*. Every regen and every human read between "first generation"
and "peephole added" paid the tax of uglier, slower, harder-to-diff C.

The transpiler is a force multiplier: one improvement upgrades the entire corpus at once. Treat
"emit clean C" (liveness-gated flag elision, named `mem.h` accesses from `symbols.csv`, folded
load→store idioms) as a **prerequisite milestone**, not a later optimization. Cleaner generated C
also directly reduces how many functions ever need a hand-written native twin — which is the
expensive downstream work.

---

## 3. Validation — where I'd change the most

The nastiest bug class on this project was **passes `make validate` green, breaks at runtime.**
All three instances below are documented in `feedback-native-twin-validation-gaps`:

- **Vacuous green** — a `VALIDATE_FUNC` with no registered fixture prints `PASS` with zero
  comparisons run.
- **Endianness** — little-endian `mem[]` aliased as `uint16_t*`/`uint32_t*` reads correct on the
  little-endian SDL host but byte-swapped on the big-endian Amiga; `make validate` stays green
  while the Amiga renders garbage.
- **Live exit registers** — a twin's exit register consumed by a transpiled caller is a real
  contract, but the harness hides it as "incidental cpu diff" (the `audio_timer_setup` exit-A=0
  bug → level-select construction detour).

### 3.1 Make vacuous / hidden-failure passes structurally impossible
Bake the countermeasures into the harness from the **first** twin, not after each bites:
- **Fail (not warn)** when a `VALIDATE_FUNC` has no registered fixture — no silent
  zero-comparison passes.
- **Run the differential big-endian as well as host** (real or emulated target in CI), or at
  minimum a linter that flags any `uint16_t*`/`uint32_t*` alias of `mem[]`, so endianness cannot
  hide behind a green host run.
- **Auto-randomize inputs, including the gating bytes**, rather than hand-authoring fixtures that
  silently leave whole branches untested.

### 3.2 Stand up the reference + measurement loops as first-class infra at project start
Both the headless `atari800` reference-capture loop and the headless FS-UAE + gdb beam-probe loop
retroactively became "the thing that diagnosed timing/render bugs precisely where static reasoning
kept failing." Yet both read as tools built *reactively* once already stuck, and the rule
"validate against the 6502 + atari800, NOT PlatformSDL (SDL is an approximation)" is a *learned*
lesson rather than a starting assumption. Next time build both harnesses (and the DL-analyzer
equivalent) **first**, so "measure, don't theorize" is the default from frame one.

---

## 4. Scope / performance sequencing

### 4.1 Profile an end-to-end slow skeleton on real hardware before committing the approach
The retired **"algorithmic floor / 50 FPS impossible without an algorithm change"** conclusion
(2026-06-29) was later disproven by hand-asm — the ceiling was GCC, not the algorithm. That wrong
turn cost real time and nearly steered scope. A crude full-pipeline skeleton profiled **on the
real A500 early** would have shown terrain rasterize / project / subdivide as the ~167 ms hot core
up front — telling you exactly which handful of functions ever needed the native→asm treatment,
and that the algorithm was fine.

General principle for a fixed-hardware target: get *something* running end-to-end on the real
machine as early as possible. The target's constraints are the whole game, and armchair reasoning
about them was repeatedly wrong here.

---

## 5. Architecture — write the faithfulness-seam rule down first

The `rof_native.c` (faithful, validated, linked into both backends) vs `rof_native_amiga.cpp`
(genuinely Amiga-only, lossy, unvalidated) split is good architecture — but the *rule* for which
side a function lands on was clarified only after churn. "A faithful, pure-`mem[]` routine that
merely needs a small Amiga variation stays a validated twin in `rof_native.c` with the variation
under `#ifdef ROF_PLATFORM_AMIGA`" is a call you make hundreds of times. Write that decision rule
as the first architectural doc, before the first twin.

---

## Checklist to carry into the next binary-only port

- [ ] Enumerate + seed ALL entry points first: indirect-jump/RTS-dispatch tables and every
      hardware/OS/shadow vector. Make disassembly complete before generating C.
- [ ] One concentrated behavioral-naming pass up front; single source-of-truth symbol file feeding
      the transpiler.
- [ ] Invest in transpiler output quality (clean C, flag elision, named memory) *before*
      mass-generating — it compounds over every regen and shrinks the twin backlog.
- [ ] Validation harness from twin #1: fixture-or-fail (no vacuous green), cross-endian
      differential, auto-randomized inputs incl. gating bytes, exit-register contracts explicit.
- [ ] Build the emulator reference-capture loop AND the real-hardware measurement loop as
      first-class infra day one; never trust the dev-host backend as ground truth.
- [ ] Stand up a slow end-to-end skeleton on real hardware early and profile it before choosing
      what to optimize; don't declare an "algorithmic floor" without a hand-asm datapoint.
- [ ] Write the faithful-twin vs platform-specific seam rule down before the first twin.

---

## Next target (historical)

This document's original closing section planned the *Revs* port. That port exists
(`~/Documents/Revs`), so the section is retired rather than kept as a stale plan — read
`~/Documents/Revs/PROJECT.md` and `~/Documents/Revs/docs/postmortem.md` for where it actually went.
Two of its premises turned out to be wrong in instructive ways, both recorded there: Revs was not
binary-only (an annotated source reconstruction existed), and "the same binary across all tracks"
was only approximately true (the expansion track files are executable and patch the engine).
**The general lesson is the one to carry: a plan written before the binary was opened had two
load-bearing factual errors in it, and both were cheap to check and expensive to assume.**

---

## ⭐ How this maps onto a Mac 68k port (*Vette!*, this repo)

The checklist above was written for a **6502 binary transliterated to C**. This port starts from
**68000 code that can stay 68000 code**, which retires some items outright and sharpens others.

**Retired — no equivalent here:**
- §2 *Transpiler quality* in its entirety. There is no transpiler, so its compounding leverage —
  the postmortem's #2 finding — is simply absent. ⚠ Do not go looking for a substitute lever of the
  same size; accept that the front end is cheaper here and spend the saving on the seam.
- §3.1's *cross-endian differential*. Both prior ports carried a little-endian `mem[]` onto a
  big-endian target. The Mac 68000 is big-endian and so is the Amiga, so that entire hazard class
  — the one that let `make validate` pass green while the target rendered garbage — does not exist.

**Survives, unchanged and still the highest-leverage item:**
- §1.1 *the exhaustive dispatch sweep before generating anything.* It bites **harder** here, not
  less: a Mac application reaches everything through the A-line trap table and jump-table
  (`CODE` 0) entries, and it is loaded and relocated by the Segment Loader rather than living at
  fixed addresses. Enumerate every trap site and every jump-table entry first.
- §1.2 *one concentrated naming pass up front*, feeding a single symbol file. Unchanged.
- §3.2 *stand up the reference loop and the measurement loop as first-class infra on day one, and
  never trust the dev-host backend as ground truth.* Unchanged — and this port has an unusually
  good reference available (the original running under a Mac emulator on a machine within 12% of
  the A500's clock).
- §4.1 *profile a slow end-to-end skeleton on real hardware before choosing what to optimise.*
  Unchanged.
- §5 *write the faithfulness-seam rule down before the first conversion.* Unchanged in spirit;
  **different in content**, and see below.

**Genuinely new, and the two things to build first:**
1. **The trap/OS surface is the whole port, and it is much larger than either prior port's.** RoF
   replaced the Atari OS wholesale; Revs serviced a *closed* MOS surface of 4 entries and 17 sites.
   A Mac game talks to QuickDraw, the Event Manager, the Memory Manager, the Resource Manager, the
   Segment Loader and the Sound Manager — that is not a handful of reason codes, it is a
   reimplementation of the parts of a system the game touches. **Inventory it from the binary before
   estimating anything**, and expect the answer to be the project's centre of gravity.
   ⚠ Revs's lesson applies with force: its MOS layer was **a floor, not a closed surface** — three
   calls were found by RUNNING it. Treat any trap inventory as a lower bound.
2. **The seam rule is a different question here.** In both prior ports the seam was "faithful
   validated twin vs Amiga-only code", because everything faithful was generated. Here the question
   is *whether each routine stays as original 68000 instructions or becomes port-authored code*, and
   the answer has a whole extra option the prior ports lacked: **keep the original bytes**. Write
   that rule down before converting a single routine — it is the decision made most often.
