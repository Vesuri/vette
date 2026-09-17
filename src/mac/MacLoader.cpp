#include <proto/exec.h>
#include <exec/memory.h>
#include <hardware/dmabits.h>

#include "MacLoader.h"
#include "ResourceArchive.h"
#include "platform/amiga/VetteScreen.h"
#include "platform/amiga/framework/AmigaHardware.h"

extern "C" {
extern uint8_t vette_code_0[],  vette_code_0_end[];
extern uint8_t vette_code_1[],  vette_code_1_end[];
extern uint8_t vette_code_2[],  vette_code_2_end[];
extern uint8_t vette_code_3[],  vette_code_3_end[];
extern uint8_t vette_code_4[],  vette_code_4_end[];
extern uint8_t vette_code_5[],  vette_code_5_end[];
extern uint8_t vette_code_6[],  vette_code_6_end[];
extern uint8_t vette_code_7[],  vette_code_7_end[];
extern uint8_t vette_code_8[],  vette_code_8_end[];
extern uint8_t vette_code_9[],  vette_code_9_end[];
extern uint8_t vette_code_10[], vette_code_10_end[];
extern uint8_t vette_resources[], vette_resources_end[];

void vette_line_a_handler();
void vette_call_mac_code(void* entry, void* a5);

volatile uint16_t g_stageBState = 0;
volatile uint16_t g_trapWord = 0;
volatile int32_t  g_trapSelector = -1;
volatile uint16_t g_trapSegment = 0xffff;
volatile uint32_t g_trapOffset = 0xffffffffUL;
volatile uint32_t g_trapPC = 0;
volatile uint32_t g_trapRegisters[15] = {0};
volatile uint32_t g_trapUserStack = 0;
volatile uint32_t g_resourceCount = 0;
volatile uint16_t g_jumpEntryCount = 0;
volatile uint16_t g_blockMoveCount = 0;
volatile uint16_t g_stageCDepth = 1;       // _BlockMove is row 1
volatile uint32_t g_macTicks = 0;
volatile uint32_t* g_macTicksAddress = 0;
volatile uint32_t g_macVBLCallbackEntry = 0;
volatile uint32_t g_macVBLCallbackTask = 0;
volatile uint32_t g_macVBLCallbackA5 = 0;
volatile uint32_t g_macVBLCallbackReturn = 0;
volatile uint16_t g_introAudioState = 0;
volatile uint32_t g_introAudioBytes = 0;
volatile uint16_t g_introAudioPeriod = 0;
char g_trapManager[24] = "";
char g_trapRoutine[24] = "";
}

static const uint32_t kBelowA5 = 31272;
static const uint32_t kAboveA5 = 4104;
static const uint32_t kJumpOffset = 32;
static const uint32_t kJumpBytes = 4072;
static const uint16_t kJumpCount = 509;
static uint8_t s_a5World[kBelowA5 + kAboveA5] __attribute__((aligned(4)));
static VetteScreen* s_loudStopScreen;
static ResourceArchive s_resourceArchive;
static uint8_t* s_resourceMasters[572];
static bool s_resourceLocked[572];
static bool s_resourcePurgeable[572];
static uint8_t s_quickDrawScreen[(512 / 8) * 320];
static uint8_t s_colorScreen[(512 / 2) * 320];
static uint8_t s_windowManagerPort[108];
static uint8_t s_windowManagerPixMap[50];
static uint8_t* s_windowManagerPixMapMaster;
static uint8_t s_mainDevice[62];
static uint8_t* s_mainDeviceMaster;
static uint8_t s_windowManagerColors[8 + 16 * 8];
static uint8_t* s_windowManagerColorsMaster;
static uint8_t s_windowManagerVisRgn[10];
static uint8_t* s_windowManagerVisRgnMaster;
static uint8_t s_windowManagerClipRgn[10];
static uint8_t* s_windowManagerClipRgnMaster;
static uint8_t s_grayRgn[10];
static uint8_t* s_grayRgnMaster;
static uint8_t s_textEditScrap[1];
static uint8_t* s_textEditScrapMaster;
static uint8_t s_trapTokens[4096];
static uint8_t* s_trapAddresses[4096];
static uint8_t* s_qdThePort;
static uint8_t* s_currentA5;
static uint16_t s_currentResourceFork = 0;  // application resource file at process launch

struct WindowSlot {
    uint8_t record[170];                    // WindowRecord plus DialogRecord tail
    uint8_t* window;
    bool used;
    uint8_t structureRegion[10];
    uint8_t* structureRegionMaster;
    uint8_t contentRegion[10];
    uint8_t* contentRegionMaster;
    uint8_t clipRegion[10];
    uint8_t* clipRegionMaster;
    uint8_t updateRegion[10];
    uint8_t* updateRegionMaster;
    uint8_t title[256];
    uint8_t* titleMaster;
    int16_t procID;
    uint8_t** palette;
    bool paletteUpdates;
    bool updating;
    bool dialog;
    uint16_t dialogItemCount;
    bool dialogDrawn;
};
static WindowSlot s_windows[8];
static uint8_t* s_windowList;
static uint32_t s_colorSeed = 1;
static uint8_t** s_activePalette;
static bool s_screenDirty = true;
static bool s_pixelsDirty = false;
static int16_t s_dirtyTop, s_dirtyLeft, s_dirtyBottom, s_dirtyRight;
static uint16_t read16(const uint8_t* p);

static void markDirty(const uint8_t* rectangle)
{
    if (!rectangle) return;
    int16_t top = (int16_t)read16(rectangle);
    int16_t left = (int16_t)read16(rectangle + 2);
    int16_t bottom = (int16_t)read16(rectangle + 4);
    int16_t right = (int16_t)read16(rectangle + 6);
    if (top >= bottom || left >= right) return;
    if (!s_pixelsDirty) {
        s_dirtyTop = top; s_dirtyLeft = left;
        s_dirtyBottom = bottom; s_dirtyRight = right;
        s_pixelsDirty = true;
    } else {
        if (top < s_dirtyTop) s_dirtyTop = top;
        if (left < s_dirtyLeft) s_dirtyLeft = left;
        if (bottom > s_dirtyBottom) s_dirtyBottom = bottom;
        if (right > s_dirtyRight) s_dirtyRight = right;
    }
    s_screenDirty = true;
}

// VBLTask is a 14-byte 68k record: qLink, qType, vblAddr, vblCount,
// vblPhase.  Keep the caller-owned records linked exactly as the classic
// Vertical Retrace Manager does.  Execution is deliberately a separate
// concern: calling application code from Amiga's supervisor-mode VERTB ISR
// would give Line-A traps the wrong exception/USP context.
static uint8_t* s_vblTasks[8];
static uint16_t s_vblTaskCount;
static uint32_t s_vblLastTick;

struct IntroSample {
    int16_t resourceID;
    uint8_t* chipData;
    uint32_t size;
};
static IntroSample s_introSamples[] = {
    {1425, 0, 0},                         // Opening song
    {19354, 0, 0},                        // cable car bell
    {11584, 0, 0},                        // Engine
    {28215, 0, 0},                        // mic
    {12083, 0, 0}                         // Signature
};
static bool s_introSoundStarted[5];
static uint32_t s_introMusicEndTick;
static uint32_t s_introEffectEndTick[2];  // Paula channels 2 and 3
static bool s_introLogoHeld;
static bool s_introLogoParked;
static uint16_t s_introLogoFrames;
static uint32_t s_introLastLogoDeadline;

struct GWorldSlot {
    uint8_t port[108];
    uint8_t pixMap[50];
    uint8_t* pixMapMaster;
    uint8_t visRegion[10];
    uint8_t* visRegionMaster;
    uint8_t clipRegion[10];
    uint8_t* clipRegionMaster;
    uint8_t* pixels;
    bool used;
    bool locked;
    bool purgeable;
};
// Initialize can keep six offscreen worlds alive at once.  This is capacity,
// not emulated heap exhaustion: a full slot table must never masquerade as a
// Macintosh memFullErr while Exec still has memory available.
static GWorldSlot s_gworlds[8];

struct FontManagerState {
    bool initialized;
    int16_t systemFont;
    int16_t systemSize;
};
static FontManagerState s_fontManager;

struct WindowManagerState {
    bool initialized;
    bool palettesInitialized;
    uint8_t* port;
};
static WindowManagerState s_windowManager;

struct MenuManagerState {
    bool initialized;
    uint8_t** colorTable;
};
static MenuManagerState s_menuManager;

struct TextEditState {
    bool initialized;
    uint8_t** scrap;
};
static TextEditState s_textEdit;

struct DialogManagerState {
    bool initialized;
    uint8_t* resumeProcedure;
};
static DialogManagerState s_dialogManager;

struct CursorState {
    bool initialized;
    bool visible;
    const uint8_t* image;
};
static CursorState s_cursor;

struct MemoryManagerState {
    int16_t error;
    uint32_t allocationCount;
    bool applicationZoneMaximized;
};
static MemoryManagerState s_memoryManager;

struct PointerAllocation {
    uint8_t* pointer;
    uint8_t* master;
    uint32_t size;
};
static PointerAllocation s_pointerAllocations[128];

struct HandleAllocation {
    uint8_t* master;
    uint32_t size;
    bool locked;
    bool purgeable;
};
static HandleAllocation s_handleAllocations[128];
static uint16_t s_handleAllocationCount;

struct Segment { uint8_t* begin; uint8_t* end; const char* name; };
static const Segment s_segments[11] = {
    {vette_code_0, vette_code_0_end, "CODE0"},
    {vette_code_1, vette_code_1_end, "MAIN"},
    {vette_code_2, vette_code_2_end, "INITIALIZE"},
    {vette_code_3, vette_code_3_end, "COMMUNICATION"},
    {vette_code_4, vette_code_4_end, "LOAD"},
    {vette_code_5, vette_code_5_end, "SCORE"},
    {vette_code_6, vette_code_6_end, "TRAFFIC"},
    {vette_code_7, vette_code_7_end, "FRED"},
    {vette_code_8, vette_code_8_end, "INTRO"},
    {vette_code_9, vette_code_9_end, "SOUND"},
    {vette_code_10, vette_code_10_end, "%A5INIT"}
};

static uint16_t read16(const uint8_t* p) { return (uint16_t)((p[0] << 8) | p[1]); }
static uint32_t read32(const uint8_t* p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint32_t)p[2] << 8) | p[3];
}
static void write16(uint8_t* p, uint16_t v) { p[0] = (uint8_t)(v >> 8); p[1] = (uint8_t)v; }
static void write32(uint8_t* p, uint32_t v)
{
    p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16);
    p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v;
}
static void copyString(char* out, const char* in)
{
    uint16_t i = 0;
    while (i != 23 && in[i]) { out[i] = in[i]; ++i; }
    out[i] = 0;
}

struct TrapName { uint16_t word; const char* manager; const char* routine; };
static const TrapName s_trapNames[] = {
    {0xa02e,"MEMORY MANAGER","BLOCKMOVE"}, {0xa9f1,"SEGMENT MANAGER","UNLOADSEG"},
    {0xa86e,"QUICKDRAW","INITGRAF"},
    {0xa8fe,"FONT MANAGER","INITFONTS"}, {0xa912,"WINDOW MANAGER","INITWINDOWS"},
    {0xa930,"MENU MANAGER","INITMENUS"}, {0xa9cc,"TEXTEDIT","TEINIT"},
    {0xa97b,"DIALOG MANAGER","INITDIALOGS"},
    {0xa997,"RESOURCE MANAGER","OPENRESFILE"},
    {0xa9a1,"RESOURCE MANAGER","GETNAMEDRESOURCE"},
    {0xa063,"MEMORY MANAGER","MAXAPPLZONE"}, {0xa01c,"MEMORY MANAGER","FREEMEM"},
    {0xa090,"TOOLBOX UTILITIES","SYSENVIRONS"},
    {0xa746,"TRAP MANAGER","GETTOOLTRAPADDRESS"},
    {0xa31e,"MEMORY MANAGER","NEWPTRCLEAR"}, {0xaa32,"QUICKDRAW","GETGDEVICE"},
    {0xa9a0,"RESOURCE MANAGER","GETRESOURCE"}, {0xa064,"MEMORY MANAGER","MOVEHHI"},
    {0xa029,"MEMORY MANAGER","HLOCK"}, {0xa11e,"MEMORY MANAGER","NEWPTR"},
    {0xa51e,"MEMORY MANAGER","NEWPTRSYS"},
    {0xa122,"MEMORY MANAGER","NEWHANDLE"},
    {0xa128,"MEMORY MANAGER","RECOVERHANDLE"},
    {0xa025,"MEMORY MANAGER","GETHANDLESIZE"},
    {0xa024,"MEMORY MANAGER","SETHANDLESIZE"},
    {0xa9ef,"MEMORY MANAGER","PTRANDHAND"},
    {0xa02a,"MEMORY MANAGER","HUNLOCK"}, {0xa049,"MEMORY MANAGER","HPURGE"},
    {0xa04a,"MEMORY MANAGER","HNOPURGE"},
    {0xa03b,"TIME MANAGER","DELAY"},
    {0xa03c,"TEXT UTILITIES","CMPSTRING"}, {0xa23c,"TEXT UTILITIES","CMPSTRING"},
    {0xa43c,"TEXT UTILITIES","CMPSTRING"}, {0xa63c,"TEXT UTILITIES","CMPSTRING"},
    {0xa033,"VERTICAL RETRACE","VINSTALL"},
    {0xa998,"RESOURCE MANAGER","USERESFILE"}, {0xa994,"RESOURCE MANAGER","CURRESFILE"},
    {0xaa46,"WINDOW MANAGER","GETNEWCWINDOW"}, {0xa91b,"WINDOW MANAGER","MOVEWINDOW"},
    {0xa915,"WINDOW MANAGER","SHOWWINDOW"},
    {0xaa92,"PALETTE MANAGER","GETNEWPALETTE"}, {0xa873,"QUICKDRAW","SETPORT"},
    {0xaa28,"COLOR MANAGER","GETCTSEED"}, {0xa91f,"WINDOW MANAGER","SELECTWINDOW"},
    {0xa922,"WINDOW MANAGER","BEGINUPDATE"}, {0xa923,"WINDOW MANAGER","ENDUPDATE"},
    {0xa889,"QUICKDRAW","TEXTMODE"}, {0xa9b9,"QUICKDRAW","GETCURSOR"},
    {0xa851,"QUICKDRAW","SETCURSOR"},
    {0xa97c,"DIALOG MANAGER","GETNEWDIALOG"}, {0xa981,"DIALOG MANAGER","DRAWDIALOG"},
    {0xab1d,"QUICKDRAW","QDEXTENSIONS"},
    {0xaa95,"PALETTE MANAGER","SETPALETTE"}, {0xa146,"TRAP MANAGER","GETTRAPADDRESS"},
    {0xaa2e,"GRAPHICS DEVICE MANAGER","INITGDEVICE"},
    {0xa047,"TRAP MANAGER","SETTRAPADDRESS"}, {0xa983,"DIALOG MANAGER","DISPOSEDIALOG"},
    {0xa850,"QUICKDRAW","INITCURSOR"}, {0xa9bc,"QUICKDRAW","GETPICTURE"},
    {0xa8f6,"QUICKDRAW","DRAWPICTURE"}, {0xa89b,"QUICKDRAW","PENSIZE"},
    {0xa89c,"QUICKDRAW","PENMODE"}, {0xa8a1,"QUICKDRAW","FRAMERECT"},
    {0xa8a9,"QUICKDRAW","INSETRECT"}, {0xa8b0,"QUICKDRAW","FRAMEROUNDRECT"},
    {0xa8ec,"QUICKDRAW","COPYBITS"}, {0xa8a3,"QUICKDRAW","ERASERECT"},
    {0xa87b,"QUICKDRAW","CLIPRECT"}, {0xa974,"EVENT MANAGER","BUTTON"},
    {0xa98d,"DIALOG MANAGER","GETDITEM"}, {0xa98f,"DIALOG MANAGER","SETITEXT"},
    {0xa914,"WINDOW MANAGER","DISPOSEWINDOW"}, {0xa90d,"WINDOW MANAGER","PAINTBEHIND"},
    {0xa04d,"MEMORY MANAGER","PURGEMEM"}, {0xa04c,"MEMORY MANAGER","COMPACTMEM"},
    {0xa93a,"MENU MANAGER","DISABLEITEM"}, {0xa931,"MENU MANAGER","NEWMENU"},
    {0xa933,"MENU MANAGER","APPENDMENU"}, {0xa9bf,"MENU MANAGER","GETRMENU"},
    {0xa937,"MENU MANAGER","DRAWMENUBAR"}, {0xa970,"EVENT MANAGER","GETNEXTEVENT"},
    {0xa9b4,"EVENT MANAGER","SYSTEMTASK"}, {0xaa94,"PALETTE MANAGER","ACTIVATEPALETTE"},
    {0xa874,"QUICKDRAW","GETPORT"}
};

static bool buildA5World(uint8_t*& a5)
{
    if ((uint32_t)(vette_code_0_end - vette_code_0) != 16 + kJumpBytes
        || read32(vette_code_0) != kAboveA5 || read32(vette_code_0 + 4) != kBelowA5
        || read32(vette_code_0 + 8) != kJumpBytes || read32(vette_code_0 + 12) != kJumpOffset)
        return false;
    for (uint32_t i = 0; i < sizeof(s_a5World); ++i) s_a5World[i] = 0;
    a5 = s_a5World + kBelowA5;
    uint8_t* jump = a5 + kJumpOffset;
    const uint8_t* source = vette_code_0 + 16;
    for (uint16_t i = 0; i < kJumpCount; ++i, source += 8, jump += 8) {
        uint16_t offset = read16(source);
        uint16_t segment = read16(source + 4);
        if (read16(source + 2) != 0x3f3c || read16(source + 6) != 0xa9f0
            || segment == 0 || segment > 10
            || offset >= (uint32_t)(s_segments[segment].end - s_segments[segment].begin) - 4)
            return false;
        write16(jump, segment);             // retained for caller attribution / UnLoadSeg
        write16(jump + 2, 0x4ef9);          // JMP abs.l
        write32(jump + 4, (uint32_t)(s_segments[segment].begin + 4 + offset));
        ++g_jumpEntryCount;
    }
    return true;
}

static bool redirectLowMemoryGlobals(uint8_t* a5)
{
    // The shipped Main segment directly reads two documented Mac low-memory globals.
    // Those addresses belong to exception vectors / AmigaOS on this machine, so redirect
    // the same-width instructions to reserved application-parameter slots above A5.
    if (read16(vette_code_1 + 0x570) != 0x2038 || read16(vette_code_1 + 0x572) != 0x0156
        || read16(vette_code_1 + 0x8a6) != 0x2078 || read16(vette_code_1 + 0x8a8) != 0x09de
        || read16(vette_code_2 + 0x8c4) != 0x2078 || read16(vette_code_2 + 0x8c6) != 0x09ee)
        return false;
    write16(vette_code_1 + 0x570, 0x202d);  // MOVE.L 4(A5),D0: RndSeed
    write16(vette_code_1 + 0x572, 4);
    write16(vette_code_1 + 0x8a6, 0x206d);  // MOVEA.L 8(A5),A0: WMgrPort
    write16(vette_code_1 + 0x8a8, 8);
    write16(vette_code_2 + 0x8c4, 0x206d);  // MOVEA.L 12(A5),A0: GrayRgn
    write16(vette_code_2 + 0x8c6, 12);

    // Ticks ($016A) is read directly at 87 instruction sites.  Every measured
    // encoding uses absolute-word source EA $38; d16(A5) is the same width, so
    // redirect all of them to the next reserved application-parameter slot.
    uint16_t tickReferences = 0;
    for (uint16_t segment = 1; segment <= 10; ++segment) {
        uint8_t* code = s_segments[segment].begin;
        uint32_t size = (uint32_t)(s_segments[segment].end - code);
        for (uint32_t offset = 2; offset + 1 < size; offset += 2) {
            uint16_t opcode = read16(code + offset - 2);
            if (read16(code + offset) == 0x016a && (opcode & 0x003f) == 0x0038) {
                write16(code + offset - 2, (uint16_t)((opcode & 0xffc0) | 0x002d));
                write16(code + offset, 16);
                ++tickReferences;
            }
        }
    }
    if (tickReferences != 87) return false;
    write32(a5 + 4, 1);
    write32(a5 + 8, 0);
    write32(a5 + 12, 0);
    write32(a5 + 16, g_macTicks);
    g_macTicksAddress = (volatile uint32_t*)(a5 + 16);
    return true;
}

static void blockMove(uint8_t* source, uint8_t* destination, uint32_t count)
{
    if (destination > source && destination < source + count) {
        source += count;
        destination += count;
        if (((uint32_t)source ^ (uint32_t)destination) & 1) {
            while (count) { --source; --destination; *destination = *source; --count; }
            return;
        }
        if ((uint32_t)source & 1) {
            --source; --destination; *destination = *source; --count;
        }
        while (count >= 2) {
            source -= 2; destination -= 2;
            *(uint16_t*)destination = *(const uint16_t*)source;
            count -= 2;
        }
        if (count) { --source; --destination; *destination = *source; }
    } else {
        if (((uint32_t)source ^ (uint32_t)destination) & 1) {
            while (count--) *destination++ = *source++;
            return;
        }
        if ((uint32_t)source & 1) {
            *destination++ = *source++; --count;
        }
        while (count >= 2) {
            *(uint16_t*)destination = *(const uint16_t*)source;
            source += 2; destination += 2; count -= 2;
        }
        if (count) *destination = *source;
    }
}

static void blockClear(uint8_t* destination, uint32_t count)
{
    if ((uint32_t)destination & 1) {
        *destination++ = 0;
        if (!--count) return;
    }
    while (count >= 2) {
        *(uint16_t*)destination = 0;
        destination += 2;
        count -= 2;
    }
    if (count) *destination = 0;
}

static uint8_t** getResource(uint32_t type, int16_t id)
{
    // GetResource searches the current resource file first.  The system resource chain is
    // absent on the port; the two shipped forks are searched in chain order after it.
    for (uint16_t pass = 0; pass < s_resourceArchive.forkCount(); ++pass) {
        uint16_t fork = (uint16_t)(s_currentResourceFork + pass);
        if (fork >= s_resourceArchive.forkCount()) fork -= s_resourceArchive.forkCount();
        for (uint32_t i = 0; i < s_resourceArchive.resourceCount(); ++i) {
            ResourceArchive::Item item;
            if (!s_resourceArchive.item(i, item)) return 0;
            if (item.fork == fork && item.type == type && item.id == id) {
                s_resourceMasters[i] = (uint8_t*)item.data;
                return &s_resourceMasters[i];
            }
        }
    }
    return 0;
}

static IntroSample* introSample(uint16_t index)
{
    if (index >= sizeof(s_introSamples) / sizeof(s_introSamples[0])) return 0;
    IntroSample& sample = s_introSamples[index];
    if (sample.chipData) return &sample;

    ResourceArchive::Item item;
    if (!s_resourceArchive.find(1, 0x494e5354UL, sample.resourceID, item) || !item.size)
        return 0;
    const uint8_t* source = item.data;
    uint32_t size = item.size;
    // Short Bogas instruments carry an eight-byte instrument header.  Its
    // final word is the exact PCM byte count; the long samples are bare PCM.
    if (size > 8 && read32(source) == 0 && read16(source + 6) == size - 8) {
        source += 8;
        size -= 8;
    }
    uint32_t allocated = (size + 1) & ~1UL;
    if (!size || allocated > 131070UL) return 0;
    sample.chipData = (uint8_t*)AllocMem(allocated, MEMF_CHIP);
    if (!sample.chipData) return 0;
    sample.size = size;
    for (uint32_t i = 0; i < size; ++i) sample.chipData[i] = source[i] ^ 0x80;
    if (allocated != size) sample.chipData[size] = 0;
    return &sample;
}

static void playIntroSample(uint16_t sampleIndex, uint16_t channel, uint16_t volume)
{
    IntroSample* sample = introSample(sampleIndex);
    if (!sample || channel > 3) { g_introAudioState = 3; return; }
    uint16_t dma = (uint16_t)(DMAF_AUD0 << channel);
    volatile uint8_t* audio = (volatile uint8_t*)(0xdff0a0UL + channel * 16);
    *dmaconPointer = dma;
    *(volatile uint32_t*)(audio + 0) = (uint32_t)sample->chipData;
    *(volatile uint16_t*)(audio + 4) = (uint16_t)((sample->size + 1) / 2);
    *(volatile uint16_t*)(audio + 6) = 319; // 11,118.8 Hz; Mac nominal 11.127 kHz
    *(volatile uint16_t*)(audio + 8) = volume;
    *dmaconPointer = (uint16_t)(DMAF_SETCLR | DMAF_MASTER | dma);
}

static void stopIntroChannel(uint16_t channel)
{
    uint16_t dma = (uint16_t)(DMAF_AUD0 << channel);
    volatile uint8_t* audio = (volatile uint8_t*)(0xdff0a0UL + channel * 16);
    *dmaconPointer = dma;
    *(volatile uint16_t*)(audio + 8) = 0;
}

static void stabilizeIntroAnimation()
{
    if (!s_currentA5) return;
    if (read16(s_currentA5 - 0x58)) {
        uint8_t* tram = s_currentA5 - 0x19e;
        int16_t left = (int16_t)read16(tram + 2);
        if (left < 0) {
            // Intro's cable-car callback has no terminal branch: on a real
            // Macintosh the later actors finish while it is arriving at x=0,
            // but a slower host walks it off the lower-left edge.  Apply the
            // complete overshoot and retire only that callback.
            write16(tram + 0, (uint16_t)((int16_t)read16(tram + 0) + left));
            write16(tram + 2, 0);
            write16(tram + 4, (uint16_t)((int16_t)read16(tram + 4) + left));
            write16(tram + 6, (uint16_t)((int16_t)read16(tram + 6) - left));
            write32(s_currentA5 - 0xa2, 0x7fffffffUL);
        }
    }

    // The fourth callback is armed from an absolute tick deadline, whereas
    // the Corvette approach and singer/mic motion advance per completed draw.
    // On the A1200 compatibility path the absolute deadline can overtake that
    // work.  Hold it ten ticks ahead until the original code raises its own
    // mic-hit flag; the logo then follows the completed animation normally.
    if (read32(s_currentA5 - 0x9a) && !read16(s_currentA5 - 0x52)
        && !read16(s_currentA5 - 0x8a)) {
        write32(s_currentA5 - 0x9a, 0x7fffffffUL);
        s_introLogoHeld = true;
    } else if (s_introLogoHeld && read16(s_currentA5 - 0x52)
               && !read16(s_currentA5 - 0x8a)) {
        write32(s_currentA5 - 0x9a, g_macTicks + 10);
        s_introLogoHeld = false;
    }

    if (read16(s_currentA5 - 0x8a) && !s_introLogoParked) {
        uint32_t deadline = read32(s_currentA5 - 0x9a);
        if (deadline != s_introLastLogoDeadline && deadline != 0x7fffffffUL) {
            s_introLastLogoDeadline = deadline;
            ++s_introLogoFrames;
        }
        if (s_introLogoFrames >= 1) {
            // The first pass constructs the complete VETTE composite.  Later
            // ten-tick callbacks repeat the same five CopyBits rectangles
            // without changing their geometry; keep the completed pixels and
            // begin the original 600-tick hold only after that expensive pass.
            write32(s_currentA5 - 0x9a, 0x7fffffffUL);
            write32(s_currentA5 - 0x5004, g_macTicks + 600);
            s_introLogoParked = true;
        } else write32(s_currentA5 - 0x5004, 0x7fffffffUL);
    }
}

static void updateIntroAudio()
{
    if (!s_currentA5) return;

    // Follow the original intro's own one-shot flags.  The Mac code sets each
    // immediately after its BogasLoad call, so animation and sound remain tied
    // to the same state transitions even when drawing falls behind real time.
    if (!s_introSoundStarted[0] && read16(s_currentA5 - 0x5a)) {
        playIntroSample(0, 0, 48);
        playIntroSample(0, 1, 48);           // centred music
        s_introSoundStarted[0] = true;
        g_introAudioBytes = s_introSamples[0].size;
        g_introAudioPeriod = 319;
        if (g_introAudioState != 3) g_introAudioState = 1;
    }
    if (!s_introSoundStarted[1] && read16(s_currentA5 - 0x58)) {
        playIntroSample(1, 2, 64);
        s_introEffectEndTick[0] = g_macTicks + 54;
        s_introSoundStarted[1] = true;
    }
    if (!s_introSoundStarted[2] && read16(s_currentA5 - 0x56)) {
        playIntroSample(2, 2, 40);            // engine loops until the logo sting
        s_introEffectEndTick[0] = 0;
        s_introSoundStarted[2] = true;
    }
    if (!s_introSoundStarted[3] && read16(s_currentA5 - 0x52)) {
        playIntroSample(3, 3, 64);
        s_introEffectEndTick[1] = g_macTicks + 241;
        s_introSoundStarted[3] = true;
    }
    if (!s_introSoundStarted[4] && read16(s_currentA5 - 0x54)) {
        // Signature is the logo music, not another effect over the opening
        // piano.  Replace the centred music pair and silence the engine voice;
        // unlike Opening song, Signature is a one-shot.
        stopIntroChannel(0);
        stopIntroChannel(1);
        stopIntroChannel(2);
        playIntroSample(4, 0, 48);
        playIntroSample(4, 1, 48);
        s_introMusicEndTick = g_macTicks + 243;
        s_introEffectEndTick[0] = 0;
        s_introSoundStarted[4] = true;
    }
    if (s_introMusicEndTick
        && (int32_t)(g_macTicks - s_introMusicEndTick) >= 0) {
        stopIntroChannel(0);
        stopIntroChannel(1);
        s_introMusicEndTick = 0;
        if (g_introAudioState != 3) g_introAudioState = 2;
    }
    for (uint16_t i = 0; i < 2; ++i)
        if (s_introEffectEndTick[i]
            && (int32_t)(g_macTicks - s_introEffectEndTick[i]) >= 0) {
            stopIntroChannel((uint16_t)(i + 2));
            s_introEffectEndTick[i] = 0;
        }
}

static uint8_t asciiUpper(uint8_t c)
{
    return c >= 'a' && c <= 'z' ? (uint8_t)(c - ('a' - 'A')) : c;
}

// EqualString's register trap compares MacRoman bytes.  Bit 10 of the trap
// word makes case count; bit 9 makes diacritical marks count.  These tables
// are the complete MacRoman lowercase and mark-stripping maps, rather than an
// ASCII approximation that would quietly mis-handle resource names.
static const uint8_t kMacRomanLower[256] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
    0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,
    0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f,
    0x40,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x5b,0x5c,0x5d,0x5e,0x5f,
    0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b,0x7c,0x7d,0x7e,0x7f,
    0x8a,0x8c,0x8d,0x8e,0x96,0x9a,0x9f,0x87,0x88,0x89,0x8a,0x8b,0x8c,0x8d,0x8e,0x8f,
    0x90,0x91,0x92,0x93,0x94,0x95,0x96,0x97,0x98,0x99,0x9a,0x9b,0x9c,0x9d,0x9e,0x9f,
    0xa0,0xa1,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xab,0xac,0xad,0xbe,0xbf,
    0xb0,0xb1,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xbb,0xbc,0xbd,0xbe,0xbf,
    0xc0,0xc1,0xc2,0xc3,0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0x88,0x8b,0x9b,0xcf,0xcf,
    0xd0,0xd1,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0xd8,0xd8,0xda,0xdb,0xdc,0xdd,0xde,0xdf,
    0xe0,0xe1,0xe2,0xe3,0xe4,0x89,0x90,0x87,0x91,0x8f,0x92,0x94,0x95,0x93,0x97,0x99,
    0xf0,0x98,0x9c,0x9e,0x9d,0xf5,0xf6,0xf7,0xf8,0xf9,0xfa,0xfb,0xfc,0xfd,0xfe,0xff
};

static const uint8_t kMacRomanWithoutMarks[256] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
    0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f,
    0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f,
    0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f,
    0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f,
    0x50,0x51,0x52,0x53,0x54,0x55,0x56,0x57,0x58,0x59,0x5a,0x5b,0x5c,0x5d,0x5e,0x5f,
    0x60,0x61,0x62,0x63,0x64,0x65,0x66,0x67,0x68,0x69,0x6a,0x6b,0x6c,0x6d,0x6e,0x6f,
    0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78,0x79,0x7a,0x7b,0x7c,0x7d,0x7e,0x7f,
    0x41,0x41,0x43,0x45,0x4e,0x4f,0x55,0x61,0x61,0x61,0x61,0x61,0x61,0x63,0x65,0x65,
    0x65,0x65,0x69,0x69,0x69,0x69,0x6e,0x6f,0x6f,0x6f,0x6f,0x6f,0x75,0x75,0x75,0x75,
    0xa0,0xa1,0xa2,0xa3,0xa4,0xa5,0xa6,0xa7,0xa8,0xa9,0xaa,0xab,0xac,0x3d,0xae,0xaf,
    0xb0,0xb1,0xb2,0xb3,0xb4,0xb5,0xb6,0xb7,0xb8,0xb9,0xba,0xbb,0xbc,0xbd,0xbe,0xbf,
    0xc0,0xc1,0xc2,0xc3,0xc4,0xc5,0xc6,0xc7,0xc8,0xc9,0xca,0x41,0x41,0x4f,0xce,0xcf,
    0xd0,0xd1,0xd2,0xd3,0xd4,0xd5,0xd6,0xd7,0x79,0x59,0xda,0xdb,0xdc,0xdd,0xde,0xdf,
    0xe0,0xe1,0xe2,0xe3,0xe4,0x41,0x45,0x41,0x45,0x45,0x49,0x49,0x49,0x49,0x4f,0x4f,
    0xf0,0x4f,0x55,0x55,0x55,0xf5,0xf6,0xf7,0xf8,0xf9,0xfa,0xfb,0xfc,0xfd,0xfe,0xff
};

static uint8_t normalizedMacRoman(uint8_t value, bool caseSensitive, bool marksSensitive)
{
    if (!marksSensitive) value = kMacRomanWithoutMarks[value];
    if (!caseSensitive) value = kMacRomanLower[value];
    return value;
}

static bool equalMacRomanStrings(const uint8_t* first, uint16_t firstLength,
                                 const uint8_t* second, uint16_t secondLength,
                                 bool caseSensitive, bool marksSensitive)
{
    if (!first || !second || firstLength != secondLength) return false;
    for (uint16_t i = 0; i < firstLength; ++i)
        if (normalizedMacRoman(first[i], caseSensitive, marksSensitive)
            != normalizedMacRoman(second[i], caseSensitive, marksSensitive)) return false;
    return true;
}

static bool resourceNameEquals(const ResourceArchive::Item& item, const uint8_t* name)
{
    if (!name || name[0] != item.nameLength) return false;
    for (uint16_t i = 0; i < item.nameLength; ++i)
        if (asciiUpper(name[i + 1]) != asciiUpper(item.name[i])) return false;
    return true;
}

static uint8_t** getNamedResource(uint32_t type, const uint8_t* name)
{
    for (uint16_t pass = 0; pass < s_resourceArchive.forkCount(); ++pass) {
        uint16_t fork = (uint16_t)(s_currentResourceFork + pass);
        if (fork >= s_resourceArchive.forkCount()) fork -= s_resourceArchive.forkCount();
        for (uint32_t i = 0; i < s_resourceArchive.resourceCount(); ++i) {
            ResourceArchive::Item item;
            if (!s_resourceArchive.item(i, item)) return 0;
            if (item.fork == fork && item.type == type && resourceNameEquals(item, name)) {
                s_resourceMasters[i] = (uint8_t*)item.data;
                return &s_resourceMasters[i];
            }
        }
    }
    return 0;
}

static bool pascalEquals(const uint8_t* value, const char* expected)
{
    uint16_t length = 0;
    while (expected[length]) ++length;
    if (!value || value[0] != length) return false;
    for (uint16_t i = 0; i < length; ++i)
        if (asciiUpper(value[i + 1]) != asciiUpper((uint8_t)expected[i])) return false;
    return true;
}

static int16_t openResourceFile(const uint8_t* name)
{
    if (s_resourceArchive.forkCount() > 1 && pascalEquals(name, "Vette!.DATA")) {
        s_currentResourceFork = 1;
        return 1;
    }
    return -1;
}

static void initGraf(uint8_t* thePort)
{
    // QDGlobals is a 206-byte decrementing record whose last field is thePort.
    // InitGraf receives &thePort; all other public globals have negative offsets.
    s_qdThePort = thePort;
    for (int16_t offset = -202; offset < 4; ++offset) thePort[offset] = 0;

    // The five standard QuickDraw patterns, from light to dark in memory order.
    static const uint8_t patterns[40] = {
        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, // white   (-8)
        0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff, // black   (-16)
        0xaa,0x55,0xaa,0x55,0xaa,0x55,0xaa,0x55, // gray    (-24)
        0x88,0x22,0x88,0x22,0x88,0x22,0x88,0x22, // ltGray  (-32)
        0x77,0xdd,0x77,0xdd,0x77,0xdd,0x77,0xdd  // dkGray  (-40)
    };
    for (uint16_t pattern = 0; pattern < 5; ++pattern)
        for (uint16_t byte = 0; byte < 8; ++byte)
            thePort[-8 * (int16_t)(pattern + 1) + byte] = patterns[pattern * 8 + byte];

    // The standard 16x16 arrow Cursor: image, mask, then hot spot (0,0).
    static const uint16_t arrowImage[16] = {
        0x0000,0x4000,0x6000,0x7000,0x7800,0x7c00,0x7e00,0x7f00,
        0x7f80,0x7c00,0x6c00,0x4600,0x0600,0x0300,0x0300,0x0000
    };
    static const uint16_t arrowMask[16] = {
        0xc000,0xe000,0xf000,0xf800,0xfc00,0xfe00,0xff00,0xff80,
        0xffc0,0xffe0,0xfe00,0xef00,0xcf00,0x0780,0x0780,0x0380
    };
    uint8_t* arrow = thePort - 108;
    for (uint16_t i = 0; i < 16; ++i) {
        write16(arrow + i * 2, arrowImage[i]);
        write16(arrow + 32 + i * 2, arrowMask[i]);
    }

    // screenBits is a one-bit BitMap describing the whole logical screen.
    uint8_t* screenBits = thePort - 122;
    write32(screenBits, (uint32_t)s_quickDrawScreen);
    write16(screenBits + 4, 512 / 8);
    write16(screenBits + 6, 0);             // bounds.top
    write16(screenBits + 8, 0);             // bounds.left
    write16(screenBits + 10, 320);          // bounds.bottom
    write16(screenBits + 12, 512);          // bounds.right
    write32(thePort - 126, 1);               // randSeed
    write32(thePort, 0);                     // no current GrafPort until InitWindows/SetPort
}

static void initFonts()
{
    // Classic InitFonts selects the system font.  Keep the selection as manager state;
    // GrafPort text attributes are established when a port is opened, not here.
    s_fontManager.initialized = true;
    s_fontManager.systemFont = 0;             // system font
    s_fontManager.systemSize = 12;
}

static void writeRect(uint8_t* p, int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    write16(p, (uint16_t)top); write16(p + 2, (uint16_t)left);
    write16(p + 4, (uint16_t)bottom); write16(p + 6, (uint16_t)right);
}

static void initRegion(uint8_t* region, uint8_t*& master,
                       int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    master = region;
    write16(region, 10);                    // rectangular region: header only
    writeRect(region + 2, top, left, bottom, right);
}

static void initWindowManagerPort()
{
    for (uint16_t i = 0; i < sizeof(s_windowManagerPort); ++i) s_windowManagerPort[i] = 0;
    for (uint16_t i = 0; i < sizeof(s_windowManagerPixMap); ++i) s_windowManagerPixMap[i] = 0;
    for (uint16_t i = 0; i < sizeof(s_mainDevice); ++i) s_mainDevice[i] = 0;
    for (uint16_t i = 0; i < sizeof(s_windowManagerColors); ++i) s_windowManagerColors[i] = 0;

    s_windowManagerColorsMaster = s_windowManagerColors;
    write32(s_windowManagerColors, 1);      // ctSeed
    write16(s_windowManagerColors + 4, 0);  // ctFlags
    write16(s_windowManagerColors + 6, 15); // ctSize is the final array index
    for (uint16_t i = 0; i < 16; ++i) {
        uint8_t* spec = s_windowManagerColors + 8 + i * 8;
        write16(spec, i);
        uint16_t level = (uint16_t)((15 - i) * 0x1111U);
        write16(spec + 2, level); write16(spec + 4, level); write16(spec + 6, level);
    }

    s_windowManagerPixMapMaster = s_windowManagerPixMap;
    write32(s_windowManagerPixMap, (uint32_t)s_colorScreen);
    write16(s_windowManagerPixMap + 4, 0x8000 | (512 / 2));
    writeRect(s_windowManagerPixMap + 6, 0, 0, 320, 512);
    write32(s_windowManagerPixMap + 22, 72UL << 16); // hRes
    write32(s_windowManagerPixMap + 26, 72UL << 16); // vRes
    write16(s_windowManagerPixMap + 30, 0);          // indexed pixelType
    write16(s_windowManagerPixMap + 32, 4);          // pixelSize
    write16(s_windowManagerPixMap + 34, 1);          // cmpCount
    write16(s_windowManagerPixMap + 36, 4);          // cmpSize
    write32(s_windowManagerPixMap + 42, (uint32_t)&s_windowManagerColorsMaster);

    // One active screen GDevice is sufficient for the shipped single-monitor game.
    // gdPMap is at +22 in a classic GDevice record and is itself a Handle.
    s_mainDeviceMaster = s_mainDevice;
    write16(s_mainDevice + 4, 0);           // clutType
    write16(s_mainDevice + 20, 1);          // screenDevice
    write32(s_mainDevice + 22, (uint32_t)&s_windowManagerPixMapMaster);
    writeRect(s_mainDevice + 34, 0, 0, 320, 512);

    initRegion(s_windowManagerVisRgn, s_windowManagerVisRgnMaster, 0, 0, 320, 512);
    initRegion(s_windowManagerClipRgn, s_windowManagerClipRgnMaster,
               -32767, -32767, 32767, 32767);
    initRegion(s_grayRgn, s_grayRgnMaster, 20, 0, 320, 512);

    // WMgrPort remains an old-style GrafPort on this system.  Vette reads its
    // embedded BitMap directly to obtain the screen bounds before centering windows.
    write32(s_windowManagerPort + 2, (uint32_t)s_colorScreen);
    write16(s_windowManagerPort + 6, 512 / 2);
    writeRect(s_windowManagerPort + 8, 0, 0, 320, 512);
    writeRect(s_windowManagerPort + 16, 0, 0, 320, 512);
    write32(s_windowManagerPort + 24, (uint32_t)&s_windowManagerVisRgnMaster);
    write32(s_windowManagerPort + 28, (uint32_t)&s_windowManagerClipRgnMaster);
    for (uint16_t i = 0; i < 8; ++i) {
        s_windowManagerPort[32 + i] = 0;              // bkPat = white
        s_windowManagerPort[40 + i] = 0xff;           // fillPat = black
        s_windowManagerPort[58 + i] = 0xff;           // pnPat = black
    }
    write16(s_windowManagerPort + 52, 1);             // pnSize.v
    write16(s_windowManagerPort + 54, 1);             // pnSize.h
    write16(s_windowManagerPort + 56, 8);             // patCopy
    write16(s_windowManagerPort + 68, s_fontManager.systemFont);
    write16(s_windowManagerPort + 72, 1);             // srcOr
    write16(s_windowManagerPort + 74, s_fontManager.systemSize);
    write32(s_windowManagerPort + 80, 33);            // blackColor
    write32(s_windowManagerPort + 84, 30);            // whiteColor

    s_windowManager.initialized = true;
    s_windowManager.palettesInitialized = true;       // InitWindows calls InitPalettes
    s_windowManager.port = s_windowManagerPort;
    write32(s_qdThePort, (uint32_t)s_windowManagerPort);
    write32(s_currentA5 + 8, (uint32_t)s_windowManagerPort);
    write32(s_currentA5 + 12, (uint32_t)&s_grayRgnMaster);
}

static void initColorPort(uint8_t* port, uint8_t** visRgn, uint8_t** clipRgn,
                          int16_t top, int16_t left, int16_t bottom, int16_t right)
{
    write32(port + 2, (uint32_t)&s_windowManagerPixMapMaster);
    write16(port + 6, 0xc000);                        // CGrafPort version
    writeRect(port + 16, top, left, bottom, right);
    write32(port + 24, (uint32_t)visRgn);
    write32(port + 28, (uint32_t)clipRgn);
    write16(port + 42, 0xffff);
    write16(port + 44, 0xffff);
    write16(port + 46, 0xffff);                       // rgbBkColor = white
    write16(port + 52, 1);
    write16(port + 54, 1);
    write16(port + 56, 8);                            // patCopy
    write16(port + 68, s_fontManager.systemFont);
    write16(port + 72, 1);                            // srcOr
    write16(port + 74, s_fontManager.systemSize);
    write32(port + 80, 33);                           // blackColor
    write32(port + 84, 30);                           // whiteColor
}

static uint8_t* newColorWindow(int16_t id, uint8_t* storage, uint8_t* behind)
{
    uint8_t** resource = getResource(0x57494e44UL, id); // 'WIND'
    if (!resource || !*resource) return 0;
    const uint8_t* wind = *resource;

    WindowSlot* slot = 0;
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (!s_windows[i].used) { slot = &s_windows[i]; break; }
    if (!slot) return 0;
    slot->used = true;
    slot->dialog = false;
    for (uint16_t i = 0; i < sizeof(slot->record); ++i) slot->record[i] = 0;

    int16_t top = (int16_t)read16(wind);
    int16_t left = (int16_t)read16(wind + 2);
    int16_t bottom = (int16_t)read16(wind + 4);
    int16_t right = (int16_t)read16(wind + 6);
    uint8_t* window = storage ? storage : slot->record;
    slot->window = window;
    if (storage)
        for (uint16_t i = 0; i < 156; ++i) storage[i] = 0;

    initRegion(slot->structureRegion, slot->structureRegionMaster,
               top, left, bottom, right);
    initRegion(slot->contentRegion, slot->contentRegionMaster,
               top, left, bottom, right);
    initRegion(slot->clipRegion, slot->clipRegionMaster,
               top, left, bottom, right);
    initRegion(slot->updateRegion, slot->updateRegionMaster, 0, 0, 0, 0);
    initColorPort(window, &slot->contentRegionMaster, &slot->clipRegionMaster,
                  top, left, bottom, right);

    write16(window + 108, 0);                         // windowKind
    window[110] = wind[10];                           // visible
    window[112] = wind[11];                           // goAwayFlag
    write32(window + 114, (uint32_t)&slot->structureRegionMaster);
    write32(window + 118, (uint32_t)&slot->contentRegionMaster);
    write32(window + 122, (uint32_t)&slot->updateRegionMaster);
    slot->procID = (int16_t)read16(wind + 8);         // WDEF selection for later operations
    uint8_t titleLength = wind[16];
    slot->title[0] = titleLength;
    for (uint16_t i = 0; i < titleLength; ++i) slot->title[i + 1] = wind[17 + i];
    slot->titleMaster = slot->title;
    write32(window + 134, (uint32_t)&slot->titleMaster);
    write32(window + 144, (uint32_t)s_windowList);
    write32(window + 152, read32(wind + 12));         // refCon
    s_windowList = window;                            // front of our window chain
    (void)behind;                                     // both shipped calls use behindWindow=-1
    return window;
}

static uint8_t* newDialog(int16_t id, uint8_t* storage, uint8_t* behind)
{
    uint8_t** resource = getResource(0x444c4f47UL, id); // 'DLOG'
    if (!resource || !*resource) return 0;
    const uint8_t* dlog = *resource;
    WindowSlot* slot = 0;
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (!s_windows[i].used) { slot = &s_windows[i]; break; }
    if (!slot) return 0;
    slot->used = true;
    slot->dialog = true;
    uint8_t* dialog = storage ? storage : slot->record;
    slot->window = dialog;
    for (uint16_t i = 0; i < sizeof(slot->record); ++i) dialog[i] = 0;

    int16_t top = (int16_t)read16(dlog);
    int16_t left = (int16_t)read16(dlog + 2);
    int16_t bottom = (int16_t)read16(dlog + 4);
    int16_t right = (int16_t)read16(dlog + 6);
    initRegion(slot->structureRegion, slot->structureRegionMaster, top, left, bottom, right);
    initRegion(slot->contentRegion, slot->contentRegionMaster, top, left, bottom, right);
    initRegion(slot->clipRegion, slot->clipRegionMaster, top, left, bottom, right);
    initRegion(slot->updateRegion, slot->updateRegionMaster, 0, 0, 0, 0);
    initColorPort(dialog, &slot->contentRegionMaster, &slot->clipRegionMaster,
                  top, left, bottom, right);

    dialog[110] = dlog[10];
    dialog[112] = dlog[12];
    write32(dialog + 114, (uint32_t)&slot->structureRegionMaster);
    write32(dialog + 118, (uint32_t)&slot->contentRegionMaster);
    write32(dialog + 122, (uint32_t)&slot->updateRegionMaster);
    slot->procID = (int16_t)read16(dlog + 8);
    uint8_t titleLength = dlog[20];
    slot->title[0] = titleLength;
    for (uint16_t i = 0; i < titleLength; ++i) slot->title[i + 1] = dlog[21 + i];
    slot->titleMaster = slot->title;
    write32(dialog + 134, (uint32_t)&slot->titleMaster);
    write32(dialog + 144, (uint32_t)s_windowList);
    write32(dialog + 152, read32(dlog + 14));
    write32(dialog + 156,
            (uint32_t)getResource(0x4449544cUL, (int16_t)read16(dlog + 18))); // 'DITL'
    write16(dialog + 164, 0xffff);           // no editable-text item selected
    write16(dialog + 168, 1);                // default item
    s_windowList = dialog;
    (void)behind;
    return dialog;
}

static void moveWindow(uint8_t* window, int16_t h, int16_t v, bool front)
{
    int16_t height = (int16_t)(read16(window + 20) - read16(window + 16));
    int16_t width = (int16_t)(read16(window + 22) - read16(window + 18));
    writeRect(window + 16, v, h, (int16_t)(v + height), (int16_t)(h + width));
    uint8_t** structure = (uint8_t**)read32(window + 114);
    uint8_t** content = (uint8_t**)read32(window + 118);
    if (structure && *structure) writeRect(*structure + 2, v, h, v + height, h + width);
    if (content && *content) writeRect(*content + 2, v, h, v + height, h + width);
    if (front) s_windowList = window;
}

static WindowSlot* windowSlot(uint8_t* window)
{
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (s_windows[i].used && s_windows[i].window == window) return &s_windows[i];
    return 0;
}

static bool disposeWindow(uint8_t* window)
{
    WindowSlot* slot = windowSlot(window);
    if (!slot) return false;
    uint8_t* next = (uint8_t*)read32(window + 144);
    if (s_windowList == window) s_windowList = next;
    else {
        for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i) {
            uint8_t* candidate = s_windows[i].used ? s_windows[i].window : 0;
            if (candidate && (uint8_t*)read32(candidate + 144) == window) {
                write32(candidate + 144, (uint32_t)next);
                break;
            }
        }
    }
    if ((uint8_t*)read32(s_qdThePort) == window)
        write32(s_qdThePort, (uint32_t)s_windowManagerPort);
    window[110] = 0;
    write32(window + 144, 0);
    slot->used = false;
    slot->window = 0;
    slot->dialog = false;
    slot->dialogItemCount = 0;
    slot->dialogDrawn = false;
    return true;
}

static bool disposeDialog(uint8_t* dialog)
{
    WindowSlot* slot = windowSlot(dialog);
    return slot && slot->dialog && disposeWindow(dialog);
}

static int32_t resourceHandleIndex(uint8_t** handle);
static uint8_t** newHandle(uint32_t size, bool clear);

static uint32_t resourceHandleSize(uint8_t** handle)
{
    int32_t index = resourceHandleIndex(handle);
    ResourceArchive::Item item;
    return index >= 0 && s_resourceArchive.item((uint32_t)index, item) ? item.size : 0;
}

static void fillColorRect(int16_t top, int16_t left, int16_t bottom, int16_t right,
                          uint8_t color)
{
    if (top < 0) top = 0;
    if (left < 0) left = 0;
    if (bottom > 320) bottom = 320;
    if (right > 512) right = 512;
    for (int16_t y = top; y < bottom; ++y)
        for (int16_t x = left; x < right; ++x) {
            uint8_t* pixel = s_colorScreen + (uint32_t)y * (512 / 2) + (x >> 1);
            if (x & 1) *pixel = (uint8_t)((*pixel & 0xf0) | (color & 0x0f));
            else *pixel = (uint8_t)((*pixel & 0x0f) | ((color & 0x0f) << 4));
        }
}

static bool drawDialog(uint8_t* dialog)
{
    WindowSlot* slot = windowSlot(dialog);
    if (!slot || !slot->dialog) return false;
    uint8_t** itemsHandle = (uint8_t**)read32(dialog + 156);
    uint32_t size = resourceHandleSize(itemsHandle);
    if (!itemsHandle || !*itemsHandle || size < 2) return false;
    const uint8_t* items = *itemsHandle;
    uint16_t count = (uint16_t)(read16(items) + 1);
    uint32_t offset = 2;
    for (uint16_t i = 0; i < count; ++i) {
        if (offset + 14 > size) return false;
        uint8_t dataLength = items[offset + 13];
        offset += 14 + dataLength;
        if (offset & 1) ++offset;
        if (offset > size) return false;
    }
    slot->dialogItemCount = count;
    slot->dialogDrawn = true;
    dialog[110] = 1;
    write32(s_qdThePort, (uint32_t)dialog);
    fillColorRect((int16_t)read16(dialog + 16), (int16_t)read16(dialog + 18),
                  (int16_t)read16(dialog + 20), (int16_t)read16(dialog + 22), 0);
    return true;
}

static bool unpackPackBitsRow(const uint8_t* packed, uint32_t packedSize,
                              uint8_t* unpacked, uint16_t rowBytes)
{
    uint32_t source = 0;
    uint16_t destination = 0;
    while (source < packedSize && destination < rowBytes) {
        int8_t header = (int8_t)packed[source++];
        if (header >= 0) {
            uint16_t count = (uint16_t)header + 1;
            if (source + count > packedSize || destination + count > rowBytes) return false;
            for (uint16_t i = 0; i < count; ++i) unpacked[destination++] = packed[source++];
        } else if (header != -128) {
            uint16_t count = (uint16_t)(1 - header);
            if (source >= packedSize || destination + count > rowBytes) return false;
            uint8_t value = packed[source++];
            for (uint16_t i = 0; i < count; ++i) unpacked[destination++] = value;
        }
    }
    return destination == rowBytes && source == packedSize;
}

static uint32_t multiplyUnsigned16(uint16_t first, uint16_t second)
{
    uint32_t product = first;
    __asm__ volatile ("mulu.w %1,%0" : "+d" (product) : "d" (second));
    return product;
}

static uint8_t packedPixel(const uint8_t* pixels, uint16_t rowBytes,
                           int16_t boundsTop, int16_t boundsLeft, int16_t x, int16_t y)
{
    const uint8_t* byte = pixels + multiplyUnsigned16((uint16_t)(y - boundsTop), rowBytes)
                         + (uint16_t)(x - boundsLeft) / 2;
    return (x - boundsLeft) & 1 ? (uint8_t)(*byte & 0x0f) : (uint8_t)(*byte >> 4);
}

static void setPackedPixel(uint8_t* pixels, uint16_t rowBytes,
                           int16_t boundsTop, int16_t boundsLeft,
                           int16_t x, int16_t y, uint8_t value)
{
    uint8_t* byte = pixels + multiplyUnsigned16((uint16_t)(y - boundsTop), rowBytes)
                    + (uint16_t)(x - boundsLeft) / 2;
    if ((x - boundsLeft) & 1) *byte = (uint8_t)((*byte & 0xf0) | (value & 0x0f));
    else *byte = (uint8_t)((*byte & 0x0f) | ((value & 0x0f) << 4));
}

static uint32_t multiplyDivide(uint16_t value, uint16_t multiplier, uint16_t divisor)
{
    if (!divisor) return 0;
    if (multiplier == divisor) return value;
    uint32_t quotient = value;
    __asm__ volatile ("mulu.w %1,%0" : "+d" (quotient) : "d" (multiplier));
    // Every caller maps one 16-bit coordinate between rectangles, so the
    // quotient is itself a 16-bit coordinate.  DIVU.W leaves that quotient in
    // the low word and the remainder in the high word.
    __asm__ volatile ("divu.w %1,%0" : "+d" (quotient) : "d" (divisor));
    return quotient & 0xffff;
}

static bool drawPackedPictureBits(const uint8_t* picture, uint32_t size, uint32_t& offset,
                                  const uint8_t* pictureFrame, const uint8_t* targetRect)
{
    if (offset + 46 > size) return false;
    const uint8_t* pixMap = picture + offset;
    uint16_t rowBytes = (uint16_t)(read16(pixMap) & 0x3fff);
    uint16_t pixelSize = read16(pixMap + 28);
    if (!(read16(pixMap) & 0x8000) || (pixelSize != 4 && pixelSize != 8) || !rowBytes)
        return false;
    int16_t sourceTop = (int16_t)read16(pixMap + 2);
    int16_t sourceLeft = (int16_t)read16(pixMap + 4);
    int16_t sourceBottom = (int16_t)read16(pixMap + 6);
    int16_t sourceRight = (int16_t)read16(pixMap + 8);
    if (sourceBottom <= sourceTop || sourceRight <= sourceLeft) return false;
    offset += 46;

    if (offset + 8 > size) return false;
    const uint8_t* colorTable = picture + offset;
    uint16_t colorFlags = read16(colorTable + 4);
    uint16_t finalColor = read16(colorTable + 6);
    if (pixelSize == 8 && finalColor > 255) return false;
    uint32_t colorBytes = 8UL + ((uint32_t)finalColor + 1) * 8;
    if (offset + colorBytes > size) return false;
    uint8_t colorMap[256];
    for (uint16_t i = 0; i < 256; ++i) colorMap[i] = 0;
    if (pixelSize == 8) {
        for (uint16_t i = 0; i <= finalColor; ++i) {
            const uint8_t* sourceColor = colorTable + 8 + (uint32_t)i * 8;
            uint16_t sourceIndex = colorFlags & 0x8000 ? i : read16(sourceColor);
            uint32_t bestDistance = 0xffffffffUL;
            uint8_t bestIndex = 0;
            for (uint8_t destinationIndex = 0; destinationIndex < 16; ++destinationIndex) {
                const uint8_t* destinationColor
                    = s_windowManagerColors + 8 + (uint16_t)destinationIndex * 8;
                uint16_t sr = read16(sourceColor + 2), sg = read16(sourceColor + 4);
                uint16_t sb = read16(sourceColor + 6);
                uint16_t dr = read16(destinationColor + 2), dg = read16(destinationColor + 4);
                uint16_t db = read16(destinationColor + 6);
                uint32_t distance = (sr > dr ? sr - dr : dr - sr)
                                  + (sg > dg ? sg - dg : dg - sg)
                                  + (sb > db ? sb - db : db - sb);
                if (distance < bestDistance) {
                    bestDistance = distance;
                    bestIndex = destinationIndex;
                }
            }
            if (sourceIndex < 256) colorMap[sourceIndex] = bestIndex;
        }
    }
    offset += colorBytes;
    if (offset + 18 > size) return false;
    const uint8_t* rasterSource = picture + offset;
    const uint8_t* rasterDestination = picture + offset + 8;
    uint16_t mode = read16(picture + offset + 16);
    if (mode != 0) return false;              // srcCopy is the measured title path
    offset += 18;

    uint16_t height = (uint16_t)(sourceBottom - sourceTop);
    uint32_t pixelBytes = multiplyUnsigned16(rowBytes, height);
    uint8_t* pixels = (uint8_t*)AllocMem(pixelBytes, 0);
    if (!pixels) return false;
    bool valid = true;
    for (uint16_t row = 0; row < height && valid; ++row) {
        if (offset + (rowBytes > 250 ? 2 : 1) > size) { valid = false; break; }
        uint16_t packedSize;
        if (rowBytes > 250) { packedSize = read16(picture + offset); offset += 2; }
        else packedSize = picture[offset++];
        if (offset + packedSize > size
            || !unpackPackBitsRow(picture + offset, packedSize,
                                  pixels + multiplyUnsigned16(row, rowBytes), rowBytes)) {
            valid = false; break;
        }
        offset += packedSize;
    }
    if (offset & 1) ++offset;

    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** destinationHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* destinationMap = destinationHandle ? *destinationHandle : 0;
    uint8_t* destinationPixels = destinationMap ? (uint8_t*)read32(destinationMap) : 0;
    uint16_t destinationRowBytes = destinationMap ? (uint16_t)(read16(destinationMap + 4) & 0x3fff) : 0;
    if (!valid || !destinationPixels || read16(destinationMap + 32) != 4) valid = false;

    int16_t frameTop = (int16_t)read16(pictureFrame);
    int16_t frameLeft = (int16_t)read16(pictureFrame + 2);
    int16_t frameBottom = (int16_t)read16(pictureFrame + 4);
    int16_t frameRight = (int16_t)read16(pictureFrame + 6);
    int16_t targetTop = (int16_t)read16(targetRect);
    int16_t targetLeft = (int16_t)read16(targetRect + 2);
    int16_t targetBottom = (int16_t)read16(targetRect + 4);
    int16_t targetRight = (int16_t)read16(targetRect + 6);
    int16_t rasterTop = (int16_t)read16(rasterDestination);
    int16_t rasterLeft = (int16_t)read16(rasterDestination + 2);
    int16_t rasterBottom = (int16_t)read16(rasterDestination + 4);
    int16_t rasterRight = (int16_t)read16(rasterDestination + 6);
    int16_t copyTop = (int16_t)read16(rasterSource);
    int16_t copyLeft = (int16_t)read16(rasterSource + 2);
    int16_t copyBottom = (int16_t)read16(rasterSource + 4);
    int16_t copyRight = (int16_t)read16(rasterSource + 6);
    int16_t mapTop = destinationMap ? (int16_t)read16(destinationMap + 6) : 0;
    int16_t mapLeft = destinationMap ? (int16_t)read16(destinationMap + 8) : 0;
    int16_t mapBottom = destinationMap ? (int16_t)read16(destinationMap + 10) : 0;
    int16_t mapRight = destinationMap ? (int16_t)read16(destinationMap + 12) : 0;
    if (frameBottom <= frameTop || frameRight <= frameLeft || targetBottom <= targetTop
        || targetRight <= targetLeft || rasterBottom <= rasterTop || rasterRight <= rasterLeft
        || copyBottom <= copyTop || copyRight <= copyLeft) valid = false;

    if (valid) {
        for (int16_t y = targetTop; y < targetBottom; ++y) {
            if (y < mapTop || y >= mapBottom) continue;
            int16_t pictureY = (int16_t)(frameTop + multiplyDivide(
                (uint16_t)(y - targetTop), (uint16_t)(frameBottom - frameTop),
                (uint16_t)(targetBottom - targetTop)));
            if (pictureY < rasterTop || pictureY >= rasterBottom) continue;
            int16_t sourceY = (int16_t)(copyTop + multiplyDivide(
                (uint16_t)(pictureY - rasterTop), (uint16_t)(copyBottom - copyTop),
                (uint16_t)(rasterBottom - rasterTop)));
            const uint8_t* sourceRow = pixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes);
            for (int16_t x = targetLeft; x < targetRight; ++x) {
                if (x < mapLeft || x >= mapRight) continue;
                int16_t pictureX = (int16_t)(frameLeft + multiplyDivide(
                    (uint16_t)(x - targetLeft), (uint16_t)(frameRight - frameLeft),
                    (uint16_t)(targetRight - targetLeft)));
                if (pictureX < rasterLeft || pictureX >= rasterRight) continue;
                int16_t sourceX = (int16_t)(copyLeft + multiplyDivide(
                    (uint16_t)(pictureX - rasterLeft), (uint16_t)(copyRight - copyLeft),
                    (uint16_t)(rasterRight - rasterLeft)));
                if (sourceY >= sourceTop && sourceY < sourceBottom
                    && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t sourceColumn = (uint16_t)(sourceX - sourceLeft);
                    uint8_t value;
                    if (pixelSize == 4) {
                        uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                        value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                                 : (uint8_t)(sourceByte >> 4);
                    } else value = colorMap[sourceRow[sourceColumn]];
                    uint16_t destinationColumn = (uint16_t)(x - mapLeft);
                    uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                    if (destinationColumn & 1)
                        destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                    else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
                }
            }
        }
    }
    FreeMem(pixels, pixelBytes);
    return valid;
}

static bool drawPackedMonochromePictureBits(const uint8_t* picture, uint32_t size,
                                            uint32_t& offset,
                                            const uint8_t* pictureFrame,
                                            const uint8_t* targetRect)
{
    if (offset + 28 > size) return false;
    uint16_t rowBytesWord = read16(picture + offset);
    uint16_t rowBytes = (uint16_t)(rowBytesWord & 0x3fff);
    if ((rowBytesWord & 0x8000) || !rowBytes) return false; // BitMap, not PixMap
    int16_t sourceTop = (int16_t)read16(picture + offset + 2);
    int16_t sourceLeft = (int16_t)read16(picture + offset + 4);
    int16_t sourceBottom = (int16_t)read16(picture + offset + 6);
    int16_t sourceRight = (int16_t)read16(picture + offset + 8);
    if (sourceBottom <= sourceTop || sourceRight <= sourceLeft
        || rowBytes < ((uint16_t)(sourceRight - sourceLeft) + 7) / 8) return false;
    offset += 10;

    const uint8_t* rasterSource = picture + offset;
    const uint8_t* rasterDestination = picture + offset + 8;
    uint16_t mode = read16(picture + offset + 16);
    if (mode != 0 && mode != 1) return false; // srcCopy or srcOr
    offset += 18;

    uint16_t height = (uint16_t)(sourceBottom - sourceTop);
    uint32_t pixelBytes = multiplyUnsigned16(rowBytes, height);
    uint8_t* pixels = (uint8_t*)AllocMem(pixelBytes, 0);
    if (!pixels) return false;
    bool valid = true;
    for (uint16_t row = 0; row < height && valid; ++row) {
        if (offset + (rowBytes > 250 ? 2 : 1) > size) { valid = false; break; }
        uint16_t packedSize;
        if (rowBytes > 250) { packedSize = read16(picture + offset); offset += 2; }
        else packedSize = picture[offset++];
        if (offset + packedSize > size
            || !unpackPackBitsRow(picture + offset, packedSize,
                                  pixels + multiplyUnsigned16(row, rowBytes), rowBytes)) {
            valid = false; break;
        }
        offset += packedSize;
    }

    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** destinationHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* destinationMap = destinationHandle ? *destinationHandle : 0;
    uint8_t* destinationPixels = destinationMap ? (uint8_t*)read32(destinationMap) : 0;
    uint16_t destinationRowBytes = destinationMap
        ? (uint16_t)(read16(destinationMap + 4) & 0x3fff) : 0;
    if (!valid || !destinationPixels || read16(destinationMap + 32) != 4) valid = false;

    int16_t frameTop = (int16_t)read16(pictureFrame);
    int16_t frameLeft = (int16_t)read16(pictureFrame + 2);
    int16_t frameBottom = (int16_t)read16(pictureFrame + 4);
    int16_t frameRight = (int16_t)read16(pictureFrame + 6);
    int16_t targetTop = (int16_t)read16(targetRect);
    int16_t targetLeft = (int16_t)read16(targetRect + 2);
    int16_t targetBottom = (int16_t)read16(targetRect + 4);
    int16_t targetRight = (int16_t)read16(targetRect + 6);
    int16_t rasterTop = (int16_t)read16(rasterDestination);
    int16_t rasterLeft = (int16_t)read16(rasterDestination + 2);
    int16_t rasterBottom = (int16_t)read16(rasterDestination + 4);
    int16_t rasterRight = (int16_t)read16(rasterDestination + 6);
    int16_t copyTop = (int16_t)read16(rasterSource);
    int16_t copyLeft = (int16_t)read16(rasterSource + 2);
    int16_t copyBottom = (int16_t)read16(rasterSource + 4);
    int16_t copyRight = (int16_t)read16(rasterSource + 6);
    int16_t mapTop = destinationMap ? (int16_t)read16(destinationMap + 6) : 0;
    int16_t mapLeft = destinationMap ? (int16_t)read16(destinationMap + 8) : 0;
    int16_t mapBottom = destinationMap ? (int16_t)read16(destinationMap + 10) : 0;
    int16_t mapRight = destinationMap ? (int16_t)read16(destinationMap + 12) : 0;
    if (frameBottom <= frameTop || frameRight <= frameLeft || targetBottom <= targetTop
        || targetRight <= targetLeft || rasterBottom <= rasterTop || rasterRight <= rasterLeft
        || copyBottom <= copyTop || copyRight <= copyLeft) valid = false;

    if (valid) {
        for (int16_t y = targetTop; y < targetBottom; ++y) {
            if (y < mapTop || y >= mapBottom) continue;
            int16_t pictureY = (int16_t)(frameTop + multiplyDivide(
                (uint16_t)(y - targetTop), (uint16_t)(frameBottom - frameTop),
                (uint16_t)(targetBottom - targetTop)));
            if (pictureY < rasterTop || pictureY >= rasterBottom) continue;
            int16_t sourceY = (int16_t)(copyTop + multiplyDivide(
                (uint16_t)(pictureY - rasterTop), (uint16_t)(copyBottom - copyTop),
                (uint16_t)(rasterBottom - rasterTop)));
            const uint8_t* sourceRow = pixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), rowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes);
            for (int16_t x = targetLeft; x < targetRight; ++x) {
                if (x < mapLeft || x >= mapRight) continue;
                int16_t pictureX = (int16_t)(frameLeft + multiplyDivide(
                    (uint16_t)(x - targetLeft), (uint16_t)(frameRight - frameLeft),
                    (uint16_t)(targetRight - targetLeft)));
                if (pictureX < rasterLeft || pictureX >= rasterRight) continue;
                int16_t sourceX = (int16_t)(copyLeft + multiplyDivide(
                    (uint16_t)(pictureX - rasterLeft), (uint16_t)(copyRight - copyLeft),
                    (uint16_t)(rasterRight - rasterLeft)));
                if (sourceY >= sourceTop && sourceY < sourceBottom
                    && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t sourceColumn = (uint16_t)(sourceX - sourceLeft);
                    uint8_t value = sourceRow[sourceColumn >> 3]
                        & (uint8_t)(0x80 >> (sourceColumn & 7)) ? 15 : 0;
                    uint16_t destinationColumn = (uint16_t)(x - mapLeft);
                    uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                    if (mode == 1) {
                        uint8_t destinationValue = destinationColumn & 1
                            ? (uint8_t)(destinationByte & 0x0f)
                            : (uint8_t)(destinationByte >> 4);
                        value = (uint8_t)(destinationValue | value);
                    }
                    if (destinationColumn & 1)
                        destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                    else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
                }
            }
        }
    }
    FreeMem(pixels, pixelBytes);
    return valid;
}

static bool drawDirectPictureBits(const uint8_t* picture, uint32_t size, uint32_t& offset,
                                  const uint8_t* pictureFrame, const uint8_t* targetRect)
{
    if (offset + 68 > size) return false;
    offset += 4;                            // baseAddr is not stored in a PICT PixMap
    const uint8_t* pixMap = picture + offset;
    uint16_t rowBytes = (uint16_t)(read16(pixMap) & 0x3fff);
    int16_t sourceTop = (int16_t)read16(pixMap + 2);
    int16_t sourceLeft = (int16_t)read16(pixMap + 4);
    int16_t sourceBottom = (int16_t)read16(pixMap + 6);
    int16_t sourceRight = (int16_t)read16(pixMap + 8);
    if (!(read16(pixMap) & 0x8000) || read16(pixMap + 12) != 4
        || read16(pixMap + 26) != 16 || read16(pixMap + 28) != 32
        || read16(pixMap + 30) != 3 || read16(pixMap + 32) != 8
        || sourceBottom <= sourceTop || sourceRight <= sourceLeft || !rowBytes) return false;
    uint16_t width = (uint16_t)(sourceRight - sourceLeft);
    uint16_t componentRowBytes = (uint16_t)(width + width + width);
    if (rowBytes < (uint16_t)(width << 2)) return false;
    offset += 46;

    const uint8_t* rasterSource = picture + offset;
    const uint8_t* rasterDestination = picture + offset + 8;
    uint16_t mode = read16(picture + offset + 16);
    if (mode != 0 && mode != 0x0040) return false; // srcCopy or ditherCopy
    offset += 18;

    uint16_t height = (uint16_t)(sourceBottom - sourceTop);
    uint32_t pixelBytes = multiplyUnsigned16(componentRowBytes, height);
    uint8_t* pixels = (uint8_t*)AllocMem(pixelBytes, 0);
    if (!pixels) return false;
    bool valid = true;
    for (uint16_t row = 0; row < height && valid; ++row) {
        if (offset + (rowBytes > 250 ? 2 : 1) > size) { valid = false; break; }
        uint16_t packedSize;
        if (rowBytes > 250) { packedSize = read16(picture + offset); offset += 2; }
        else packedSize = picture[offset++];
        if (offset + packedSize > size
            || !unpackPackBitsRow(picture + offset, packedSize,
                                  pixels + multiplyUnsigned16(row, componentRowBytes),
                                  componentRowBytes)) {
            valid = false; break;
        }
        offset += packedSize;
    }
    if (offset & 1) ++offset;

    uint8_t colorMap[256];
    static const uint16_t levels3[8] = {
        0x0000,0x2492,0x4924,0x6db6,0x9249,0xb6db,0xdb6d,0xffff
    };
    static const uint16_t levels2[4] = { 0x0000,0x5555,0xaaaa,0xffff };
    for (uint16_t key = 0; key < 256; ++key) {
        uint16_t sr = levels3[key >> 5];
        uint16_t sg = levels3[(key >> 2) & 7];
        uint16_t sb = levels2[key & 3];
        uint32_t bestDistance = 0xffffffffUL;
        uint8_t bestIndex = 0;
        for (uint8_t destinationIndex = 0; destinationIndex < 16; ++destinationIndex) {
            const uint8_t* destinationColor
                = s_windowManagerColors + 8 + (uint16_t)destinationIndex * 8;
            uint16_t dr = read16(destinationColor + 2), dg = read16(destinationColor + 4);
            uint16_t db = read16(destinationColor + 6);
            uint32_t distance = (sr > dr ? sr - dr : dr - sr)
                              + (sg > dg ? sg - dg : dg - sg)
                              + (sb > db ? sb - db : db - sb);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = destinationIndex;
            }
        }
        colorMap[key] = bestIndex;
    }

    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** destinationHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* destinationMap = destinationHandle ? *destinationHandle : 0;
    uint8_t* destinationPixels = destinationMap ? (uint8_t*)read32(destinationMap) : 0;
    uint16_t destinationRowBytes = destinationMap
        ? (uint16_t)(read16(destinationMap + 4) & 0x3fff) : 0;
    if (!valid || !destinationPixels || read16(destinationMap + 32) != 4) valid = false;

    int16_t frameTop = (int16_t)read16(pictureFrame);
    int16_t frameLeft = (int16_t)read16(pictureFrame + 2);
    int16_t frameBottom = (int16_t)read16(pictureFrame + 4);
    int16_t frameRight = (int16_t)read16(pictureFrame + 6);
    int16_t targetTop = (int16_t)read16(targetRect);
    int16_t targetLeft = (int16_t)read16(targetRect + 2);
    int16_t targetBottom = (int16_t)read16(targetRect + 4);
    int16_t targetRight = (int16_t)read16(targetRect + 6);
    int16_t rasterTop = (int16_t)read16(rasterDestination);
    int16_t rasterLeft = (int16_t)read16(rasterDestination + 2);
    int16_t rasterBottom = (int16_t)read16(rasterDestination + 4);
    int16_t rasterRight = (int16_t)read16(rasterDestination + 6);
    int16_t copyTop = (int16_t)read16(rasterSource);
    int16_t copyLeft = (int16_t)read16(rasterSource + 2);
    int16_t copyBottom = (int16_t)read16(rasterSource + 4);
    int16_t copyRight = (int16_t)read16(rasterSource + 6);
    int16_t mapTop = destinationMap ? (int16_t)read16(destinationMap + 6) : 0;
    int16_t mapLeft = destinationMap ? (int16_t)read16(destinationMap + 8) : 0;
    int16_t mapBottom = destinationMap ? (int16_t)read16(destinationMap + 10) : 0;
    int16_t mapRight = destinationMap ? (int16_t)read16(destinationMap + 12) : 0;
    if (frameBottom <= frameTop || frameRight <= frameLeft || targetBottom <= targetTop
        || targetRight <= targetLeft || rasterBottom <= rasterTop || rasterRight <= rasterLeft
        || copyBottom <= copyTop || copyRight <= copyLeft) valid = false;

    if (valid) {
        for (int16_t y = targetTop; y < targetBottom; ++y) {
            if (y < mapTop || y >= mapBottom) continue;
            int16_t pictureY = (int16_t)(frameTop + multiplyDivide(
                (uint16_t)(y - targetTop), (uint16_t)(frameBottom - frameTop),
                (uint16_t)(targetBottom - targetTop)));
            if (pictureY < rasterTop || pictureY >= rasterBottom) continue;
            int16_t sourceY = (int16_t)(copyTop + multiplyDivide(
                (uint16_t)(pictureY - rasterTop), (uint16_t)(copyBottom - copyTop),
                (uint16_t)(rasterBottom - rasterTop)));
            const uint8_t* sourceRow = pixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), componentRowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - mapTop), destinationRowBytes);
            for (int16_t x = targetLeft; x < targetRight; ++x) {
                if (x < mapLeft || x >= mapRight) continue;
                int16_t pictureX = (int16_t)(frameLeft + multiplyDivide(
                    (uint16_t)(x - targetLeft), (uint16_t)(frameRight - frameLeft),
                    (uint16_t)(targetRight - targetLeft)));
                if (pictureX < rasterLeft || pictureX >= rasterRight) continue;
                int16_t sourceX = (int16_t)(copyLeft + multiplyDivide(
                    (uint16_t)(pictureX - rasterLeft), (uint16_t)(copyRight - copyLeft),
                    (uint16_t)(rasterRight - rasterLeft)));
                if (sourceY >= sourceTop && sourceY < sourceBottom
                    && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t column = (uint16_t)(sourceX - sourceLeft);
                    uint8_t red = sourceRow[column];
                    uint8_t green = sourceRow[width + column];
                    uint8_t blue = sourceRow[width + width + column];
                    uint8_t value = colorMap[(red & 0xe0) | ((green >> 3) & 0x1c)
                                             | (blue >> 6)];
                    uint16_t destinationColumn = (uint16_t)(x - mapLeft);
                    uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                    if (destinationColumn & 1)
                        destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                    else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
                }
            }
        }
    }
    FreeMem(pixels, pixelBytes);
    return valid;
}

static bool drawVersionOnePicture(const uint8_t* picture, uint32_t size,
                                  const uint8_t* frame, const uint8_t* targetRect)
{
    uint32_t offset = 12;                    // version opcode $11, version byte $01
    bool drewPixels = false;
    while (offset < size) {
        uint8_t opcode = picture[offset++];
        if (opcode == 0xff) return drewPixels;
        if (opcode == 0x00) continue;
        if (opcode == 0xa0) { if (offset + 2 > size) return false; offset += 2; continue; }
        if (opcode == 0x01) {
            if (offset + 2 > size) return false;
            uint16_t bytes = read16(picture + offset);
            if (bytes < 2 || offset + bytes > size) return false;
            offset += bytes; continue;
        }
        if (opcode == 0x0a) { if (offset + 8 > size) return false; offset += 8; continue; }
        if (opcode == 0x98) {
            if (!drawPackedMonochromePictureBits(picture, size, offset, frame, targetRect))
                return false;
            drewPixels = true; continue;
        }
        return false;
    }
    return false;
}

static bool drawPicture(uint8_t** pictureHandle, const uint8_t* targetRect)
{
    uint32_t size = resourceHandleSize(pictureHandle);
    if (!pictureHandle || !*pictureHandle || !targetRect || size < 12) return false;
    const uint8_t* picture = *pictureHandle;
    const uint8_t* frame = picture + 2;
    if (picture[10] == 0x11 && picture[11] == 0x01)
        return drawVersionOnePicture(picture, size, frame, targetRect);
    uint32_t offset = 10;
    bool drewPixels = false;
    while (offset + 2 <= size) {
        uint16_t opcode = read16(picture + offset); offset += 2;
        if (opcode == 0x00ff) return drewPixels;
        if (opcode == 0x0000 || opcode == 0x001e) continue;
        if (opcode == 0x0011) { if (offset + 2 > size) return false; offset += 2; continue; }
        if (opcode == 0x0c00) { if (offset + 24 > size) return false; offset += 24; continue; }
        if (opcode == 0x0001) {
            if (offset + 2 > size) return false;
            uint16_t bytes = read16(picture + offset);
            if (bytes < 2 || offset + bytes > size) return false;
            offset += bytes; continue;
        }
        if (opcode == 0x000a) { if (offset + 8 > size) return false; offset += 8; continue; }
        if (opcode == 0x00a1) {
            if (offset + 4 > size) return false;
            uint16_t bytes = read16(picture + offset + 2);
            if (offset + 4UL + bytes > size) return false;
            offset += 4UL + bytes; if (offset & 1) ++offset; continue;
        }
        if (opcode == 0x0098) {
            if (!drawPackedPictureBits(picture, size, offset, frame, targetRect)) return false;
            drewPixels = true; continue;
        }
        if (opcode == 0x009a) {
            if (!drawDirectPictureBits(picture, size, offset, frame, targetRect)) return false;
            drewPixels = true; continue;
        }
        return false;                        // retain the loud stop for every unseen opcode
    }
    return false;
}

static bool currentPortPixels(uint8_t*& pixels, uint16_t& rowBytes,
                              int16_t& top, int16_t& left, int16_t& bottom, int16_t& right)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** mapHandle = port ? (uint8_t**)read32(port + 2) : 0;
    uint8_t* map = mapHandle ? *mapHandle : 0;
    if (!map || read16(map + 32) != 4) return false;
    pixels = (uint8_t*)read32(map);
    rowBytes = (uint16_t)(read16(map + 4) & 0x3fff);
    top = (int16_t)read16(map + 6); left = (int16_t)read16(map + 8);
    bottom = (int16_t)read16(map + 10); right = (int16_t)read16(map + 12);
    return pixels && rowBytes;
}

static bool frameRect(const uint8_t* rectangle)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t mapTop, mapLeft, mapBottom, mapRight;
    if (!port || !rectangle
        || !currentPortPixels(pixels, rowBytes, mapTop, mapLeft, mapBottom, mapRight)) return false;
    int16_t top = (int16_t)read16(rectangle);
    int16_t left = (int16_t)read16(rectangle + 2);
    int16_t bottom = (int16_t)read16(rectangle + 4);
    int16_t right = (int16_t)read16(rectangle + 6);
    int16_t penHeight = (int16_t)read16(port + 52);
    int16_t penWidth = (int16_t)read16(port + 54);
    if (top >= bottom || left >= right || penHeight <= 0 || penWidth <= 0
        || read16(port + 56) != 0) return false;
    for (int16_t y = top; y < bottom; ++y) {
        if (y < mapTop || y >= mapBottom) continue;
        uint8_t* row = pixels + multiplyUnsigned16((uint16_t)(y - mapTop), rowBytes);
        for (int16_t x = left; x < right; ++x) {
            if (x < mapLeft || x >= mapRight) continue;
            if (y >= top + penHeight && y < bottom - penHeight
                && x >= left + penWidth && x < right - penWidth) continue;
            uint16_t column = (uint16_t)(x - mapLeft);
            uint8_t& byte = row[column >> 1];
            if (column & 1) byte = (uint8_t)(byte | 0x0f);
            else byte = (uint8_t)(byte | 0xf0);
        }
    }
    return true;
}

static bool eraseRect(const uint8_t* rectangle)
{
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t mapTop, mapLeft, mapBottom, mapRight;
    if (!rectangle
        || !currentPortPixels(pixels, rowBytes, mapTop, mapLeft, mapBottom, mapRight)) return false;
    int16_t top = (int16_t)read16(rectangle);
    int16_t left = (int16_t)read16(rectangle + 2);
    int16_t bottom = (int16_t)read16(rectangle + 4);
    int16_t right = (int16_t)read16(rectangle + 6);
    if (top >= bottom || left >= right) return false;
    if (top < mapTop) top = mapTop;
    if (left < mapLeft) left = mapLeft;
    if (bottom > mapBottom) bottom = mapBottom;
    if (right > mapRight) right = mapRight;
    if (top >= bottom || left >= right) return true;
    uint16_t firstColumn = (uint16_t)(left - mapLeft);
    uint16_t lastColumn = (uint16_t)(right - mapLeft);
    for (int16_t y = top; y < bottom; ++y) {
        uint8_t* row = pixels + multiplyUnsigned16((uint16_t)(y - mapTop), rowBytes);
        uint16_t firstByte = (uint16_t)(firstColumn >> 1);
        uint16_t lastByte = (uint16_t)((lastColumn + 1) >> 1);
        if (firstColumn & 1) {
            row[firstByte] &= 0xf0;
            ++firstByte;
        }
        bool keepLowNibble = lastColumn & 1;
        if (keepLowNibble && lastByte > firstByte) --lastByte;
        if (lastByte > firstByte) blockClear(row + firstByte, lastByte - firstByte);
        if (keepLowNibble) row[lastByte] &= 0x0f;
    }
    return true;
}

static bool bitmapPixels(const uint8_t* bitmap, uint8_t*& pixels, uint16_t& rowBytes,
                         int16_t& top, int16_t& left, int16_t& bottom, int16_t& right)
{
    if (!bitmap) return false;
    uint8_t* map = 0;
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (s_gworlds[i].used && bitmap == s_gworlds[i].port + 2) map = s_gworlds[i].pixMap;
    for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
        if (s_windows[i].used && bitmap == s_windows[i].window + 2)
            map = s_windowManagerPixMap;
    if (bitmap == s_windowManagerPort + 2) map = s_windowManagerPixMap;
    if (!map || read16(map + 32) != 4) return false;
    pixels = (uint8_t*)read32(map);
    rowBytes = (uint16_t)(read16(map + 4) & 0x3fff);
    top = (int16_t)read16(map + 6); left = (int16_t)read16(map + 8);
    bottom = (int16_t)read16(map + 10); right = (int16_t)read16(map + 12);
    return pixels && rowBytes;
}

static bool bitmapIsScreen(const uint8_t* bitmap)
{
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t top, left, bottom, right;
    return bitmapPixels(bitmap, pixels, rowBytes, top, left, bottom, right)
        && pixels == s_colorScreen;
}

static bool currentPortIsScreen()
{
    uint8_t* pixels;
    uint16_t rowBytes;
    int16_t top, left, bottom, right;
    return currentPortPixels(pixels, rowBytes, top, left, bottom, right)
        && pixels == s_colorScreen;
}

static bool copyBits(const uint8_t* sourceBitmap, const uint8_t* destinationBitmap,
                     const uint8_t* sourceRect, const uint8_t* destinationRect,
                     uint16_t mode, const uint8_t* maskRegion)
{
    if (!sourceRect || !destinationRect || (mode != 0 && mode != 1 && mode != 3)
        || maskRegion) return false;
    uint8_t *sourcePixels, *destinationPixels;
    uint16_t sourceRowBytes, destinationRowBytes;
    int16_t sourceTop, sourceLeft, sourceBottom, sourceRight;
    int16_t destinationTop, destinationLeft, destinationBottom, destinationRight;
    if (!bitmapPixels(sourceBitmap, sourcePixels, sourceRowBytes,
                      sourceTop, sourceLeft, sourceBottom, sourceRight)
        || !bitmapPixels(destinationBitmap, destinationPixels, destinationRowBytes,
                         destinationTop, destinationLeft, destinationBottom, destinationRight))
        return false;
    int16_t fromTop = (int16_t)read16(sourceRect);
    int16_t fromLeft = (int16_t)read16(sourceRect + 2);
    int16_t fromBottom = (int16_t)read16(sourceRect + 4);
    int16_t fromRight = (int16_t)read16(sourceRect + 6);
    int16_t toTop = (int16_t)read16(destinationRect);
    int16_t toLeft = (int16_t)read16(destinationRect + 2);
    int16_t toBottom = (int16_t)read16(destinationRect + 4);
    int16_t toRight = (int16_t)read16(destinationRect + 6);
    if (fromBottom <= fromTop || fromRight <= fromLeft
        || toBottom <= toTop || toRight <= toLeft) return false;
    uint16_t width = (uint16_t)(toRight - toLeft);
    uint16_t height = (uint16_t)(toBottom - toTop);
    int16_t clipTop = destinationTop, clipLeft = destinationLeft;
    int16_t clipBottom = destinationBottom, clipRight = destinationRight;
    uint8_t* currentPort = (uint8_t*)read32(s_qdThePort);
    if (currentPort && destinationBitmap == currentPort + 2) {
        uint8_t** clipHandle = (uint8_t**)read32(currentPort + 28);
        uint8_t* clip = clipHandle ? *clipHandle : 0;
        if (clip && read16(clip) >= 10) {
            clipTop = (int16_t)read16(clip + 2); clipLeft = (int16_t)read16(clip + 4);
            clipBottom = (int16_t)read16(clip + 6); clipRight = (int16_t)read16(clip + 8);
        }
    }
    bool unscaled = fromRight - fromLeft == toRight - toLeft
                 && fromBottom - fromTop == toBottom - toTop;
    // All intro masks and sprites remain nibble-aligned even when their
    // destination rectangles cross a GWorld or clip boundary.  Clip first,
    // then operate on packed bytes.  The old fast paths required the *whole*
    // rectangle to be in bounds, so the tram's srcOr/srcBic pair fell back to
    // a pixel-at-a-time loop as soon as it touched the bottom or left edge.
    // That made the other concurrently scheduled actors lose real time.
    int16_t packedTop = toTop;
    int16_t packedLeft = toLeft;
    int16_t packedBottom = toBottom;
    int16_t packedRight = toRight;
    if (packedTop < destinationTop) packedTop = destinationTop;
    if (packedTop < clipTop) packedTop = clipTop;
    if (packedTop < toTop + sourceTop - fromTop)
        packedTop = (int16_t)(toTop + sourceTop - fromTop);
    if (packedLeft < destinationLeft) packedLeft = destinationLeft;
    if (packedLeft < clipLeft) packedLeft = clipLeft;
    if (packedLeft < toLeft + sourceLeft - fromLeft)
        packedLeft = (int16_t)(toLeft + sourceLeft - fromLeft);
    if (packedBottom > destinationBottom) packedBottom = destinationBottom;
    if (packedBottom > clipBottom) packedBottom = clipBottom;
    if (packedBottom > toTop + sourceBottom - fromTop)
        packedBottom = (int16_t)(toTop + sourceBottom - fromTop);
    if (packedRight > destinationRight) packedRight = destinationRight;
    if (packedRight > clipRight) packedRight = clipRight;
    if (packedRight > toLeft + sourceRight - fromLeft)
        packedRight = (int16_t)(toLeft + sourceRight - fromLeft);
    int16_t packedSourceTop = (int16_t)(fromTop + packedTop - toTop);
    int16_t packedSourceLeft = (int16_t)(fromLeft + packedLeft - toLeft);
    bool packedClippedPath = unscaled && packedTop < packedBottom
        && packedLeft < packedRight
        && ((packedSourceLeft - sourceLeft) & 1) == 0
        && ((packedLeft - destinationLeft) & 1) == 0
        && ((packedRight - packedLeft) & 1) == 0;
    if (packedClippedPath) {
        uint16_t copyBytes = (uint16_t)(packedRight - packedLeft) >> 1;
        uint16_t copyHeight = (uint16_t)(packedBottom - packedTop);
        int16_t firstY = 0, lastY = (int16_t)copyHeight, stepY = 1;
        if (sourcePixels == destinationPixels && packedTop > packedSourceTop) {
            firstY = (int16_t)(copyHeight - 1); lastY = -1; stepY = -1;
        }
        for (int16_t y = firstY; y != lastY; y = (int16_t)(y + stepY)) {
            uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(packedSourceTop + y - sourceTop),
                                     sourceRowBytes)
                + (uint16_t)(packedSourceLeft - sourceLeft) / 2;
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(packedTop + y - destinationTop),
                                     destinationRowBytes)
                + (uint16_t)(packedLeft - destinationLeft) / 2;
            if (mode == 0) {
                blockMove(source, destination, copyBytes);
            } else if (sourcePixels == destinationPixels && destination > source
                       && destination < source + copyBytes) {
                for (uint16_t x = copyBytes; x; --x) {
                    uint16_t i = (uint16_t)(x - 1);
                    if (mode == 1)
                        destination[i] = (uint8_t)(destination[i] | source[i]);
                    else
                        destination[i] = (uint8_t)(destination[i]
                            & (uint8_t)~source[i]);
                }
            } else if (mode == 1) {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] | source[x]);
            } else {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] & (uint8_t)~source[x]);
            }
        }
        return true;
    }
    if (unscaled && sourcePixels != destinationPixels
        && packedTop < packedBottom && packedLeft < packedRight) {
        // Cross-GWorld sprite/logo transfers frequently have an odd source or
        // destination nibble.  They are still one-to-one copies: assemble two
        // source pixels per destination byte instead of redoing clipping,
        // bounds tests, multiplies and read/modify/write for every pixel.
        for (int16_t y = packedTop; y < packedBottom; ++y) {
            int16_t sourceY = (int16_t)(fromTop + y - toTop);
            const uint8_t* sourceRow = sourcePixels
                + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes);
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(y - destinationTop), destinationRowBytes);
            int16_t x = packedLeft;
            uint16_t destinationColumn = (uint16_t)(x - destinationLeft);
            uint16_t sourceColumn = (uint16_t)(fromLeft + x - toLeft - sourceLeft);
            if (destinationColumn & 1) {
                uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                uint8_t value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                                 : (uint8_t)(sourceByte >> 4);
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode == 1) value = (uint8_t)((destinationByte & 0x0f) | value);
                else if (mode == 3)
                    value = (uint8_t)((destinationByte & 0x0f) & (uint8_t)~value);
                destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                ++x; ++sourceColumn; ++destinationColumn;
            }
            for (; x + 1 < packedRight; x += 2, sourceColumn += 2,
                                              destinationColumn += 2) {
                uint8_t value;
                if ((sourceColumn & 1) == 0) value = sourceRow[sourceColumn >> 1];
                else value = (uint8_t)((sourceRow[sourceColumn >> 1] << 4)
                    | (sourceRow[(sourceColumn >> 1) + 1] >> 4));
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode == 0) destinationByte = value;
                else if (mode == 1) destinationByte = (uint8_t)(destinationByte | value);
                else destinationByte = (uint8_t)(destinationByte & (uint8_t)~value);
            }
            if (x < packedRight) {
                uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                uint8_t value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                                 : (uint8_t)(sourceByte >> 4);
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode == 1) value = (uint8_t)((destinationByte >> 4) | value);
                else if (mode == 3)
                    value = (uint8_t)((destinationByte >> 4) & (uint8_t)~value);
                destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
            }
        }
        return true;
    }
    bool packedFastPath = unscaled && mode == 0 && ((fromLeft - sourceLeft) & 1) == 0
        && ((toLeft - destinationLeft) & 1) == 0 && (width & 1) == 0
        && fromTop >= sourceTop && fromBottom <= sourceBottom
        && fromLeft >= sourceLeft && fromRight <= sourceRight
        && toTop >= destinationTop && toBottom <= destinationBottom
        && toLeft >= destinationLeft && toRight <= destinationRight
        && toTop >= clipTop && toBottom <= clipBottom
        && toLeft >= clipLeft && toRight <= clipRight;
    bool packedVerticalClipPath = unscaled && mode == 0
        && ((fromLeft - sourceLeft) & 1) == 0
        && ((toLeft - destinationLeft) & 1) == 0 && (width & 1) == 0
        && fromTop >= sourceTop && fromBottom <= sourceBottom
        && fromLeft >= sourceLeft && fromRight <= sourceRight
        && toTop >= destinationTop && toBottom <= destinationBottom
        && toLeft >= destinationLeft && toRight <= destinationRight
        && toLeft >= clipLeft && toRight <= clipRight
        && toTop < clipBottom && toBottom > clipTop;
    bool rectanglesOverlap = sourcePixels == destinationPixels
        && fromLeft < toRight && fromRight > toLeft
        && fromTop < toBottom && fromBottom > toTop;
    bool packedBooleanPath = unscaled && (mode == 1 || mode == 3)
        && ((fromLeft - sourceLeft) & 1) == 0
        && ((toLeft - destinationLeft) & 1) == 0 && (width & 1) == 0
        && fromTop >= sourceTop && fromBottom <= sourceBottom
        && fromLeft >= sourceLeft && fromRight <= sourceRight
        && toTop >= destinationTop && toBottom <= destinationBottom
        && toLeft >= destinationLeft && toRight <= destinationRight
        && toTop >= clipTop && toBottom <= clipBottom
        && toLeft >= clipLeft && toRight <= clipRight
        && !rectanglesOverlap;

    // The intro scrolls large, aligned rectangles inside a GWorld.  For srcCopy
    // that is a memmove, not a scale operation: retain overlap correctness while
    // moving packed 4-bpp rows directly.  This is the normal fast QuickDraw path
    // and keeps the original animation from losing time inside the compatibility
    // layer.
    if (packedFastPath || packedVerticalClipPath) {
        uint16_t copyBytes = width >> 1;
        int16_t copyTop = toTop < clipTop ? clipTop : toTop;
        int16_t copyBottom = toBottom > clipBottom ? clipBottom : toBottom;
        uint16_t copyHeight = (uint16_t)(copyBottom - copyTop);
        int16_t sourceCopyTop = (int16_t)(fromTop + copyTop - toTop);
        int16_t first = 0, last = (int16_t)copyHeight, step = 1;
        if (sourcePixels == destinationPixels && copyTop > sourceCopyTop) {
            first = (int16_t)(copyHeight - 1); last = -1; step = -1;
        }
        for (int16_t y = first; y != last; y = (int16_t)(y + step)) {
            uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(sourceCopyTop + y - sourceTop), sourceRowBytes)
                + (uint16_t)(fromLeft - sourceLeft) / 2;
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(copyTop + y - destinationTop), destinationRowBytes)
                + (uint16_t)(toLeft - destinationLeft) / 2;
            blockMove(source, destination, copyBytes);
        }
        return true;
    }
    if (packedBooleanPath) {
        uint16_t copyBytes = width >> 1;
        for (uint16_t y = 0; y < height; ++y) {
            const uint8_t* source = sourcePixels
                + multiplyUnsigned16((uint16_t)(fromTop + y - sourceTop), sourceRowBytes)
                + (uint16_t)(fromLeft - sourceLeft) / 2;
            uint8_t* destination = destinationPixels
                + multiplyUnsigned16((uint16_t)(toTop + y - destinationTop), destinationRowBytes)
                + (uint16_t)(toLeft - destinationLeft) / 2;
            if (mode == 1) {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] | source[x]);
            } else {
                for (uint16_t x = 0; x < copyBytes; ++x)
                    destination[x] = (uint8_t)(destination[x] & (uint8_t)~source[x]);
            }
        }
        return true;
    }

    // An unscaled transfer has a one-to-one source/destination mapping and
    // does not need the byte-per-pixel expansion buffer below.  Walk in the
    // memmove direction when both BitMaps share storage so odd-aligned and
    // clipped self-copies retain the original source pixels.
    if (unscaled) {
        int16_t visibleTop = toTop;
        int16_t visibleLeft = toLeft;
        int16_t visibleBottom = toBottom;
        int16_t visibleRight = toRight;
        if (visibleTop < destinationTop) visibleTop = destinationTop;
        if (visibleTop < clipTop) visibleTop = clipTop;
        if (visibleLeft < destinationLeft) visibleLeft = destinationLeft;
        if (visibleLeft < clipLeft) visibleLeft = clipLeft;
        if (visibleBottom > destinationBottom) visibleBottom = destinationBottom;
        if (visibleBottom > clipBottom) visibleBottom = clipBottom;
        if (visibleRight > destinationRight) visibleRight = destinationRight;
        if (visibleRight > clipRight) visibleRight = clipRight;
        if (visibleTop >= visibleBottom || visibleLeft >= visibleRight) return true;

        int16_t firstY = visibleTop, lastY = visibleBottom, stepY = 1;
        int16_t firstX = visibleLeft, lastX = visibleRight, stepX = 1;
        if (sourcePixels == destinationPixels
            && toTop - destinationTop > fromTop - sourceTop) {
            firstY = (int16_t)(visibleBottom - 1);
            lastY = (int16_t)(visibleTop - 1);
            stepY = -1;
        }
        if (sourcePixels == destinationPixels
            && toLeft - destinationLeft > fromLeft - sourceLeft) {
            firstX = (int16_t)(visibleRight - 1);
            lastX = (int16_t)(visibleLeft - 1);
            stepX = -1;
        }
        for (int16_t destinationY = firstY; destinationY != lastY;
             destinationY = (int16_t)(destinationY + stepY)) {
            int16_t sourceY = (int16_t)(fromTop + destinationY - toTop);
            const uint8_t* sourceRow = sourceY >= sourceTop && sourceY < sourceBottom
                ? sourcePixels
                    + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes)
                : 0;
            uint8_t* destinationRow = destinationPixels
                + multiplyUnsigned16((uint16_t)(destinationY - destinationTop),
                                     destinationRowBytes);
            for (int16_t destinationX = firstX; destinationX != lastX;
                 destinationX = (int16_t)(destinationX + stepX)) {
                int16_t sourceX = (int16_t)(fromLeft + destinationX - toLeft);
                uint8_t value = 0;
                if (sourceRow && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t sourceColumn = (uint16_t)(sourceX - sourceLeft);
                    uint8_t sourceByte = sourceRow[sourceColumn >> 1];
                    value = sourceColumn & 1 ? (uint8_t)(sourceByte & 0x0f)
                                             : (uint8_t)(sourceByte >> 4);
                }
                uint16_t destinationColumn = (uint16_t)(destinationX - destinationLeft);
                uint8_t& destinationByte = destinationRow[destinationColumn >> 1];
                if (mode != 0) {
                    uint8_t destinationValue = destinationColumn & 1
                        ? (uint8_t)(destinationByte & 0x0f)
                        : (uint8_t)(destinationByte >> 4);
                    if (mode == 1) value = (uint8_t)(destinationValue | value);
                    else value = (uint8_t)(destinationValue & (uint8_t)(~value & 0x0f));
                }
                if (destinationColumn & 1)
                    destinationByte = (uint8_t)((destinationByte & 0xf0) | value);
                else destinationByte = (uint8_t)((destinationByte & 0x0f) | (value << 4));
            }
        }
        return true;
    }

    uint32_t temporaryBytes = multiplyUnsigned16(width, height);
    uint8_t* temporary = (uint8_t*)AllocMem(temporaryBytes, 0);
    if (!temporary) return false;
    for (uint16_t y = 0; y < height; ++y) {
        uint8_t* temporaryRow = temporary + multiplyUnsigned16(y, width);
        int16_t sourceY = unscaled ? (int16_t)(fromTop + y)
            : (int16_t)(fromTop + multiplyDivide(
                y, (uint16_t)(fromBottom - fromTop), height));
        const uint8_t* row = sourceY >= sourceTop && sourceY < sourceBottom
            ? sourcePixels + multiplyUnsigned16((uint16_t)(sourceY - sourceTop), sourceRowBytes)
            : 0;
        if (unscaled) {
            for (uint16_t x = 0; x < width; ++x) {
                int16_t sourceX = (int16_t)(fromLeft + x);
                uint8_t value = 0;
                if (row && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t column = (uint16_t)(sourceX - sourceLeft);
                    uint8_t byte = row[column >> 1];
                    value = column & 1 ? (uint8_t)(byte & 0x0f) : (uint8_t)(byte >> 4);
                }
                temporaryRow[x] = value;
            }
        } else {
            for (uint16_t x = 0; x < width; ++x) {
                int16_t sourceX = (int16_t)(fromLeft + multiplyDivide(
                    x, (uint16_t)(fromRight - fromLeft), width));
                uint8_t value = 0;
                if (row && sourceX >= sourceLeft && sourceX < sourceRight) {
                    uint16_t column = (uint16_t)(sourceX - sourceLeft);
                    uint8_t byte = row[column >> 1];
                    value = column & 1 ? (uint8_t)(byte & 0x0f) : (uint8_t)(byte >> 4);
                }
                temporaryRow[x] = value;
            }
        }
    }
    for (uint16_t y = 0; y < height; ++y) {
        const uint8_t* temporaryRow = temporary + multiplyUnsigned16(y, width);
        int16_t destinationY = (int16_t)(toTop + y);
        if (destinationY < destinationTop || destinationY >= destinationBottom
            || destinationY < clipTop || destinationY >= clipBottom) continue;
        uint8_t* row = destinationPixels
            + multiplyUnsigned16((uint16_t)(destinationY - destinationTop), destinationRowBytes);
        for (uint16_t x = 0; x < width; ++x) {
            int16_t destinationX = (int16_t)(toLeft + x);
            if (destinationX < destinationLeft || destinationX >= destinationRight
                || destinationX < clipLeft || destinationX >= clipRight) continue;
            uint8_t value = temporaryRow[x];
            uint16_t column = (uint16_t)(destinationX - destinationLeft);
            uint8_t& byte = row[column >> 1];
            if (mode != 0) {
                uint8_t destinationValue = column & 1 ? (uint8_t)(byte & 0x0f)
                                                       : (uint8_t)(byte >> 4);
                if (mode == 1)               // srcOr: destination OR source
                    value = (uint8_t)(destinationValue | value);
                else                         // srcBic: destination AND NOT source
                    value = (uint8_t)(destinationValue & (uint8_t)(~value & 0x0f));
            }
            if (column & 1) byte = (uint8_t)((byte & 0xf0) | value);
            else byte = (uint8_t)((byte & 0x0f) | (value << 4));
        }
    }
    FreeMem(temporary, temporaryBytes);
    return true;
}

static bool clipRect(const uint8_t* rectangle)
{
    uint8_t* port = (uint8_t*)read32(s_qdThePort);
    uint8_t** clipHandle = port ? (uint8_t**)read32(port + 28) : 0;
    uint8_t* clip = clipHandle ? *clipHandle : 0;
    if (!rectangle || !clip) return false;
    write16(clip, 10);
    writeRect(clip + 2, (int16_t)read16(rectangle), (int16_t)read16(rectangle + 2),
              (int16_t)read16(rectangle + 4), (int16_t)read16(rectangle + 6));
    return true;
}

static void activatePalette(uint8_t* window)
{
    WindowSlot* slot = windowSlot(window);
    if (!slot || !slot->palette || !*slot->palette) return;
    s_activePalette = slot->palette;
    const uint8_t* palette = *slot->palette;
    uint16_t count = read16(palette);
    if (count > 16) count = 16;
    for (uint16_t i = 0; i < count; ++i) {
        const uint8_t* color = palette + 16 + i * 16;
        // All shipped palettes are 16-entry pmTolerant palettes.  The Palette
        // Manager keeps white and black in the device's reserved end slots and
        // allocates the remaining entries through slots 1..14.  The game's 4-bpp
        // pixels use those physical CLUT indices, not the resource entry number.
        uint16_t physical = count == 16 ? (i == 0 ? 0 : (i == 1 ? 15 : i - 1)) : i;
        uint8_t* spec = s_windowManagerColors + 8 + physical * 8;
        write16(spec, physical);
        write16(spec + 2, read16(color));
        write16(spec + 4, read16(color + 2));
        write16(spec + 6, read16(color + 4));
    }
    write32(s_windowManagerColors, s_colorSeed++);
}

static uint8_t* newGWorld(const uint8_t* bounds, uint16_t depth)
{
    GWorldSlot* slot = 0;
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (!s_gworlds[i].used) { slot = &s_gworlds[i]; break; }
    if (!slot || !bounds) return 0;
    for (uint16_t i = 0; i < sizeof(slot->port); ++i) slot->port[i] = 0;
    for (uint16_t i = 0; i < sizeof(slot->pixMap); ++i) slot->pixMap[i] = 0;
    int16_t top = (int16_t)read16(bounds);
    int16_t left = (int16_t)read16(bounds + 2);
    int16_t bottom = (int16_t)read16(bounds + 4);
    int16_t right = (int16_t)read16(bounds + 6);
    uint16_t pixelDepth = depth ? depth : 4;
    uint16_t width = (uint16_t)(right - left);
    uint16_t height = (uint16_t)(bottom - top);
    uint16_t rowBytes = (uint16_t)(((uint32_t)width * pixelDepth + 31) >> 5 << 2);
    slot->pixels = (uint8_t*)AllocMem((uint32_t)rowBytes * height, MEMF_CLEAR);
    if (!slot->pixels) return 0;
    slot->used = true;
    slot->locked = false;
    slot->purgeable = true;
    slot->pixMapMaster = slot->pixMap;
    write32(slot->pixMap, (uint32_t)slot->pixels);
    write16(slot->pixMap + 4, (uint16_t)(0x8000 | rowBytes));
    writeRect(slot->pixMap + 6, top, left, bottom, right);
    write32(slot->pixMap + 22, 72UL << 16);
    write32(slot->pixMap + 26, 72UL << 16);
    write16(slot->pixMap + 30, 0);
    write16(slot->pixMap + 32, pixelDepth);
    write16(slot->pixMap + 34, 1);
    write16(slot->pixMap + 36, pixelDepth);
    write32(slot->pixMap + 42, (uint32_t)&s_windowManagerColorsMaster);
    initRegion(slot->visRegion, slot->visRegionMaster, top, left, bottom, right);
    initRegion(slot->clipRegion, slot->clipRegionMaster, top, left, bottom, right);
    initColorPort(slot->port, &slot->visRegionMaster, &slot->clipRegionMaster,
                  top, left, bottom, right);
    write32(slot->port + 2, (uint32_t)&slot->pixMapMaster);
    return slot->port;
}

static GWorldSlot* gWorldForPixMap(uint8_t** pixMap)
{
    for (uint16_t i = 0; i < sizeof(s_gworlds) / sizeof(s_gworlds[0]); ++i)
        if (s_gworlds[i].used && &s_gworlds[i].pixMapMaster == pixMap) return &s_gworlds[i];
    return 0;
}

static void initMenus()
{
    s_menuManager.initialized = true;
    s_menuManager.colorTable = 0;

    // InitMenus optionally adopts the menu-color table resource.  Its ID is not
    // prescribed, so mirror the Resource Manager search and take the first 'mctb'.
    for (uint32_t i = 0; i < s_resourceArchive.resourceCount(); ++i) {
        ResourceArchive::Item item;
        if (!s_resourceArchive.item(i, item)) break;
        if (item.type == 0x6d637462UL) {      // 'mctb'
            s_resourceMasters[i] = (uint8_t*)item.data;
            s_menuManager.colorTable = &s_resourceMasters[i];
            break;
        }
    }

    // The initialized menu list is empty, so the menu bar is its white background.
    for (uint32_t i = 0; i < (512 / 2) * 20; ++i) s_colorScreen[i] = 0;
}

static void initTextEdit()
{
    // TEInit creates an empty private scrap handle and resets its manager globals.
    s_textEditScrapMaster = s_textEditScrap;
    s_textEdit.initialized = true;
    s_textEdit.scrap = &s_textEditScrapMaster;
}

static void initDialogs(uint8_t* resumeProcedure)
{
    s_dialogManager.initialized = true;
    s_dialogManager.resumeProcedure = resumeProcedure;
}

static void initCursor()
{
    s_cursor.initialized = true;
    s_cursor.visible = true;
    s_cursor.image = s_qdThePort - 108;       // qd.arrow
}

static bool isImplementedToolTrap(uint16_t trap)
{
    if (trap == 0xab03) return true;           // Jackson: Color QuickDraw is present
    for (uint16_t i = 0; i < sizeof(s_trapNames) / sizeof(s_trapNames[0]); ++i)
        if (s_trapNames[i].word == trap) return true;
    return false;
}

static uint8_t* getToolTrapAddress(uint16_t trap)
{
    uint16_t index = trap & 0x03ff;
    if (!isImplementedToolTrap(trap)) index = 0x009f; // _Unimplemented's shared address
    return &s_trapTokens[index];
}

static uint8_t* getTrapAddress(uint16_t trap)
{
    uint16_t index = trap & 0x0fff;
    return s_trapAddresses[index] ? s_trapAddresses[index] : &s_trapTokens[index];
}

static void setTrapAddress(uint16_t trap, uint8_t* address)
{
    s_trapAddresses[trap & 0x0fff] = address;
}

static uint8_t* newPointer(uint32_t size, bool clear)
{
    uint8_t* pointer = (uint8_t*)AllocMem(size ? size : 1, clear ? MEMF_CLEAR : 0);
    if (!pointer) {
        s_memoryManager.error = -108;        // memFullErr
        return 0;
    }
    s_memoryManager.error = 0;
    if (s_memoryManager.allocationCount < sizeof(s_pointerAllocations) / sizeof(s_pointerAllocations[0])) {
        PointerAllocation& allocation = s_pointerAllocations[s_memoryManager.allocationCount];
        allocation.pointer = pointer;
        allocation.master = pointer;
        allocation.size = size ? size : 1;
    }
    ++s_memoryManager.allocationCount;
    return pointer;
}

static uint8_t** recoverHandle(uint8_t* pointer)
{
    uint32_t address = (uint32_t)pointer;
    uint32_t recorded = s_memoryManager.allocationCount;
    if (recorded > sizeof(s_pointerAllocations) / sizeof(s_pointerAllocations[0]))
        recorded = sizeof(s_pointerAllocations) / sizeof(s_pointerAllocations[0]);
    for (uint32_t i = 0; i < recorded; ++i) {
        PointerAllocation& allocation = s_pointerAllocations[i];
        uint32_t base = (uint32_t)allocation.pointer;
        if (address >= base && address < base + allocation.size)
            return &allocation.master;
    }
    for (uint32_t i = 0; i < s_resourceArchive.resourceCount(); ++i) {
        ResourceArchive::Item item;
        if (!s_resourceArchive.item(i, item)) break;
        uint32_t base = (uint32_t)item.data;
        if (address >= base && address < base + item.size) {
            s_resourceMasters[i] = (uint8_t*)item.data;
            return &s_resourceMasters[i];
        }
    }
    return 0;
}

static uint8_t** newHandle(uint32_t size, bool clear)
{
    if (s_handleAllocationCount == sizeof(s_handleAllocations) / sizeof(s_handleAllocations[0])) {
        s_memoryManager.error = -108;
        return 0;
    }
    uint8_t* data = (uint8_t*)AllocMem(size ? size : 1, clear ? MEMF_CLEAR : 0);
    if (!data) {
        s_memoryManager.error = -108;
        return 0;
    }
    HandleAllocation& allocation = s_handleAllocations[s_handleAllocationCount++];
    allocation.master = data;
    allocation.size = size;
    allocation.locked = false;
    allocation.purgeable = false;
    s_memoryManager.error = 0;
    return &allocation.master;
}

static HandleAllocation* handleAllocation(uint8_t** handle)
{
    for (uint16_t i = 0; i < s_handleAllocationCount; ++i)
        if (&s_handleAllocations[i].master == handle) return &s_handleAllocations[i];
    return 0;
}

static uint32_t handleSize(uint8_t** handle)
{
    if (HandleAllocation* allocation = handleAllocation(handle)) {
        s_memoryManager.error = 0;
        return allocation->size;
    }
    int32_t index = resourceHandleIndex(handle);
    ResourceArchive::Item item;
    if (index >= 0 && s_resourceArchive.item((uint32_t)index, item)) {
        s_memoryManager.error = 0;
        return item.size;
    }
    s_memoryManager.error = -109;
    return 0;
}

static int16_t setHandleSize(uint8_t** handle, uint32_t newSize)
{
    HandleAllocation* allocation = handleAllocation(handle);
    if (!allocation) return -109;
    if (allocation->locked) return -117;     // memLockedErr
    uint8_t* data = (uint8_t*)AllocMem(newSize ? newSize : 1, 0);
    if (!data) return -108;
    uint32_t retained = allocation->size < newSize ? allocation->size : newSize;
    for (uint32_t i = 0; i < retained; ++i) data[i] = allocation->master[i];
    FreeMem(allocation->master, allocation->size ? allocation->size : 1);
    allocation->master = data;
    allocation->size = newSize;
    return 0;
}

static int16_t pointerAndHandle(const uint8_t* source, uint8_t** handle, uint32_t size)
{
    HandleAllocation* allocation = handleAllocation(handle);
    if (!allocation || (!source && size)) return -109;
    uint32_t newSize = allocation->size + size;
    uint8_t* data = (uint8_t*)AllocMem(newSize ? newSize : 1, 0);
    if (!data) return -108;
    for (uint32_t i = 0; i < allocation->size; ++i) data[i] = allocation->master[i];
    for (uint32_t i = 0; i < size; ++i) data[allocation->size + i] = source[i];
    FreeMem(allocation->master, allocation->size ? allocation->size : 1);
    allocation->master = data;
    allocation->size = newSize;
    return 0;
}

static int16_t installVBLTask(uint8_t* task)
{
    if (!task) return -50;                   // paramErr
    for (uint16_t i = 0; i < s_vblTaskCount; ++i)
        if (s_vblTasks[i] == task) return -94; // vTypErr: already installed
    if (s_vblTaskCount == sizeof(s_vblTasks) / sizeof(s_vblTasks[0]))
        return -94;

    write16(task + 4, 1);                    // vType
    write32(task, 0);
    if (s_vblTaskCount) write32(s_vblTasks[s_vblTaskCount - 1], (uint32_t)task);
    s_vblTasks[s_vblTaskCount++] = task;
    s_vblLastTick = g_macTicks;
    return 0;
}

static void scheduleVBLTask()
{
    if (!s_vblTaskCount || g_macVBLCallbackEntry) return;
    uint32_t now = g_macTicks;
    uint32_t elapsed = now - s_vblLastTick;
    if (!elapsed) return;
    s_vblLastTick = now;
    for (uint16_t i = 0; i < s_vblTaskCount; ++i) {
        uint8_t* task = s_vblTasks[i];
        int32_t count = (int16_t)read16(task + 10);
        count -= (int32_t)elapsed;
        if (count > 0) {
            write16(task + 10, (uint16_t)count);
            continue;
        }
        // MacEntry.s substitutes a user-mode trampoline for the normal trap
        // return PC.  The pending flag is cleared before the callback executes,
        // so any Line-A traps made by the driver nest normally.
        write16(task + 10, 0);
        g_macVBLCallbackTask = (uint32_t)task;
        g_macVBLCallbackA5 = (uint32_t)s_currentA5;
        g_macVBLCallbackEntry = read32(task + 6);
        return;
    }
}

static int32_t resourceHandleIndex(uint8_t** handle)
{
    uint32_t address = (uint32_t)handle;
    uint32_t base = (uint32_t)s_resourceMasters;
    uint32_t bytes = s_resourceArchive.resourceCount() * sizeof(s_resourceMasters[0]);
    if (address < base || address >= base + bytes
        || (address - base) % sizeof(s_resourceMasters[0]) != 0)
        return -1;
    return (int32_t)((address - base) / sizeof(s_resourceMasters[0]));
}

static bool isPermanentHandle(uint8_t** handle)
{
    // The screen device and its PixMap are permanent system-style handles.  They
    // cannot move, but HLock on either is still a successful operation.
    return resourceHandleIndex(handle) >= 0 || handleAllocation(handle) || gWorldForPixMap(handle)
        || handle == &s_mainDeviceMaster || handle == &s_windowManagerPixMapMaster;
}

static bool validatePermanentHandle(uint8_t** handle)
{
    if (isPermanentHandle(handle)) {
        s_memoryManager.error = 0;
        return true;
    }
    s_memoryManager.error = -109;           // nilHandleErr / invalid emulated handle
    return false;
}

// AmigaDOS runs the application in user mode: parameters are on USP, while Line-A creates
// a six-byte frame on the supervisor stack.  This differs from the supervisor-mode Mac II.
extern "C" uint32_t vetteLineADispatch(uint32_t* regs, uint8_t* frame, uint8_t* userStack)
{
    uint32_t pc = read32(frame + 2);
    uint16_t trap = read16((const uint8_t*)pc);
    if (trap == 0xa02e) {                    // _BlockMove: A0, A1, D0; registers preserved
        blockMove((uint8_t*)regs[8], (uint8_t*)regs[9], regs[0]);
        ++g_blockMoveCount;
        return 1;
    }
    if (trap == 0xa9f1) {                    // _UnLoadSeg(Ptr), deliberately kept resident
        g_stageCDepth = 2;
        return 5;                             // handled + four parameter bytes consumed
    }
    if (trap == 0xa9a0) {                    // GetResource(type:4, id:2) -> Handle result:4
        int16_t id = (int16_t)read16(userStack);
        uint32_t type = read32(userStack + 2);
        write32(userStack + 6, (uint32_t)getResource(type, id));
        if (g_stageCDepth < 3) g_stageCDepth = 3;
        return 7;
    }
    if (trap == 0xa9a1) {                    // GetNamedResource(type:4, name:4) -> Handle result:4
        uint8_t** handle = getNamedResource(read32(userStack + 4),
                                             (const uint8_t*)read32(userStack));
        write32(userStack + 8, (uint32_t)handle);
        if (g_stageCDepth < 51) g_stageCDepth = 51;
        return 9;
    }
    if (trap == 0xa86e) {                    // InitGraf(&qd.thePort)
        initGraf((uint8_t*)read32(userStack));
        if (g_stageCDepth < 4) g_stageCDepth = 4;
        return 5;
    }
    if (trap == 0xa8fe) {                    // InitFonts()
        initFonts();
        if (g_stageCDepth < 5) g_stageCDepth = 5;
        return 1;
    }
    if (trap == 0xa912) {                    // InitWindows()
        if (!s_qdThePort || !s_fontManager.initialized) return 0;
        initWindowManagerPort();
        if (g_stageCDepth < 6) g_stageCDepth = 6;
        return 1;
    }
    if (trap == 0xa930) {                    // InitMenus()
        if (!s_windowManager.initialized) return 0;
        initMenus();
        if (g_stageCDepth < 7) g_stageCDepth = 7;
        return 1;
    }
    if (trap == 0xa9cc) {                    // TEInit()
        initTextEdit();
        if (g_stageCDepth < 8) g_stageCDepth = 8;
        return 1;
    }
    if (trap == 0xa97b) {                    // InitDialogs(resumeProc)
        initDialogs((uint8_t*)read32(userStack));
        if (g_stageCDepth < 9) g_stageCDepth = 9;
        return 5;
    }
    if (trap == 0xa850) {                    // InitCursor()
        initCursor();
        if (g_stageCDepth < 10) g_stageCDepth = 10;
        return 1;
    }
    if (trap == 0xa746) {                    // GetToolTrapAddress(D0) -> A0
        regs[8] = (uint32_t)getToolTrapAddress((uint16_t)regs[0]);
        if (g_stageCDepth < 11) g_stageCDepth = 11;
        return 1;
    }
    if (trap == 0xa146) {                    // GetTrapAddress(D0) -> A0
        regs[8] = (uint32_t)getTrapAddress((uint16_t)regs[0]);
        if (g_stageCDepth < 47) g_stageCDepth = 47;
        return 1;
    }
    if (trap == 0xa047) {                    // SetTrapAddress(A0, D0)
        setTrapAddress((uint16_t)regs[0], (uint8_t*)regs[8]);
        if (g_stageCDepth < 48) g_stageCDepth = 48;
        return 1;
    }
    if (trap == 0xa31e) {                    // NewPtrSysClear: D0 size -> A0 pointer
        regs[8] = (uint32_t)newPointer(regs[0], true);
        regs[0] = (uint32_t)(int32_t)s_memoryManager.error;
        if (g_stageCDepth < 12) g_stageCDepth = 12;
        return 1;
    }
    if (trap == 0xa997) {                    // OpenResFile(name: Str255) -> refNum
        write16(userStack + 4, (uint16_t)openResourceFile((uint8_t*)read32(userStack)));
        if (g_stageCDepth < 13) g_stageCDepth = 13;
        return 5;
    }
    if (trap == 0xa063) {                    // MaxApplZone()
        // AllocMem is already one expandable process-wide heap on AmigaOS; retain
        // the requested zone state so FreeMem reports against that same allocator.
        s_memoryManager.applicationZoneMaximized = true;
        if (g_stageCDepth < 14) g_stageCDepth = 14;
        return 1;
    }
    if (trap == 0xa01c) {                    // FreeMem() -> D0
        regs[0] = AvailMem(MEMF_PUBLIC);
        if (g_stageCDepth < 15) g_stageCDepth = 15;
        return 1;
    }
    if (trap == 0xa874) {                    // GetPort(VAR port)
        write32((uint8_t*)read32(userStack), read32(s_qdThePort));
        if (g_stageCDepth < 16) g_stageCDepth = 16;
        return 5;
    }
    if (trap == 0xa090) {                    // SysEnvirons(version in D0, record in A0)
        uint8_t* environment = (uint8_t*)regs[8];
        if ((uint16_t)regs[0] != 1 || !environment) {
            regs[0] = (uint32_t)(int32_t)-5501; // envNotPresent
            return 1;
        }
        write16(environment + 0, 1);         // environsVersion
        write16(environment + 2, 4);         // envMacII
        write16(environment + 4, 0x0608);    // System 6.0.8 reference environment
        write16(environment + 6, 3);         // env68020
        environment[8] = 0;                  // hasFPU
        environment[9] = 1;                  // hasColorQD
        write16(environment + 10, 5);        // standard ADB keyboard
        write16(environment + 12, 0);        // AppleTalk driver unavailable
        write16(environment + 14, 0);        // no Macintosh system volume
        regs[0] = 0;                         // noErr
        if (g_stageCDepth < 17) g_stageCDepth = 17;
        return 1;
    }
    if (trap == 0xaa32) {                    // GetGDevice() -> GDHandle
        write32(userStack, (uint32_t)&s_mainDeviceMaster);
        if (g_stageCDepth < 18) g_stageCDepth = 18;
        return 1;
    }
    if (trap == 0xaa2e) {                    // InitGDevice(refNum, mode, device)
        uint8_t** deviceHandle = (uint8_t**)read32(userStack);
        int16_t refNum = (int16_t)read16(userStack + 8);
        if (deviceHandle == &s_mainDeviceMaster && *deviceHandle == s_mainDevice
            && refNum == (int16_t)read16(s_mainDevice)) {
            write32(s_mainDevice + 42, read32(userStack + 4)); // gdMode
            if (g_stageCDepth < 67) g_stageCDepth = 67;
            return 11;
        }
    }
    if (trap == 0xa064) {                    // MoveHHi(Handle in A0)
        uint8_t** handle = (uint8_t**)regs[8];
        // Resource data is in the permanently resident archive, already outside
        // the application A5 world.  Validate the handle; no relocation is needed.
        validatePermanentHandle(handle);
        if (g_stageCDepth < 19) g_stageCDepth = 19;
        return 1;
    }
    if (trap == 0xa029) {                    // HLock(Handle in A0)
        uint8_t** handle = (uint8_t**)regs[8];
        int32_t index = resourceHandleIndex(handle);
        if (index >= 0) { s_resourceLocked[index] = true; s_memoryManager.error = 0; }
        else if (HandleAllocation* allocation = handleAllocation(handle)) {
            allocation->locked = true; s_memoryManager.error = 0;
        } else validatePermanentHandle(handle);
        if (g_stageCDepth < 20) g_stageCDepth = 20;
        return 1;
    }
    if (trap == 0xa02a) {                    // HUnlock(Handle in A0)
        uint8_t** handle = (uint8_t**)regs[8];
        int32_t index = resourceHandleIndex(handle);
        if (index >= 0) { s_resourceLocked[index] = false; s_memoryManager.error = 0; }
        else if (HandleAllocation* allocation = handleAllocation(handle)) {
            allocation->locked = false; s_memoryManager.error = 0;
        } else validatePermanentHandle(handle);
        if (g_stageCDepth < 46) g_stageCDepth = 46;
        return 1;
    }
    if (trap == 0xa049) {                    // HPurge(Handle in A0)
        uint8_t** handle = (uint8_t**)regs[8];
        int32_t index = resourceHandleIndex(handle);
        if (index >= 0) { s_resourcePurgeable[index] = true; s_memoryManager.error = 0; }
        else if (HandleAllocation* allocation = handleAllocation(handle)) {
            allocation->purgeable = true; s_memoryManager.error = 0;
        } else validatePermanentHandle(handle);
        if (g_stageCDepth < 65) g_stageCDepth = 65;
        return 1;
    }
    if (trap == 0xa04a) {                    // HNoPurge(Handle in A0)
        uint8_t** handle = (uint8_t**)regs[8];
        int32_t index = resourceHandleIndex(handle);
        if (index >= 0) { s_resourcePurgeable[index] = false; s_memoryManager.error = 0; }
        else if (HandleAllocation* allocation = handleAllocation(handle)) {
            allocation->purgeable = false; s_memoryManager.error = 0;
        } else validatePermanentHandle(handle);
        if (g_stageCDepth < 52) g_stageCDepth = 52;
        return 1;
    }
    if (trap == 0xa994) {                    // CurResFile() -> refNum
        write16(userStack, s_currentResourceFork);
        if (g_stageCDepth < 21) g_stageCDepth = 21;
        return 1;
    }
    if (trap == 0xa998) {                    // UseResFile(refNum)
        uint16_t fork = read16(userStack);
        if (fork < s_resourceArchive.forkCount()) {
            s_currentResourceFork = fork;
            s_memoryManager.error = 0;
        } else {
            s_memoryManager.error = -193;    // resFNotFound
        }
        if (g_stageCDepth < 22) g_stageCDepth = 22;
        return 3;
    }
    if (trap == 0xa11e) {                    // NewPtrClear: D0 size -> A0 pointer
        regs[8] = (uint32_t)newPointer(regs[0], true);
        regs[0] = (uint32_t)(int32_t)s_memoryManager.error;
        if (g_stageCDepth < 23) g_stageCDepth = 23;
        return 1;
    }
    if (trap == 0xa51e) {                    // NewPtrSys: D0 size -> A0 pointer
        regs[8] = (uint32_t)newPointer(regs[0], false);
        regs[0] = (uint32_t)(int32_t)s_memoryManager.error;
        if (g_stageCDepth < 43) g_stageCDepth = 43;
        return 1;
    }
    if (trap == 0xa122) {                    // NewHandle: D0 size -> A0 handle
        regs[8] = (uint32_t)newHandle(regs[0], false);
        regs[0] = (uint32_t)(int32_t)s_memoryManager.error;
        if (g_stageCDepth < 45) g_stageCDepth = 45;
        return 1;
    }
    if (trap == 0xa025) {                    // GetHandleSize(Handle in A0) -> D0 size
        regs[0] = handleSize((uint8_t**)regs[8]);
        if (g_stageCDepth < 49) g_stageCDepth = 49;
        return 1;
    }
    if (trap == 0xa024) {                    // SetHandleSize(Handle in A0, D0 size)
        s_memoryManager.error = setHandleSize((uint8_t**)regs[8], regs[0]);
        if (g_stageCDepth < 54) g_stageCDepth = 54;
        return 1;
    }
    if (trap == 0xa9ef) {                    // PtrAndHand(A0 source, A1 handle, D0 size)
        int16_t error = pointerAndHandle((const uint8_t*)regs[8],
                                         (uint8_t**)regs[9], regs[0]);
        s_memoryManager.error = error;
        regs[0] = (uint32_t)(int32_t)error;
        if (g_stageCDepth < 50) g_stageCDepth = 50;
        return 1;
    }
    if (trap == 0xa128) {                    // RecoverHandle(pointer in A0) -> handle in A0
        regs[8] = (uint32_t)recoverHandle((uint8_t*)regs[8]);
        s_memoryManager.error = regs[8] ? 0 : -109;
        if (g_stageCDepth < 41) g_stageCDepth = 41;
        return 1;
    }
    if (trap == 0xa03b) {                    // Delay(ticks in A0) -> final ticks in D0
        uint32_t target = g_macTicks + regs[8];
        while ((int32_t)(g_macTicks - target) < 0) { }
        regs[0] = g_macTicks;
        if (g_stageCDepth < 42) g_stageCDepth = 42;
        return 1;
    }
    if ((trap & 0xf9ff) == 0xa03c) {          // CmpString / EqualString register trap
        uint16_t firstLength = (uint16_t)(regs[0] >> 16);
        uint16_t secondLength = (uint16_t)regs[0];
        bool equal = equalMacRomanStrings((const uint8_t*)regs[8], firstLength,
                                           (const uint8_t*)regs[9], secondLength,
                                           (trap & 0x0400) != 0, (trap & 0x0200) != 0);
        regs[0] = equal ? 0 : 1;              // ROM result; glue flips it for EqualString
        if (g_stageCDepth < 53) g_stageCDepth = 53;
        return 1;
    }
    if (trap == 0xa033) {                    // VInstall(VBLTaskPtr in A0) -> OSErr in D0
        regs[0] = (uint32_t)(int32_t)installVBLTask((uint8_t*)regs[8]);
        if (g_stageCDepth < 44) g_stageCDepth = 44;
        return 1;
    }
    if (trap == 0xaa46) {                    // GetNewCWindow(id, storage, behind) -> WindowPtr
        uint8_t* window = newColorWindow((int16_t)read16(userStack + 8),
                                         (uint8_t*)read32(userStack + 4),
                                         (uint8_t*)read32(userStack));
        write32(userStack + 10, (uint32_t)window);
        if (g_stageCDepth < 24) g_stageCDepth = 24;
        return 11;
    }
    if (trap == 0xa91b) {                    // MoveWindow(window, h, v, front)
        moveWindow((uint8_t*)read32(userStack + 6),
                   (int16_t)read16(userStack + 4), (int16_t)read16(userStack + 2),
                   userStack[0] != 0);
        if (g_stageCDepth < 25) g_stageCDepth = 25;
        return 11;
    }
    if (trap == 0xa914) {                    // DisposeWindow(window)
        if (disposeWindow((uint8_t*)read32(userStack))) {
            if (g_stageCDepth < 66) g_stageCDepth = 66;
            return 5;
        }
    }
    if (trap == 0xa873) {                    // SetPort(GrafPtr)
        write32(s_qdThePort, read32(userStack));
        if (g_stageCDepth < 26) g_stageCDepth = 26;
        return 5;
    }
    if (trap == 0xaa92) {                    // GetNewPalette(id) -> PaletteHandle
        write32(userStack + 2,
                (uint32_t)getResource(0x706c7474UL, (int16_t)read16(userStack))); // 'pltt'
        if (g_stageCDepth < 27) g_stageCDepth = 27;
        return 3;
    }
    if (trap == 0xaa28) {                    // GetCTSeed() -> unique long seed
        write32(userStack, s_colorSeed++);
        if (g_stageCDepth < 28) g_stageCDepth = 28;
        return 1;
    }
    if (trap == 0xaa95) {                    // SetPalette(window, palette, update)
        WindowSlot* slot = windowSlot((uint8_t*)read32(userStack + 6));
        if (slot) {
            slot->palette = (uint8_t**)read32(userStack + 2);
            slot->paletteUpdates = userStack[0] != 0;
        }
        if (g_stageCDepth < 29) g_stageCDepth = 29;
        return 11;
    }
    if (trap == 0xaa94) {                    // ActivatePalette(window)
        activatePalette((uint8_t*)read32(userStack));
        s_screenDirty = true;
        if (g_stageCDepth < 30) g_stageCDepth = 30;
        return 5;
    }
    if (trap == 0xa915) {                    // ShowWindow(window)
        uint8_t* window = (uint8_t*)read32(userStack);
        if (windowSlot(window)) window[110] = 1;
        if (g_stageCDepth < 31) g_stageCDepth = 31;
        return 5;
    }
    if (trap == 0xa91f) {                    // SelectWindow(window)
        uint8_t* window = (uint8_t*)read32(userStack);
        for (uint16_t i = 0; i < sizeof(s_windows) / sizeof(s_windows[0]); ++i)
            if (s_windows[i].used) s_windows[i].record[111] = s_windows[i].record == window;
        s_windowList = window;
        if (g_stageCDepth < 32) g_stageCDepth = 32;
        return 5;
    }
    if (trap == 0xa922) {                    // BeginUpdate(window)
        WindowSlot* slot = windowSlot((uint8_t*)read32(userStack));
        if (slot) slot->updating = true;
        if (g_stageCDepth < 33) g_stageCDepth = 33;
        return 5;
    }
    if (trap == 0xa923) {                    // EndUpdate(window)
        WindowSlot* slot = windowSlot((uint8_t*)read32(userStack));
        if (slot) {
            slot->updating = false;
            initRegion(slot->updateRegion, slot->updateRegionMaster, 0, 0, 0, 0);
        }
        if (g_stageCDepth < 34) g_stageCDepth = 34;
        return 5;
    }
    if (trap == 0xa889) {                    // TextMode(mode)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) write16(port + 72, read16(userStack));
        if (g_stageCDepth < 35) g_stageCDepth = 35;
        return 3;
    }
    if (trap == 0xa89b) {                    // PenSize(horizontal, vertical)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) {
            write16(port + 52, read16(userStack));
            write16(port + 54, read16(userStack + 2));
        }
        if (g_stageCDepth < 58) g_stageCDepth = 58;
        return 5;
    }
    if (trap == 0xa89c) {                    // PenMode(mode)
        uint8_t* port = (uint8_t*)read32(s_qdThePort);
        if (port) write16(port + 56, read16(userStack));
        if (g_stageCDepth < 59) g_stageCDepth = 59;
        return 3;
    }
    if (trap == 0xa87b) {                    // ClipRect(Rect*)
        if (clipRect((const uint8_t*)read32(userStack))) {
            if (g_stageCDepth < 63) g_stageCDepth = 63;
            return 5;
        }
    }
    if (trap == 0xa974) {                    // Button() -> Boolean
        scheduleVBLTask();
        stabilizeIntroAnimation();
        updateIntroAudio();
        if (s_screenDirty && s_loudStopScreen
            && s_loudStopScreen->presentMacFrame(
                s_colorScreen, s_windowManagerColors,
                s_pixelsDirty ? s_dirtyTop : 0, s_pixelsDirty ? s_dirtyLeft : 0,
                s_pixelsDirty ? s_dirtyBottom : 0, s_pixelsDirty ? s_dirtyRight : 0)) {
            s_screenDirty = false;
            s_pixelsDirty = false;
        }
        write16(userStack, AmigaHardware::isLeftMouseButtonPressed() ? 1 : 0);
        if (g_stageCDepth < 64) g_stageCDepth = 64;
        return 1;
    }
    if (trap == 0xa8a1) {                    // FrameRect(rectangle)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        if (frameRect(rectangle)) {
            if (currentPortIsScreen()) markDirty(rectangle);
            if (g_stageCDepth < 60) g_stageCDepth = 60;
            return 5;
        }
    }
    if (trap == 0xa8a3) {                    // EraseRect(rectangle)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        if (eraseRect(rectangle)) {
            if (currentPortIsScreen()) markDirty(rectangle);
            if (g_stageCDepth < 62) g_stageCDepth = 62;
            return 5;
        }
    }
    if (trap == 0xa9b9) {                    // GetCursor(id) -> CursHandle
        write32(userStack + 2,
                (uint32_t)getResource(0x43555253UL, (int16_t)read16(userStack))); // 'CURS'
        if (g_stageCDepth < 36) g_stageCDepth = 36;
        return 3;
    }
    if (trap == 0xa9bc) {                    // GetPicture(id) -> PicHandle
        write32(userStack + 2,
                (uint32_t)getResource(0x50494354UL, (int16_t)read16(userStack))); // 'PICT'
        if (g_stageCDepth < 56) g_stageCDepth = 56;
        return 3;
    }
    if (trap == 0xa8f6) {                    // DrawPicture(PicHandle, destination Rect)
        const uint8_t* rectangle = (const uint8_t*)read32(userStack);
        if (drawPicture((uint8_t**)read32(userStack + 4),
                        rectangle)) {
            if (currentPortIsScreen()) markDirty(rectangle);
            if (g_stageCDepth < 57) g_stageCDepth = 57;
            return 9;
        }
    }
    if (trap == 0xa8ec) {                    // CopyBits(src, dst, srcRect, dstRect, mode, mask)
        const uint8_t* destinationRect = (const uint8_t*)read32(userStack + 6);
        if (copyBits((const uint8_t*)read32(userStack + 18),
                     (const uint8_t*)read32(userStack + 14),
                     (const uint8_t*)read32(userStack + 10),
                     destinationRect, read16(userStack + 4),
                     (const uint8_t*)read32(userStack))) {
            if (bitmapIsScreen((const uint8_t*)read32(userStack + 14)))
                markDirty(destinationRect);
            if (g_stageCDepth < 61) g_stageCDepth = 61;
            return 23;
        }
    }
    if (trap == 0xa851) {                    // SetCursor(Cursor*)
        s_cursor.image = (const uint8_t*)read32(userStack);
        s_cursor.visible = true;
        if (g_stageCDepth < 37) g_stageCDepth = 37;
        return 5;
    }
    if (trap == 0xa97c) {                    // GetNewDialog(id, storage, behind) -> DialogPtr
        uint8_t* dialog = newDialog((int16_t)read16(userStack + 8),
                                    (uint8_t*)read32(userStack + 4),
                                    (uint8_t*)read32(userStack));
        write32(userStack + 10, (uint32_t)dialog);
        if (g_stageCDepth < 38) g_stageCDepth = 38;
        return 11;
    }
    if (trap == 0xa981) {                    // DrawDialog(dialog)
        drawDialog((uint8_t*)read32(userStack));
        if (g_stageCDepth < 39) g_stageCDepth = 39;
        return 5;
    }
    if (trap == 0xa983) {                    // DisposeDialog(dialog)
        disposeDialog((uint8_t*)read32(userStack));
        if (g_stageCDepth < 55) g_stageCDepth = 55;
        return 5;
    }
    if (trap == 0xab1d && regs[0] == 0) {    // QDExtensions: NewGWorld
        const uint8_t* bounds = (const uint8_t*)read32(userStack + 12);
        uint8_t* world = newGWorld(bounds, read16(userStack + 16));
        write32((uint8_t*)read32(userStack + 18), (uint32_t)world);
        write16(userStack + 22, world ? 0 : (uint16_t)-108);
        if (g_stageCDepth < 40) g_stageCDepth = 40;
        return 23;
    }
    if (trap == 0xab1d && regs[0] == 1) {    // QDExtensions: LockPixels
        GWorldSlot* world = gWorldForPixMap((uint8_t**)read32(userStack));
        if (world) world->locked = true;
        userStack[4] = world ? 1 : 0;
        if (g_stageCDepth < 40) g_stageCDepth = 40;
        return 5;
    }
    if (trap == 0xab1d && regs[0] == 12) {   // QDExtensions: NoPurgePixels
        GWorldSlot* world = gWorldForPixMap((uint8_t**)read32(userStack));
        if (world) world->purgeable = false;
        return 5;
    }

    g_stageBState = 3;
    g_trapWord = trap;
    g_trapPC = pc;
    for (uint16_t i = 0; i < 15; ++i) g_trapRegisters[i] = regs[i];
    g_trapUserStack = (uint32_t)userStack;
    g_trapSelector = -1;
    g_trapSegment = 0xffff;
    g_trapOffset = 0xffffffffUL;
    const char* segmentName = "UNKNOWN";
    for (uint16_t i = 1; i <= 10; ++i) {
        uint32_t lo = (uint32_t)s_segments[i].begin;
        uint32_t hi = (uint32_t)s_segments[i].end;
        if (pc >= lo && pc < hi) {
            g_trapSegment = i; g_trapOffset = pc - lo; segmentName = s_segments[i].name;
            break;
        }
    }
    const char* manager = "UNKNOWN MANAGER";
    const char* routine = "UNKNOWN TRAP";
    for (uint16_t i = 0; i < sizeof(s_trapNames) / sizeof(s_trapNames[0]); ++i)
        if (s_trapNames[i].word == trap) {
            manager = s_trapNames[i].manager; routine = s_trapNames[i].routine; break;
        }
    if (trap == 0xab1d) g_trapSelector = (int32_t)regs[0];
    copyString(g_trapManager, manager);
    copyString(g_trapRoutine, routine);
    if (s_loudStopScreen)
        s_loudStopScreen->showLoudStop(manager, routine, g_trapSelector,
                                       segmentName, g_trapOffset, trap);
    for (;;) { }                             // VBI remains enabled, so the report stays live
}

bool MacLoader::run(VetteScreen* screen)
{
    s_loudStopScreen = screen;
    if (!s_resourceArchive.open(vette_resources,
                                (uint32_t)(vette_resources_end - vette_resources)))
        return false;
    g_resourceCount = s_resourceArchive.resourceCount();

    uint8_t* a5;
    if (!buildA5World(a5)) return false;
    s_currentA5 = a5;
    if (!redirectLowMemoryGlobals(a5)) return false;

    Disable();
    *(void (**)())0x28 = vette_line_a_handler;
    Enable();
    g_stageBState = 1;
    uint8_t* firstJump = a5 + kJumpOffset;
    if (read16(firstJump + 2) != 0x4ef9) return false;
    // Main+1EDA is the application entry stub.  Its first JSR is through the final
    // jump-table entry to %A5Init; invoking %A5Init here as well would initialise twice.
    vette_call_mac_code((void*)read32(firstJump + 4), a5);
    return true;
}
