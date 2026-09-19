#ifndef VETTE_MAC_INPUT_H
#define VETTE_MAC_INPUT_H

bool vetteInputInitialize();
void vetteInputShutdown();
bool vetteInputPopKey(uint8_t& rawKey, bool& down, uint16_t& modifiers);
bool vetteInputKeyDown(uint8_t rawKey);
uint16_t vetteInputModifiers();

#endif
