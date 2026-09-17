/* Vette! — entry point.
 *
 * Stage A: bring the Amiga display up in the locked mode and show Target 1's captured
 * Macintosh frame from chip RAM.  No Macintosh code runs yet (docs/open-work.md).
 */
#ifdef VETTE_PLATFORM_AMIGA
#include "platform/amiga/PlatformAmiga.h"

// ⚠ FILE SCOPE, not a function-local static.  A function-local static needs a thread-safe
// initialisation guard (`__cxa_guard_acquire`/`_release`), and the freestanding CRT has
// neither -- an undefined reference at link time, not a runtime surprise.  It must also stay
// off the stack: the CRT's stack is small and this will grow to hold the Macintosh world.
static PlatformAmiga s_platform;

int main(void)
{
    return s_platform.run() ? 0 : 20;   // 20 = the AmigaDOS FAIL level
}
#else
int main(void) { return 0; }
#endif
