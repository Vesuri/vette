#include "framework/AmigaHardware.h"
#include "PerfProbe.h"

extern "C" {
extern volatile uint16_t g_vbiCount;
extern volatile uint16_t g_macFramesPresented;

// State: 0 has not reached steady driving, 1 is measuring, 2 is frozen.
volatile uint16_t g_profileState = 0;
volatile uint16_t g_profileGeneration = 0;
volatile uint32_t g_profileStartEpoch = 0;
volatile uint32_t g_profileStopEpoch = 0;
volatile uint16_t g_profileStartField = 0;
volatile uint16_t g_profileStopField = 0;
volatile uint16_t g_profileStartFrames = 0;
volatile uint16_t g_profileStopFrames = 0;
volatile uint32_t g_profileTicks[kProfileCategoryCount] = {0};
volatile uint32_t g_profileCalls[kProfileCategoryCount] = {0};
}

#ifdef VETTE_PROBE
static uint32_t beamPosition()
{
    uint16_t high = *vposrPointer;
    uint16_t vh = *vhposrPointer;
    uint16_t line = (uint16_t)(((high & 1u) << 8) | (vh >> 8));
    return (uint32_t)line * 256u + (vh & 0xffu);
}

uint32_t vetteProfileBeamEpoch()
{
    // The field counter changes beside the beam wrap in the VBI handler.  Read
    // around VPOSR/VHPOSR so an interrupt between the two cannot manufacture a
    // one-field error.  Each scanline is divided into 256 horizontal beam units;
    // 313 lines per field is deliberately monotonic. PAL interlace's alternating
    // half-line makes its absolute scale differ by less than 0.2%, while every
    // category and the denominator share it.
    uint16_t before, after;
    uint32_t position;
    do {
        before = g_vbiCount;
        position = beamPosition();
        after = g_vbiCount;
    } while (before != after);
    return (uint32_t)before * (313u * 256u) + position;
}

void vetteProfileStart()
{
#ifdef VETTE_PROBE_FIELDS
    if (g_profileState != 0) return;
    for (uint16_t i = 0; i < kProfileCategoryCount; ++i) {
        g_profileTicks[i] = 0;
        g_profileCalls[i] = 0;
    }
    ++g_profileGeneration;
    g_profileStartField = g_vbiCount;
    g_profileStopField = g_vbiCount;
    g_profileStartFrames = g_macFramesPresented;
    g_profileStopFrames = g_macFramesPresented;
    g_profileStartEpoch = vetteProfileBeamEpoch();
    g_profileStopEpoch = g_profileStartEpoch;
    g_profileState = 1;
#endif
}

void vetteProfileOnVBI()
{
#ifdef VETTE_PROBE_FIELDS
    if (g_profileState != 1
        || (uint16_t)(g_vbiCount - g_profileStartField) < VETTE_PROBE_FIELDS) return;
    g_profileStopEpoch = vetteProfileBeamEpoch();
    g_profileStopField = g_vbiCount;
    g_profileStopFrames = g_macFramesPresented;
    g_profileState = 2;
#endif
}

VetteProfileScope::VetteProfileScope(VetteProfileCategory category)
    : m_category(category), m_start(0), m_generation(0)
{
    if (g_profileState != 1) return;
    m_generation = g_profileGeneration;
    m_start = vetteProfileBeamEpoch();
    ++g_profileCalls[category];
}

VetteProfileScope::~VetteProfileScope()
{
    if (!m_generation || m_generation != g_profileGeneration) return;
    uint32_t end;
    if (g_profileState == 1) end = vetteProfileBeamEpoch();
    else if (g_profileState == 2) end = g_profileStopEpoch;
    else return;
    if (end > m_start) g_profileTicks[m_category] += end - m_start;
}

VetteProfileCategory vetteProfileTrapCategory(uint16_t trap)
{
    switch (trap) {
    // QuickDraw drawing and state which is part of constructing the surface.
    case 0xa851: case 0xa852: case 0xa853: case 0xa873: case 0xa874:
    case 0xa87b: case 0xa889: case 0xa89b: case 0xa89c:
    case 0xa8a1: case 0xa8a2: case 0xa8a3: case 0xa8a4: case 0xa8ad:
    case 0xa8ec: case 0xa8f6: case 0xab1d:
        return kProfileDrawing;

    // Resource Manager calls plus the typed QuickDraw convenience getters.
    case 0xa994: case 0xa997: case 0xa998:
    case 0xa9a0: case 0xa9a1: case 0xa9a3:
    case 0xa9b9: case 0xa9bc:
        return kProfileResource;

    // No Sound Manager trap is implemented yet.  Keep this category explicit
    // so the profile says zero rather than silently folding future audio work
    // into compatibility overhead.
    default:
        return kProfileOtherTrap;
    }
}
#endif
