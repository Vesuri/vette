/* VetteScreen — THE SINGLE OWNER of the Amiga display mode registers.
 *
 * ⭐⭐ ONE OWNER, ON PURPOSE.  DIWSTRT/DIWSTOP, DDFSTRT/DDFSTOP, BPLCON0-3, FMODE
 * and BPL1MOD/BPL2MOD are write-only and mutually constrained: the display window,
 * the fetch window and the row modulo have to agree by CONSTRUCTION, not because
 * two files happen to hold matching literals.  Every one of them is derived here
 * from the constants below and written in one place.  (Revs learned this the hard
 * way; docs/amiga-lessons.md.)
 *
 * ⚠⚠ THE VENDORED FRAMEWORK CANNOT DO THIS MODE, and the way it cannot is the
 * dangerous way: AmigaHardware::setPlayfield() and CopperList::setPlayfield() both
 * take an `interlace` argument and BOTH `(void)` it -- no LACE bit is ever written.
 * `PROJECT.md` locks the port's mode to 4 bitplanes hires INTERLACED, so calling
 * the framework would have produced a plausible 160-line display from 320 lines of
 * data with nothing reporting a problem.  The framework's DIW/DDF arithmetic is
 * also hardcoded for a 320-lores/640-hires window (`0x81..0x1c1`) and its hires
 * DDFSTRT formula yields the LORES standard value, so neither is usable at 512 px.
 * → docs/open-work.md.  ⛔ Do not "simplify" this file back onto setPlayfield().
 */
#ifndef VETTE_SCREEN_H
#define VETTE_SCREEN_H

// ⚠ NO <stdint.h> -- SASCCompat.h is force-included and already typedefs these.  See
// PlatformAmiga.h for the conflicting-declaration error the two together produce.

class VetteScreen {
public:
    // The Macintosh surface the port has to reproduce, [MEASURED] (docs/mac-hardware.md).
    static const uint16_t kWidth  = 512;
    static const uint16_t kHeight = 320;
    static const uint16_t kPlanes = 4;
    static const uint16_t kBytesPerRow = kWidth / 8;                 // 64
    static const uint16_t kRowStride   = kBytesPerRow * kPlanes;     // 256, interleaved
    static const uint32_t kPictureBytes = (uint32_t)kRowStride * kHeight;

    // Copies `picture` (kPictureBytes of INTERLEAVED bitplanes, as produced by
    // tools/mac_fb_to_amiga.py) into chip RAM and builds the copper list.
    // ⚠ Returns false if chip RAM could not be had -- the caller must not display.
    bool initialize(const uint8_t* picture, const uint16_t* palette16);
    void shutdown();

    // ⭐ Called FIRST in the VERTB handler, before any other work: an interlaced
    // display needs the bitplane pointers re-pointed at the other field's rows
    // every field, and a torn pointer garbages the whole viewport for a frame
    // (CLAUDE.md).  Cheap by construction: four 32-bit stores into the copper list.
    void vbiUpdate();

    uint32_t* copperList() const { return m_copper; }
    uint8_t*  picture() const    { return m_chip; }

    // Stage A evidence, read by amiga/stage_a.gdb.  The checksum is computed from
    // the bytes IN CHIP RAM after the copy, so it proves the whole asset path
    // (converter -> .incbin -> load -> chip copy), not just that a blob exists.
    uint32_t pictureChecksum() const { return m_checksum; }

private:
    void writeModeRegisters();

    uint32_t* m_copper = 0;
    uint8_t*  m_chip = 0;
    uint32_t  m_checksum = 0;
    uint16_t  m_ptrIndex = 0;      // copper-list index of the first BPLxPT move
};

#endif
