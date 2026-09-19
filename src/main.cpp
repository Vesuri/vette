/* Vette! — platform-independent entry point. */
#include "platform/platform.h"

// ⚠ FILE SCOPE, not a function-local static. A function-local static needs a thread-safe
// initialization guard (`__cxa_guard_acquire`/`_release`), which the freestanding CRT does not
// provide. Platform stays stateless; large machine-specific storage belongs to the backend.
static Platform s_platform;

int main(void)
{
    return s_platform.run() ? 0 : 20;   // 20 = the AmigaDOS FAIL level
}
