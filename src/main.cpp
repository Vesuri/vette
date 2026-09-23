/* Vette! — platform-independent entry point. */
#include "platform/platform.h"
#ifdef VETTE_PLATFORM_AMIGA
#include <proto/exec.h>
#include <dos/dosextens.h>
#include <workbench/startup.h>
#endif

// ⚠ FILE SCOPE, not a function-local static. A function-local static needs a thread-safe
// initialization guard (`__cxa_guard_acquire`/`_release`), which the freestanding CRT does not
// provide. Platform stays stateless; large machine-specific storage belongs to the backend.
static Platform s_platform;

#ifdef VETTE_PLATFORM_AMIGA
// The freestanding CRT does not implement Amiga Workbench startup.  A Shell
// launch has pr_CLI set and no startup message; an icon launch has no CLI and
// Workbench waits for us to take and eventually reply its WBStartup message.
// This must happen before Platform opens dos.library because the Process port
// otherwise still contains foreign Workbench traffic.
static struct WBStartup* getWorkbenchStartupMessage()
{
    struct Process* process = (struct Process*)FindTask(0);
    if (process->pr_CLI) return 0;
    WaitPort(&process->pr_MsgPort);
    return (struct WBStartup*)GetMsg(&process->pr_MsgPort);
}

// Reply strictly last.  Once Workbench receives this message it may unload our
// segment, so task switching must stay forbidden until the Process disappears.
static void replyWorkbenchStartupMessage(struct WBStartup* message)
{
    if (!message) return;
    Forbid();
    ReplyMsg(&message->sm_Message);
}
#endif

int main(void)
{
#ifdef VETTE_PLATFORM_AMIGA
    struct WBStartup* workbenchMessage = getWorkbenchStartupMessage();
    int result = s_platform.run() ? 0 : 20; // 20 = the AmigaDOS FAIL level
    replyWorkbenchStartupMessage(workbenchMessage);
    return result;
#else
    return s_platform.run() ? 0 : 20;
#endif
}
