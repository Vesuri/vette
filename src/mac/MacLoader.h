#ifndef VETTE_MAC_LOADER_H
#define VETTE_MAC_LOADER_H

class VetteScreen;

class MacLoader {
public:
    // Builds the complete A5 world, makes all CODE segments resident, runs %A5Init,
    // then transfers control to the application's first jump-table export.
    bool run(VetteScreen* screen);
};

// Classic Mac OS updates the low-memory KeyMap asynchronously from its
// keyboard interrupt.  The Amiga CIA edge path calls this bridge so original
// code that waits without making a Toolbox call still sees transitions.
extern "C" void vetteMacRawKeyChanged(uint8_t rawKey, bool down);

#endif
