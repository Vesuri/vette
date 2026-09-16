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

⭐⭐ **For the COLOR build three of those are now `[MEASURED]`, because the game states them itself
and refuses to run otherwise:** it needs **32-Bit QuickDraw** (quits without it), **more than 2 MB**
("not enough memory" at the 2 MB default; 8 MB is what the reference loop runs), and a **16-colour
screen** — the game's own words are *"Please change your Monitors setting in the Control Panel to
16 colors."* ⭐ That last one is the game declaring the 4-bitplane requirement directly, and it is
much stronger evidence than the `pltt` count it replaces. So the row below is the compact-Mac
*B&W* build's machine; the Color build is a **Mac II-class colour machine**, and the reference loop
runs it as one. → §The display surface.

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

## ⭐⭐ The display surface — `[MEASURED]` from the running original

**This section closes the old open-work #18 (“confirm the real offscreen depth”) and re-bases #16, and it supersedes every `pltt`/`PICT` inference.** The numbers
come from the Mac's own structures while `Color VETTE!` is on screen, read by
`tools/mac_probe_fb.lua`, and the pixel format is *proved* rather than read off a field — see
§How it was proved below.

| What | Value | Where it was read |
|---|---|---|
| Screen | **640 × 480**, **4 bpp**, `pixelType` 0 = **chunky / CLUT-indexed** | `MainDevice` ($8A4) → `GDevice` → `gdPMap` |
| Screen `rowBytes` | **320** — i.e. **2 pixels per byte**, no padding | same PixMap |
| Screen base | `$F9000A00`, agreeing with `ScrnBase` ($824) — the NuBus **slot 9** card's framebuffer, not RAM | PixMap `baseAddr` |
| **The game's window** | **512 × 320** of content, at screen `(64,92)`–`(575,411)` | front `WindowRecord`'s `portRect`, **and** independently the bounding box of non-desktop pixels in the framebuffer dump |
| Second window | 512 × 342 (the compact-Mac screen size), behind it | `WindowList` ($9D6) chain |
| Offscreen surface | **512 × 512, 4 bpp, `rowBytes` 260** (256 bytes of pixels + 4 of padding) | `CurrentA5` → QD globals → `thePort` (a CGrafPort) |
| Palette | **16 entries**, reloaded per scene (the intro's CLUT and the garage's differ) | PixMap `pmTable` |
| Sound | mono, active through the ~20 s intro, **silent on the garage screen** | `-wavwrite` capture |

⭐⭐ **512 × 320 in 16 colours is the number the port has to hit**, and it is an awkward one for PAL:
4 bitplanes at 512 px wide is OCS hires at its maximum depth, and 320 lines is more than a
non-interlaced PAL field shows. It is a real decision, not a formality — `PROJECT.md`, and #16.

⭐⭐ **The game composites from an offscreen GWorld with MASKS.** The 512 × 512 scratch page caught
mid-frame holds the spec panel, two gauge sprites, and a car image **with its black silhouette mask
beside it** — the classic Mac masked-`CopyBits` idiom. That is the single most useful thing learned
so far about the render architecture, because it maps directly onto the Amiga blitter's cookie-cut
mode rather than needing to be re-invented. ⚠ `[INFERRED]` that this is how the game draws
generally: one probe caught one scratch page. The trap sweep confirms it or kills it.

### ⚠⚠ The CLUT is NOT what the player saw — there is a gamma table in the way

QuickDraw's `pmTable` holds the *requested* colour; the video card's driver passes it through a
**gamma table** before it reaches the DAC. Measured against MAME's own output across all 16 entries
(48 channels): a pure power law with **γ = 1.435**, worst-case error **1/255**.

It is not a subtlety. Index 4 is `(43,43,43)` in `pmTable` and `(74,74,74)` on the glass — Amiga
`$222` vs `$444`, **a factor of two in the midtones**, and the mid-greys are most of the garage.

⭐ **Rule: derive the Amiga palette from the DISPLAYED colour, never from `pmTable` directly.** The
reference loop's screenshots are the authority; `pmTable` is the request, not the result.

### How it was proved — and the trap it was nearly lost to

`tools/mac_probe_fb.lua` dumps the live framebuffer and CLUT; `tools/fb_to_png.py` re-renders the
dump and diffs it against MAME's screenshot of the same frame. Every one of the 16 indices maps to
**exactly one** displayed colour across all 307 200 pixels (`distinct=1` for all 16), which settles
the base address, the `rowBytes`, 2-pixels-per-byte, **high nibble = left pixel** and the index order
in a single measurement. Guess any one of them wrong and the picture comes out visibly mangled.

⚠⚠ **A Mac II boots in 24-BIT MODE, so a Memory Manager master pointer carries FLAG BITS IN ITS HIGH
BYTE** (bit 7 locked, 6 purgeable, 5 resource). Dereferencing a handle without masking to
`$00FFFFFF` does not fail — it reads a wild address and formats whatever is there. The first version
of this probe reported the screen as **“12730 × −17543 px, 18923 bpp”** in exactly the same confident
tone as the correct run. **Mask every pointer that came out of a handle**, and sanity-check the
result rather than printing it.

⚠ A dump taken during the intro *animation* differs from the snapshot beside it by 40% of the
screen, which reads as a broken format guess rather than as two different moments. Probe on a static
screen and bracket the dump with snapshots.


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
5. ~~What does it draw with?~~ **Partly answered:** it keeps a 512 × 512 4 bpp offscreen GWorld of
   sprite art *with masks*, so at least some of the drawing is masked `CopyBits` compositing
   (§The display surface). ⚠ Still open: whether the driving view also goes through QuickDraw or
   writes the framebuffer directly, and that is what decides the render architecture.
6. Where is its entropy from?
7. What is in the "and extras" half of the archive — documentation, a manual, saved games? The
   manual is worth reading before the binary (RoF's `docs/manual.md` earned its place).
