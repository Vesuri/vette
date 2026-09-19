/* Vette! platform boundary.
 *
 * The original Macintosh program and its compatibility layer run inside the
 * selected backend.  Machine takeover, display, input, audio, and restoration
 * are backend ownership; application startup only needs the resulting status.
 */
#ifndef VETTE_PLATFORM_H
#define VETTE_PLATFORM_H

class Platform {
public:
    // No constructor/destructor: the freestanding Amiga CRT has neither a
    // reliable cross-unit initialization order nor atexit support.
    bool run();
};

#endif
