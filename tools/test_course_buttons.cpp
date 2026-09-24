#include <stdint.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../src/mac/CourseButtons.h"

static uint8_t before[320 * 256], after[sizeof(before)];
static unsigned pixel(const uint8_t* image, unsigned x, unsigned y)
{
    return (image[y * 256 + x / 2] >> ((x & 1) ? 0 : 4)) & 15;
}
int main()
{
    for (unsigned i = 0; i < sizeof(before); ++i) before[i] = (i * 13 + i / 251) & 255;
    memcpy(after, before, sizeof(before));
    CourseButtons::arrange(after, 256);
    assert(CourseButtons::left[2] == CourseButtons::originalLeft[2]);
    for (unsigned button = 0; button < 5; ++button) {
        if (button) assert(CourseButtons::left[button] - CourseButtons::left[button-1] - 64 == 8);
        for (unsigned y = 297; y < 317; ++y)
            for (unsigned x = 0; x < 64; ++x)
                assert(pixel(after, CourseButtons::left[button] + x, y)
                    == pixel(before, CourseButtons::originalLeft[button] + x, y));
    }
    for (unsigned y = 0; y < 320; ++y)
        if (y < 297 || y >= 317) assert(memcmp(before+y*256, after+y*256, 256) == 0);
    puts("PASS: five unchanged button images, fixed COURSE 3, four 8-pixel gaps, untouched rows outside the button strip");
}
