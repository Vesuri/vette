/* Native regression for the generated Workbench icon. Not part of the helper. */
#include <exec/execbase.h>
#include <workbench/workbench.h>
#include <proto/exec.h>
#include <proto/dos.h>
#include <proto/icon.h>
struct ExecBase *SysBase;
struct DosLibrary *DOSBase;
struct Library *IconBase;
static int equal(const char *a,const char *b) {
    if(!a || !b) return 0;
    while(*a && *a==*b) { a++; b++; }
    return *a==*b;
}
int amiga_main(void) {
    struct DiskObject *icon; BPTR f; int ok=0;
    __asm__ volatile("move.l 4.w,%0":"=r"(SysBase));
    DOSBase=(struct DosLibrary *)OpenLibrary((CONST_STRPTR)"dos.library",37);
    if(DOSBase) {
        BPTR lock=CreateDir((CONST_STRPTR)"RAM:T"); if(lock) UnLock(lock);
        lock=CreateDir((CONST_STRPTR)"RAM:ENV"); if(lock) UnLock(lock);
        lock=Lock((CONST_STRPTR)"RAM:T",ACCESS_READ);
        if(lock && !AssignLock((CONST_STRPTR)"T",lock)) UnLock(lock);
        lock=Lock((CONST_STRPTR)"RAM:ENV",ACCESS_READ);
        if(lock && !AssignLock((CONST_STRPTR)"ENV",lock)) UnLock(lock);
    }
    IconBase=OpenLibrary((CONST_STRPTR)"icon.library",37);
    if(DOSBase && IconBase) {
        icon=GetDiskObject((CONST_STRPTR)"DH0:Install");
        if(icon) {
            ok=icon->do_Type==WBPROJECT && equal((const char *)icon->do_DefaultTool,"Installer")
                && icon->do_ToolTypes && equal((const char *)FindToolType(icon->do_ToolTypes,(CONST_STRPTR)"APPNAME"),"Vette!")
                && icon->do_StackSize==4096 && icon->do_Gadget.GadgetRender
                && icon->do_Gadget.Width==32 && icon->do_Gadget.Height==24;
            FreeDiskObject(icon);
        }
        if(ok) {
            icon=GetDiskObject((CONST_STRPTR)"DH0:Vette");
            ok=icon && icon->do_Type==WBTOOL && icon->do_StackSize==4096
                && icon->do_Gadget.GadgetRender && !icon->do_DefaultTool;
            if(icon) FreeDiskObject(icon);
        }
        if(ok && (f=Open((CONST_STRPTR)"DH2:icon-ok",MODE_NEWFILE))) { Write(f,(APTR)"OK\n",3); Close(f); }
    }
    if(IconBase) CloseLibrary(IconBase);
    if(DOSBase) CloseLibrary((struct Library *)DOSBase);
    return ok?0:20;
}
