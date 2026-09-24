#include <stdint.h>
#include "../src/mac/PaulaSample.h"
#include <cassert>
#include <cstdio>
#include <vector>

static void check(unsigned size, unsigned start, unsigned end, bool header, bool repeat)
{
    std::vector<uint8_t> resource(size + (header ? 8 : 0));
    unsigned offset = header ? 8 : 0;
    if (header) {
        unsigned fields[] = {start, end, 6400, size};
        for (unsigned i = 0; i < 4; ++i) {
            resource[i*2] = fields[i] >> 8;
            resource[i*2+1] = fields[i];
        }
    }
    for (unsigned i = 0; i < size; ++i) resource[offset+i] = (i*37+19) & 255;
    PaulaSample::Layout layout;
    assert(PaulaSample::describe(resource.data(), resource.size(), repeat, layout));
    assert(layout.size == size);
    assert(layout.rate == (header ? 6400 : 0));
    assert(!(layout.attackBytes & 1) && !(layout.reloadOffset & 1) && !(layout.reloadBytes & 1));
    std::vector<uint8_t> converted(layout.allocated + 2, 0x55);
    PaulaSample::convert(layout, converted.data());
    assert(converted[layout.allocated] == 0x55 && converted[layout.allocated+1] == 0x55);
    bool looping = header ? end > start && end <= size : repeat;
    if (!header) { start = 0; end = size; }
    unsigned cursor = 0;
    // Compare the actual DMA stream, across attack and several reloads, with
    // a byte-granular reference that has no Paula alignment restrictions.
    for (unsigned i = 0; i < layout.attackBytes + 4*layout.reloadBytes; ++i) {
        unsigned address = i < layout.attackBytes ? i : layout.reloadOffset + (i-layout.attackBytes)%layout.reloadBytes;
        uint8_t expected = cursor < size ? (resource[offset+cursor] ^ 0x80) : 0;
        assert(converted[address] == expected);
        ++cursor;
        if (looping && cursor == end) cursor = start;
    }
}
int main()
{
    for (unsigned size = 1; size < 40; ++size) {
        check(size, 0, 0, true, false);
        check(size, 0, 0, false, false);
        check(size, 0, 0, false, true);
        for (unsigned start = 0; start < size; ++start)
            for (unsigned end = start+1; end <= size; ++end)
                check(size, start, end, true, false);
        check(size, size, size+1, true, false); // invalid loop: play once
    }
    check(6053, 370, 5682, true, false); // engine
    check(5606, 1428, 4989, true, false); // horn: odd loop, odd attack
    check(8400, 0, 0, true, false); // ready/set
    check(4608, 0, 0, true, false); // go
    check(117558, 0, 0, false, true); // opening song
    PaulaSample::Layout layout;
    uint8_t dummy[8] = {};
    assert(!PaulaSample::describe(dummy, 0, false, layout));
    puts("Paula sample stream tests PASS");
}
