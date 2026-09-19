#include "platform.h"

#ifdef VETTE_PLATFORM_AMIGA
#include "amiga/PlatformAmiga.h"

bool Platform::run()
{
    // PlatformAmiga deliberately has no state or lifetime hooks.  Keeping the
    // backend local avoids exposing its headers through the shared boundary.
    PlatformAmiga backend;
    return backend.run();
}
#else
bool Platform::run()
{
    return false;
}
#endif
