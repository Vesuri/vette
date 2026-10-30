#ifndef VETTE_MAC_INPUT_H
#define VETTE_MAC_INPUT_H

bool vetteInputInitialize();
void vetteInputShutdown();
// From the VBI: map the port 1 joystick or CD32 pad onto keys.
void vetteInputPollController();
// Before each driving KeyMap refresh, which the original shift latch scans.
void vetteInputDrivingScan();
bool vetteInputPopKey(uint8_t& rawKey, bool& down, uint16_t& modifiers);
bool vetteInputKeyDown(uint8_t rawKey);
uint16_t vetteInputModifiers();
void vetteInputInjectProbeKey(uint8_t rawKey, bool down);

#endif
