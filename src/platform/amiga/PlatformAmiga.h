/* PlatformAmiga — the Amiga backend's machine takeover and Stage B launch.
 *
 * What it is: LoadView(NULL), display DMA down, the VERTB vector taken over wholesale,
 * VetteScreen brought up, the A5 loader entered behind the Line-A vector, everything restored
 * if execution returns.  Input, sound, and the Stage C Toolbox implementations do not exist yet.
 */
#ifndef VETTE_PLATFORM_AMIGA_H
#define VETTE_PLATFORM_AMIGA_H

// ⚠ NO <stdint.h> HERE.  The Amiga build force-includes framework/SASCCompat.h, which
// typedefs int8_t..uint32_t for m68k LP32; pulling in the compat stdint.h as well gives
// `conflicting declaration 'typedef signed char int8_t'` (it says `char`).  Both files are
// vendored, so the fix is to depend on the one that is already always there.

class PlatformAmiga {
public:
    // ⚠⚠ NO CONSTRUCTOR AND NO DESTRUCTOR, and both absences are load-bearing.
    //
    // NO CONSTRUCTOR: this object is a file-scope static (src/main.cpp says why it cannot be
    // a function-local one), and cross-translation-unit static initialisation order is
    // UNSPECIFIED.  GCCRuntime.cpp sets `SysBase` from location 4 in its own
    // __attribute__((constructor)), and every OS call -- OpenLibrary included -- goes
    // through SysBase.  A constructor here that opened graphics.library would be a coin
    // flip on whether SysBase was set yet, and the losing side is a null deref during
    // startup with nothing on screen to say so.  run() opens it, in a defined order.
    //
    // NO DESTRUCTOR: a static object with one makes GCC register an `atexit` call, and the
    // freestanding CRT has no atexit -- an undefined reference at link time.
    //
    // ⭐ So this class has no state that needs a lifetime, and `run()` both opens and closes
    // everything it touches.  Keep it that way.
    bool run();          // false = the takeover could not be set up (nothing was changed)
};

#endif
