#include <proto/exec.h>

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
volatile uint32_t g_resourceCount = 0;
volatile uint16_t g_jumpEntryCount = 0;
volatile uint16_t g_blockMoveCount = 0;
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

static void blockMove(uint8_t* source, uint8_t* destination, uint32_t count)
{
    if (destination > source && destination < source + count) {
        while (count) { --count; destination[count] = source[count]; }
    } else {
        for (uint32_t i = 0; i < count; ++i) destination[i] = source[i];
    }
}

// regs is the exception wrapper's d0-d7/a0-a6 image. frame is SR:w, PC:l.
extern "C" uint32_t vetteLineADispatch(uint32_t* regs, uint8_t* frame)
{
    uint32_t pc = read32(frame + 2);
    uint16_t trap = read16((const uint8_t*)pc);
    if (trap == 0xa02e) {                    // _BlockMove: A0, A1, D0; registers preserved
        blockMove((uint8_t*)regs[8], (uint8_t*)regs[9], regs[0]);
        ++g_blockMoveCount;
        return 1;
    }

    g_stageBState = 3;
    g_trapWord = trap;
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
    if (trap == 0xa9f1) { manager = "SEGMENT MANAGER"; routine = "UNLOADSEG"; }
    if (trap == 0xab1d) { manager = "QUICKDRAW"; routine = "QDEXTENSIONS";
                          g_trapSelector = (int32_t)regs[0]; }
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
    ResourceArchive archive;
    if (!archive.open(vette_resources, (uint32_t)(vette_resources_end - vette_resources)))
        return false;
    g_resourceCount = archive.resourceCount();

    uint8_t* a5;
    if (!buildA5World(a5)) return false;

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
