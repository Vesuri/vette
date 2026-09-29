// Differential tests against the user's loaded original instructions, before
// any kernel entry is patched. The same addresses are reused for both runs.
#ifdef VETTE_GAME_KERNEL_VERIFY
#include "m68k_math.h"
extern "C" {
void vetteTestGameKernel(uint32_t* state, void (*entry)());
void vetteVertexTransform();
void vetteVertexDispatch();
extern uint16_t vetteVertexPassOriginal[];
void vetteGeometryTransform();
void vettePointTransform();
void vetteGeometryTransformFast();
void vettePointTransformFast();
extern uint16_t vetteGeometryOriginal[], vettePointOriginal[];
volatile uint32_t g_gameKernelLiveCases = 0, g_gameKernelLiveFailures = 0, g_gameKernelLiveKind = 0;
volatile uint32_t g_gameKernelFastTicks[2] = {}, g_gameKernelOriginalTicks[2] = {}, g_gameKernelTimedCases[2] = {};
extern volatile uint16_t g_vbiCount;
extern volatile uint32_t g_macDrivingIterations;
volatile uint32_t g_gameKernelCases = 0, g_gameKernelFailures = 0;
volatile uint32_t g_gameKernelFirstFailure = 0;
}
static uint32_t randomState = 0x913cab57;
static uint32_t nextRandom()
{
    randomState ^= randomState << 13;
    randomState ^= randomState >> 17;
    randomState ^= randomState << 5;
    return randomState;
}
static uint16_t matrix[14], coordinates[8], output[16], expectedOutput[16];
static void initialState(uint32_t* state)
{
    for (uint16_t i = 0; i < 16; ++i) state[i] = nextRandom();
}
static void compareState(uint32_t* fast, uint32_t* original, bool bad)
{
    for (uint16_t i = 0; i < 15; ++i) if (fast[i] != original[i]) bad = true;
    if ((fast[15] & 31) != (original[15] & 31)) bad = true;
    ++g_gameKernelCases;
    if (bad) {
        ++g_gameKernelFailures;
        if (!g_gameKernelFirstFailure) g_gameKernelFirstFailure = g_gameKernelCases;
    }
}
static void geometryCase(void (*fastEntry)(), void (*originalEntry)(), uint16_t kind, uint16_t sample)
{
    uint32_t fast[16], original[16];
    initialState(fast);
    for (uint16_t i = 0; i < 12; ++i) matrix[i] = (uint16_t)nextRandom();
    if (kind < 3) matrix[1] = matrix[3] = matrix[5] = matrix[7] = 0;
    if (kind == 0) matrix[0] = matrix[4] = matrix[8] = 0x7fff;
    if (kind == 1) matrix[0] = matrix[4] = matrix[8] = 0x8000;
    const uint16_t boundary[] = {0,1,0xffff,0x7fff,0x8000,0x4000,0xc000,0x3fff};
    for (uint16_t i = 0; i < 8; ++i)
        coordinates[i] = sample < 16 ? boundary[(sample+i)&7] : (uint16_t)nextRandom();
    fast[8] = (uint32_t)coordinates;
    fast[9] = (uint32_t)matrix;
    fast[10] = (uint32_t)(output + 4);
    for (uint16_t i = 0; i < 16; ++i) original[i] = fast[i];
    for (uint16_t i = 0; i < 16; ++i) output[i] = 0xa55a;
    vetteTestGameKernel(fast, fastEntry);
    for (uint16_t i = 0; i < 16; ++i) { expectedOutput[i] = output[i]; output[i] = 0xa55a; }
    vetteTestGameKernel(original, originalEntry);
    bool bad = false;
    for (uint16_t i = 0; i < 16; ++i) if (output[i] != expectedOutput[i]) bad = true;
    compareState(fast, original, bad);
}
static uint8_t globals[0x6200];
static uint16_t vertices[32], transformed[24], projected[64];
static uint16_t expectedTransformed[24], expectedProjected[64];
static void vertexPassCase(uint16_t kind, uint16_t cached, uint16_t sample)
{
    uint32_t fast[16], original[16];
    initialState(fast);
    for (uint16_t i = 0; i < 14; ++i) matrix[i] = (uint16_t)nextRandom();
    if (kind < 3) matrix[1] = matrix[3] = matrix[5] = matrix[7] = 0;
    if (kind == 0) matrix[0] = matrix[4] = matrix[8] = 0x7fff;
    if (kind == 1) matrix[0] = matrix[4] = matrix[8] = 0x8000;
    for (uint16_t i = 0; i < 32; ++i) vertices[i] = (uint16_t)nextRandom();
    uint8_t* a5 = globals + 0x6000;
    *(uint16_t*)(a5-0x3c6) = sample & 1;
    *(uint16_t*)(a5-0x356) = 0; *(uint16_t*)(a5-0x354) = 511;
    *(uint16_t*)(a5-0x352) = 0; *(uint16_t*)(a5-0x350) = 319;
    *(uint16_t*)(a5-0x5438) = 256; *(uint16_t*)(a5-0x5436) = 160;
    *(uint32_t*)(a5-0x5434) = 256; *(uint32_t*)(a5-0x5430) = 160;
    fast[1] = (fast[1] & 0xffff0000UL) | cached;
    fast[5] = (fast[5] & 0xffff0000UL) | (sample & 7);
    fast[8] = (uint32_t)vertices; fast[9] = (uint32_t)matrix;
    fast[10] = (uint32_t)transformed; fast[11] = (uint32_t)projected;
    fast[13] = (uint32_t)a5; fast[14] = (uint32_t)matrix;
    for (uint16_t i = 0; i < 16; ++i) original[i] = fast[i];
    for (uint16_t i = 0; i < 24; ++i) transformed[i] = (uint16_t)(i*277+sample);
    for (uint16_t i = 0; i < 64; ++i) projected[i] = 0xa55a;
    vetteTestGameKernel(fast, vetteVertexDispatch);
    for (uint16_t i = 0; i < 24; ++i) { expectedTransformed[i] = transformed[i]; transformed[i] = (uint16_t)(i*277+sample); }
    for (uint16_t i = 0; i < 64; ++i) { expectedProjected[i] = projected[i]; projected[i] = 0xa55a; }
    vetteTestGameKernel(original, (void (*)())vetteVertexPassOriginal);
    bool bad = false;
    for (uint16_t i = 0; i < 24; ++i) if (transformed[i] != expectedTransformed[i]) bad = true;
    for (uint16_t i = 0; i < 64; ++i) if (projected[i] != expectedProjected[i]) bad = true;
    compareState(fast, original, bad);
}

// Field/beam ticks, not host time. Both arms include the same register bridge
// and clock-read overhead; memory restoration/comparison is outside the clocks.
static uint32_t kernelClock()
{
    uint32_t field, beam;
    do {
        field = g_vbiCount;
        beam = ((*(volatile uint16_t*)0xdff004 & 1UL) << 16) | *(volatile uint16_t*)0xdff006;
    } while (field != g_vbiCount);
    return (vette_mulu16((uint16_t)field, 313) << 8) + beam;
}
// Live replay at the actual game's call boundary. Restore all touched
// transformed coordinates before executing the original oracle.
// Verification builds return the oracle state, and fail the observer on any
// discrepancy. These wrappers and their memory copies vanish in normal builds.
extern "C" void vetteVerifyLiveGameKernel(uint32_t* state, uint32_t kind)
{
    uint32_t fast[16], original[16];
    for (uint16_t i = 0; i < 16; ++i) fast[i] = original[i] = state[i];
    void (*entry)() = kind == 0 ? vetteGeometryTransformFast : vettePointTransformFast;
    void (*oracle)() = (void (*)())(kind == 0 ? vetteGeometryOriginal : vettePointOriginal);
    uint16_t* destination = (uint16_t*)state[10];
    uint16_t before[3] = {destination[0], destination[1], destination[2]};
    uint16_t expected[3];
    uint32_t beforeFast = kernelClock();
    vetteTestGameKernel(fast, entry);
    uint32_t fastTicks = kernelClock() - beforeFast;
    // Fixed word copies avoid a compiler-generated MOVE.B (An)+,(An,index)
    // in a combined byte loop: the destination would use the advanced An.
    expected[0] = destination[0];
    expected[1] = destination[1];
    expected[2] = destination[2];
    destination[0] = before[0];
    destination[1] = before[1];
    destination[2] = before[2];
    uint32_t beforeOriginal = kernelClock();
    vetteTestGameKernel(original, oracle);
    uint32_t originalTicks = kernelClock() - beforeOriginal;
    // Ignore startup (before our VBI counter exists) and a counter rollover.
    if (g_macDrivingIterations && fastTicks < 160256 && originalTicks < 160256) {
        g_gameKernelFastTicks[kind] += fastTicks;
        g_gameKernelOriginalTicks[kind] += originalTicks;
        ++g_gameKernelTimedCases[kind];
    }
    bool bad = destination[0] != expected[0] || destination[1] != expected[1]
            || destination[2] != expected[2];
    for (uint16_t i = 0; i < 15; ++i) if (fast[i] != original[i]) bad = true;
    if ((fast[15] & 31) != (original[15] & 31)) bad = true;
    ++g_gameKernelLiveCases;
    if (bad) { ++g_gameKernelLiveFailures; g_gameKernelLiveKind = kind; }
    for (uint16_t i = 0; i < 16; ++i) state[i] = original[i];
}
extern "C" bool vetteCheckGameKernels(void (*vertex)(), void (*geometry)(), void (*point)())
{
    for (uint16_t kind = 0; kind < 5; ++kind)
        for (uint16_t sample = 0; sample < 128; ++sample) {
            geometryCase(vetteVertexTransform, vertex, kind, sample);
            geometryCase(vetteGeometryTransformFast, geometry, kind, sample);
            geometryCase(vettePointTransformFast, point, kind, sample);
        }
    for (uint16_t kind = 0; kind < 5; ++kind)
        for (uint16_t cached = 0; cached < 2; ++cached)
            for (uint16_t sample = 0; sample < 32; ++sample)
                vertexPassCase(kind, cached, sample);
    return g_gameKernelFailures == 0 && g_gameKernelLiveFailures == 0;
}
#endif
