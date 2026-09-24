#include <stdint.h>
#include "../src/mac/FramePacing.h"
#include <assert.h>
#include <stdio.h>

int main()
{
    FramePacer p = {};
    assert(!p.needsWait(0)); // First frame starts immediately.
    p.advance(0);
    assert(p.needsWait(0));
    assert(!p.needsWait(1));
    p.advance(1);
    assert(!p.needsWait(12)); // Slow drawing incurs no additional field wait.
    p.advance(65535);
    assert(!p.needsWait(0)); // PAL counter wrap.
    FramePacer other = {};
    assert(!other.needsWait(65535)); // Independent scene clocks.
    assert(animationPaceStream(8, 0x224, 0xa974) == kPaceIntro);
    assert(animationPaceStream(2, 0x11ac, 0xa974) == kPaceGarageDeparture);
    assert(animationPaceStream(2, 0xe86, 0xa8ec) == kPaceGarageTest);
    assert(animationPaceStream(2, 0xeac, 0xa8ec) == kPaceGarageTest);
    assert(animationPaceStream(2, 0x1a34, 0xa8ec) == kPaceOpponent);
    assert(animationPaceStream(1, 0x1ab8, 0xa974) == kPacePreview);
    assert(animationPaceStream(2, 0x1a0e, 0xa8ec) == -1); // Background copy.
    assert(animationPaceStream(2, 0xef0, 0xa8ec) == -1); // Test graph reveal.
    assert(animationPaceStream(1, 0xfe4, 0xa974) == -1); // Recovery prompt.
    assert(animationPaceStream(1, 0x224, 0xa974) == -1); // Wrong segment.
    assert(animationPaceStream(8, 0x224, 0xa8ec) == -1); // Wrong instruction.
    puts("PASS: frame pacing first/fast/slow/wrapped fields and exact caller selection");
}
