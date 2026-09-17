#include <proto/exec.h>
#include <exec/memory.h>

#include "MacLoader.h"
#include "ResourceArchive.h"
#include "platform/amiga/VetteScreen.h"

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
static uint32_t s_ticks;

// VBLTask is a 14-byte 68k record: qLink, qType, vblAddr, vblCount,
// vblPhase.  Keep the caller-owned records linked exactly as the classic
// Vertical Retrace Manager does.  Execution is deliberately a separate
// concern: calling application code from Amiga's supervisor-mode VERTB ISR
// would give Line-A traps the wrong exception/USP context.
static uint8_t* s_vblTasks[8];
static uint16_t s_vblTaskCount;

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
static GWorldSlot s_gworlds[4];

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
    {0xa9ef,"MEMORY MANAGER","PTRANDHAND"},
    {0xa02a,"MEMORY MANAGER","HUNLOCK"}, {0xa049,"MEMORY MANAGER","HPURGE"},
    {0xa03b,"TIME MANAGER","DELAY"},
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
    {0xa047,"TRAP MANAGER","SETTRAPADDRESS"}, {0xa983,"DIALOG MANAGER","DISPOSEDIALOG"},
    {0xa850,"QUICKDRAW","INITCURSOR"}, {0xa9bc,"QUICKDRAW","GETPICTURE"},
    {0xa8f6,"QUICKDRAW","DRAWPICTURE"}, {0xa89b,"QUICKDRAW","PENSIZE"},
    {0xa8ec,"QUICKDRAW","COPYBITS"}, {0xa8a3,"QUICKDRAW","ERASERECT"},
    {0xa87b,"QUICKDRAW","CLIPRECT"}, {0xa974,"EVENT MANAGER","BUTTON"},
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
    write32(a5 + 4, 1);
    write32(a5 + 8, 0);
    write32(a5 + 12, 0);
    return true;
}

static void blockMove(uint8_t* source, uint8_t* destination, uint32_t count)
{
    if (destination > source && destination < source + count) {
        while (count) { --count; destination[count] = source[count]; }
    } else {
        for (uint32_t i = 0; i < count; ++i) destination[i] = source[i];
    }
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

static uint8_t asciiUpper(uint8_t c)
{
    return c >= 'a' && c <= 'z' ? (uint8_t)(c - ('a' - 'A')) : c;
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
    for (uint16_t i = 0; i < sizeof(slot->record); ++i) slot->record[i] = 0;

    int16_t top = (int16_t)read16(wind);
    int16_t left = (int16_t)read16(wind + 2);
    int16_t bottom = (int16_t)read16(wind + 4);
    int16_t right = (int16_t)read16(wind + 6);
    uint8_t* window = storage ? storage : slot->record;
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
        if (s_windows[i].used && s_windows[i].record == window) return &s_windows[i];
    return 0;
}

static int32_t resourceHandleIndex(uint8_t** handle);

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
        uint8_t* spec = s_windowManagerColors + 8 + i * 8;
        write16(spec, i);
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
    return 0;
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
        if (g_stageCDepth < 51) g_stageCDepth = 51;
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
        s_ticks += regs[8];
        regs[0] = s_ticks;
        if (g_stageCDepth < 42) g_stageCDepth = 42;
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
    if (trap == 0xa9b9) {                    // GetCursor(id) -> CursHandle
        write32(userStack + 2,
                (uint32_t)getResource(0x43555253UL, (int16_t)read16(userStack))); // 'CURS'
        if (g_stageCDepth < 36) g_stageCDepth = 36;
        return 3;
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
    if (trap == 0xab1d && regs[0] == 0) {    // QDExtensions: NewGWorld
        uint8_t* world = newGWorld((const uint8_t*)read32(userStack + 12),
                                   read16(userStack + 16));
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
