// Diagnostic differential of the original byte loop and accelerated row.
// Test identical memory/register state, including alignment, overlap and CCR.
#ifdef VETTE_GAME_RASTER_VERIFY
extern "C" {
void vetteGameCopyRow();
void vetteGameCopyRowOriginal();
void vetteTestGameCopyRow(uint32_t* state, void (*entry)());
volatile uint32_t g_gameRasterVerifyCases = 0;
volatile uint32_t g_gameRasterVerifyFailures = 0;
}
static uint8_t memory[131104], expected[131104];
static void verifyRow(uint16_t countMinusOne, uint32_t source, uint32_t destination,
                      uint16_t flags, uint32_t size)
{
    uint32_t fast[16], original[16];
    for (uint16_t i = 0; i < 16; ++i) fast[i] = original[i] = 0x12345600UL + i;
    fast[2] = original[2] = 0x43210000UL | countMinusOne;
    fast[10] = original[10] = (uint32_t)(memory + destination);
    fast[11] = original[11] = (uint32_t)(memory + source);
    fast[15] = original[15] = flags;
    for (uint32_t i = 0; i < size; ++i) memory[i] = (uint8_t)(i * 13 + (i >> 8) + 7);
    vetteTestGameCopyRow(fast, vetteGameCopyRow);
    for (uint32_t i = 0; i < size; ++i) expected[i] = memory[i];
    for (uint32_t i = 0; i < size; ++i) memory[i] = (uint8_t)(i * 13 + (i >> 8) + 7);
    vetteTestGameCopyRow(original, vetteGameCopyRowOriginal);
    bool bad = false;
    for (uint32_t i = 0; i < size; ++i) if (memory[i] != expected[i]) bad = true;
    for (uint16_t i = 0; i < 15; ++i) if (fast[i] != original[i]) bad = true;
    if ((fast[15] & 31) != (original[15] & 31)) bad = true;
    ++g_gameRasterVerifyCases;
    if (bad) ++g_gameRasterVerifyFailures;
}
extern "C" bool vetteCheckGameRaster()
{
    const uint16_t lengths[] = {4, 8, 12, 20, 64, 256};
    const int16_t overlaps[] = {-8, -3, -1, 0, 1, 2, 3, 4, 5, 8, 16, 384};
    for (uint16_t n = 0; n < 6; ++n)
        for (uint16_t overlap = 0; overlap < 12; ++overlap)
            for (uint16_t alignment = 0; alignment < 4; ++alignment)
                for (uint16_t flags = 0; flags < 32; flags += 15)
                    verifyRow(lengths[n] - 1, 16 + alignment,
                              16 + alignment + overlaps[overlap], flags, 1024);
    // DBF's maximum extent and a backward-overlap case, with X both ways.
    verifyRow(65535, 16, 65552, 0, sizeof(memory));
    verifyRow(65535, 65552, 16, 31, sizeof(memory));
    return g_gameRasterVerifyFailures == 0;
}
#endif
