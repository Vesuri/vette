#ifndef VETTE_PERF_PROBE_H
#define VETTE_PERF_PROBE_H

// Diagnostic-only phase accounting.  All calls compile to nothing in ordinary
// builds: the profiler reads custom-chip registers and is intentionally never
// part of a quoted shipping-build frame rate.
enum VetteProfileCategory {
    kProfileDrawing = 0,
    kProfileResource,
    kProfileAudio,
    kProfileOtherTrap,
    kProfilePresent,
    kProfileSync,
    kProfileWait,
    kProfileControl,
    kProfileVBI,
    kProfileC2P,
    kProfilePalette,
    kProfileCategoryCount
};

#ifdef VETTE_PROBE
uint32_t vetteProfileBeamEpoch();
void vetteProfileStart();
void vetteProfileOnVBI();
VetteProfileCategory vetteProfileTrapCategory(uint16_t trap);

class VetteProfileScope {
public:
    explicit VetteProfileScope(VetteProfileCategory category);
    ~VetteProfileScope();
private:
    VetteProfileCategory m_category;
    uint32_t m_start;
    uint16_t m_generation;
};
#else
inline void vetteProfileStart() {}
inline void vetteProfileOnVBI() {}
class VetteProfileScope {
public:
    explicit VetteProfileScope(VetteProfileCategory) {}
};
#endif

#endif
