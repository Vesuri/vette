# Amiga architecture decisions

> ⚑ Carried over from the *Rescue on Fractalus!* and *Revs* ports, where each of these was chosen
> with a measurement behind it.  The rationale is kept because it is what stops the decision being
> re-litigated.  ⚠ **Nothing here is implemented in this repo yet** — `src/platform/amiga/` holds
> only the vendored framework and the GCC runtime shim.  Read this as the shape `PlatformAmiga.cpp`
> should take when Phase 0 writes it.

## Display: takeover, not OS-friendly

- `LoadView(NULL)` + `WaitTOF()` × 2 to suspend the OS display.
- Our own copper list pointed at by `COP1LC` directly (not `MakeScreen`/`LoadRGB4`).
- `*dmaconPointer = DMAF_SETCLR | DMAF_MASTER | DMAF_COPPER | …` — copper DMA only at first;
  bitplane/blitter DMA enabled as needed.
- On exit: restore the saved DMA/interrupt masks, `LoadView(savedView)`, `WaitTOF()` × 2, close
  libraries.

**Why takeover:** a port like this needs per-scanline copper rewrites (colour splits, sprite
pointer patches) every frame.  The OS-friendly route (`OpenScreen CUSTOMBITMAP` +
`AddIntServer`) re-inserts the system copper list after every `WaitTOF`, which would clobber ours
or require `MrgCop` overhead.  Takeover also lets us write Paula registers directly instead of
going through the audio device.

⚠ Order matters at bring-up: install the copper list **while display DMA is off**.  Enable copper
DMA before the scene's one-time register setup and the OS copper will run through it and
intermittently reset those registers — a bug that only shows up when an OS-copper frame happens
to land after your write.

## VBI: take over the VERTB IntVector

Not `AddIntServer(INTB_VERTB, …)`.  Replacing exec's `IntVector` wholesale drops
graphics.library / gameport.device / timer.device off the vblank — measured **~780 µs per 20 ms
frame ≈ 3.9% of all wall clock** on the Atari port.

Two obligations that come with it, both of which will bite immediately if missed:
- **The handler must clear `INTREQ` itself.**  Exec's chain walker used to do that; miss it and
  level 3 re-triggers forever.
- **`WaitTOF()` stops working** (it is signalled by graphics.library's VERTB server).  Wait on
  your own vblank counter, and hand the vector back *before* the closing `LoadView`/`WaitTOF`
  pair.

A `VERTB_SERVER=1`-style A/B fallback to the old `AddIntServer` chain is worth keeping for
bisecting an interrupt-delivery regression.

### ⭐⭐ …but the GAME BODY does NOT run in that handler (Revs, 2026-08-14, measured)

⭐ **The general rule, before the worked example: if the original machine ran its periodic body
once per DRAWN frame and the port draws far slower than the original, the body must not run in the
port's vblank ISR.** It will run many times per painted frame and the renderer will be drawing a
scene that changes under it. Drive it from main-loop context at the points where the game is
provably not drawing. ⚠ Whether this applies to Vette depends on what its Mac original does per
frame and how far off 1:1 the Amiga framerate lands — it is a question to answer in Phase 0, not an
assumption to inherit.

The Revs evidence, because the failure mode is hard to recognise from the symptom:
the obvious shape — Amiga VERTB drives the game's own IRQ1V band cycle, whose last band is
`tick_wheel_spin` — is what that port shipped first, and it produced a visible
artefact roughly once a minute: one or two display lines drawn with the road's left edge tens of
pixels off, leaving grass green where the road belongs.

**Why, and it is not a bug in anything.** The body *draws*: it writes the frame buffer at
`$6E00-$70FF`, display lines 120-143 — the road just below the horizon. On a BBC the main loop is
vsync-locked, so the body runs **once per drawn frame** and always at the same point in the drawing
sequence. Here a frame takes ~50 fields, so the body ran ~50 times per painted frame, landing
anywhere: the rasteriser was drawing a scene that changed under it, and the decode was reading one.
Measured over 198 painted frames with the body in the ISR: **238 frames where a character row moved
under the decode, 327 line-instances where the decoded bitplanes no longer matched `mem[]`**, plus
the green/black horizon runs. Everything else was provably intact — A/X/Y preserved, flags
preserved, the two-level-RTS flag preserved, zero page untouched by the body (it writes exactly one
byte there, `$FC`, and that is the port's own ISR shim), no writes to the engine's code, the column
sources or the `$7B00` overlay.

**The model now:** `Revs::vbi()` *counts* fields; `Revs::drainTicks()` runs them, from main-loop
context, at the two points where the engine is provably not drawing — its own frame hook (`$1701`,
before the decode) and its own frame-wait spin (`$1760`, which is exactly where a BBC's main loop
sits waiting for this interrupt). Same 50 ticks per second of wall clock, same fixed-step
trajectory; what changes is only that the drawing is atomic with respect to them. After: **0 rows
moved, 0 decode mismatches, 0 horizon runs**, and the reporter stopped seeing broken frames.

`make BODY_IN_ISR=1` restores the old model for A/B; `amiga/fill_catch.gdb` is the detector.
⚠ As the framerate rises the burst shrinks — at 25-50 FPS it is one or two ticks per frame, i.e. it
converges on the BBC's own interleaving rather than diverging from it.

`Forbid()`/`Permit()` around the whole run window: nothing here needs exec's scheduler and we
never `Wait()`.  ⚠ Everything between them must be `Wait()`-free — the `WaitTOF()` pairs and every
library open/close stay outside.

## Two-layer split

| Layer | Source | What we take |
|---|---|---|
| **Hardware** | dA JoRMaS Template/C++ (vendored, `framework/`) | `AmigaHardware`, `Bitmap`, `CopperList`, `Sprite`, `Palette`, `Util` — hand-written m68k asm via vasm with GCC bridges; `Sprite`/`Palette` are C++ |
| **App skeleton** | the PETSCII-Robots / WHDLoad-menu pattern | `main()` + the VBI handler + `while(!quit){poll; update; render; waitVBI}` |

Deliberately **not** used: the framework's `Production`/`Part`/`Script`/`ProductionRunner`
timeline, and its `ModulePlayer` / TrackerPacker replay.

**Audio: undecided, and structurally different from both prior ports.** Neither of them had OS audio
to reproduce in the same sense — RoF drove POKEY directly, Revs reached the SN76489 only through the
MOS sound scheduler (so `src/platform/sound.c` reproduced the *scheduler*). Vette's original drives
the **Mac Sound Manager / the Sound Driver**, which is a sampled-audio path, not a tone-generator
one — so the Amiga side is a Paula sample player, and the faithful surface to reproduce is whatever
the game asks the Mac for. Settle it when the trap sweep says which calls it makes.
⚠ Inherited placement rule that will apply whatever the backend is: audio work goes **AFTER** the
copper work in the handler, because a Paula DMA restart busy-waits on the beam and nothing that
waits on the beam may precede the copper writes.

Local modifications to the vendored framework are recorded in `framework/UPSTREAM.md` — keep that
current, it is what makes a future upstream re-sync possible.

## Build

`make` from `amiga/` (ASSEMBLER is on by default — vasm assembles the framework `*Assembler.s`;
`-DNO_ASSEMBLER` selects the portable C++ bodies).  Toolchain on PATH via `. amiga/env.sh`.

Every hand-asm twin gets a `VETTE_<NAME>_ASM` seam, a `make <NAME>_C=1` C-fallback, and a
`make VERIFY=1 PROBES=1` in-process differential — the template is in `amiga/Makefile`.
