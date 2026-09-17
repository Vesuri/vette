/* PlatformAmiga — the machine takeover.  See PlatformAmiga.h for the scope.
 *
 * The shape is inherited from the Revs port (same toolchain, same target, and its
 * ordering comments record failures that were paid for once already):
 *   LoadView(NULL) -> display DMA down -> VERTB vector taken over -> screen built ->
 *   publish to the ISR -> DMA up -> Forbid() -> frame pump -> restore in reverse.
 *
 * ⚠ INCLUDE ORDER IS LOAD-BEARING: every system header FIRST, AmigaHardware.h LAST
 * (its bare register macros collide with `struct Custom`'s members).
 */
#include <proto/exec.h>
#include <proto/graphics.h>
#include <exec/execbase.h>
#include <exec/interrupts.h>
#include <exec/nodes.h>
#include <exec/memory.h>
#include <graphics/gfxbase.h>
#include <graphics/view.h>
#include <hardware/dmabits.h>
#include <hardware/intbits.h>

#include "framework/AmigaHardware.h"
#include "PlatformAmiga.h"
#include "VetteScreen.h"

extern struct GfxBase* GfxBase;         // opened below; the global lives in GCCRuntime.cpp

// The embedded Target 1 frame (incbin.s).
extern "C" uint8_t vette_intro_planes[];
extern "C" uint8_t vette_intro_planes_end[];
extern "C" uint8_t vette_intro_palette[];

// ---------------------------------------------------------------------------
// ⚠⚠ EVERY GLOBAL A COMMITTED .gdb SCRIPT READS MUST BE IN amiga/Makefile's PROBE_SYMS.
// -Wl,--gc-sections drops an unreferenced counter, and gdb then resolves the name into
// .text and prints INSTRUCTION BYTES as a value -- a fake measurement, not an obvious
// zero.  `make probe-audit` enforces it on every link.  (CLAUDE.md)
//
// These five are Stage A's whole acceptance test: they say the display came up, in the
// mode that was asked for, showing the bytes that were meant to be there.
extern "C" {
volatile uint16_t g_vbiCount      = 0;   // real PAL fields, the only honest timebase
volatile uint32_t g_planeChecksum = 0;   // of the blob IN CHIP RAM (VetteScreen)
volatile uint16_t g_screenReady   = 0;   // 0 = allocation failed, 1 = displaying
volatile uint16_t g_laceFields    = 0;   // fields SINCE the display came up (the denominator)
volatile uint16_t g_longFields    = 0;   // ...of which long; ~half if LACE took
volatile uint16_t g_lofSamples[8];       // those fields' raw VPOSR, for the parity check
}

/* ⚠⚠ THE FIELD-PARITY RATIO HAS TO BE MEASURED FROM WHEN THE MODE IS SET, NOT FROM BOOT,
 * and getting that wrong produced a confident wrong answer twice in a row.
 *
 * The VERTB vector is taken over ~40 lines before screen.initialize() runs, so the handler
 * is already counting while the display is still the OS's non-interlaced one -- where LOF is
 * always 1.  Measured over the whole run that gave long/total = 0.636 (159 of 250): about 68
 * boot fields all long, then a correctly alternating remainder.  0.636 is not 1.0, so it does
 * not read as "interlace is dead", and it is not 0.5, so it does not read as working either.
 * It reads as a subtly broken display -- which is the most expensive kind of wrong number.
 *
 * So the counters below only advance once s_screen is published, and 0.5 means 0.5.  */

// ⚠⚠ THERE IS NO `g_bplcon0Read`, AND THE REASON IS WORTH KEEPING.  This file had one, on
// the argument that reading a register back beats trusting the write.  It cannot: BPLCON0 is
// WRITE-ONLY, and a write-only custom register reads as 0xFFFF (measured under FS-UAE --
// the probe printed `bplcon0(read) = 0xFFFF` against an expected 0xC205).  A readback that
// always returns 0xFFFF is not a weak test, it is a test that can never fail, which is worse
// than none.  What replaced it: a static_assert on the derived constant (VetteScreen.cpp,
// compile time) plus g_lofSamples below (run time, and the hardware's own answer).

static VetteScreen* s_screen = 0;

static struct Interrupt s_vbiServer;
static struct IntVector s_savedVertb;
static bool     s_vertbTaken  = false;
static uint16_t s_savedIntena = 0;

// exec puts IntVects[] at ExecBase+84, so VERTB (bit 5) is ExecBase+144 -- exactly the
// offset Kickstart's level-3 autovector stub dispatches through.  If this stops compiling,
// the vector takeover needs re-deriving before it is trusted.
static_assert(__builtin_offsetof(struct ExecBase, IntVects) == 84,
              "ExecBase::IntVects moved — re-check the VERTB vector takeover");

static uint32_t vbiHandler()
{
    // ⚠ Clearing the request is THIS handler's job now -- exec's server-chain walker used
    // to do it and we replaced it.  Miss it and level 3 re-triggers forever.
    *intreqPointer = (uint16_t)INTF_VERTB;

    // ⭐⭐ THE COPPER BITPLANE POINTERS GO FIRST, before any other ISR work.  "In the VBI
    // ISR" is not "in the vblank": anything behind another 100+ scanlines of handler lands
    // inside the displayed picture, and a torn pointer garbages the whole field.
    // (docs/amiga-lessons.md)
    if (s_screen) s_screen->vbiUpdate();

    // ⭐ Sample the RAW VPOSR for the first 8 fields.  The long/total ratio alone cannot
    // distinguish "LACE is not working" from "the LOF read is wrong" -- both pin it to 1.0.
    // The raw words separate them: a non-interlaced display reads a constant high byte with
    // LOF set, a working interlaced one alternates it, and a bad ADDRESS reads 0xFFFF.
    uint16_t vp = *vposrPointer;
    g_vbiCount++;

    if (s_screen) {                    // non-null only once the mode registers are set
        if (g_laceFields < 8) g_lofSamples[g_laceFields] = vp;
        g_laceFields++;
        if (vp & 0x8000) g_longFields++;   // LOF; see VetteScreen::vbiUpdate()
    }
    return 0;
}

// ---------------------------------------------------------------------------
bool PlatformAmiga::run()
{
    // Everything this function touches, it opens here and closes at the end.  See the header
    // for why none of this is in a constructor.
    GfxBase = (struct GfxBase*)OpenLibrary((CONST_STRPTR)"graphics.library", 33);
    if (!GfxBase) return false;     // nothing has been changed yet, so there is nothing to undo

    static VetteScreen screen;      // file-scope lifetime, off the stack — see src/main.cpp

    // --- takeover -----------------------------------------------------------
    struct View* savedView = GfxBase->ActiView;
    LoadView(NULL);
    WaitTOF();
    WaitTOF();

    // Raster + sprite + copper DMA off so no OS state leaks through.  Copper comes back
    // on below, once OUR list is installed.
    *dmaconPointer = (uint16_t)(DMAF_RASTER | DMAF_SPRITE | DMAF_COPPER);

    // Mask blit-done: nothing here consumes it and every armed one is a pointless level-3
    // dispatch into graphics.library's queue handler.  INTENA is restored verbatim.
    s_savedIntena = (uint16_t)(*intenarPointer);
    *intenaPointer = (uint16_t)INTF_BLIT;    // no SETCLR = disable
    *intreqPointer = (uint16_t)INTF_BLIT;

    // A KNOWN-BLANK display for the window before the screen exists: no bitplanes.
    // ⚠ The geometry is NOT set here.  It has exactly one owner, VetteScreen.
    *bplcon0Pointer = 0x0000;

    // --- take over the whole VERTB vector ------------------------------------
    // Not AddIntServer: exec's iv_Code IS the server-chain walker, so overwriting it drops
    // graphics.library / gameport.device / timer.device off the vblank entirely.  iv_Node
    // is cosmetic -- it is what OS debug tools report as the vector's owner.
    s_vbiServer.is_Node.ln_Type = NT_INTERRUPT;
    s_vbiServer.is_Node.ln_Pri  = 127;
    s_vbiServer.is_Node.ln_Name = (char*)"Vette VBI";
    s_vbiServer.is_Data = 0;
    s_vbiServer.is_Code = (void(*)())vbiHandler;
    {
        struct IntVector* iv = &SysBase->IntVects[INTB_VERTB];
        Disable();
        s_savedVertb = *iv;
        iv->iv_Data = 0;
        iv->iv_Code = (void(*)())vbiHandler;
        iv->iv_Node = &s_vbiServer.is_Node;
        Enable();
        s_vertbTaken = true;
    }

    // --- bring the screen up -------------------------------------------------
    bool ok = screen.initialize(vette_intro_planes, (const uint16_t*)vette_intro_palette);
    g_screenReady   = ok ? 1 : 0;
    g_planeChecksum = ok ? screen.pictureChecksum() : 0;

    // ⭐⭐ PUBLISH TO THE ISR ONLY ONCE THE SCREEN IS BUILT.  The VERTB vector has been ours
    // for ~40 lines already, so the handler is firing at 50 Hz throughout initialize() --
    // which calls AllocMem twice and comfortably spans a vblank.  An ISR that saw the
    // half-built object would patch a copper list that has not been written yet.  (This is
    // the Revs black-screen bug, which every probe reported as healthy.)
    if (ok) s_screen = &screen;

    // Our list is installed and the mode registers are set — safe to start display DMA.
    // The copper restarts from COP1LC (ours) at the next vblank.  ⚠ No sprite DMA: nothing
    // here uses sprites, and BPLCON2 already puts the playfield in front.
    if (ok)
        *dmaconPointer = (uint16_t)(DMAF_SETCLR | DMAF_MASTER | DMAF_COPPER | DMAF_RASTER);

    // --- run -----------------------------------------------------------------
    // Nothing here Wait()s, so multitasking can stay off for the duration.
    Forbid();

    // The Stage A frame pump.  There is no game body yet: the picture is static and the
    // only per-field work is the interlace pointer swap, which is the ISR's.
    // ⚠ QUIT IS THE BARE LEFT MOUSE BUTTON FOR NOW, not the CTRL+LMB chord amiga/run.sh
    // documents.  Reading CTRL needs the keyboard layer, which Stage A does not have; the
    // chord must arrive BEFORE anything binds the bare button (the Mac original is a
    // one-button machine, so the game will bind it).  docs/open-work.md carries the item.
    while (!AmigaHardware::isLeftMouseButtonPressed()) {
        uint16_t f = g_vbiCount;
        while (g_vbiCount == f) { }     // wait for the next field
    }

    Permit();

    // --- restore, in reverse --------------------------------------------------
    // VERTB goes back BEFORE the LoadView/WaitTOF restore: WaitTOF() is signalled by
    // graphics.library's VERTB server, which only runs once exec's walker is back.
    if (s_vertbTaken) {
        Disable();
        SysBase->IntVects[INTB_VERTB] = s_savedVertb;
        Enable();
        s_vertbTaken = false;
    }
    s_screen = 0;
    screen.shutdown();

    *dmaconPointer = (uint16_t)(DMAF_COPPER | DMAF_RASTER | DMAF_SPRITE);
    *intreqPointer = (uint16_t)INTF_BLIT;
    *intenaPointer = (uint16_t)(INTF_SETCLR | (s_savedIntena & 0x7FFFu));

    LoadView(savedView);
    WaitTOF();
    WaitTOF();

    // Closed here rather than in a destructor -- see the note in PlatformAmiga.h.  ⚠ AFTER
    // the LoadView restore, which needs GfxBase.
    CloseLibrary((struct Library*)GfxBase);
    GfxBase = 0;
    return true;
}
