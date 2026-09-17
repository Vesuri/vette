# Amiga OCS lessons — inherited, hard-won, still true

> ⚑ **Carried over from the *Rescue on Fractalus!* and *Revs* Amiga ports.**  These are properties
> of OCS hardware and of the vendored dA JoRMaS framework, not of those games, so they apply here
> unchanged.  Each one cost a real debugging session there.  Worked examples name RoF/Revs code
> (`RevsScreen`, the band cycle, `tick_wheel_spin`, …) — read them as evidence, not as references
> to anything in this tree.
>
> ⚠ The standing checks these lessons prescribe are named after the prior ports' probe scripts
> (`amiga/beam_watch.gdb` / `g_beamPresentsLate`, `amiga/fill_catch.gdb`).  **Nothing in
> `amiga/*.gdb` exists in this repo yet** — porting the standing checks is Phase 0 work, and a rule
> here that says "this counter must read 0" is an instruction to build the counter.
>
> Read this before writing or changing a copper list, a sprite, or anything in the VBI.

## Copper

### Colour-register writes are IMMEDIATE
There is **no** one-scanline pipeline latency on OCS colour registers.  A copper `MOVE` to
`COLORxx` takes effect at the next pixel the beam draws.  (An earlier note claiming a one-line
latency, and a "colours one line early" two-WAIT scheme built on it, were both wrong.)

**Correct horizontal colour split:** `WAIT` for the **end of the *previous* scanline** — an hpos
out in the right border / H-blank — then issue the MOVEs there.  They land during H-blank, so
the new palette is active for the first visible pixel of the target line.

```c
// region B starts at raster line R:
d[idx++] = copperWait(R - 1, 0xE0);   // end of previous line, in overscan
d[idx++] = copperMove(bpl1pth, ...);  // pointers FIRST (timing-critical)
d[idx++] = copperMove(color00, ...);  // colours after (immediate)
```

**Pointers before colours, deliberately:** if pointers miss the H-blank window the whole display
goes off (wrong DMA address); a late colour is a cosmetic few-pixel edge artefact.  `0xE0` is a
right-border hpos — tune ~`0xC0`–`0xE2`, never past the max H-count or the copper hangs until
line wrap.

### …EXCEPT when the colour change itself is the visible thing
A region's bitplane-pointer MOVEs (6 for a 3-bitplane region) after the `WAIT(line-1, 0xE0)`
**overrun ~16 px into the region's first line**.  So a colour that must land on the region's
FIRST pixel needs its own copper slot placed **before** the pointers.  Otherwise you get a ~16 px
stripe of the previous colour.  (RoF: a teal stripe at the windscreen band top, commit 8481ec0.)
- To make a shared/optional copper MOVE a **no-op**, retarget it to an unused pen (`color31`,
  `$1BE`).

### ☠ An all-zero copper word HALTS the copper
`0x00000000` is `MOVE #0 -> register $000`, below the CDANG threshold: the copper **stops for the
rest of the frame**.  Everything below that word freezes on whatever pointers and modulos were
last set.

**Symptom: the ENTIRE screen renders with the topmost region's bitplane parameters** — no
mid-screen modulo, no viewport.  It looks exactly like a bitmap/geometry bug, so you hunt in the
wrong file.  The cause is one `data_[INDEX_x] = ...` that nothing wrote.

The framework's `CopperList` constructor now pre-fills every slot with a copper NOP
(`copperMove(0x1FE, 0)`) before the layout is built, so a forgotten slot costs one copper cycle
instead of the display.  **Do not "optimise" that loop away.**  It does not excuse an unwritten
slot — a NOP where a MOVE belonged is still a missing colour or pointer — it just stops the
failure being catastrophic and misleading.  For a fixed-layout list built by scattered `INDEX_*`
writes, whenever you add or re-home a slot, **check both ends**: the new slot is written AND the
old one still is.

### The `d[0]` preamble belongs to the constructor
`CopperList::CopperList` already writes `data_[0] = copperWait(16, 0)` and the terminating
`data_[length-1] = copperWait(255, 254)`.  Per-frame builders start at `idx = 1` and must not
re-write `d[0]`.  (Chip RAM is not zeroed, so the preamble matters — but it is a one-time job.)

### A VARIABLE-length list must terminate right after its content
`d[idx++] = copperWait(255,254);` at the end of the builder.  Double-buffered lists rebuilt at
different lengths per frame will otherwise run into each buffer's **stale trailing instructions**
from a previous longer frame — which differ between buffers and so **flicker every frame**.
Relying on the constructor's terminator at `length-1` only works while the length is constant.

### Mid-screen band splits
1. **Pointers FIRST after every WAIT**, before bplcon0/modulo/colours.  Too many MOVEs before the
   pointer writes pushes them past display-fetch start, and that band sits at a constant
   horizontal offset.
2. **One WAIT per scanline — skip zero-height bands.**  When an animated band shrinks to 0 rows
   its WAIT collides with the next band's on the same line: the copper does the first block, the
   second WAIT is already satisfied, and its pointer writes run into the visible area.  Detect
   the degenerate case and emit one band; drop a band whose WAIT comes within ~2 lines of the
   next fixed WAIT and let the neighbour cover it.

### Bitmap height must exactly match the display region
`new Bitmap(data, w, h, …)`: `h` = the number of display lines the copper gives that region, no
more.  Oversizing achieves nothing and hides issues.

## The pointer-swap rule (the one that costs a whole frame)

> **Copper bitplane POINTER swaps happen in the VBI ISR, never mid-frame.**

Poking a **live** list's `BPLxPT` words at an arbitrary beam position can coincide with the
copper fetching them → a **torn pointer** (new hi word + old lo word) → wrong DMA address → the
whole viewport garbages for one frame.  Symptom: an intermittent flash of the wrong colour
"every now and then".

The working shape: the main thread paints the off-screen buffer, publishes it, raises a
`volatile swapPending` flag, then busy-waits; the VERTB ISR rewrites the `BPLxPT` words at
vblank START — before the beam reaches the region's `WAIT` — and clears the flag.  The busy-wait
doubles as the frame sync.

⚠ **DEAD END:** deferring the poke to *after* the VBI wait is NOT enough — it still races the
copper's own fetch and desyncs which buffer is displayed.

**Colour-only mid-frame pokes are tolerable** (a torn colour is invisible for one frame).
Pointer pokes are not.

### ⭐⭐ "In the VBI ISR" is not the same as "in the vblank" — Revs, 2026-08-14
The rule above says *where in the code*; what it means is *where the beam is*.  Those coincide
only while the handler is **shorter than the blank**, and this port's VERTB handler is not: it
runs the game's whole 50 Hz body (the IRQ1V band cycle, ending in `tick_wheel_spin`) before
it got to the swap.  Measured with two `VPOSR`/`VHPOSR` reads at the swap itself: **49 of 49
presents at raster line 46-149, every one inside the 44..251 display window** — while the handler
was being *entered* at line 1 every time, 0 late.  The body costs only a few milliseconds, and a
few milliseconds is a hundred scanlines.

Consequence, and it is worse than a torn pointer, because the same call also rebuilt the palette
bands: **a rewritten `WAIT` whose line is already behind the beam blocks the copper until the
next field, so every band after it is skipped** and the rest of the screen keeps the previous
band's colours.  In Revs that painted a black or green run across the horizon, appearing and
disappearing frame to frame — read for a week as a bug in the game's own fill.

Two things follow:
- **Do the copper work FIRST in the handler, above any game work.**  One field of extra latency
  in a frame that takes fifty of them.
- ⚠ **A frame-boundary dump CANNOT see this.**  The list you dump after the field is consistent;
  the damage was the copper's *execution* of it.  Twelve consecutive clean captures preceded an
  obviously broken screen.  The instrument for a raster race is the beam position at the write
  (`amiga/beam_watch.gdb`, `g_beamPresentsLate` — a standing check that must read 0), not the
  bytes afterwards.

### ⭐⭐ In INTERLACED mode the VBI's LOF read names the field that is ENDING — Vette, 2026-09-17

A handler that re-points bitplanes per field has to know which of the two row sets to name, and
`VPOSR` bit 15 (LOF, set for the long field) is the only source.  The obvious code —
`if (isLongFrame()) point at the long field's rows` — is **backwards**.  The copper list the
handler writes is not re-fetched from `COP1LC` until the top of the *next* field, and by the time
the VERTB handler runs LOF already names the field whose vertical blank this is.  Invert the test.

⚠⚠ **And no probe can catch it**, which is why it is here.  Nothing blanks, tears or drops: both
fields still display, each simply showing the other's rows.  A long/short field ratio — the
standard headless proof that LACE is alive at all — reads exactly 0.500 with the polarity right
*and* wrong.  **A measurement of *whether* the fields alternate cannot measure *which is which*.**
On the glass it shows as **doubling**: every thin horizontal feature repeated one scanline down, so
one-pixel text is unreadable while a solid picture just looks soft.  Put it on a human-eyeball
checklist and say what to look for, rather than trusting it to look right.

### `SPRxPT` operands obey the same rule, with an earlier deadline
The copper executes a list's sprite-pointer MOVEs at **scanline 16** (`d[0] = copperWait(16,0)`),
and the sprite's control-word DMA fetch is at **~scanline 25**.  So a per-frame `SPRxPT`
re-point must be final before line 16, and the control words it points at before line 25 —
i.e. **in the VBI ISR, not the render pass**.

⚠ **The A500's slow render HIDES a violation.**  A render-pass publish "a frame ahead" looks
correct on the target because the slow render lands it late in the frame.  RoF's starfield did
exactly this: measured beam line 78–307 on A500+ (safe) but **5–117 on a 68040, with 31 of 32
advances at line ≤16**.  Past the deadline the copper latches the new pointer in the SAME frame
while the control words still sit at the old slot → the sprite fetches PIXELS as its control
words → garbage VSTART/VSTOP.
**Method:** stamp the beam line at the write, count the ones past the deadline, and **re-run on
a faster CPU** — `AMIGA_MODEL=A1200 EXTRA_ARGS=--cpu=68040 ./diag_run.sh 40`.  A1200 alone was
NOT enough (it measured min line 18 and reported zero violations); the 68040 made it fire.

### A list that starts MOVING pointers must become double-buffered
…and **the poke-on-change cache goes with it.**  A "last value written" cache compares against
the *live* list while you are now writing the *back* one, whose contents are two frames stale —
so unchanged slots silently keep the wrong value.  Write every dynamic slot unconditionally; for
a ~25-MOVE list that is nothing.

### An immediate `COPJMP1` (swap NOW) is safe ONLY at vblank, in the VBI ISR
`setCopperList(cl, /*immediate=*/true)` sets `COP1LC` **and** strobes `COPJMP1`, so the copper
jumps to the new list's top immediately.  From the VBI ISR the beam is parked at the top of the
frame, so the new list's sprite MOVEs run before the beam reaches the sprite fetch.  A
**mid-frame** immediate COPJMP smears the sprites: the new list's sprite MOVEs are already past
the beam, so the old sprite DMA keeps drawing for the rest of the frame.

### Copper lists install at the TAIL of the render pass
A list built during a frame must be handed over at the end of that render, not partway through —
otherwise the copper picks up a half-built list.

## Sprites

### Hardware sprite CHAINING beats a copper re-point for vertical reuse
Two sprites laid back-to-back in ONE chip buffer — `[ctrlA][dataA][ctrlB][dataB][0,0]` — let a
single channel display both: after VSTOP the DMA fetches the next two words as new control
words straight out of the buffer.  **No copper words, and therefore no arming deadline.**
(`Sprite::allocateChain(hA, hB, &a, &b)` / `freeChain`; both Sprites are non-owning views, so
the caller releases the buffer.)

⚠ **The second sprite's VSTART must be STRICTLY GREATER than the first's VSTOP** — the control
re-fetch happens ON the VSTOP line, so an exactly-adjacent VSTART races that line's compare.
Give it a line of slack and eat the lost scanline.

⚠ **Double-buffering a chained channel duplicates the whole chain**, second sprite included.
Cheap when the element is a build-once solid whose only per-frame change is `setY` — mirror the
two control words each frame and the pixels only on the one-time fill.  Do NOT memcpy the whole
block per frame (that was ~1% of wall clock).

### Priority is NOT a general way to hide a sprite
Over a **pen-0 playfield pixel a sprite wins at EVERY BPLCON2 value**.  COLOR00 is the
background; there is no priority code that puts the playfield in front of a sprite where the
playfield draws nothing.  A sprite overhanging its intended window can only be hidden where the
bitmap has a non-zero pen — anywhere else, blank the sprite's own pen for those scanlines (or
end the sprite).

## Write-only registers

### BPLCON2 is per-SCENE state with no owner
Sprite-vs-playfield priority **persists across copper lists**.  A list that emits no `$104` MOVE
does not get "unchanged" — it gets whatever the previous scene left.  On RoF that meant a scene
inheriting PFxP=4 (all sprites in front of the playfield) and drawing a gauge over the cockpit —
and it looked right on a fresh boot, where `initialize()` had just set it by hand.

**Treat every write-only display register as scene state with a NAMED owner.**  The "emit only
what the original's interrupt handler emits" rule keeps lists minimal but says nothing about who
owns a register no list touches.

**Don't cache a write-only register's value.**  A "last value we wrote" shadow goes stale the
moment a copper list moves the register, and then it suppresses exactly the corrective write it
guards.  One 16-bit store is cheaper than reasoning about who wrote it last.

**Measuring one:** a **68000 read of `$DFF104` returns the FLOATING BUS** (measured `ffff`,
`7f81`, `6441` on successive frames) — an Amiga-side probe of it measures nothing.  **gdb's**
read of the same address under FS-UAE does return the stored value.  Cross-check by reading
`$DFF100` BPLCON0, which must come back as the live list's bitplane word.
⚠ And use **two marker functions, not one with a tag argument** — a gdb breakpoint fires at
function ENTRY, so a marker that records "which call am I" in its own body reads one call stale.

## Interrupts

### Work in the vblank ISR is capped at ONE FRAME
Over that, a displayed frame is silently dropped — and the dropped frame (a stall, a 2×
animation jump, a copper write landing behind the beam) is what the user reports, not the cost.
Bracket any ISR-side work with VPOSR/VHPOSR beam-line reads before theorising.  On RoF a 19.7 ms
decode in the vblank ISR dropped a displayed frame; a long keyboard busy-wait starved the VBI
spin into a deadlock.

### The VERTB vector takeover
Replacing exec's VERTB `IntVector` wholesale (rather than `AddIntServer`-ing onto its chain)
drops graphics.library / gameport.device / timer.device off the vblank — measured **~780 µs per
20 ms frame ≈ 3.9% of all wall clock**.  Two consequences:
- **The handler must clear `INTREQ` itself** (exec's chain walker used to do it).  Miss it and
  level 3 re-triggers forever.
- **`WaitTOF()` no longer works** — it is signalled by graphics.library's VERTB server.  Wait on
  your own vblank counter instead, and hand the vector back BEFORE the closing `LoadView` /
  `WaitTOF` pair on the way out.

### Mask blit-done for the takeover window
Nothing in a port like this consumes blit-done; every armed one is a level-3 dispatch into
graphics.library's queue handler doing nothing for you (measured ~6 per render iteration ×
~52 µs).  Save `INTENAR`, mask `INTF_BLIT`, drop any latched request, and restore verbatim on
exit (the OS needs it back for QBlit).

### ⭐⭐ The ISR must not see a HALF-BUILT scene — and a non-null pointer is not "built"
**Measured 2026-08-15, and it presented as a black screen that looked exactly like a hang.**
The VERTB vector is taken over ~40 lines *before* `scene.initialize()` runs, so the handler is
already firing at 50 Hz while the scene is being constructed — and construction is full of OS
calls (`AllocMem` for ~50 KB of chip RAM, `OpenResource`, `AddICRVector`) that comfortably span
a vblank.  `RevsScreen::initialize()` assigns `m_copper` / `m_ttCopper` / `m_ttBitmap` the
instant each allocation returns, ~40 lines before it fills either copper list in.  A VERTB
landing in that window ran `applyMode()`, found the machine in MODE 7, **latched
`m_ttOnScreen = 1` and installed the still-empty teletext list**.  `initialize()` then finished
by writing the race list and installing it with its four pens deliberately black — and because
the latch was already set, `applyMode()` never switched again for the rest of the run.

Two things make this expensive to find, and both are the lesson:
- **`if (!m_copper) return;` reads like the guard for exactly this and is not.** A non-null
  pointer means the allocation returned, nothing more.  The guard has to be a flag set on the
  LAST line of `initialize()` (`m_built`), so every early `return` leaves it clear.
- **Every probe read healthy.** The teletext page in `mem[]` was byte-correct, `mode7=1`,
  `planes=3`, `height=250`, `ttAllocFailed=0`, `unknown=0`.  What gave it away was that the
  probe set was INCOHERENT rather than wrong: `g_screenBytes`/`g_screenCopperAddr`/
  `g_screenFrontAddr` held race-view values (16640 / `m_copper` / `m_bitmap[0]`) while
  `planes`/`height`/`mode7` held teletext ones — i.e. two writers had interleaved.  A probe dump
  is worth cross-checking for internal consistency, not just for plausible individual values.
  (`g_ttModeDisagree` also read 9, which was the one honest complaint in the set; it is 0 now.)

The fix is at the platform layer — publish `s_scene`/`s_platform` to the ISR only after BOTH
`scene.initialize()` and `input.initialize()` — with the `m_built` flag as the structural guard
so a future reordering cannot reintroduce it.  Reordering *inside* `initialize()` is not a fix:
"allocate, then build" is unavoidable.

### Don't take over PORTS (level 2)
Tried and rejected on RoF: the chain is `ciaa.resource` plus FS-UAE's host-filesystem trap
server, and starving that trap server makes FS-UAE **reset the machine**.  Measured cost of
leaving it alone: ~0.3% of wall clock.

## Keyboard
CIA-A serial-port ICR handler; the keycode is `ROR(~SDR, 1)` and the handshake needs ~85 µs.

## vasm

`-no-opt` is **load-bearing** (it keeps hand-written encodings exactly as written), which means
**hot in-range branches must be hand-marked `.s`** or they assemble as long branches.

## Include-order trap (found while scaffolding this port)

`framework/AmigaHardware.h` `#define`s bare register names (`bplcon0`, `vposr`, `dmaconr`, …) as
offsets, and those collide with the `struct Custom` **members** in `<hardware/custom.h>` — a
header the graphics includes pull in.  **Every system header first, `AmigaHardware.h` last.**
