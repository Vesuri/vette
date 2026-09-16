# The Macintosh side — hardware, the Toolbox, and the trap surface

> **Read this before touching the trap layer, the display, input or sound.** It is the direct
> counterpart of the prior ports' `docs/atari-hardware.md` / `docs/bbc-hardware.md`.
>
> ⚠⚠ **EVERYTHING HERE IS `[ASSUMED]` UNTIL THE BINARY SAYS OTHERWISE.** This file is seeded from
> general knowledge of the platform, which is exactly the material the postmortem warns calcifies
> into documented fact. **Every row gets replaced by a `[DERIVED]` one from the trap map
> (`make traps`) and the reference loop.** Do not build against a row that is still `[ASSUMED]`
> without saying so at the code.

## The target machine — `[ASSUMED]`, and it needs deciding, not assuming

*Vette!* (Spectrum HoloByte, 1989) shipped for the compact Macs. Which machine the 1.02 build
actually requires — a Plus, an SE, a machine with a bigger screen, 1 MB or more — is a question for
the binary and the documentation in the archive, and it matters because it fixes the reference
machine and the performance comparison.

| | Mac Plus / SE `[ASSUMED]` | A500 (the target) |
|---|---|---|
| CPU | 68000 @ 7.8336 MHz | 68000 @ 7.09 MHz (PAL) |
| Display | 512×342, **1 bit**, no colour | planar bitplanes, 320×256 / 640×256, up to 32 colours |
| Frame rate | ~60.15 Hz | 50 Hz (PAL) |
| Sound | Sound Driver / Sound Manager, sampled, ~22 kHz 8-bit, 1 channel | Paula, 4 channels, DMA-fed samples |
| Input | keyboard + **one-button** mouse | keyboard + 2-button mouse + joystick/CD32 pad |
| Memory | 1-4 MB, one flat space | 512 KB chip + slow/fast expansion; **chip RAM is what the display can see** |

⭐ **The two lines that will shape the whole port** are the display and the frame rate. 512×342×1bpp
is 21.4 KB a frame; the Amiga has no 512-pixel-wide 1-bit mode that is free, the PAL display is 256
lines tall, and 60 Hz vs 50 Hz means any animation timed in frames runs 17% slow. All three are
decisions, and all three are in PROJECT.md.

⚠ **The one-button mouse is a genuine advantage over both prior ports** — there is no analogue axis
to substitute for (Revs had to replace a uPD7002) and no two-button assumption to unpick.

## The trap surface — `[ASSUMED]` shape, `[DERIVED]` content pending

Every OS and Toolbox call is an **A-line trap**: a `$Axxx` opcode that the Mac's trap dispatcher
services. The word encodes the routine number plus flags (auto-pop, and for OS traps whether A0/D0
are preserved). **That is the port's abstraction boundary**, and enumerating it is the analogue of
RoF's hardware-access map and Revs's MOS inventory.

Managers a game of this kind is likely to reach — **a checklist for the sweep, not an inventory**:

| Manager | Why it would be called | Port consequence `[ASSUMED]` |
|---|---|---|
| **Segment Loader** | `LoadSeg`/`UnloadSeg` through the `CODE 0` jump table | either honoured, or designed away by linking every segment resident |
| **Memory Manager** | `NewHandle`/`NewPtr`/`HLock`, the heap | an allocator; ⚠ handles are double-indirect and *move* |
| **Resource Manager** | `GetResource` for `PICT`/`snd `/level data | the assets have to come from somewhere on the Amiga side |
| **QuickDraw** | drawing, `CopyBits`, regions, ports | ⭐ the largest and most likely to dominate. How much of it the game actually uses is *the* sizing question |
| **Event Manager** | `GetNextEvent`/`WaitNextEvent`, keys, mouse | maps onto the Amiga input layer |
| **Window/Menu/Dialog/Control** | any UI outside the game view | possibly large, possibly avoidable |
| **Sound** | `SndPlay`/the Sound Driver | Paula sample playback |
| **File Manager** | saves, high scores, level files | ⚠ and the *format* is then a compatibility question |
| **Toolbox Utilities / low memory** | `Random`, `TickCount`, `Ticks`, `Time` | ⭐ these are the entropy and timing sources — the analogue of Revs's VIA T2 counter, which was its only entropy and had to be a real clock, not a call counter |

⚠⚠ **The inventory is a FLOOR.** Revs's MOS surface looked closed after a static sweep and three
more calls were found by running it. Expect the same and build the "unknown trap" reporter *before*
it is needed: a named, loud report, never a silent absorb (`docs/faithfulness-seam.md` §5).

## Low memory and the A5 world — `[ASSUMED]`

- `$0000-$0BFF` is the system's low-memory globals (`Ticks`, `MouseLocation`, `ScrnBase`, `KeyMap`,
  …). A game reaching these directly bypasses the trap layer entirely, so **the sweep must look for
  absolute references into low memory as well as for traps** — otherwise a whole class of hardware
  access is invisible.
- `A5` points into the application's own globals (negative offsets) and its jump table (positive).
  ⚠ **A global here is an A5 offset, not an address** — unlike both prior ports, where a named cell
  had a fixed address. Naming the A5 world is its own pass.

## Open questions this file exists to have answers written into

1. Which Mac does 1.02 require, and is there a version that targets a larger screen?
2. What is the complete trap set, at how many sites, with which selectors? (`make traps`)
3. Does the game reach low memory or hardware (the VIA, the SCC, the sound buffer) directly?
4. How does it time itself — `TickCount`, a VBL task, a vertical-retrace interrupt, or a spin?
5. What does it draw with — `CopyBits` from an offscreen `BitMap`, direct writes to screen memory,
   or both? **This single answer decides most of the render architecture.**
6. Where is its entropy from?
7. What is in the "and extras" half of the archive — documentation, a manual, saved games? The
   manual is worth reading before the binary (RoF's `docs/manual.md` earned its place).
