# Phases and the gating between them

> ⚑ The ordering is the *Revs* port's, which was itself the shape `docs/postmortem.md` argued for
> after *Rescue on Fractalus!*. **The gating is the point:** every phase boundary below exists
> because doing that work out of order cost real time once.
>
> ⚠ The phase *contents* are re-derived for this port — a Mac 68k port has no transpiler phase, and
> it has a trap-layer phase neither prior port needed at this size.

## ⭐ The four things that must happen in order

| # | Gate | Doc |
|---|---|---|
| 1 | **The Macintosh reference loop is built and DRIVES** | `docs/mac-reference-loop.md` |
| 2 | **Exhaustive entry-point + trap sweep** before a line of port code is written against the binary — every `CODE 0` jump-table entry, every `$Axxx` site, every stored procedure pointer, every absolute low-memory reference | `docs/toolchain.md` §Before the FIRST export is trusted |
| 3 | **The seam rule is written down** before the first routine is converted | `docs/faithfulness-seam.md` |
| 4 | **Profile an end-to-end skeleton on the real A500** before choosing what to optimise, and before setting any performance target | `docs/perf-method.md` |

⚠ #3 replaces Revs's "the transpiler emits clean C before mass-generating". Both are the same
principle — *decide the mechanical policy before applying it 500 times* — and both are late-is-pure-tax.

---

## Phase 0 — Scaffolding

Build infrastructure only; no game code. **Exit criteria:**

- [x] The source archive is unpacked and its contents catalogued → `docs/source-inventory.md`.
- [ ] `src/platform/platform.h` exists and is written from *this* port's boundary.
- [ ] The Amiga build links: `out/Vette.exe`, with `muldiv-audit` and `probe-audit` clean on every
      link.
- [ ] A headless FS-UAE run reports a real framerate on an `FPSCOUNT=1` build and `painted=0` on a
      plain one — i.e. display takeover, the VERTB handler, the copper list and the frame pump are
      verified **on the target**, not assumed from the inherited docs.
- [ ] The standing checks from `docs/amiga-lessons.md` exist as counters and `.gdb` scripts.

⭐ Do not skip the last two. Revs's Phase 0 is the reason its Amiga side was never in doubt while
harder questions were being settled.

## Phase 1 — The Macintosh reference loop

**Exit criteria:**

- [x] An emulator is chosen and installed (**MAME 0.289 / `mac2fdhd`**) and driven headlessly.
      ⚠ From a documented invocation, not yet from a `make` target.
- [x] A framebuffer capture at a named moment, reproducibly — and re-rendered host-side from the
      live PixMap + CLUT, diffed against MAME's own screenshot.
- [x] Memory reads from a script (Lua). ⚠ **Breakpoints + register reads are NOT exercised yet**,
      and that is the capability the trap inventory runs on.
- [x] A scripted input sequence that reaches the game, deterministically — boot → launch → garage
      screen, unattended. ⚠ Not yet *gameplay*: the driving view has never been reached.
- [x] ⭐ A **positive control** in every capture — completion is read from `CurApName` in the Mac's
      own low memory, so a run that did nothing reports "Finder" instead of passing quietly.

⛔ **The one thing still open here is the A-trap log** (`docs/open-work.md` #1) — without it Phase 2's
trap map is a static guess.

⚠ **This gates Phase 2.** Revs proved its memory image against real hardware in Phase 1 and then
discovered in Phase 2 that the image had been the wrong input all along. The reference is what makes
that discoverable.

## Phase 2 — Complete static map

**Exit criteria:**

- [ ] Every `CODE` resource extracted and disassembled; the `CODE 0` jump table read out in full.
- [ ] The **trap map**: every `$Axxx` site, with the manager, the routine and the selector.
- [ ] The **low-memory map**: every absolute reference below `$0C00`.
- [ ] The **A5 world**: the application globals, named as far as the code supports.
- [ ] The entry-point sweep, cross-checked by two independent methods.
- [ ] One concentrated naming pass — rough but directionally correct, in `symbols.csv`.
- [ ] Static coverage: how many bytes are unclassified, honestly counted.
      ⚠ **A number that improves because the tool got looser is worse than no number**
      (`docs/method-lessons.md`).
- [ ] Findings written to `docs/static-map.md` (to be created) and the `[ASSUMED]` rows in
      `docs/mac-hardware.md` replaced with `[DERIVED]` ones.

## Phase 3 — The trap layer

The phase with no counterpart in either prior port at this size. **Exit criteria:**

- [ ] Every trap in the inventory either serviced or **loudly reported** — never silently absorbed.
- [ ] The unknown-trap reporter exists and is read on every run.
- [ ] The timing and entropy sources identified and implemented as what they actually are (a clock
      is a clock, not a call counter).
- [ ] ⚠ The inventory re-checked **by running it**. It is a floor until then.

## Phase 4 — End-to-end skeleton on the target, then profile, then set a target

- [ ] The game reaches its first real frame on the Amiga.
- [ ] A phase-share profile with its accounting check printing ~100% every run.
- [ ] **Only then**: a performance target, argued from that profile and from the original's own
      framerate under the reference loop.

⚠ Postmortem §4.1. Do not set the target earlier, and do not quote the Mac's framerate as the
Amiga's.

## Phase 5 — Render + input

- [ ] The display architecture decided **from measurement** (`docs/mac-hardware.md` question 5).
- [ ] Input mapped; the one-button mouse's second button and the keyboard assigned deliberately.
- [ ] A framebuffer differential against the reference loop — the gate that settles "faithful or
      port bug?".

## Phase 6 — Optimisation

- [ ] Shape-probe before optimising (`docs/perf-method.md` Rule 4).
- [ ] Representation before asm — asm written against an arrangement that is about to change has to
      be rewritten.
- [ ] Hand asm only where the C floor is provably GCC's floor, verified with an in-process
      differential.

## Phase 7 — Packaging

- [ ] WHDLoad slave, or an equivalent. RoF's `docs/whdload-slave.md` is the worked example.
- [ ] Machine requirements stated from measurement.

---

## ⚠ A coverage question hides behind an apparently complete one

⚑ Revs's most expensive structural lesson, and it transfers directly: five phases of green
measurements were **all** one session type, because the other one was gated behind a flag nobody
had set — and the first run of the other mode hung immediately on a bug that had been latent the
whole time.

**When the target has modes, enumerate them and ask which code each one EXCLUDES.** For a driving
game that means: every track/course, every difficulty, every race type, the practice/qualify/race
split, split-screen or two-player if it has one, and every menu path. Grep for the flag that gates
the branch; it finds the untested subsystem faster than any amount of frame-staring.
