#include <sys/socket.h>

uint16_t htonsCFunc(uint16_t hostShort)
{
    return htons(hostShort);
}

uint32_t htonlCFunc(uint32_t hostInt)
{
    return htons(hostInt);
}