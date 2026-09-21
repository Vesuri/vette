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
#include "PerfProbe.h"

extern "C" {
volatile uint16_t g_macFramesQueued = 0;
volatile uint16_t g_macFramesPresented = 0;
volatile uint16_t g_beamPresentLine = 0;
volatile uint16_t g_beamPresentMin = 0xffff;
volatile uint16_t g_beamPresentMax = 0;
volatile uint32_t g_beamPresents = 0;
volatile uint32_t g_beamPresentsLate = 0;
#ifdef VETTE_FILLWATCH
volatile uint32_t g_fillWatchFrames = 0;
volatile uint32_t g_fillWatchRows = 0;
volatile uint32_t g_fillBadFrames = 0;
volatile uint32_t g_fillBadPixels = 0;
volatile uint16_t g_fillBadX = 0;
volatile uint16_t g_fillBadY = 0;
volatile uint16_t g_fillBadExpected = 0;
volatile uint16_t g_fillBadActual = 0;
#endif
}

static uint16_t beamLine()
{
    // Read VPOSR first: the pair is not atomic, and taking V8 after V0..V7
    // could straddle the line-256 transition.
    uint16_t high = *vposrPointer;
    uint16_t low = *vhposrPointer;
    return (uint16_t)(((high & 1u) << 8) | (low >> 8));
}

// Four Macintosh chunky bytes describe eight pixels.  Each table entry places
// one such pixel pair into the correct two bit positions of four packed Amiga
// plane bytes, so four lookups and ORs perform the complete 8-pixel transpose.
// Building this once costs 4 KiB of fast RAM and removes the per-pixel/per-plane
// inner loop that was too slow to keep up with the intro on a 68000.
static uint32_t s_pairToPlanes[4][256];
static bool s_pairToPlanesReady = false;

static void initializePairToPlanes()
{
    if (s_pairToPlanesReady) return;
    for (uint16_t position = 0; position < 4; ++position) {
        uint16_t shift = (uint16_t)(6 - position * 2);
        for (uint16_t value = 0; value < 256; ++value) {
            uint16_t highPixel = value >> 4;
            uint16_t lowPixel = value & 15;
            uint32_t packed = 0;
            for (uint16_t plane = 0; plane < 4; ++plane) {
                uint32_t pair = ((highPixel >> plane) & 1) << 1;
                pair |= (lowPixel >> plane) & 1;
                packed |= pair << (24 - plane * 8 + shift);
            }
            s_pairToPlanes[position][value] = packed;
        }
    }
    s_pairToPlanesReady = true;
}

/* ---------------------------------------------------------------------------
 * The mode, DERIVED — every value below comes from the two facts above it.
 *
 * [MEASURED] the Macintosh game surface is 512x320 (docs/mac-hardware.md).  The Amiga
 * display is 512x384 with that surface centred between 32-line black bars.  It is four
 * bitplanes, hires INTERLACED, so each PAL field carries 192 of the 384 display rows.
 *
 * Horizontal.  The standard 320-lores window is [129, 449); ours is 512 hires = 256 lores
 * wide, centred in it: HSTART = 129 + (320-256)/2 = 161 = 0xA1, HSTOP = 161 + 256 = 417,
 * and DIWSTOP's H field drops bit 8 (the hardware forces it), so 417 -> 0xA1 as well.
 * Vertical.  192 field lines centred at line 172: VSTART=76=$4C, VSTOP=268=$10C.
 *
 * ⚠ DDF IS NOT THE SAME FORMULA IN HIRES.  DDFSTRT = (HSTART - 9) / 2 holds for both, but
 * the fetch step is 4 colour clocks per word in hires and 8 in lores, so
 * DDFSTOP = DDFSTRT + 4*(words - 2).  (Amiga Hardware Reference Manual ch. 3, §Telling the
 * System How to Fetch and Display Data: the normal pairs are $38/$D0 lores, $3C/$D4 hires.)
 * AmigaHardware::setPlayfield() used the LORES step for hires; that is fixed, and the
 * VS_* constants below are static_asserted against its formulas so the two cannot drift.
 */
#define VS_DIWSTRT  0x4CA1
#define VS_DIWSTOP  0x0CA1
#define VS_DDFSTRT  0x004C          /* (161 - 9) / 2                            */
#define VS_DDFSTOP  0x00C4          /* 0x4C + 4 * (32 - 2)                      */
#define VS_WORDS    (VetteScreen::kWidth / 16)                    /* 32         */

/* ⚠⚠ DIWHIGH IS WRITTEN, NOT LEFT ALONE.  On ECS/AGA it carries the ninth horizontal and
 * the upper vertical bits of both display-window corners, and it OVERRIDES the old rules
 * that DIWSTOP's H8 is forced to 1 and its V8 to the complement of V7 -- and once anything
 * has written it, it stays written.  Kickstart's own copper list writes it ($2100, a
 * 200-line NTSC-style window whose VSTOP is above 255), so a takeover that only writes
 * DIWSTRT/DIWSTOP inherits a stale VSTOP high bit and the window stays open to the bottom
 * of the frame.  Ours: HSTOP 417 has H8 set (0x2000), VSTOP 268 has upper bit 1, while HSTART
 * 161 and VSTART 76 fit in their low bits.  On plain OCS the register does not exist and this is
 * a no-op;
 * the legacy rules force HSTOP bit 8 to one and VSTOP bit 8 to !V7, which produces these exact
 * HSTOP=$1A1 and VSTOP=$10C corners.  OCS is not the package target, but it does not require a
 * cropped or squeezed display mode. */
#define VS_DIWHIGH  0x2100

/* BPLCON0: HIRES | 4 planes | COLOR | LACE | ECSENA.
 * ⚠⚠ THE LACE BIT (0x0004) IS THE ONE THE FRAMEWORK DROPS.  Without it the display shows
 * one field's 160 rows as a whole picture -- a plausible, half-resolution, WRONG image. */
#define VS_BPLCON0  (0x8000 | (VetteScreen::kPlanes << 12) | 0x0200 | 0x0004 | 0x0001)

// ⭐ The mode word is DERIVED above, so assert what it derives to.  This is the honest
// replacement for the BPLCON0 readback that could not work (PlatformAmiga.cpp says why):
// it verifies the arithmetic, at compile time, and claims nothing about the hardware.
static_assert(VS_BPLCON0 == 0xC205, "BPLCON0 no longer derives to HIRES|4 planes|COLOR|LACE|ECSENA");
static_assert(VS_DDFSTOP == VS_DDFSTRT + 4 * (VS_WORDS - 2), "hires DDF window inconsistent");

/* ⭐⭐ THE CROSS-CHECK AGAINST THE FRAMEWORK.  AmigaHardware::setPlayfield() can express
 * this mode now, and this file keeps the writes (VetteScreen.h says why) -- so the one
 * thing that must not happen is the two derivations disagreeing.  Below are the framework's
 * own formulas, evaluated at compile time for THIS mode with centerY = 172, asserted
 * against the measured constants above.  ⚠ If a future framework change moves a formula,
 * this is what fails, at build time, instead of the picture drifting sideways on the glass.
 */
#define VS_CENTER_Y     172                                      /* (92 + 252) / 2        */
#define VS_LORES_WIDTH  (VetteScreen::kWidth / 2)                /* DIW is lores units    */
#define VS_FIELD_LINES  (VetteScreen::kHeight / 2)               /* ...and non-interlaced */
#define VS_HSTART       (0x81 + ((320 - VS_LORES_WIDTH) / 2))
#define VS_HSTOP        (VS_HSTART + VS_LORES_WIDTH)
#define VS_VSTART       (VS_CENTER_Y - VS_FIELD_LINES / 2)
#define VS_VSTOP        (VS_CENTER_Y + VS_FIELD_LINES / 2)
static_assert(VS_DIWSTRT == ((VS_VSTART << 8) | (VS_HSTART & 0xff)), "DIWSTRT != the framework's");
static_assert(VS_DIWSTOP == (((VS_VSTOP & 0xff) << 8) | (VS_HSTOP & 0xff)),
              "DIWSTOP != the framework's");
static_assert(VS_DDFSTRT == ((VS_HSTART - 9) / 2), "DDFSTRT != the framework's hires formula");
static_assert(VS_DIWHIGH == ((((VS_HSTOP & 0x100) ? 0x2000 : 0) | (((VS_VSTOP >> 8) & 7) << 8)
                              | ((VS_HSTART & 0x100) ? 0x20 : 0) | ((VS_VSTART >> 8) & 7))),
              "DIWHIGH != the framework's");

/* ⭐ The interlaced row modulo.  A bitplane pointer advances by kBytesPerRow (64) as it
 * fetches one line; to reach the SAME plane of the row two rows down (the next row of THIS
 * field) it must land at +2*kRowStride.  modulo = 2*256 - 64 = 448.  Same expression the
 * framework now uses: (interlace ? 2 : 1) * rowBytes - bytesPerRow. */
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
    initializePairToPlanes();
    // ⚠ The picture MUST live in chip RAM: FS-UAE runs this port with --fast_memory=8192, so
    // a linked-in blob lands in fast RAM, which the display DMA cannot reach.  The failure is
    // not a crash -- the copper happily fetches whatever chip address the truncated pointer
    // lands on -- so allocate explicitly and copy.
    m_chip = (uint8_t*)AllocMem(kPictureBytes, MEMF_CHIP);
    if (!m_chip) return false;
    m_back = (uint8_t*)AllocMem(kPictureBytes, MEMF_CHIP);
    if (!m_back) { FreeMem(m_chip, kPictureBytes); m_chip = 0; return false; }

    m_copper = (uint32_t*)AllocMem(VS_CL_LONGS * sizeof(uint32_t), MEMF_CHIP | MEMF_CLEAR);
    if (!m_copper) {
        FreeMem(m_back, kPictureBytes); m_back = 0;
        FreeMem(m_chip, kPictureBytes); m_chip = 0;
        return false;
    }

    for (uint32_t i = 0; i < kPictureBytes; i++)
        m_chip[i] = m_back[i] = picture ? picture[i] : 0;

    // Checksum what is IN CHIP RAM, after the copy -- that is what the display reads, and it
    // is the only form of the data that proves the whole asset path end to end.
    m_checksum = rotXorChecksum(m_chip, kPictureBytes);

    m_ptrIndex = VS_CL_PTRS;
    for (uint16_t k = 0; k < kPlanes; k++) {
        m_copper[VS_CL_PTRS + k * 2 + 0] = copperMove(bpl1pth + k * 4, 0);
        m_copper[VS_CL_PTRS + k * 2 + 1] = copperMove(bpl1ptl + k * 4, 0);
    }
    for (uint16_t i = 0; i < 16; i++)
        m_copper[VS_CL_COLORS + i] = copperMove(color00 + i * 2,
                                                palette16 ? palette16[i] : 0);
    m_copper[VS_CL_END] = 0xfffffffe;

    // Fill in a valid set of bitplane pointers for whichever field is next, before anything
    // displays, so the first field out of the gate is a whole picture rather than four
    // dangling pointers.  Which row set that is comes from vbiUpdate()'s LOF test.
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
    *diwhighPointer = VS_DIWHIGH;  // ⚠ must be written, not inherited -- see above
    *ddfstrtPointer = VS_DDFSTRT;
    *ddfstopPointer = VS_DDFSTOP;
    *bpl1modPointer = VS_BPLMOD;
    *bpl2modPointer = VS_BPLMOD;
}

void VetteScreen::vbiUpdate()
{
    if (!m_copper || !m_chip) return;   // the ISR must never see a half-built screen

    if (m_framePending) {
        // Measure before touching the live list. A publication inside the
        // 76..267 display window has raced the beam and must never occur.
        uint16_t line = beamLine();
        g_beamPresentLine = line;
        if (line < g_beamPresentMin) g_beamPresentMin = line;
        if (line > g_beamPresentMax) g_beamPresentMax = line;
        ++g_beamPresents;
        if (line >= VS_VSTART && line < VS_VSTOP) ++g_beamPresentsLate;

        uint8_t* oldFront = m_chip;
        m_chip = m_back;
        m_back = oldFront;
        for (uint16_t i = 0; i < 16; ++i)
            m_copper[VS_CL_COLORS + i] = copperMove(color00 + i * 2, m_nextPalette[i]);
        m_framePending = false;
        ++g_macFramesPresented;
    }

    // ⭐ Which field the copper is ABOUT TO DISPLAY decides which of the two row sets the
    // bitplane pointers name: the long field shows rows 0, 2, 4, ..., the short field
    // rows 1, 3, 5, ..., so the pointers move by one kRowStride between them.
    // ⚠⚠ [MEASURED] POLARITY, AND IT IS THE OPPOSITE OF THE OBVIOUS READING OF LOF.
    // VPOSR bit 15 (LOF) is set for the long field, but what this handler reads is the
    // parity of the field whose vertical blank it is standing in -- ALREADY ENTERED, not
    // the one the list it is writing will serve.  The copper list is re-fetched from
    // COP1LC at the top of the NEXT field, so writing `long rows when LOF is set` serves
    // the long field's pointers to the short field and vice versa.  Shipped that way
    // first: the intro's copyright overlay rendered DOUBLED, each thin horizontal stroke
    // repeated one scanline down, because both fields were showing each other's rows.
    // ⚠ It does NOT blank or tear, so it cannot be caught by a frame-boundary probe or
    // by the long/lace ratio (still exactly 0.500 either way) -- only on the glass.
    // ⚠ AmigaHardware::isLongFrame() used to be an undefined symbol at LINK time in this
    // build's GCC+ASSEMBLER configuration (its bridge `jsr`ed a routine no .s defined);
    // it is fixed and unconditional now, and it is exactly this test.
    uint32_t base = (uint32_t)m_chip;
    if (AmigaHardware::isLongFrame()) base += kRowStride;   // LOF set here => SHORT field next

    for (uint16_t k = 0; k < kPlanes; k++) {
        uint32_t p = base + (uint32_t)k * kBytesPerRow;
        m_copper[m_ptrIndex + k * 2 + 0] = copperMove(bpl1pth + k * 4, (uint16_t)(p >> 16));
        m_copper[m_ptrIndex + k * 2 + 1] = copperMove(bpl1ptl + k * 4, (uint16_t)p);
    }
}

#ifdef VETTE_FILLWATCH
static void validateConvertedFrame(const uint8_t* chunky, const uint8_t* planar)
{
    static uint16_t nextRow = 0;
    bool bad = false;
    // Decode eight complete rows per frame.  Forty successive frames therefore
    // audit every one of the 163,840 pixels without turning the diagnostic into
    // the dominant workload on a 68020.
    for (uint16_t checked = 0; checked < 8; ++checked) {
        uint16_t y = nextRow++;
        if (nextRow == VetteScreen::kMacHeight) nextRow = 0;
        const uint8_t* source = chunky + (uint32_t)y * (VetteScreen::kWidth / 2);
        const uint8_t* row = planar
            + (uint32_t)(y + VetteScreen::kMacTop) * VetteScreen::kRowStride;
        for (uint16_t x = 0; x < VetteScreen::kWidth; ++x) {
            uint8_t packed = source[x >> 1];
            uint8_t expected = (x & 1) ? (packed & 15) : (packed >> 4);
            uint8_t mask = (uint8_t)(0x80u >> (x & 7));
            uint8_t actual = 0;
            for (uint16_t plane = 0; plane < VetteScreen::kPlanes; ++plane)
                if (row[(uint32_t)plane * VetteScreen::kBytesPerRow + (x >> 3)] & mask)
                    actual |= (uint8_t)(1u << plane);
            if (actual == expected) continue;
            if (!bad) {
                g_fillBadX = x;
                g_fillBadY = y;
                g_fillBadExpected = expected;
                g_fillBadActual = actual;
            }
            bad = true;
            ++g_fillBadPixels;
        }
        ++g_fillWatchRows;
    }
    ++g_fillWatchFrames;
    if (bad) ++g_fillBadFrames;
}
#endif

static uint8_t gammaToOcs(uint16_t component)
{
    static const uint8_t thresholds[15] = {
        2, 10, 20, 32, 46, 61, 77, 95, 113, 133, 153, 175, 197, 220, 243
    };
    uint8_t value = (uint8_t)(component >> 8), result = 0;
    while (result < 15 && value >= thresholds[result]) ++result;
    return result;
}

bool VetteScreen::presentMacFrame(const uint8_t* chunky, const uint8_t* colorTable,
                                  int16_t dirtyTop, int16_t dirtyLeft,
                                  int16_t dirtyBottom, int16_t dirtyRight)
{
    if (!chunky || !colorTable || !m_back) return false;
    if (m_framePending) {
#ifdef VETTE_PROBE
        VetteProfileScope profileWait(kProfileWait);
#endif
        return false;
    }

#ifdef VETTE_PROBE
    VetteProfileScope profilePresent(kProfilePresent);
#endif

#ifdef VETTE_FREEWAY_ROUTE
    // The freeway-route build observes original game physics and collision,
    // not video output.  A full Mac draw has already updated `chunky` before
    // this boundary; omit only the host chunky-to-planar conversion and swap
    // so a long, input-only diagnostic is not paced by redundant display DMA.
    ++g_macFramesQueued;
    ++g_macFramesPresented;
    return true;
#endif

    // After the previous swap m_back is the frame from two updates ago.  Bring
    // forward only the rectangle that changed in the last frame, then apply the
    // new dirty rectangle.  Both buffers therefore remain coherent without a
    // full-screen chip-RAM copy.
    if (m_syncPending) {
        uint16_t byteLeft = (uint16_t)m_syncLeft / 8;
        uint16_t byteRight = (uint16_t)m_syncRight / 8;
        for (int16_t y = m_syncTop; y < m_syncBottom; ++y) {
            uint32_t row = (uint32_t)(y + kMacTop) * kRowStride;
            for (uint16_t plane = 0; plane < kPlanes; ++plane) {
                uint32_t offset = row + (uint32_t)plane * kBytesPerRow + byteLeft;
                for (uint16_t x = byteLeft; x < byteRight; ++x, ++offset)
                    m_back[offset] = m_chip[offset];
            }
        }
        m_syncPending = false;
    }

    if (dirtyTop < 0) dirtyTop = 0;
    if (dirtyLeft < 0) dirtyLeft = 0;
    if (dirtyBottom > (int16_t)kMacHeight) dirtyBottom = kMacHeight;
    if (dirtyRight > (int16_t)kWidth) dirtyRight = kWidth;
    dirtyLeft &= (int16_t)~15;
    dirtyRight = (int16_t)((dirtyRight + 15) & ~15);
    bool pixelsDirty = dirtyTop < dirtyBottom && dirtyLeft < dirtyRight;
    if (pixelsDirty) {
        uint16_t firstWord = (uint16_t)dirtyLeft / 16;
        uint16_t finalWord = (uint16_t)dirtyRight / 16;
        for (int16_t y = dirtyTop; y < dirtyBottom; ++y) {
            const uint8_t* source = chunky + (uint32_t)y * (kWidth / 2)
                                  + (uint16_t)dirtyLeft / 2;
            uint8_t* destination = m_back + (uint32_t)(y + kMacTop) * kRowStride;
            for (uint16_t word = firstWord; word < finalWord; ++word, source += 8) {
            uint32_t first = s_pairToPlanes[0][source[0]] | s_pairToPlanes[1][source[1]]
                           | s_pairToPlanes[2][source[2]] | s_pairToPlanes[3][source[3]];
            uint32_t second = s_pairToPlanes[0][source[4]] | s_pairToPlanes[1][source[5]]
                            | s_pairToPlanes[2][source[6]] | s_pairToPlanes[3][source[7]];
            uint16_t column = word * 2;
            destination[column] = (uint8_t)(first >> 24);
            destination[column + 1] = (uint8_t)(second >> 24);
            destination[kBytesPerRow + column] = (uint8_t)(first >> 16);
            destination[kBytesPerRow + column + 1] = (uint8_t)(second >> 16);
            destination[kBytesPerRow * 2 + column] = (uint8_t)(first >> 8);
            destination[kBytesPerRow * 2 + column + 1] = (uint8_t)(second >> 8);
            destination[kBytesPerRow * 3 + column] = (uint8_t)first;
            destination[kBytesPerRow * 3 + column + 1] = (uint8_t)second;
            }
        }
        m_syncTop = dirtyTop; m_syncLeft = dirtyLeft;
        m_syncBottom = dirtyBottom; m_syncRight = dirtyRight;
        m_syncPending = true;
    }

    uint16_t finalIndex = (uint16_t)(colorTable[6] << 8 | colorTable[7]);
    if (finalIndex > 15) finalIndex = 15;
    bool deviceTable = (colorTable[4] & 0x80) != 0;
    for (uint16_t i = 0; i < 16; ++i) m_nextPalette[i] = 0;
    for (uint16_t i = 0; i <= finalIndex; ++i) {
        const uint8_t* spec = colorTable + 8 + i * 8;
        // A device ColorTable uses its array position as the physical pen.
        // ColorSpec.value is private Color Manager state (protected/tolerant
        // ownership flags in System 6), not an index suitable for COLORxx.
        uint16_t index = deviceTable ? i : (uint16_t)(spec[0] << 8 | spec[1]);
        if (index >= 16) continue;
        uint8_t red = gammaToOcs((uint16_t)(spec[2] << 8 | spec[3]));
        uint8_t green = gammaToOcs((uint16_t)(spec[4] << 8 | spec[5]));
        uint8_t blue = gammaToOcs((uint16_t)(spec[6] << 8 | spec[7]));
        m_nextPalette[index] = (uint16_t)(red << 8 | green << 4 | blue);
    }
#ifdef VETTE_FILLWATCH
    // Rolling validation is intentionally diagnostic: it proves that dirty
    // synchronization plus the converted rectangle leave the back buffer an
    // exact planar encoding of the game's complete 4-bit chunky surface.
    validateConvertedFrame(chunky, m_back);
#endif
    ++g_macFramesQueued;
    m_framePending = true;
    return true;
}

void VetteScreen::shutdown()
{
    if (m_copper) { FreeMem(m_copper, VS_CL_LONGS * sizeof(uint32_t)); m_copper = 0; }
    if (m_back)   { FreeMem(m_back, kPictureBytes); m_back = 0; }
    if (m_chip)   { FreeMem(m_chip, kPictureBytes); m_chip = 0; }
}

// Compact 5x7 capitals.  Rows are five low bits, left to right.  The Stage B stop uses
// only capitals deliberately: this is exception-path code, not a general text renderer.
static const uint8_t s_font[37][7] = {
    {14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},
    {30,1,1,14,1,1,30},{2,6,10,18,31,2,2},{31,16,16,30,1,1,30},
    {14,16,16,30,17,17,14},{31,1,2,4,8,8,8},{14,17,17,14,17,17,14},
    {14,17,17,15,1,1,14},
    {14,17,17,31,17,17,17},{30,17,17,30,17,17,30},{14,17,16,16,16,17,14},
    {30,17,17,17,17,17,30},{31,16,16,30,16,16,31},{31,16,16,30,16,16,16},
    {14,17,16,23,17,17,14},{17,17,17,31,17,17,17},{14,4,4,4,4,4,14},
    {7,2,2,2,2,18,12},{17,18,20,24,20,18,17},{16,16,16,16,16,16,31},
    {17,27,21,21,17,17,17},{17,25,21,19,17,17,17},{14,17,17,17,17,17,14},
    {30,17,17,30,16,16,16},{14,17,17,17,21,18,13},{30,17,17,30,20,18,17},
    {15,16,16,14,1,1,30},{31,4,4,4,4,4,4},{17,17,17,17,17,17,14},
    {17,17,17,17,17,10,4},{17,17,17,21,21,21,10},{17,17,10,4,10,17,17},
    {17,17,10,4,4,4,4},{31,1,2,4,8,16,31},
    {0,0,0,0,0,0,0}
};

static uint8_t glyphRow(char c, uint16_t row)
{
    if (c >= '0' && c <= '9') return s_font[c - '0'][row];
    if (c >= 'A' && c <= 'Z') return s_font[10 + c - 'A'][row];
    if (c == ':') return (row == 2 || row == 5) ? 4 : 0;
    if (c == '+') return row == 3 ? 31 : ((row >= 1 && row <= 5) ? 4 : 0);
    if (c == '/') return (uint8_t)(1u << (row < 5 ? 4 - row : 0));
    if (c == '-') return row == 3 ? 31 : 0;
    if (c == '$') return s_font[28][row]; // readable S-shaped dollar substitute
    return s_font[36][row];
}

static void setWhitePixel(uint8_t* chip, uint16_t x, uint16_t y)
{
    if (x >= VetteScreen::kWidth || y >= VetteScreen::kHeight) return;
    uint8_t mask = (uint8_t)(0x80u >> (x & 7));
    uint32_t row = (uint32_t)y * VetteScreen::kRowStride;
    uint16_t byte = x >> 3;
    for (uint16_t p = 0; p < VetteScreen::kPlanes; ++p)
        chip[row + (uint32_t)p * VetteScreen::kBytesPerRow + byte] |= mask;
}

static void drawLine(uint8_t* chip, uint16_t x, uint16_t y, const char* text)
{
    for (; *text; ++text, x += 12) {
        for (uint16_t row = 0; row < 7; ++row) {
            uint8_t bits = glyphRow(*text, row);
            for (uint16_t col = 0; col < 5; ++col) if (bits & (16u >> col)) {
                setWhitePixel(chip, x + col * 2,     y + row * 2);
                setWhitePixel(chip, x + col * 2 + 1, y + row * 2);
                setWhitePixel(chip, x + col * 2,     y + row * 2 + 1);
                setWhitePixel(chip, x + col * 2 + 1, y + row * 2 + 1);
            }
        }
    }
}

static char hexDigit(uint8_t v) { return (char)(v < 10 ? '0' + v : 'A' + v - 10); }

static void append(char*& p, const char* s) { while (*s) *p++ = *s++; }
static void appendHex(char*& p, uint32_t value, uint16_t digits)
{
    while (digits--) *p++ = hexDigit((uint8_t)(value >> (digits * 4)) & 15);
}

void VetteScreen::showLoudStop(const char* manager, const char* routine, int32_t selector,
                               const char* segment, uint32_t offset, uint16_t trapWord)
{
    if (!m_chip) return;
    for (uint32_t i = 0; i < kPictureBytes; ++i) m_chip[i] = 0;

    char line[48]; char* p;
    drawLine(m_chip, 24, 24, "STAGE B LOUD STOP");
    p = line; append(p, "TRAP: $"); appendHex(p, trapWord, 4); *p = 0;
    drawLine(m_chip, 24, 58, line);
    p = line; append(p, "MANAGER: "); append(p, manager); *p = 0;
    drawLine(m_chip, 24, 82, line);
    p = line; append(p, "ROUTINE: "); append(p, routine); *p = 0;
    drawLine(m_chip, 24, 106, line);
    p = line; append(p, "SELECTOR: ");
    if (selector < 0) append(p, "N/A"); else appendHex(p, (uint32_t)selector, 8);
    *p = 0; drawLine(m_chip, 24, 130, line);
    p = line; append(p, "CALLER: "); append(p, segment); *p++ = '+';
    appendHex(p, offset, 4); *p = 0;
    drawLine(m_chip, 24, 154, line);
}
