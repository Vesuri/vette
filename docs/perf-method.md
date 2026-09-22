# Performance method — how to get a number you can trust

> ⚑ **Method inherited from the *Rescue on Fractalus!* (Atari) and *Revs* (BBC) ports.** Every rule
> below was learned by getting a number wrong first, on **this target with this toolchain**, so it
> applies here unchanged.
>
> ⚠⚠ **What is deliberately NOT carried over is the NUMBERS.** `~/Documents/Revs/docs/perf-method.md`
> is ~1500 lines of Revs's own measurements — a frame budget, a phase→function map, a view-pipeline
> ledger. None of it describes Vette, and Rule 3 below says an old number is wrong even within one
> project. Read it as a **worked example of the method** (it is the best one that exists), never as
> a figure to quote. This file will grow its own numbers section once there is something on the
> target to measure.
>
> Companions: `docs/m68k-optimisation.md` (what to do once you know where the time goes),
> `docs/headless-fsuae.md` (how to drive the target), `docs/method-lessons.md` (how to work at all).

## The target machine

**A1200, 14 MHz 68020, PAL, 2 MiB chip RAM and 8 MiB fast RAM.** A field is 20 ms. The display is
interlaced, so two fields make one complete 512×384 raster. Units: one PAL raster scanline is about
64 µs and a field is approximately 313 lines. Be conscious of absolute milliseconds, always — a
percentage of an unknown total is not a measurement.

⚠ **This project starts from a 68000 original, which is new and cuts both ways.** The Mac Plus/SE
the game targeted is a 7.83 MHz 68000, while the package target is a faster 68020. Unlike the two
prior ports there is therefore a *real* performance reference: the original's measured cadence
provides a lower-bound expectation for the resident instructions. That makes a large shortfall diagnosable
(it is the seam, the display conversion or the trap layer, not "the algorithm") and it makes the
target arguable rather than a pure scope call. It does **not** license quoting a Mac number as an
Amiga measurement: the Mac's 1-bit 512×342 display and the Amiga's planar bitmap are different
amounts of work, and that difference is the port.

## The target

The moving-driving fidelity workload must complete with a median interval of at most 12 Macintosh
ticks, a 95th-percentile interval of at most 15 ticks, and no more than twice the captured Macintosh
median. The reference median is 6 ticks; the production A1200 median is 9. The target therefore
passes while acknowledging that presentation makes the Amiga behave like a somewhat slower Mac.
This is a cadence ceiling, not a demand for lockstep Traffic phase or an arbitrary 50 FPS claim.

## Vette measurements

### 2026-09-21 — first full-accounting moving-driving profile

`make driving-profile` starts its counters immediately after the first completed driving update and
freezes them after 300 PAL fields. It has no debugger stop inside the window. The timer combines the
VBI field epoch with VPOSR/VHPOSR at 1/256-scanline resolution; the empty bracket runs at the same
rate as trap classification.

On the target A1200 configuration, the six-second window contained ten presentation calls and eleven
published-frame boundaries. The exclusive shares were:

| Phase | Beam ticks | Share | Approx. ms per presentation call |
|---|---:|---:|---:|
| Resident game and callbacks | 3,269,061 | 13.603% | 81.7 |
| Drawing traps | 1,362,931 | 5.671% | 34.1 |
| Resource traps | 33,724 | 0.140% | 0.8 |
| Audio shim | 0 | 0.000% | 0.0 |
| Other compatibility work | 55,892 | 0.233% | 1.4 |
| C2P, back-buffer synchronization and palette | 19,310,267 | 80.353% | 482.8 |
| Display back-pressure | 0 | 0.000% | 0.0 |
| **Accounting** | **24,031,875** | **100.000%** | **600.8** |

The nested VBI diagnostic is 0.322%; the empty-bracket control is 0.035%. The first optimization
target is therefore the presentation path, not resident road logic or PICT decoding. These are
probe-build attribution numbers, not shipping-build framerate numbers.

### 2026-09-21 — remove synchronization fully covered by C2P

A focused 100-field baseline separated the presentation row: copying the previous dirty rectangle
from front to back consumed 39.711% of the complete window, while conversion and palette work used
38.236%. All four updates covered the complete 512×320 surface, so each 81,920-byte synchronization
copy was immediately overwritten by C2P.

`presentMacFrame` now omits that copy only when the new normalized dirty rectangle fully contains
the pending synchronization rectangle. Partial updates retain the old path. In the matching short
run the synchronization row is exactly zero and six rather than four updates fit in the window.
Those update counts describe different amounts of advancing game state and are not claimed as a
controlled speed ratio; the deleted row itself is the priced work. A capture of the second driving
conversion after the omission decodes all 163,840 planar pixels back to their simultaneous chunky
source with zero differences (`amiga/driving_planar_check.gdb` and
`tools/verify_driving_planar.py`).

### 2026-09-21 — 68000 C2P row kernel

The retained 4 KiB pixel-pair table is already the right representation: four lookups transpose
eight chunky pixels into four complete plane bytes. The generated C loop, however, repeatedly
reconstructed the four table bases and used long shift/extract sequences for the scattered plane
stores. `C2P.s` keeps the table quarters in address registers and performs one tight group loop;
`C2P_C=1` retains the C oracle.

The `VERIFY=1 PROBES=1` in-process differential runs assembly and C back-to-back on identical rows
and the same chip-RAM destination. It compared 2,874,776 output bytes across 12,123 spans with zero
failures. The C oracle used 34,854,037 beam ticks against assembly's 26,764,037, a C/assembly ratio
of 1.302. In the matching 100-field full profile, presentation time per full conversion fell from
888,137 to 708,861 beam ticks (20.2%); seven instead of six updates fit in the window. The in-process
ratio is the controlled kernel result; the advancing-state window is supporting end-to-end evidence,
not a claimed cross-run speed ratio.

### 2026-09-21 — packed-input Kalms word-write adaptation

The closest stock routine in Mikael Kalms' public-domain collection is
`special/c2p1x1_4_c5_word`: a four-plane CPU5 converter whose word writes are specifically intended
for OCS/ECS chip RAM. It does not directly accept this game's pixels, however. Kalms expects one
byte per pixel and separated planes, while Vette supplies two four-bit pixels per byte and this
display keeps the four planes 64 bytes apart inside each scanline.

The unmodified shuffle was tested rather than assumed faster. Expanding only each dirty row to an
8-bit fast-RAM scratch row and then invoking Kalms compared 971,016 plane bytes with the C oracle
without a mismatch, but used 12,381,373 beam ticks against the oracle's 11,828,747: 4.7% slower
even before considering a second framebuffer. That exact integration was discarded.

The retained adaptation applies the part that fits the target: Kalms' word-write strategy. The
packed table kernel now converts 16 pixels per iteration, interleaves the two four-plane byte sets
in registers, and performs four chip-RAM word writes instead of eight byte writes. It remains
68000-compatible and requires neither an unpacked surface nor a display-layout change. The
in-process differential compared 257,528 output bytes with zero failures; the C oracle used
3,134,605 ticks against assembly's 2,143,492, a ratio of 1.462. Normalized through the same C
oracle, that is about 11% less kernel time than the previous 1.302-ratio byte writer. In the
supporting 100-field profile, seven full conversions used 4,602,903 ticks, or 657,557 per call,
down from 708,861 (7.2%); eight rather than seven advancing updates fit in the window, so only the
back-to-back ratio is the controlled comparison.

### 2026-09-21 — 32-pixel longword C2P batches

The same packed kernel now combines two 16-pixel results once more and writes one 32-pixel
longword to each plane. A separate word-write tail preserves the existing 16-pixel dirty-boundary
contract, so narrow drawing does not convert an enlarged rectangle merely to suit the fast path.
The verifier exercised both paths and compared 722,008 output bytes with zero failures. The C
oracle used 9,046,373 beam ticks against assembly's 5,264,348, a ratio of 1.718. Normalized through
the oracle, this is another 14.9% kernel reduction from the 1.462-ratio word-only implementation.
The supporting 100-field profile recorded eight full conversions in 4,474,820 ticks, or 559,353
per call, also 14.9% below the previous 657,557. C2P plus palette now occupies 55.945% of that
advancing-state window; synchronization remains zero.

### 2026-09-21 — split the remaining presentation cost

The profiler now brackets C2P and palette construction independently inside the existing inclusive
presentation scope. In the fixed 100-field A1200 window, eight calls attribute 4,443,105 ticks
(55.955%) to C2P, 19,084 (0.240%) to palette construction, 3,249 (0.041%) to presentation overhead,
and zero to both synchronization and back-pressure. Accounting remains exactly 100%. The next
presentation experiment therefore belongs in conversion or its source/destination representation;
palette caching cannot materially change this workload.

### 2026-09-21 — renderer-derived driving dirty rectangles

The game's completed driving frame is not the full 512x342 GWorld transport that `_CopyBits`
publishes. The outside view occupies `(0,0)-(198,512)`, while two Traffic segment packed-rectangle
writers receive the independently changing dashboard and mirror bounds in registers. Private Line-A
entry hooks record those bounds and emulate the displaced shift. A typical completed frame contains
the outside view plus thirteen dashboard/mirror rectangles. Only containment or exact rectangular
adjacency is coalesced; arbitrary overlaps cannot inflate into a larger bounding box. There is no
shadow framebuffer and no tile map.

The first completed driving frame remains full-size so both-buffer history has a defined base. The
profile begins after the following partial update has paid that one-time synchronization cost. In
the warmed 100-field target-A1200 window, nine calls used 3,779,452 C2P ticks (47.429%), or about
419,939 per call. The preceding full-frame profile used 4,443,105 ticks over eight calls, about
555,388 per call, so the advancing-state evidence shows 24.4% less conversion time per call.
Synchronization used 7,933 ticks (0.100%); palette used 19,056 (0.239%); presentation overhead used
20,438 (0.256%). The hooks increase the broad compatibility row to 364,116 ticks (4.569%, 457 calls),
so reducing their dispatch cost is a possible follow-up. Accounting is exactly 100%.

This optimization has two independent correctness checks. `amiga/driving_planar_check.gdb` captures
the second conversion and `tools/verify_driving_planar.py` compares all 163,840 pixels with zero
differences. `FILLWATCH=1` then samples eight rows per update; 40 frames covered all 320 rows with
zero bad frames and zero bad pixels.

### 2026-09-21 — lightweight raster-bound capture

The first dirty-list implementation sent every `$AFFD` marker through the complete Line-A C++
dispatcher. The handler now recognizes that private word before its general register save, appends
the D4/D3/D1/D2-derived rectangle to a 64-entry fast-RAM buffer, emulates `ASL.L #2,D2`, and returns
directly. Overflow saturates the count and makes the next boundary request a full conversion, so
lost bounds cannot produce stale pixels. Coalescing happens once at the completed-frame boundary.

The captured presentation list is unchanged: thirteen dashboard/mirror rectangles plus the outside
view. Both the complete second-frame comparison and the 40-frame rolling audit remain pixel-exact.
In the warmed 100-field profile, general compatibility dispatches fall from 457 to 25 and that row
falls from 364,116 ticks (4.569%) to 192,036 (2.418%). The two advancing runs performed different
amounts of C2P work, so their total elapsed times are not treated as a controlled speed comparison;
the removed dispatcher call count and within-run accounting are the defensible evidence.

### 2026-09-21 — four-pixel C2P lookup

The packed-input kernel formerly performed sixteen 32-bit fast-RAM table reads for every 32
pixels: four positional byte lookups for each eight-pixel result. A 256 KiB fast-RAM table now
maps four packed pixels to four plane nibbles, so two lookups plus one shift/OR produce the same
eight-pixel result. The source remains Vette's packed-nibble surface, dirty bounds remain aligned
to 16 pixels, and the destination remains the same interleaved four-plane chip buffer. No shadow
surface or tile representation was added.

The in-process verifier compared 2,748,000 output bytes with zero failures. Against the same C
oracle, the new kernel's ratio is 1.976 versus 1.718 for the preceding 32-pixel longword version;
normalizing through the oracle gives about 13.1% less kernel time. In the warmed 100-field A1200
profile, ten calls use 3,685,815 ticks, or about 368,582 per call, compared with the previous
419,939. That supporting moving workload is a 12.2% reduction per call; C2P is now 46.297% of the
window. The ordinary build pays no verifier or probe cost, but does reserve the 256 KiB table in
the configured 8 MiB fast memory.

### 2026-09-21 — A1200 scaled C2P indexing

The four-pixel table exposed one remaining address-generation cost: the 68000-compatible kernel
shifted every 16-bit index, copied the table base, and added the offset before each lookup. The
supported package target is the A1200, so `C2P.s` alone is now assembled for 68020 and uses its
scaled long-index addressing. All Macintosh code and other port assembly retain their existing
68000/68010 settings.

The in-process verifier compares 3,243,112 bytes with zero failures. Its C/assembly ratio rises
from 1.976 to 2.521, which normalizes to 21.6% less kernel time. The warmed 100-field A1200 profile
records 3,326,465 C2P ticks over eleven calls, about 302,406 per call: 18.0% below the immediately
preceding 368,582 measurement. C2P is now 41.532% of the window, and twelve completed frames fall
inside it versus ten in the previous advancing-state run; only the verifier ratio and per-call C2P
cost are treated as controlled evidence.

### 2026-09-21 — CopyBits split and rejected dirty publish

A nested profile bracket isolates the implemented `_CopyBits` body from its Line-A dispatch and
bookkeeping. In the restored generic-path 300-field A1200 run, CopyBits consumes 2,914,419 of
2,957,204 drawing ticks over 32 calls: 98.6% of the row, about 91,076 ticks per call. Dispatch and
other drawing overhead is only 42,785 ticks. This identifies a single measured owner rather than a
collection of QuickDraw primitives.

The source GWorld uses 260-byte rows while the logical screen uses 256-byte rows, so the existing
full 512×320 publish is necessarily a 320-row copy. A tested alternative used the renderer's exact
dirty information: 512×198 exterior rows plus clipped, losslessly coalesced dashboard/mirror
bounds. It transferred 1,963,323 bytes in 434 rectangles over 31 measured calls—about 63.3 KiB and
14 rectangles per update instead of 80 KiB. `FILLWATCH=1` compared the resulting chunky screen
against the strided source GWorld and then the planar display against that screen; 40 frames and
all 320 rows had zero bad frames or pixels.

Despite moving 20.7% fewer bytes, the rectangle path used 3,296,008 ticks over 31 calls, about
106,323 per call: 16.7% slower than the generic full copy. The extra clipping, coalescing, and many
short row spans outweighed the byte saving in fast RAM, so the implementation was removed. This is
a closed negative result; the retained CopyBits bracket will price a representation or transfer
change without reopening that design on intuition.

### 2026-09-21 — Fixed-stride driving publisher

The retained full publish has one stable shape: copy 256 visible bytes from each of 320 source
rows, advancing the source by its four-byte QuickDraw padding. A 68000 assembly twin performs that
transfer as eight unrolled longword moves per 32-byte group. Eligibility remains strict—matching
rectangles, `srcCopy`, no mask, 260/256-byte strides, the logical-screen destination, and matching
ColorTable seeds—so every other CopyBits operation still takes the generic implementation.

The in-process verifier ran the generic C oracle and assembly path on the same 25 moving publishes,
compared all 2,048,000 destination bytes, and found zero failures. It measured 2,205,266 C ticks
against 932,036 assembly ticks, a 2.366 ratio. `FILLWATCH=1` then checked 40 consecutive frames and
all 320 displayed rows with zero bad frames or pixels. In the standardized 300-field profile the
CopyBits core is 1,293,230 ticks over 34 calls, about 38,036 per publish versus the previous 91,076;
the complete drawing row falls from 12.342% to 5.554%. C2P is now again the largest port-owned row
at 41.385%, so it is the next measurement target.

### 2026-09-21 — C2P destination and coverage split

`C2P_SPLIT=1 PROBES=1` runs every normalized rectangle through the same assembly routine twice,
first into the real chip-RAM back buffer and then into an equivalently aligned fast-RAM buffer.
The timed inputs, table, geometry, row stride, and instruction path are identical; only the write
destination changes. It also counts post-alignment/post-coalescing pixels and rectangles.

Over 106 moving frames and 952 rectangles, the real destination used 25,459,010 ticks and the fast
destination 16,977,889 ticks, a 1.500 ratio. Thus fast-RAM transpose/table work is about two-thirds
of the current C2P cost, while the additional chip-RAM write penalty is about one-third. The same
sample converts 104,792 pixels per frame, 63.960% of the 512×320 surface, in 8.981 rectangles per
frame. Dirty coverage is already materially below a full frame; the next optimization should target
the transpose/lookup instruction path rather than inflate or replace the dirty representation.

A direct Kalms-style scheduling experiment then retained the same lookup and transpose but wrote
two planes, performed the next fast-RAM lookup pair, and wrote the remaining two planes. It stayed
byte-exact across 2,684,832 output bytes, but the controlled C/assembly ratio fell from 2.521 to
2.315. The extra first/final-batch loop structure cost more than any chip-slot overlap saved, so the
change was removed. Do not reintroduce write pipelining without a structure that also reduces the
instruction count.

### 2026-09-21 — pre-shifted C2P lookup

Each eight-pixel result previously loaded two entries from the four-pixel table, shifted the second
longword right by four, and ORed it into the first. The ordinary build now spends another 256 KiB
of the configured 8 MiB fast RAM on a second copy whose results are pre-shifted during startup.
The packed source, dirty rectangles, bitplane layout, and four chip-RAM writes per 32 pixels are
unchanged; the inner loop simply reads the second half at a fixed table offset and omits the shift.

The in-process C oracle compared 2,685,680 output bytes with zero failures. The controlled
C/assembly ratio improves from 2.521 to 2.798, which normalizes to 9.9% less kernel time.
`FILLWATCH=1` checked 40 consecutive frames and every one of their 320 rows with zero bad frames or
pixels. In the standard 300-field driving profile C2P uses 9,766,871 ticks over 35 updates, about
279,053 per update versus 292,221 in the preceding 34-update run, a supporting 4.5% reduction.
C2P remains the largest port-owned row at 40.647%; the complete profile still accounts for exactly
100% of elapsed beam time.

### 2026-09-21 — signed C2P table indexing

The 68020 sign-extends a scaled word index, while the logical lookup index is unsigned. The prior
kernel therefore cleared its index register before all eight table reads in every 32-pixel batch.
Both 65,536-entry tables are now physically rotated by 32,768 entries and addressed from their
midpoints. The signed range then covers the complete table directly, removing those eight clears
without adding storage or changing the converted pixels, dirty rectangles, or chip writes.

The C oracle compares 2,685,632 output bytes with zero failures. Its controlled C/assembly ratio
rises from 2.798 to 2.927, equivalent to another 4.4% reduction in kernel time. The framebuffer
guard again checks 40 frames and every one of their 320 rows with zero bad frames or pixels. The
standard 300-field profile records 9,384,319 C2P ticks over 36 updates, about 260,675 per update
versus 279,053 before the change, a supporting 6.6% reduction. C2P occupies 39.097% of the fully
accounted window.

A subsequent 64-pixel unroll targeted the full-width outside-view rectangle by expanding the
32-pixel body twice per loop and retaining 32- and 16-pixel tails. It remained exact across
2,684,832 output bytes, but the controlled C/assembly ratio regressed from 2.927 to 2.711. The
doubled body and additional tail dispatch outweighed the saved loop branches, so the experiment
was removed and the 32-pixel loop restored.

## Lessons — measurement

- **Compare FPS row vectors, never a `total painted` line.** A total spans a partial trailing row
  and the run length in vblanks varies between otherwise-identical runs. Under a pinned RNG + warp
  a per-segment series is deterministic row for row — the resolution limit is one painted frame,
  not run-to-run variance, which is what makes a small (~1-3%) change quotable at all if enough
  rows are averaged.
- **Never diff a phase-bracket share across builds** — only within one run (Rule 2).
- **Calibrate a new bracket against a known cycle count before trusting what it reports.** Burn N
  known cycles inside it and check linearity in N. An uncalibrated bracket can look several times
  more expensive than the instruction count predicts, and the gap is usually arithmetic on the
  reader's side, not an instrument fault.
- **A beam-tick bracket must accumulate through a monotonic epoch, not a raw
  `beamTick() - beamTick()` difference** — a raw difference silently discards any bracket that
  straddles the once-per-display-frame wrap, and it discards the LONGEST phases hardest. A profile
  that reads several rows as flat zero is this bug, not evidence those routines are trivial.
- **Every instrument needs a cheap total-accounting check, printed every run.** One division
  (bracketed ticks vs elapsed ticks, "MUST be ~100") would have failed loudly on the first run of a
  profile that instead published an inverted hot-path ranking for two phases.
- **Size a routine's call count while the game is DOING SOMETHING, not parked.** A parked call count
  next to a driving framerate describes two different workloads.
- **`make clean` before every differently-flagged build.** The Amiga Makefile tracks neither
  `PROBES` nor a define change — a stale object reproduces the PREVIOUS build's number to the
  digit, which is the tell that a rebuild didn't happen.
- **Match the build to the control.** A `PROBES=1` build is meaningfully slower on its own merits;
  never compare a probe-build number to a shipping one.
- **Put no gdb stop inside a measurement window.** A conditional breakpoint that halts the machine
  to evaluate its own condition can bias a reading by an order of magnitude in either direction,
  and can agree with the truth on one build while being wildly wrong on another. Sample from an
  in-program counter instead.
- **An average over calls that do materially different jobs hides the finding.** Bracket each arm
  separately, and add an **empty-bracket control running at the same call rate** before trusting
  any number a new bracket reports — a bracket's own overhead can exceed what it measures.
- **Bound a measurement window in EMULATED time, not host time.** Under warp the host's throughput
  depends on what else the machine is doing, so two arms of one A/B can cover very different
  amounts of game time out of the same wall-clock window. Freeze the accumulators after N display
  fields and print the proof that the freeze fired.
  ⚠ And a partial freeze is its own trap: anything bumped outside the frozen accumulators keeps
  climbing, and a row mixing the two is fiction.
- **Prove the flags reached the build.** A shell that eats all but the first `VAR=1` produces a
  perfectly plausible table for a configuration you did not build. Print the build's own flag
  bitmask in the probe header and read it.

## Lessons — implementation

These are the ones that are about the 68000 and GCC, so they transfer intact. (The prior ports'
lessons about *transliterated 6502* — flag chains, `bus_read` hoisting, driver twins — do not apply
here: there is no interpreter to delete. That is the single biggest difference in this project's
performance shape, and it means **the machinery-overhead lever that dominated both prior ports does
not exist here**. Expect the time to be in the display conversion and the trap layer instead.)

- **A parameter that is a compile-time constant at every call site must be `always_inline`d, or it
  is a memory operand in the inner loop.** A descriptor struct left out of line costs a reload of
  its fields on every call; inlining turns them into immediates and folds each specialisation's
  now-constant tests. ⭐ `always_inline` on the LEAF does not fold a descriptor — the *selection*
  must be specialised too.
- ⚠⚠ **Making a hot routine SMALLER can revoke its inlining and cost more than the edit saved.**
  GCC's inlining threshold is part of the change in both directions. **After any size-changing edit
  to a hot function, count `jsr <hot-leaf>` in the objdump and require 0.**
- ⭐⭐ **A hot loop's state lives in MEMORY if anything takes its address.** Grep a hot kernel for
  `n(a5)` / `n(sp)` / `pea` before calling its shape clean; hand small results back packed in one
  register instead. ⚠ But **packing is not free**: the 68000 has no byte-insert, so each pack is
  ~40 cycles ≈ 2-3 stack reloads. **Count packs against reloads in the objdump — a per-LOOP-ITERATION
  reload is the prize, a per-CALL one is already nearly free.**
- ⚠ **Instruction count is not the scoreboard.** A memory operand is 16-20 cycles against 4-8 for a
  register op, so a bigger routine is routinely a faster one.
- **On a register-poor machine a stack slot is a legitimate home for a loop invariant.** Rank
  reloads **per iteration of the HOT PATH**, never stack-slot operands per loop, and identify that
  path from a census before believing a static ranking.
- **Read the objdump of a hot loop before theorising about its algorithm.** A loop-invariant
  re-read per iteration, or pointers spilled into data registers, is worth single-digit percent of
  a whole frame and is invisible to any amount of algorithm reasoning.
- **A loop is not free where the original unrolled.** Rolling an unrolled chain into `for` recovers
  legibility but pays real per-iteration cost.
- **RAM is uniformly slow — there is no "fast RAM" on an A500.** Optimise by reducing the NUMBER of
  accesses, never by moving data to a "cheaper" buffer, and never explain a measurement with
  fast-vs-chip RAM.
- **When an expensive per-tick output is a pure function of a handful of rarely-moving inputs,
  compare inputs and reuse the previous output.** The single biggest lever found in the Revs port.
  Sabotage the reuse against the real routine's rare *moving* inputs, not just static ones.
- **Before building a representation change, ask which quantity the current cost is proportional
  to.** A change that collapses *stores* when the loop's real cost is source *reads* moves nothing.
  Settle it with a differential that strips one stage at a time, never with a plan's predicted
  before/after count.
- ⭐⭐ **Price a change with THREE numbers: what it deletes, what one unit of the new shape costs,
  and what it cannot touch.** A census of deleted work bounds the saving and says nothing about the
  replacement; a per-unit hook cannot reach per-line driver cost. Both prior ports lost a built,
  proven, measured optimisation to a missing third number.
- **Don't qualify a big state array `volatile` unless something on THIS platform actually races it.**
  The qualifier blocks every optimisation over it for a hazard that has to be demonstrated.

## Rule 1 — quote a framerate from an in-program series only

`FPS = 50 * <painted frames> / <emulated vblanks>` — painted frames per **emulated** vblank, so
host speed and the gdb stub's own slowness cancel out completely. Sample it with a series the
*program* stores for itself (the VERTB handler, every N vblanks), read afterwards; never with a
conditional-breakpoint script.

For the moving-driving fidelity workload, `make driving-cadence-compare` applies the corresponding
source-domain gate directly to completed frames. The current Macintosh oracle has a median
interval of 6 ticks (normally 6–7); the target A1200 has a median of 9 ticks (normally 9–10). The
accepted A1200 ceiling is a median of 12 ticks, a 95th-percentile interval of 15 ticks, and no more
than twice the captured Macintosh median. These are deliberately throughput bounds, not a demand for lockstep frame or
Traffic phase: C2P and presentation make the target behave like a slower CPU, while equivalent
completed game states must still render identically. The separate fully accounted 300-field
profile remains the tool for attributing that cost.

⚠ Both counters must be a linker gc ROOT (`PROBE_SYMS` in `amiga/Makefile`), or `--gc-sections`
drops the unreferenced one and gdb prints **instruction bytes** in its place — a fake measurement
rather than an obvious zero. `make probe-audit` enforces it on every link.

⚠ **Never quote a framerate from a `PROBES` build.**

## ⭐⭐⭐ Rule 1a — the framerate is quantised to `50/N`, so size a change in **ms/frame**

If `renderFrame()` presents and then spins until the vblank counter changes, a painted frame lasts a
whole number of PAL fields and the framerate can only ever be `50/N`. The spin **pads** whatever the
frame's work is up to the next field boundary, so a saving smaller than the current pad is entirely
real and entirely invisible to FPS. So is a regression.

Measured on the Revs port with a known cycle burn: **7.9 ms of real added cost read as −0.97% FPS,
75% of it absorbed by the pad** — and the same factor appeared with the opposite sign on a real
optimisation (−12.5 ms/frame read as +1.5%). Under-read **~4×** in both directions.

⇒ **The scoreboard is a phase table in ms/frame; FPS is a derived `50/N` that follows.** Give the
spin its own phase row so the absorption is visible, and size a change against
`Σ(phases) − <spin phase>`, or against the one row you changed.
⭐ The corollary is good news: the payoff is a **step function**, so every millisecond cut before a
field boundary is banked, not lost.

## Rule 2 — price a twin with an IN-PROCESS differential, never cross-run

The new implementation and the old one run back-to-back on the **same inputs in one run**,
byte-compared, with beam ticks tallied per implementation.

Cross-run comparison (build A vs build B) is **not valid by default**, and the reason is structural:
a 50 Hz interrupt asynchronous to a free-running main loop means any change in render speed shifts
the phase between them — and that shift changes what the program actually does. A number measured
on a different workload is not a comparison.

- **Pin the RNG for every perf run.** OFF by default — it removes real variety, so never judge
  *rendering or gameplay* from a pinned-RNG build.
- ⚠ The differential's metric is the **ratio**, not absolute ticks/call.
- ⚠ Run any baseline **≥2× after a rebuild** before believing a delta.
- ⚠ A bracket **includes nested callees**, so it is not that function's own cost.

## Rule 3 — every old number is wrong; re-measure

Any figure in an older note or commit was measured on a different build, probe set or workload.
**Re-measure, don't quote.** Two specific traps: probe builds are much slower than shipping ones,
and an unattended run eventually stops doing the work being measured while the vblank counter keeps
ticking.

## Rule 4 — shape-probe the algorithm before optimising it

The biggest single win in either prior port did not come from PC sampling. It came from **measuring
the distribution of a routine's own inputs** with dedicated shape counters, finding that a small
number of cases covered most calls, and specialising those. Then: prove the algebra over millions of
randomised cases **on the host**, *then* write the fast path, *then* run the on-target differential.

- A "check before drawing" scheme usually re-reads the very byte the check was meant to avoid.
- After special-casing a recursion's leaves, **re-price their parents**.
- Ask whether a "serial" accumulator really has to be serial.

## Rule 5 — interrupt work is capped at one frame

Over that, a displayed frame is silently dropped — and the dropped frame (a stall, a 2× animation
jump, a copper write landing behind the beam) is what the player reports, not the cost. Bracket any
ISR-side work with VPOSR/VHPOSR beam-line reads *before* theorising. A 50 Hz ISR is also a fixed tax
on all wall clock regardless of framerate, which makes its per-firing cost one of the few
legitimately comparable cross-build numbers.

## Rule 6 — suspect a beam-timing race? re-run on a FASTER CPU

`AMIGA_MODEL=` / `EXTRA_ARGS=` on `run.sh` and `diag_run.sh`. A slow A500 can land safely inside a
race window that a faster CPU moves a violation into. Also: quote the **duration**, not the hit
count — a beam-overlap counter can read differently on two runs of one binary.

## Reporting

Surface numbers honestly. Say which build produced them, which harness, and the window size. If a
change measures at zero, that is a result — record it as closed *on data*, and do not re-open it on
optimism.
