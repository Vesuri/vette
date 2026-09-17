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

## ⭐ `setPlayfield()` COULD NOT PRODUCE THIS PORT'S MODE — the three defects, and the fix

`[MEASURED]` by reading both implementations, building the mode by hand, and then re-deriving the
framework's formulas from the **Amiga Hardware Reference Manual ch. 3** ("Forming a Basic
Playfield", ADCD 2.1 `REFERENCE/HTML/HARDWARE_MANUAL_GUIDE`).  Three defects, the first of the
dangerous kind — all three are now **fixed in the vendored framework** rather than routed around
(`src/platform/amiga/framework/UPSTREAM.md` carries them for upstream):

1. ⭐⭐ **Both took an `interlace` argument and both `(void)`-discarded it.**  Neither ever wrote
   BPLCON0's LACE bit (bit 2), and neither added the extra row of modulo an interlaced field needs
   — each field displays every *other* row, so the modulo has to skip one ("you use a modulo of 40
   to skip the lines in the other field", HRM §Modulo in Interlaced Mode).  `PROJECT.md` locks this
   port's display to **4 bitplanes, hires interlaced**, so the call would have produced a plausible
   half-resolution picture out of 320 rows of data with nothing reporting a problem — exactly
   `CLAUDE.md`'s "a silent no-op is the most expensive translation choice", inside the framework
   rather than in our own code.
2. **The DIW window was hardcoded to 320 lores / 640 hires** (`0x81`…`0x1c1`, DIWHIGH `0x2100`),
   and `height` was taken as field lines whatever the mode.  ⚠⚠ **DIWSTRT/DIWSTOP are ALWAYS in
   lores, non-interlaced units** — "if you select high resolution mode or interlaced mode, the
   starting position does not change" (HRM §Setting Display Window Starting Position) — so a hires
   width halves and an interlaced height halves *before* reaching the display window.  It now
   derives both corners from `width`/`height`/`centerY` and centres them in the standard window.
3. **The hires DDF pair used the LORES formulas.**  DDFSTRT trails HSTART by 4.5 colour clocks in
   hires against 8.5 in lores, and the fetch steps 4 clocks per word against 8:
   `DDFSTRT = DDFSTOP - 8*(words-1)` lores, `= DDFSTOP - 4*(words-2)` hires (normal pairs
   `$38/$D0` and `$3C/$D4`).  The old "hires" branch produced the *lores* `$38`, i.e. eight hires
   pixels of every line fetched before the window opened: a picture shifted left with its last word
   cut off.

⚠ A fourth, found while fixing the third: **DIWHIGH must be computed and written, never inherited.**
On ECS/AGA it carries the ninth horizontal and upper vertical bits of *both* corners and overrides
the old rules (DIWSTOP H8 forced to 1, V8 the complement of V7) — and once anything has written it,
it stays written.  Kickstart's own copper list writes `$2100`, but a takeover must still derive
that value rather than inherit it. `VetteScreen` now also writes `$2100`, derived from its 512×384
corners.
⚠ The **AGA** DDF branch is left exactly as inherited and is `[ASSUMED]`: FMODE 3 fetches four
words per access, the documented OCS formulas do not apply, and nothing here exercises it.

**Who owns the registers:** still `src/platform/amiga/VetteScreen.cpp`, the **single owner** of
BPLCON0-3, FMODE, DIWSTRT/DIWSTOP/DIWHIGH, DDFSTRT/DDFSTOP and BPL1MOD/BPL2MOD.  Two reasons
survive the fix — it centres the [MEASURED] 512×320 Macintosh surface inside the chosen 512×384
Amiga display, and this port pins FMODE to 0 so an AGA machine fetches like an A500, which
the framework's AGA branch deliberately does not.  ⭐ But the two derivations are no longer
independent: `VetteScreen.cpp` `static_assert`s its constants **against the framework's formulas**,
so a future change to either one fails the build instead of moving the picture sideways on the glass.

### ⭐ The interlaced-field arithmetic, since it is not obvious

One PAL field carries **half** the picture.  With the rows interleaved (all 4 planes of row *y*,
then all 4 of row *y+1*; stride 256 B), the long field's plane *k* starts at `base + k*64` and the
short field's at `base + 256 + k*64`.  A bitplane pointer advances 64 B as it fetches a line, and
must reach the same plane **two** rows down, so `BPL1MOD = BPL2MOD = 2*256 - 64 = 448`.
The pointers are re-pointed **first** in the VERTB handler, every field.

⚠ **`AmigaHardware::isLongFrame()` did not LINK** — in the ASSEMBLER configurations it was declared
`__asm`/bridged and `jsr`ed `_isLongFrame__13AmigaHardwareFv`, a symbol no `.s` ever defined, so the
*first* caller was an undefined-symbol link error and only an interlaced display needs the field
parity.  **Fixed** by taking it out of the bridged set altogether: the body is one register read and
a bit test (`VPOSR` bit 15), and it is now unconditional on both compilers.

⚠⚠ **AND THE POLARITY IS THE OPPOSITE OF THE OBVIOUS READING OF LOF** — `[MEASURED]`, on the
glass, after shipping it the other way round first.  LOF (`VPOSR` bit 15) is set for the long
field, so `if (isLongFrame()) use the long field's rows` looks right and is wrong: by the time the
VERTB handler runs, the bit already names **the field whose vertical blank this is**, while the
copper list the handler is writing is not re-fetched from `COP1LC` until the top of the **next**
field.  So the test must be inverted — `LOF set` here means *the short field is next*.
⚠ **Nothing headless can catch this.** It does not blank, tear or drop a frame, and the long/short
ratio stays exactly 0.500 either way, because both fields are still being displayed — just with
each other's rows.  What it looks like on the glass is **doubling**: every thin horizontal feature
repeated one scanline down (the intro's one-pixel copyright overlay was unreadable), and a solid
picture merely looking soft.  ⭐ The general lesson is in `docs/amiga-lessons.md`: a probe that
measures *whether* the two fields alternate cannot measure *which is which*.

### ⚠ How the field parity is verified, and the wrong answer it gave twice

There is no headless screenshot on FS-UAE, so the program records what it did and
`amiga/stage_a.gdb` reads it (§Build).  **Not** by reading BPLCON0 back: it is write-only and
reads as `0xFFFF`, a test that can never fail.  The evidence is the long/short **field ratio**,
which a display that ignored LACE cannot produce — plus the raw VPOSR words, which separate "LACE
is dead" (a constant `A000`) from "the read is wrong" (`FFFF`).
⚠⚠ **And the ratio must be counted from when the mode registers are written, not from boot.** The
VERTB vector is ours ~68 fields earlier, while the display is still the OS's non-interlaced one
where LOF is always 1.  Measured over the whole run that read **0.636** — not 1.0, so it does not
look dead; not 0.5, so it does not look right either.  Counted from the takeover it is 0.500.

### ⭐ The picture on the glass — `[MEASURED]`, and it took a human plus a screenshot

The last part of Stage A that no probe could reach.  Measured off an FS-UAE **Full**-frame capture
(754×576 — the whole PAL frame at hires × interlaced resolution, so one captured pixel is one
displayed pixel), by taking the bounding box of everything that is not border:

| | measured | wanted |
|---|---|---|
| window size | **512 × 320** | 512 × 320, the `[MEASURED]` Macintosh window |
| horizontal centre | lores **289** | 289 — the centre of the standard PAL window `$81..$1C1` |
| vertical centre | line **172** | 172 (`VS_CENTER_Y`) |

So the mode is 1:1 and undistorted: no clipped row or column, no doubled or dropped line, square
pixels (hires × interlaced), and the window centred where the derivation put it.
⚠ **Do not read the capture's own margins as off-centring.** They are asymmetric — 138 hires px of
border on the left, 104 on the right — because FS-UAE's capture region starts at lores hpos 92 /
line 26 and is itself 8.5 lores left of the standard window's centre.  Derive the window's position
from the *register units* the bounding box implies, not from the PNG's margins.

⭐⭐ **Two defects were found here and NEITHER was visible to any headless check** — the Macintosh
cursor composited into the captured asset, and the interlace field polarity inverted (§above).  That
is the argument for keeping a human-eyeball step with a written list of what to look for, rather
than treating a green probe run as the end of a display bring-up.

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

## ⭐ Chunky → planar: what Kalms' collection does and does not give us

⭐ **This port is a c2p problem** in a way neither prior port was: the game's drawing surface is
**chunky 4 bpp, two palette indices per byte, high nibble = left pixel** (`docs/mac-hardware.md`),
and the Amiga is planar. `https://github.com/Kalmalyzer/kalms-c2p` is the reference collection
(public domain outside its `others/` subdirectory).

⭐ **There IS a 4-bitplane routine: `normal/c2p1x1_4_c5_gen.s`** (plus a 2-bitplane one). Signature
`c2p1x1_4_c5_gen(void *chunky in a0, void *bitplanes in a1)` after a `_init(chunkyx, chunkyy,
scroffsy)`. ⚠ The collection targets **68020-68060**, CPU-only — consistent with our locked
hires-interlaced/AGA mode, and a reminder that an OCS/68000 fallback gets no help from it at all.

⚠⚠ **But its input is ONE BYTE PER PIXEL, low nibble used — not our packed two-per-byte.** `[DERIVED]`
from the source: `_init` computes `mulu.w d0,d1` (width × height, no halving) and stores that as a
**byte** count which the main loop adds straight onto the source pointer as an end sentinel; the
inner loop fetches eight longwords per pass and emits 32 pixels, so 32 source bytes → 32 pixels.

⭐⭐ **And here is the trap worth knowing before anyone "just skips the first stage".** The routine's
own first step is a nibble merge, which looks exactly like what our data already is:

```
move.l  (a0)+,d0        ; Merge 4x1
lsl.l   #4,d0
or.l    (a0)+,d0
```

⚠ It is **not** the same packing. That pairs pixel *i* with pixel *i+4* — the first longword's four
pixels against the *next* longword's four — because the later transposition stages are built around
that shuffle. Ours pairs **adjacent** pixels. So our format is neither the routine's input nor its
first intermediate, and entering one stage in would transpose the picture wrongly while still
producing a plausible-looking image. `[DERIVED]` from those three instructions, **not yet run.**

⭐ **How to settle it cheaply when it matters:** the repo ships a `_test.c` per routine. Feed it a
known ramp and read the planes back — that answers the pairing question by measurement instead of by
reading shifts, and it is the kind of thing to do *before* building on the answer.

⚠ **So the options are re-derive the early merge stages for nibble-packed input, or pre-expand
nibbles to bytes** (doubling source reads and the buffer). ⛔ **Do not pick one by argument.** Both
are measurable, and the measurement belongs in the optimisation phase, not in front of the first
frame. ⚠⚠ **Nor is it yet known that c2p is on the critical path at all** — if the driving view is
built from QuickDraw primitives, a planar-native trap layer skips chunky entirely
(`docs/open-work.md` §"The two display questions that are still open").

## Two-layer split

| Layer | Source | What we take |
|---|---|---|
| **Hardware** | dA JoRMaS Template/C++ (vendored, `framework/`) | `AmigaHardware`, `Bitmap`, `CopperList`, `Sprite`, `Palette`, `Util` — hand-written m68k asm via vasm with GCC bridges; `Sprite`/`Palette` are C++ |
| **App skeleton** | the PETSCII-Robots / WHDLoad-menu pattern | `main()` + the VBI handler + `while(!quit){poll; update; render; waitVBI}` |

Deliberately **not** used: the framework's `Production`/`Part`/`Script`/`ProductionRunner`
timeline, and its `ModulePlayer` / TrackerPacker replay.

**Audio: Bogas-driven intro cues over four Paula voices.**

⚠⚠ **CORRECTED.** This section originally said Vette's original drives the Mac Sound Manager / Sound
Driver directly, making it structurally unlike both prior ports (RoF drove POKEY directly; Revs
reached the SN76489 only through the MOS sound scheduler, so `src/platform/sound.c` reproduced the
*scheduler*). The resource inventory says otherwise: `VETTE!.Data` ships **`BGAS 128
"Bogas Driver v2.1"`** plus 16 named `INST` samples — 72% of the whole data file — and the `sound`
code segment is **732 bytes in both builds**.

The `sound` segment is now disassembled far enough to identify its 12 exported wrappers and command
block. The intro opens three Bogas contexts, resolves the named instruments during initialization,
and sets one-shot globals immediately after each load. The current Paula seam follows those original
flags for `Opening song`, `cable car bell`, `Engine`, `mic`, and `Signature`, so cues stay synchronized
with the original animation state. Music occupies a centred pair and loops; the remaining pair layers
effects over it. This is intentionally the measured intro surface, not yet a claim that every Bogas
command needed by the driving game has been reproduced. → `docs/source-inventory.md` §Audio.
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
