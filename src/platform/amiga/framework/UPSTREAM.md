# Framework upstream

Vendored from **dA JoRMaS / Template / C++**, by way of the *Revs* port
(`~/Documents/Revs/src/platform/amiga/framework`, copied 2026-09-16) — which had itself taken it
from the *Rescue on Fractalus!* port. Taking it from Revs rather than from the original template is
deliberate: Revs's copy already carries the vasm-sanitised asm and the GCC marshalling bridges, and
those were the expensive part.

Classes included: `AmigaHardware`, `Bitmap`, `CopperList`, `Sprite`, `Palette`, `Util`.
Support files: `SASCCompat.h`, `compat-include/`.

**Local changes on vendoring into this repo (all mechanical):**
- `REVS_*` macros → `VETTE_*` (`VETTE_SASC_ALIAS`, `VETTE_BLIT_IRQ`).
- `revs_mulu16`/`muls16`/`divu16`/`modu16`/`divs16`/`mods16` → `vette_*`, and `m68k_math.h` moved
  from `src/cpu/` (which this port has no use for — there is no CPU to emulate) to `src/`.
- `BitmapAssembler.s`'s two non-interleaved arms: the comments claimed the arms were unreachable,
  which was true of *Revs*'s screen and is **unproven here**. Retagged `[ASSUMED]` — they are still
  silent no-ops, and that has to be closed before the first real screen.

**Hand-written m68k asm** (inherited as vendored by Revs): `UtilAssembler.s`,
`AmigaHardwareAssembler.s`, `BitmapAssembler.s`, `CopperListAssembler.s` — the dA JoRMaS originals
with the **dotted-in-middle local labels sanitised** for vasm
(`sed -E 's/([A-Za-z0-9])\.([A-Za-z_][A-Za-z0-9_]+)/\1_\2/g'`, e.g. `cl.cpu`→`cl_cpu`), because
vasm mot reads a leading `.` as a local-label marker. Assembled by `vasmm68k_mot -m68010 -Felf`
(the only >68000 instruction is `movec vbr,d0` in `getVBR`, which the C++ `getVBR` already emits as
raw bytes through `Supervisor()`). GCC reaches them through register-marshalling bridges under
`#if defined(ASSEMBLER) && !defined(__SASC)` in the matching `.cpp`s; `AmigaHardware.h` aliases the
blitter-queue statics to their SAS/C mangled names (`VETTE_SASC_ALIAS`) so the asm's `xref`s
resolve. `Palette`/`Sprite` have no asm counterpart (pure C++ everywhere).

**Omitted intentionally:**
- `ModulePlayer` / `TrackerPackerReplayV3.1` — audio backend undecided; Vette's Mac original drives
  the Sound Manager, so whatever replaces it is a Sound Manager reimplementation, not a tracker.
- `Production`, `Part`, `Script`, `ProductionRunner`, `ExampleProduction`, `ExamplePart` — replaced
  by the `main()` + `AddIntServer` + `while(!quit)` skeleton both prior ports used.
- `GCCRuntime.cpp` — the modified version lives in `../GCCRuntime.cpp` (no `ProductionRunner`
  dependency; VBI via `AddIntServer`).
- SAS/C artefacts: `smakefile`, `*.info`, `SCoptions`, `Debug/`.

Build with plain `make` from `amiga/` (ASSEMBLER on by default — `Util.h` defines it for GCC too,
which the inherited `SASCCompat.h` comment denied; corrected on vendoring).
`make CPPFLAGS+=-DNO_ASSEMBLER` forces the portable C++ bodies and skips the vasm step.

## ⚠⚠ LATENT LINK TRAPS, inherited and VERIFIED HERE (2026-09-16)

Found by partial-linking the framework on its own (`ld -r` over the ten framework objects, which
does not garbage-collect). Both were **dormant** in the same way: `--gc-sections` drops the
referencing function while nothing calls it, so the link is clean until the first caller arrives —
at which point it fails, or worse, fails an audit for a reason that looks unrelated.

1. ✅ **FIXED — `AmigaHardware::isLongFrame()` had an ASSEMBLER bridge with no asm behind it.**
   `AmigaHardware.cpp`'s `#if defined(ASSEMBLER) && !defined(__SASC)` body did
   `jsr _isLongFrame__13AmigaHardwareFv`, and **no `.s` in this framework defined that symbol** —
   `AmigaHardwareAssembler.s` has `getVBR` and `isBlitterBusy` but not `isLongFrame`; the SAS/C
   `__asm` declaration had nothing behind it either. ⇒ the first call was an undefined-symbol link
   error, and only an interlaced display needs the field parity, so it stayed dormant for years.
   **Fix:** `isLongFrame()` is out of the bridged set on both compilers and always the C++ body —
   one `VPOSR` bit-15 test, which the bridge could not improve on. ⭐ Feed this upstream.
2. **`Bitmap::patternWithMask()` pulls in `__mulsi3`** — a 32-bit software multiply, which the
   68000 does not have and which `make muldiv-audit` fails the link over by design.
   ⇒ **the first call to `patternWithMask()` breaks the mandatory audit**, and the audit message
   will name `__mulsi3`, not the caller. If the port needs that method, convert its arithmetic to
   `src/m68k_math.h`'s 16-bit helpers first.

## ⭐⭐ `setPlayfield()` — THREE DEFECTS FIXED, and they are upstream's to take (2026-09-17)

Both `AmigaHardware::setPlayfield()` and `CopperList::setPlayfield()` accepted an `interlace`
argument and `(void)`-discarded it, so **LACE (BPLCON0 bit 2) was never written** and the
interlaced row modulo was never added; `AmigaHardware`'s also hardcoded the display window to the
full 320-lores screen whatever the width, and used the *lores* DDF formulas in its "hires" branch.
Every value is now derived from the arguments per the **Amiga Hardware Reference Manual ch. 3**
(ADCD 2.1, `REFERENCE/HTML/HARDWARE_MANUAL_GUIDE`), including a computed DIWHIGH — which must be
written, not inherited, because on ECS/AGA it overrides DIWSTOP's H8/V8 rules and stays written.
⚠ The **AGA** DDF branch is untouched and `[ASSUMED]`: FMODE 3 fetches four words per access and the
documented OCS formulas do not apply to it. `docs/amiga-arch.md` §`setPlayfield()` has the full
derivation and the measured evidence.

