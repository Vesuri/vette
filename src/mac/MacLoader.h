#ifndef VETTE_MAC_LOADER_H
#define VETTE_MAC_LOADER_H

class VetteScreen;

class MacLoader {
public:
    // Builds the complete A5 world, makes all CODE segments resident, runs %A5Init,
    // then transfers control to the application's first jump-table export.
    bool run(VetteScreen* screen);
};

#endif
