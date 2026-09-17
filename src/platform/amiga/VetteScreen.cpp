/* VetteScreen — the Amiga display for Target 1 (the intro screen).  See VetteScreen.h
 * for why this file, and not the framework, owns the mode registers.
 *
 * ⚠ INCLUDE ORDER IS LOAD-BEARING.  framework/AmigaHardware.h #defines bare register
 * names (bplcon0, vposr, …) as offsets and they collide with the `struct Custom` MEMBERS
 * in <hardware/custom.h>.  Every system header FIRST, AmigaHardware.h LAST.
 */
#include <proto/exec.h>
#include <exec/memory.h>
#include <hardware/dmabits.h>

#include "framework/AmigaHardware.h"
#include "framework/CopperList.h"   /* copperMove() -- the list entries, nothing else */
#include "VetteScreen.h"

/* ---------------------------------------------------------------------------
 * The mode, DERIVED — every value below comes from the two facts above it.
 *
 * [MEASURED] the Macintosh shows the game in a 512x320 window (docs/mac-hardware.md).
 * ⭐⭐ [DECISION, PROJECT.md] the Amiga reproduces it as 4 bitplanes, hires INTERLACED:
 * hires because 512 px does not fit a 320-px lores line, interlaced because 320 rows do
 * not fit a 256-line PAL field.  So one PAL field carries HALF the picture -- 160 lines --
 * and the two fields differ only in which rows they point at.
 *
 * Horizontal.  The standard 320-lores window is [129, 449); ours is 512 hires = 256 lores
 * wide, centred in it: HSTART = 129 + (320-256)/2 = 161 = 0xA1, HSTOP = 161 + 256 = 417,
 * and DIWSTOP's H field drops bit 8 (the hardware forces it), so 417 -> 0xA1 as well.
 * Vertical.  160 field lines centred on the standard 256-line window [44, 300): VSTART =
 * 92 = 0x5C, VSTOP = 252 = 0xFC.  (VSTOP >= 0x80 so the hardware does NOT add 256.)
 *
 * ⚠ DDF IS NOT THE SAME FORMULA IN HIRES.  DDFSTRT = (HSTART - 9) / 2 holds for both, but
 * the fetch step is 4 colour clocks per word in hires and 8 in lores, so
 * DDFSTOP = DDFSTRT + 4*(words - 2).  The vendored AmigaHardware::setPlayfield() uses the
 * LORES step for hires (its "hires" branch yields the standard LORES DDFSTRT), which is the
 * second reason this file does not call it.
 */
#define VS_DIWSTRT  0x5CA1
#define VS_DIWSTOP  0xFCA1
#define VS_DDFSTRT  0x004C          /* (161 - 9) / 2                            */
#define VS_DDFSTOP  0x00C4          /* 0x4C + 4 * (32 - 2)                      */
#define VS_WORDS    (VetteScreen::kWidth / 16)                    /* 32         */

/* BPLCON0: HIRES | 4 planes | COLOR | LACE | ECSENA.
 * ⚠⚠ THE LACE BIT (0x0004) IS THE ONE THE FRAMEWORK DROPS.  Without it the display shows
 * one field's 160 rows as a whole picture -- a plausible, half-resolution, WRONG image. */
#define VS_BPLCON0  (0x8000 | (VetteScreen::kPlanes << 12) | 0x0200 | 0x0004 | 0x0001)

// ⭐ The mode word is DERIVED above, so assert what it derives to.  This is the honest
// replacement for the BPLCON0 readback that could not work (PlatformAmiga.cpp says why):
// it verifies the arithmetic, at compile time, and claims nothing about the hardware.
static_assert(VS_BPLCON0 == 0xC205, "BPLCON0 no longer derives to HIRES|4 planes|COLOR|LACE|ECSENA");
static_assert(VS_DDFSTOP == VS_DDFSTRT + 4 * (VS_WORDS - 2), "hires DDF window inconsistent");

/* ⭐ The interlaced row modulo.  A bitplane pointer advances by kBytesPerRow (64) as it
 * fetches one line; to reach the SAME plane of the row two rows down (the next row of THIS
 * field) it must land at +2*kRowStride.  modulo = 2*256 - 64 = 448. */
#define VS_BPLMOD   (2 * VetteScreen::kRowStride - VetteScreen::kBytesPerRow)

// Copper-list layout.  Small and fixed: the pointers first (the copper must have loaded
// them before the display window opens), then the palette, then the end marker.
#define VS_CL_PTRS   0                       /* 8 moves: BPL1PTH..BPL4PTL */
#define VS_CL_COLORS (VS_CL_PTRS + 8)        /* 16 moves: COLOR00..COLOR15 */
#define VS_CL_END    (VS_CL_COLORS + 16)
#define VS_CL_LONGS  (VS_CL_END + 1)

// ⭐ The checksum the Stage A acceptance test compares against a host-computed one
// (tools/mac_fb_to_amiga.py's blob, same algorithm).  Rotate-then-xor, not a plain sum:
// a sum is blind to byte ORDER, and a plane blob loaded with the wrong stride or with the
// two interleave halves swapped has exactly the right bytes in the wrong places.
static uint32_t rotXorChecksum(const uint8_t* p, uint32_t n)
{
    uint32_t c = 0;
    for (uint32_t i = 0; i < n; i++) {
        c = (c << 1) | (c >> 31);
        c ^= (uint32_t)p[i];
    }
    return c;
}

bool VetteScreen::initialize(const uint8_t* picture, const uint16_t* palette16)
{
    // ⚠ The picture MUST live in chip RAM: FS-UAE runs this port with --fast_memory=8192, so
    // a linked-in blob lands in fast RAM, which the display DMA cannot reach.  The failure is
    // not a crash -- the copper happily fetches whatever chip address the truncated pointer
    // lands on -- so allocate explicitly and copy.
    m_chip = (uint8_t*)AllocMem(kPictureBytes, MEMF_CHIP);
    if (!m_chip) return false;

    m_copper = (uint32_t*)AllocMem(VS_CL_LONGS * sizeof(uint32_t), MEMF_CHIP | MEMF_CLEAR);
    if (!m_copper) { FreeMem(m_chip, kPictureBytes); m_chip = 0; return false; }

    for (uint32_t i = 0; i < kPictureBytes; i++) m_chip[i] = picture[i];

    // Checksum what is IN CHIP RAM, after the copy -- that is what the display reads, and it
    // is the only form of the data that proves the whole asset path end to end.
    m_checksum = rotXorChecksum(m_chip, kPictureBytes);

    m_ptrIndex = VS_CL_PTRS;
    for (uint16_t k = 0; k < kPlanes; k++) {
        m_copper[VS_CL_PTRS + k * 2 + 0] = copperMove(bpl1pth + k * 4, 0);
        m_copper[VS_CL_PTRS + k * 2 + 1] = copperMove(bpl1ptl + k * 4, 0);
    }
    for (uint16_t i = 0; i < 16; i++)
        m_copper[VS_CL_COLORS + i] = copperMove(color00 + i * 2, palette16[i]);
    m_copper[VS_CL_END] = 0xfffffffe;

    // Point the copper at the LONG field before anything displays, so the first field out of
    // the gate is a whole picture rather than four dangling pointers.
    vbiUpdate();

    writeModeRegisters();

    // Install the list.  ⚠ Copper DMA is still OFF here (PlatformAmiga turns it on only
    // after this returns): writing COP1LC with the copper halted is what makes the bring-up
    // race-free -- the OS's LoadView(NULL) list can never run over the registers just set.
    *cop1lcPointer = m_copper;
    return true;
}

void VetteScreen::writeModeRegisters()
{
    // ⭐⭐ ONE PLACE, ONE TIME.  Nothing else in the port writes any of these.
    *fmodePointer   = 0x0000;      // OCS fetch mode, so an AGA machine behaves like an A500
    *bplcon0Pointer = VS_BPLCON0;
    *bplcon1Pointer = 0x0000;      // no scroll
    *bplcon2Pointer = 0x0024;      // playfield priority, sprites behind
    *bplcon3Pointer = 0x0c00;      // AGA: bank 0, normal; harmless on OCS
    *diwstrtPointer = VS_DIWSTRT;
    *diwstopPointer = VS_DIWSTOP;
    *ddfstrtPointer = VS_DDFSTRT;
    *ddfstopPointer = VS_DDFSTOP;
    *bpl1modPointer = VS_BPLMOD;
    *bpl2modPointer = VS_BPLMOD;
}

void VetteScreen::vbiUpdate()
{
    if (!m_copper || !m_chip) return;   // the ISR must never see a half-built screen

    // ⭐ Which field is about to be displayed decides which of the two row sets the
    // bitplane pointers name.  LOF (VPOSR bit 15) is set for the LONG field, which
    // displays rows 0, 2, 4, ...; the short field displays rows 1, 3, 5, ...
    // ⚠ [ASSUMED] polarity.  Getting it backwards does not blank the screen -- it shows
    // the picture with its two half-resolution fields swapped, i.e. every row displaced
    // by one scanline.  It reads as a slightly soft image, not as a fault, so it is on
    // the Stage A eyeball checklist (docs/open-work.md), not left to look right.
    // ⚠⚠ NOT AmigaHardware::isLongFrame().  In the GCC+ASSEMBLER configuration this build
    // uses, that function is a register-marshalling bridge that `jsr`s to
    // `_isLongFrame__13AmigaHardwareFv` -- a symbol AmigaHardwareAssembler.s never defines
    // (it xdefs 9 routines and that is not one of them).  Calling it is an undefined
    // reference at LINK time, so the defect is latent until someone needs the field parity,
    // i.e. until the first interlaced display.  One register read is the whole function
    // anyway.  → docs/open-work.md.
    uint32_t base = (uint32_t)m_chip;
    if (!(*vposrPointer & 0x8000)) base += kRowStride;   // LOF clear = short field

    for (uint16_t k = 0; k < kPlanes; k++) {
        uint32_t p = base + (uint32_t)k * kBytesPerRow;
        m_copper[m_ptrIndex + k * 2 + 0] = copperMove(bpl1pth + k * 4, (uint16_t)(p >> 16));
        m_copper[m_ptrIndex + k * 2 + 1] = copperMove(bpl1ptl + k * 4, (uint16_t)p);
    }
}

void VetteScreen::shutdown()
{
    if (m_copper) { FreeMem(m_copper, VS_CL_LONGS * sizeof(uint32_t)); m_copper = 0; }
    if (m_chip)   { FreeMem(m_chip, kPictureBytes); m_chip = 0; }
}
