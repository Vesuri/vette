#ifndef VETTE_MAC_INPUT_H
#define VETTE_MAC_INPUT_H

bool vetteInputInitialize();
void vetteInputShutdown();
// From the VBI: map the port 1 joystick or CD32 pad onto keys.
void vetteInputPollController();
// Before each driving KeyMap refresh, which the original shift latch scans.
void vetteInputDrivingScan();
// The event layer turned the controller's Play into Return to Game: keep P
// up for the game until Play is released.
void vetteInputControllerResumed();
// controller: the port 1 controller, not the keyboard, made this edge.
bool vetteInputPopKey(uint8_t& rawKey, bool& down, uint16_t& modifiers, bool& controller);
bool vetteInputKeyDown(uint8_t rawKey);
uint16_t vetteInputModifiers();
void vetteInputInjectProbeKey(uint8_t rawKey, bool down);

#endif
