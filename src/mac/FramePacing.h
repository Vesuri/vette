#pragma once
// Fixed-width types come from the platform header (stdint.h in host tests).

// Each stream has one boundary per authored animation step, not per draw call.
enum FramePaceStream {
    kPaceIntro, kPaceGarageDeparture, kPaceGarageTest,
    kPaceOpponent, kPacePreview, kPaceDriving, kPaceCount
};

struct FramePacer {
    uint16_t field;
    bool started;
    bool needsWait(uint16_t now) const { return started && field == now; }
    void advance(uint16_t now) { field = now; started = true; }
};

inline int animationPaceStream(uint16_t segment, uint32_t offset, uint16_t trap)
{
    if (segment == 8 && offset == 0x0224 && trap == 0xa974) return kPaceIntro;
    if (segment == 2) {
        if (offset == 0x11ac && trap == 0xa974) return kPaceGarageDeparture;
        // The car alternates 22 times per curve increment. Pace only the
        // completed graph reveal, after its CopyBits has finished.
        if (offset == 0x0ef0 && trap == 0xa8ec)
            return kPaceGarageTest;
        if (offset == 0x1a34 && trap == 0xa8ec) return kPaceOpponent;
    }
    if (segment == 1 && offset == 0x1ab8 && trap == 0xa974) return kPacePreview;
    return -1;
}
