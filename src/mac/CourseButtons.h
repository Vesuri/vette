#pragma once
#include "../m68k_math.h"

namespace CourseButtons {
static const uint16_t count = 5, width = 64, top = 297, bottom = 317;
static const uint16_t originalLeft[count] = {38, 132, 226, 320, 413};
static const uint16_t left[count] = {82, 154, 226, 298, 370};

// The buttons are baked into PICT 26478. Preserve each button pixel exactly;
// resample only the surrounding map/water in the twenty-row button strip.
inline void arrange(uint8_t* pixels, uint16_t rowBytes)
{
    const uint16_t sourceEdges[] = {0,38,102,132,196,226,290,320,384,413,477,512};
    const uint16_t targetEdges[] = {0,82,146,154,218,226,290,298,362,370,434,512};
    uint16_t sourceX[512];
    for (uint16_t span = 0; span < 11; ++span) {
        uint16_t sourceWidth = sourceEdges[span+1] - sourceEdges[span];
        uint16_t targetWidth = targetEdges[span+1] - targetEdges[span];
        for (uint16_t x = targetEdges[span]; x < targetEdges[span+1]; ++x)
            sourceX[x] = sourceEdges[span] + vette_divu16(
                vette_mulu16(x - targetEdges[span], sourceWidth), targetWidth);
    }
    for (uint16_t y = top; y < bottom; ++y) {
        uint8_t* row = pixels + vette_mulu16(y, rowBytes);
        uint8_t original[256];
        for (uint16_t x = 0; x < 256; ++x) original[x] = row[x];
        for (uint16_t x = 0; x < 512; x += 2) {
            uint16_t a = sourceX[x], b = sourceX[x+1];
            uint8_t high = (original[a >> 1] >> ((a & 1) ? 0 : 4)) & 15;
            uint8_t low = (original[b >> 1] >> ((b & 1) ? 0 : 4)) & 15;
            row[x >> 1] = (uint8_t)((high << 4) | low);
        }
    }
}
}
