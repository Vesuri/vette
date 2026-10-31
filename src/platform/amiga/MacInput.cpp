#include <proto/exec.h>
#include <exec/interrupts.h>
#include <exec/nodes.h>
#include <resources/cia.h>
#include <proto/cia.h>
#include <hardware/cia.h>

#include "MacInput.h"
#include "framework/AmigaHardware.h"
#include "mac/MacLoader.h"

static struct Library* s_ciaaBase;
static struct Interrupt s_keyboardInterrupt;
static struct Interrupt* s_savedVector;
struct KeyEvent {
    uint8_t rawAndUp;
    uint8_t source;
    uint16_t modifiers;
};
static volatile KeyEvent s_events[32];
static volatile uint8_t s_head, s_tail;
// Each source holds its own bit, so the keyboard and the controller cannot
// release a key the other still holds. The game sees the OR.
static const uint8_t kKeyboard = 1, kController = 2;
static volatile uint8_t s_keyDown[128];

static uint16_t currentModifiers()
{
    uint16_t modifiers = 0;
    if (s_keyDown[0x60] || s_keyDown[0x61]) modifiers |= 0x0200; // shiftKey
    if (s_keyDown[0x63]) modifiers |= 0x1000;                    // controlKey
    if (s_keyDown[0x64] || s_keyDown[0x65]) modifiers |= 0x0800; // optionKey
    if (s_keyDown[0x66] || s_keyDown[0x67]) modifiers |= 0x0100; // cmdKey
    return modifiers;
}

static void recordKey(uint8_t raw, bool down, uint8_t source)
{
    uint8_t before = s_keyDown[raw];
    uint8_t after = down ? (uint8_t)(before | source) : (uint8_t)(before & ~source);
    s_keyDown[raw] = after;
    if ((before != 0) == (after != 0)) return;
    vetteMacRawKeyChanged(raw, down);
    uint8_t next = (uint8_t)((s_head + 1) & 31);
    if (next != s_tail) {
        s_events[s_head].rawAndUp = (uint8_t)(raw | (down ? 0 : 0x80));
        s_events[s_head].source = source;
        s_events[s_head].modifiers = currentModifiers();
        s_head = next;
    }
}

static uint32_t keyboardHandler()
{
    uint8_t code = (uint8_t)~*ciaasdrPointer;
    *ciaacraPointer |= CIACRAF_SPMODE;
    for (volatile uint16_t delay = 0; delay < 200; ++delay) { }
    *ciaacraPointer &= (uint8_t)~CIACRAF_SPMODE;
    code = (uint8_t)((code >> 1) | (code << 7));
    uint8_t raw = (uint8_t)(code & 0x7f);
    bool down = (code & 0x80) == 0;
    // The controller records keys from the level-3 VBI, which can interrupt
    // this level-2 handler.
    Disable();
    recordKey(raw, down, kKeyboard);
    Enable();
    return 0;
}

// Port 1 controller. A joystick or CD32 pad presses the keys the keyboard
// would, so the original game's KeyMap scan and key events serve both.
static const uint8_t kRawUp = 0x4c, kRawDown = 0x4d, kRawRight = 0x4e, kRawLeft = 0x4f;
static const uint8_t kRawShiftUp = 0x0c, kRawShiftDown = 0x0b;   // top-row = and -
static const uint8_t kRawReverse = 0x13, kRawPause = 0x19, kRawHorn = 0x31;  // R, P, Z
static const uint8_t kControllerKeys[] = {
    kRawUp, kRawDown, kRawRight, kRawLeft, kRawShiftUp, kRawShiftDown,
    kRawReverse, kRawPause, kRawHorn
};
static const uint16_t kKeyUp = 1, kKeyDown = 2, kKeyRight = 4, kKeyLeft = 8,
    kKeyShiftUp = 16, kKeyShiftDown = 32, kKeyReverse = 64, kKeyPause = 128,
    kKeyHorn = 256;
static uint16_t s_controllerKeys;
static volatile bool s_controllerReady;
// Main+$328E/$32AC shift only after a KeyMap scan with no key down
// (A5-$39BE). A new controller shift therefore first releases the
// controller's keys. The scan (Main+$2D26) runs inside the driving
// iteration, after the boundary refresh, so wait for two boundaries: one
// whole iteration, and its scan, then sees them up.
static volatile uint16_t s_drivingScans;
static uint16_t s_shiftReleaseScan;
static bool s_shiftPending;
// Set when Play resumed a suspended race: the resumed driving scan would
// otherwise read the still-held P and pause again. Cleared on release.
static volatile bool s_resumePlayHeld;

extern "C" uint16_t vette_cd32_read();
#ifdef VETTE_CONTROLLER_PROBE
// The fixture's port 1 state, scripted by MacLoader in place of the hardware.
// A CD32 fixture presents an idle pad from boot, through the detection window.
volatile uint16_t g_controllerProbeJoy;
volatile uint16_t g_controllerProbePad = VETTE_CONTROLLER_PROBE == 2 ? 0x0003 : 0;
volatile uint8_t g_controllerProbeFire;
#endif
static const uint16_t kPadBlue = 0x0200, kPadRed = 0x0100, kPadYellow = 0x0080,
    kPadGreen = 0x0040, kPadForward = 0x0020, kPadReverse = 0x0010, kPadPlay = 0x0008;

// The marker bits shift in low and not every button reads pressed: an empty
// port or a plain joystick fails this.
static bool cd32Valid(uint16_t word)
{
    return (word & 0x0003) == 0x0003 && (word & 0x03f8) != 0x03f8;
}

// Decided once, in the first fields. Commodore's CD32 notes (ADCD 2.1,
// CD32_SUPPORT/NOTES/CATS_CD32_NOTES) warn that the first reads may miss the
// special buttons, so presence needs three valid, agreeing samples taken
// eight fields apart. Without a pad the read never runs after the window.
static const uint16_t kCd32Window = 128;
static bool s_cd32Present;
static uint16_t s_cd32Probes, s_cd32Last;
static uint8_t s_cd32Streak;

static uint16_t readCd32()
{
    Disable();   // levels 4-6 would stretch the calibrated bit gaps
    uint16_t word = vette_cd32_read();
    Enable();
#ifdef VETTE_CONTROLLER_PROBE
    word = g_controllerProbePad;
#endif
    return word;
}

static void cd32DetectStep()
{
    --s_cd32Probes;
    if (s_cd32Probes & 7) return;
    uint16_t word = readCd32();
    uint16_t buttons = (uint16_t)(word & 0x03f8);
    if (!cd32Valid(word)) {
        s_cd32Streak = 0;
    } else if (s_cd32Streak && buttons == s_cd32Last) {
        if (++s_cd32Streak >= 3) {
            s_cd32Present = true;
            s_cd32Probes = 0;
        }
    } else {
        s_cd32Streak = 1;
        s_cd32Last = buttons;
    }
}

void vetteInputPollController()
{
    if (!s_controllerReady) return;
    // JOY1DAT holds quadrature counters: forward = bit 9 ^ bit 8, left = bit 9,
    // back = bit 1 ^ bit 0, right = bit 1 (Hardware Reference Manual).
    uint16_t joy = *joy1datPointer;
#ifdef VETTE_CONTROLLER_PROBE
    joy = g_controllerProbeJoy;
#endif
    bool up = ((joy >> 9) ^ (joy >> 8)) & 1;
    bool down = ((joy >> 1) ^ joy) & 1;
    bool left = (joy >> 9) & 1;
    bool right = (joy >> 1) & 1;
    uint16_t keys = (uint16_t)((left ? kKeyLeft : 0) | (right ? kKeyRight : 0));

    if (!s_cd32Present && s_cd32Probes) cd32DetectStep();
    if (s_cd32Present) {
        // The pad owns both button pins. A read that fails the check (pad
        // removed) releases every button rather than holding one.
        uint16_t pad = readCd32();
        if (!cd32Valid(pad)) pad = 0;
        if (pad & kPadForward) keys |= kKeyUp;
        if (pad & kPadReverse) keys |= kKeyDown;
        if (pad & kPadRed) keys |= kKeyShiftUp;
        if (pad & kPadGreen) keys |= kKeyShiftDown;
        if (pad & kPadBlue) keys |= kKeyReverse;
        if (pad & kPadPlay) keys |= kKeyPause;
        if (pad & kPadYellow) keys |= kKeyHorn;
    } else {
        // Fire adds shift up/down to forward/back. Keep the accelerator:
        // Traffic+$3766 undoes a manual shift whose engine speed (car+$44)
        // leaves the new gear's band, which an upshift with the throttle
        // released does at moderate speed.
        bool fire = (*ciaapraPointer & CIAF_GAMEPORT1) == 0;
#ifdef VETTE_CONTROLLER_PROBE
        fire = g_controllerProbeFire != 0;
#endif
        if (up) keys |= kKeyUp | (fire ? kKeyShiftUp : 0);
        if (down) keys |= kKeyDown | (fire ? kKeyShiftDown : 0);
    }

    if (s_resumePlayHeld) {
        if (keys & kKeyPause) keys &= (uint16_t)~kKeyPause;
        else s_resumePlayHeld = false;
    }

    const uint16_t shifts = kKeyShiftUp | kKeyShiftDown;
    if (keys & shifts & ~s_controllerKeys) {
        if (!s_shiftPending) {
            s_shiftPending = true;
            s_shiftReleaseScan = s_drivingScans;
        }
        if ((uint16_t)(s_drivingScans - s_shiftReleaseScan) < 2) keys = 0;
        else s_shiftPending = false;
    } else {
        s_shiftPending = false;
    }

    uint16_t changed = (uint16_t)(keys ^ s_controllerKeys);
    s_controllerKeys = keys;
    for (uint16_t i = 0; changed; ++i, changed >>= 1)
        if (changed & 1)
            recordKey(kControllerKeys[i], (keys >> i) & 1, kController);
}

void vetteInputDrivingScan()
{
    ++s_drivingScans;
}

void vetteInputControllerResumed()
{
    Disable();
    s_resumePlayHeld = true;
    if (s_controllerKeys & kKeyPause) {
        s_controllerKeys &= (uint16_t)~kKeyPause;
        recordKey(kRawPause, false, kController);
    }
    Enable();
}

bool vetteInputInitialize()
{
    for (uint16_t i = 0; i < 128; ++i) s_keyDown[i] = 0;
    s_head = s_tail = 0;
    s_controllerKeys = 0;
    s_shiftPending = false;
    s_resumePlayHeld = false;
    s_cd32Present = false;
    s_cd32Streak = 0;
    (void)readCd32();   // warm-up read, discarded
    s_cd32Probes = kCd32Window;
    s_ciaaBase = (struct Library*)OpenResource((CONST_STRPTR)CIAANAME);
    if (!s_ciaaBase) return false;
    s_keyboardInterrupt.is_Node.ln_Type = NT_INTERRUPT;
    s_keyboardInterrupt.is_Node.ln_Pri = 0;
    s_keyboardInterrupt.is_Node.ln_Name = (char*)"Vette keyboard";
    s_keyboardInterrupt.is_Data = 0;
    s_keyboardInterrupt.is_Code = (void(*)())keyboardHandler;
    s_savedVector = AddICRVector(s_ciaaBase, CIAICRB_SP, &s_keyboardInterrupt);
    if (s_savedVector) {
        RemICRVector(s_ciaaBase, CIAICRB_SP, s_savedVector);
        AddICRVector(s_ciaaBase, CIAICRB_SP, &s_keyboardInterrupt);
    }
    s_controllerReady = true;
    return true;
}

void vetteInputShutdown()
{
    s_controllerReady = false;
    if (!s_ciaaBase) return;
    RemICRVector(s_ciaaBase, CIAICRB_SP, &s_keyboardInterrupt);
    if (s_savedVector) AddICRVector(s_ciaaBase, CIAICRB_SP, s_savedVector);
    s_savedVector = 0;
    s_ciaaBase = 0;
}

bool vetteInputPopKey(uint8_t& rawKey, bool& down, uint16_t& modifiers, bool& controller)
{
    if (s_tail == s_head) return false;
    uint8_t event = s_events[s_tail].rawAndUp;
    modifiers = s_events[s_tail].modifiers;
    controller = s_events[s_tail].source == kController;
    s_tail = (uint8_t)((s_tail + 1) & 31);
    rawKey = (uint8_t)(event & 0x7f);
    down = (event & 0x80) == 0;
    return true;
}

void vetteInputFlushKeys(uint16_t whichMask, uint16_t stopMask)
{
    // Key events only: keyDown (3) and keyUp (4) bits of the Mac event masks.
    Disable();
    uint8_t kept = s_tail;
    uint8_t i = s_tail;
    bool stopped = false;
    for (; i != s_head; i = (uint8_t)((i + 1) & 31)) {
        uint16_t bit = (uint16_t)((s_events[i].rawAndUp & 0x80) ? 1u << 4 : 1u << 3);
        if (stopMask & bit) stopped = true;
        if (!stopped && (whichMask & bit)) continue;
        s_events[kept].rawAndUp = s_events[i].rawAndUp;
        s_events[kept].source = s_events[i].source;
        s_events[kept].modifiers = s_events[i].modifiers;
        kept = (uint8_t)((kept + 1) & 31);
    }
    s_head = kept;
    Enable();
}

bool vetteInputKeyDown(uint8_t rawKey)
{
    if (rawKey >= 128) return false;
#ifdef VETTE_INPUT_PROBE_RAW_KEY
    if (rawKey == VETTE_INPUT_PROBE_RAW_KEY) return true;
#endif
    return s_keyDown[rawKey] != 0;
}

uint16_t vetteInputModifiers()
{
    return currentModifiers();
}

void vetteInputInjectProbeKey(uint8_t rawKey, bool down)
{
    if (rawKey >= 128) return;
    Disable();
    recordKey(rawKey, down, kKeyboard);
    Enable();
}
