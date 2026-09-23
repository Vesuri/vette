#ifndef VETTE_MAC_LOADER_H
#define VETTE_MAC_LOADER_H

class VetteScreen;

class MacLoader {
public:
    static const uint32_t kPersistentScoreBytes = 1200;

    // Persistence I/O belongs to the platform while AmigaOS multitasking is
    // available. The loader only imports/exports the four original TIME
    // resources and records whether WriteResource made them dirty.
    bool importPersistentScores(const uint8_t* data, uint32_t size);
    bool exportPersistentScores(uint8_t* data, uint32_t size) const;
    bool persistentScoresDirty() const;

    // Validate and index the two original raw Macintosh resource forks while
    // AmigaDOS and normal process memory are still available. The application
    // CODE resources are copied to aligned resident storage for patching and
    // execution; the supplied file images remain untouched.
    bool prepareResourceForks(uint8_t* application, uint32_t applicationSize,
                              uint8_t* data, uint32_t dataSize);
    void releaseResourceForks();

    // Builds the complete A5 world, patches the already-resident CODE resources,
    // runs %A5Init, then transfers control to the application's first export.
    bool run(VetteScreen* screen);
};

// Classic Mac OS updates the low-memory KeyMap asynchronously from its
// keyboard interrupt.  The Amiga CIA edge path calls this bridge so original
// code that waits without making a Toolbox call still sees transitions.
extern "C" void vetteMacRawKeyChanged(uint8_t rawKey, bool down);

// The Macintosh mouse globals were maintained by a vertical-retrace task, not
// by GetNextEvent.  The Amiga VBI calls this after the time-critical bitplane
// pointer update and before sprite 0 is built for the upcoming field.
extern "C" void vetteMacMouseVBI();

#endif
