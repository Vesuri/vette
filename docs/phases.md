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
| 4 | **Profile an end-to-end skeleton on the target A1200** before choosing what to optimise, and before setting any performance target | `docs/perf-method.md` |

⚠ #3 replaces Revs's "the transpiler emits clean C before mass-generating". Both are the same
principle — *decide the mechanical policy before applying it 500 times* — and both are late-is-pure-tax.

---

## Phase 0 — Scaffolding

Build infrastructure only; no game code. **Exit criteria:**

- [x] The source archive is unpacked and its contents catalogued → `docs/source-inventory.md`.
- [x] `src/platform/platform.h` exists and is written from *this* port's boundary: startup asks
      only for `run()` status; takeover, display, input, audio, the Macintosh bridge, and teardown
      remain backend-owned. No 6502 bus or OS-call ABI was imported.
- [x] The Amiga build links: `out/Vette.exe`, with `muldiv-audit` and `probe-audit` clean on every
      link.
- [x] Display takeover, the VERTB handler, the copper list and the frame pump verified **on the
      target** rather than assumed from the inherited docs — `amiga/stage_a.gdb` reads
      `screenReady=1`, a chip-RAM checksum identical to the host's, and a long/short field ratio of
      0.500. ⚠ The original criterion was Revs's (`FPSCOUNT` + `painted=0`); this port has nothing
      to paint per frame yet, so the equivalent evidence is the field parity and the checksum.
      ⭐ The one part a probe cannot cover — the picture on the glass — is **also done**, and it
      found two defects no probe could see (`docs/amiga-arch.md` §The picture on the glass).
- [x] The standing checks from `docs/amiga-lessons.md` exist as counters and `.gdb` scripts.
      On the target A1200, `beam_watch.gdb` observed 32 publications at raster line 0 with
      `g_beamPresentsLate=0`; the `FILLWATCH=1` rolling audit decoded all 320 rows / 163,840 pixels
      from the planar back buffer with zero mismatches. Vette's fill invariant is the complete
      chunky-to-planar seam, not Revs's game-specific horizon fill.
- [x] The inherited framework exposes no supported-looking silent no-op. Vette's `Bitmap` API now
      constructs only row-interleaved layouts, records that invariant in a `const` member, and the
      two impossible `BitmapAssembler.s` arms execute `ILLEGAL` instead of returning success.

⭐ Do not skip the last two. Revs's Phase 0 is the reason its Amiga side was never in doubt while
harder questions were being settled.

⭐ **Phase 0 is CLOSED.** The remaining `patternWithMask()` multiplication link trap is guarded by
the mandatory link audit and remains deferred until a real caller needs that operation.

## Phase 1 — The Macintosh reference loop

**Exit criteria:**

- [x] An emulator is chosen and installed (**MAME 0.289 / `mac2fdhd`**) and driven headlessly.
      ⚠ From a documented invocation, not yet from a `make` target.
- [x] A framebuffer capture at a named moment, reproducibly — and re-rendered host-side from the
      live PixMap + CLUT, diffed against MAME's own screenshot.
- [x] Memory reads from a script (Lua), **and register reads + a working instrumentation hook**:
      `space:install_read_tap()` on the ROM's Line-A dispatcher plus `cpu.state["SP"]`, which is
      what the trap inventory actually runs on. ⚠ Debugger **breakpoints** are still unexercised
      and turned out not to be needed — ⛔ do not re-derive that route.
      ⚠⚠ Three tap gotchas each fake a clean "no traps" result: `docs/trap-log.md` §The six ways.
- [x] A scripted input sequence that reaches the game, deterministically — boot → launch → garage
      → vehicle/course selection → copy-protection answer → live driving, unattended.
- [x] ⭐ A **positive control** in every capture — completion is read from `CurApName` in the Mac's
      own low memory, so a run that did nothing reports "Finder" instead of passing quietly.

- [x] ⭐⭐ **The A-trap log** → `docs/trap-log.md`: **63 traps** called by the game's own segments,
      first-use ordered, callers resolved to `(segment, offset)` **live at the moment of the call**,
      segment bases pinned by matching each extracted resource's own bytes in memory **and** by
      requiring every resident jump-table export to fall inside the pinned span. ⭐ Arguments are
      read at the call site too, so `SetTrapAddress`'s target, `%A5Init`'s trap set and the
      `QDExtensions` selectors are measured, not open. ⚠ It is a **FLOOR** — the run reaches one
      bounded driving path, while `FRED` and `Communication` still never become resident.

⭐ **Phase 1 is CLOSED.** Phase 2's trap map is no longer a static guess; it is a cross-check of a
measurement, and `docs/trap-log.md` says what each method can and cannot see.

⚠ **This gates Phase 2.** Revs proved its memory image against real hardware in Phase 1 and then
discovered in Phase 2 that the image had been the wrong input all along. The reference is what makes
that discoverable.

## Phase 2 — Complete static map

**Exit criteria:**

- [x] Every `CODE` resource extracted and disassembled; the `CODE 0` jump table read out in full.
- [x] The **trap map**: 1,430 flow-followed `$Axxx` sites, with manager/routine names and a
      zero-mismatch gate against all 227 distinct full-intro live sites.
- [x] The **low-memory map**: 17 absolute locations below `$0C00`, with recursive,
      Ghidra-defined-instruction, and byte-verified production-patch accounting.
- [x] The **A5 world**: the application globals named as far as the code supports.
- [x] The entry-point sweep, cross-checked by CODE 0 parsing and the ten near headers.
- [x] One concentrated naming pass — 68 evidence-labelled code/global rows in
      `disasm/symbols.csv`.
- [x] Static coverage: **112,694 / 118,892 bytes (94.8%) classified; 6,198 bytes (5.2%)**
      honestly retained as mixed inline data, padding, or unreachable code.
      ⚠ **A number that improves because the tool got looser is worse than no number**
      (`docs/method-lessons.md`).
- [x] Findings written to `docs/static-map.md`; `make static-map-check` is the reproducible gate.

⭐ **Phase 2 is CLOSED.** The 5.2% residue is the coverage result, not a hidden claim of zero.

## Phase 3 — The trap layer

The phase with no counterpart in either prior port at this size. **Exit criteria:**

- [x] Every reached single-player trap is either serviced or **loudly reported**; optional UI and
      excluded communications calls retain named loud boundaries.
- [x] The unknown-trap reporter exists and is read by the event-driven production audit.
- [x] The timing and entropy sources identified and implemented as what they actually are (a clock
      is a clock, not a call counter).
- [x] The inventory re-checked **by running it** across the gameplay coverage matrix.

## Phase 4 — End-to-end skeleton on the target, then profile, then set a target

- [x] The game reaches its first real frame on the Amiga. The original resident code now repeatedly
      presents complete moving driving frames on the target A1200 configuration.
- [x] A phase-share profile with its accounting check printing ~100% every run. The first target-
      A1200 moving-driving window accounts exactly 100%; presentation is 80.353% and the same-rate
      empty bracket is 0.035% (`docs/perf-method.md`).
- [x] The performance target is set from matched moving-driving captures: median at most 12
      Macintosh ticks, 95th percentile at most 15, and no more than twice the Macintosh median.
      The current production path passes.

⚠ Postmortem §4.1. Do not set the target earlier, and do not quote the Mac's framerate as the
Amiga's.

## Phase 5 — Render + input

- [x] The measured display is 512×384, four-bitplane hires interlace, with exactly 512 pixels of
      fetch and the 512×320 game surface centred vertically.
- [x] Keyboard, keypad aliases, mouse, menus, and driving controls are deliberately mapped.
- [x] The synchronized named driving frame matches all 175,104 live indexed pixels exactly.

## Phase 6 — Optimisation

- [x] Shape-probe before optimising (`docs/perf-method.md` Rule 4).
- [x] Representation before asm — asm written against an arrangement that is about to change has to
      be rewritten.
- [x] Hand asm only where the C floor is provably GCC's floor, verified with an in-process
      differential.

The completed pass retains renderer-derived dirty rectangles and the verified 68020 packed-nibble
C2P. Further conversion work is measured optional work, not a fidelity or release blocker.

## Phase 7 — Packaging

- [x] Equivalent hard-disk package: Amiga HUNK executable, FS-UAE configuration, startup disk,
      original-data installer, checksums, and deterministic copyright-clean ZIP.
- [x] Machine requirements stated from measurement: A1200, 2 MiB chip, 8 MiB fast, hard disk,
      Kickstart/Workbench 3.1 or compatible.

---

## ⚠ A coverage question hides behind an apparently complete one

⚑ Revs's most expensive structural lesson, and it transfers directly: five phases of green
measurements were **all** one session type, because the other one was gated behind a flag nobody
had set — and the first run of the other mode hung immediately on a bug that had been latent the
whole time.

**When the target has modes, enumerate them and ask which code each one EXCLUDES.** For a driving
game that means: every shipped track/course, difficulty, session type, multiplayer mode if it has
one, and every menu path. Do not assume practice or qualifying exists when the resource/UI inventory
does not say so. Grep for the flag that gates the branch; it finds the untested subsystem faster than
any amount of frame-staring.
