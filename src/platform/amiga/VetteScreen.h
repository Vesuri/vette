/* VetteScreen — THE SINGLE OWNER of the Amiga display mode registers.
 *
 * ⭐⭐ ONE OWNER, ON PURPOSE.  DIWSTRT/DIWSTOP, DDFSTRT/DDFSTOP, BPLCON0-3, FMODE
 * and BPL1MOD/BPL2MOD are write-only and mutually constrained: the display window,
 * the fetch window and the row modulo have to agree by CONSTRUCTION, not because
 * two files happen to hold matching literals.  Every one of them is derived here
 * from the constants below and written in one place.  (Revs learned this the hard
 * way; docs/amiga-lessons.md.)
 *
 * ⚠ THE FRAMEWORK CAN NOW EXPRESS THIS MODE -- IT COULD NOT BEFORE, AND SILENTLY.
 * AmigaHardware::setPlayfield() and CopperList::setPlayfield() both took an `interlace`
 * argument and both `(void)`d it, so LACE was never written and an interlaced request
 * came out as a plausible half-height picture; the display window was hardcoded to the
 * full 320-lores screen whatever the width; and the hires DDFSTRT branch produced the
 * LORES value.  All three are FIXED (framework/UPSTREAM.md, docs/amiga-arch.md).
 * ⭐ This file still owns the WRITES, for two reasons that survive the fix: the values
 * below are derived from the [MEASURED] Macintosh window rather than from a centerY
 * magic number, and this port pins FMODE to 0 so an AGA machine fetches like an A500,
 * which the framework's AGA branch deliberately does not.  The two derivations are
 * cross-checked against each other by static_assert in VetteScreen.cpp, so they cannot
 * drift apart in silence.
 */
#ifndef VETTE_SCREEN_H
#define VETTE_SCREEN_H

// ⚠ NO <stdint.h> -- SASCCompat.h is force-included and already typedefs these.  See
// PlatformAmiga.h for the conflicting-declaration error the two together produce.

class VetteScreen {
public:
    struct DirtyRect {
        int16_t top, left, bottom, right;
    };
    static const uint16_t kMaxDirtyRects = 32;

    // The Macintosh surface the port has to reproduce, [MEASURED] (docs/mac-hardware.md).
    static const uint16_t kWidth  = 512;
    static const uint16_t kHeight = 384;
    static const uint16_t kMacHeight = 320;
    static const uint16_t kMacTop = (kHeight - kMacHeight) / 2;
    static const uint16_t kPlanes = 4;
    static const uint16_t kBytesPerRow = kWidth / 8;                 // 64
    static const uint16_t kRowStride   = kBytesPerRow * kPlanes;     // 256, interleaved
    static const uint32_t kPictureBytes = (uint32_t)kRowStride * kHeight;

    // Copies `picture` (kPictureBytes of interleaved bitplanes) into chip RAM and
    // builds the copper list.  A null picture and palette produce a black screen;
    // production startup uses that so no captured emulator frame is displayed.
    // ⚠ Returns false if chip RAM could not be had -- the caller must not display.
    bool initialize(const uint8_t* picture, const uint16_t* palette16);
    void shutdown();

    // ⭐ Called FIRST in the VERTB handler, before any other work: an interlaced
    // display needs the bitplane pointers re-pointed at the other field's rows
    // every field, and a torn pointer garbages the whole viewport for a frame
    // (CLAUDE.md).  Cheap by construction: four 32-bit stores into the copper list.
    void vbiUpdate();

    // Convert a Macintosh 4-bpp chunky surface and ColorTable into the Amiga's
    // interleaved planes.  The completed frame is swapped in by vbiUpdate(), so
    // the copper never scans a half-converted picture.
    bool presentMacFrame(const uint8_t* chunky, const uint8_t* colorTable,
                         const DirtyRect* dirtyRects, uint16_t dirtyRectCount);

    // Publish the Macintosh cursor shape/state to Amiga sprite 0. Physical
    // position is sampled by the VBI independently of game/Toolbox polling.
    void setMouseCursor(const uint8_t* cursor, int16_t x, int16_t y, bool visible);

    // VBI-only position publication. A 68000 word store is atomic, and the VBI
    // immediately consumes these coordinates when it builds the next sprite.
    void setMousePositionFromVBI(int16_t x, int16_t y);

    // Stage B's fail-loud surface.  It replaces the captured frame with a diagnostic
    // generated on the Amiga, so an unknown Mac trap cannot masquerade as a freeze.
    void showLoudStop(const char* manager, const char* routine, int32_t selector,
                      const char* segment, uint32_t offset, uint16_t trapWord);

    uint32_t* copperList() const { return m_copper; }
    uint8_t*  picture() const    { return m_chip; }

    // Stage A evidence, read by amiga/stage_a.gdb.  The checksum is computed from
    // the bytes IN CHIP RAM after the copy, so it proves the initialized display
    // surface rather than merely proving that host data exists.
    uint32_t pictureChecksum() const { return m_checksum; }

private:
    void writeModeRegisters();
    void updateMouseSprite(bool oddField);

    uint32_t* m_copper = 0;
    uint8_t*  m_chip = 0;
    uint8_t*  m_back = 0;
    uint32_t  m_checksum = 0;
    uint16_t  m_ptrIndex = 0;      // copper-list index of the first BPLxPT move
    uint16_t  m_nextPalette[16] = {0};
    volatile bool m_framePending = false;
    uint16_t* m_mouseSprite[2] = {0, 0}; // even/long-field rows, odd/short-field rows
    uint16_t* m_emptySprite = 0;
    uint16_t  m_cursorImage[16] = {0};
    uint16_t  m_cursorMask[16] = {0};
    int16_t   m_cursorX = 256;
    int16_t   m_cursorY = 160;
    int16_t   m_cursorHotX = 0;
    int16_t   m_cursorHotY = 0;
    bool      m_cursorVisible = false;
    DirtyRect m_syncRects[kMaxDirtyRects] = {};
    uint16_t m_syncRectCount = 0;
};

#endif
