#include <proto/exec.h>

#if defined(VETTE_GAME_GEOMETRY) || defined(VETTE_GAME_KERNEL_VERIFY)
// The executable profiler only records PCs in its first code hunk. Keep
// diagnostic copies there as zero-filled storage; original bytes still come
// exclusively from the user's disk-loaded CODE resources.
#ifdef VETTE_CODE_PROFILE
#define KERNEL_POOL(name, words) \
    extern uint16_t name[words]; \
    asm(".pushsection .text." #name ",\"ax\"\n.balign 2\n.global " #name "\n" #name ":\n.space " #words "*2\n.popsection\n");
#else
#define KERNEL_POOL(name, words) uint16_t name[words];
#endif
extern "C" {
void vetteVertexTransform();
void vetteVertexDispatch();
void vetteVertexPlanar();
KERNEL_POOL(vetteVertexPassOriginal, 361)
KERNEL_POOL(vetteVertexPassFast, 361)
void vetteGeometryTransform();
void vettePointTransform();
// These contain original instructions only after loading the user's CODE.
KERNEL_POOL(vetteGeometryOriginal, 51)
KERNEL_POOL(vettePointOriginal, 57)
static uint16_t vertexOriginal[52];
#ifdef VETTE_GAME_KERNEL_VERIFY
bool vetteCheckGameKernels(void (*vertex)(), void (*geometry)(), void (*point)());
#endif
}
static void copyKernel(void* destination, const void* source, uint16_t count)
{
    uint8_t* out = (uint8_t*)destination;
    const uint8_t* in = (const uint8_t*)source;
    while (count--) *out++ = *in++;
}
// CRC-32 guards the complete replaced kernels, not just their entry words.
static uint32_t kernelCRC(const uint8_t* p, uint16_t count)
{
    uint32_t crc = ~0UL;
    while (count--) {
        crc ^= *p++;
        for (uint16_t bit = 0; bit < 8; ++bit)
            crc = (crc >> 1) ^ ((crc & 1) ? 0xedb88320UL : 0);
    }
    return ~crc;
}
static void absoluteJump(uint8_t* p, void (*entry)(), bool call)
{
    *(uint16_t*)p = call ? 0x4eb9 : 0x4ef9;
    // Even alignment is sufficient for the original 68000 format.
    uint32_t target = (uint32_t)entry;
    *(uint16_t*)(p + 2) = (uint16_t)(target >> 16);
    *(uint16_t*)(p + 4) = (uint16_t)target;
}
extern "C" bool vetteInstallGameKernels(uint8_t* main)
{
    if (kernelCRC(main + 0x50fc, 722) != 0xacf4c309UL
        || kernelCRC(main + 0x5102, 102) != 0xe7890361UL
        || kernelCRC(main + 0x4ca2, 100) != 0x01bbfa83UL
        || kernelCRC(main + 0x4bbe, 114) != 0x468d0f70UL) return false;
    copyKernel(vetteGeometryOriginal, main + 0x4ca2, 100);
    vetteGeometryOriginal[50] = 0x4e75;
    copyKernel(vettePointOriginal, main + 0x4bbe, 114);
    copyKernel(vertexOriginal, main + 0x5102, 102);
    vertexOriginal[51] = 0x4e75;
    // Every relative branch in this guarded routine stays inside the copy.
    // Replace only the matrix product; retain original projection, overflow,
    // clipping, and cached-coordinate paths verbatim at runtime.
    copyKernel(vetteVertexPassOriginal, main + 0x50fc, 722);
    copyKernel(vetteVertexPassFast, main + 0x50fc, 722);
    absoluteJump((uint8_t*)vetteVertexPassFast + 6, vetteVertexPlanar, true);
    vetteVertexPassFast[6] = 0x6000;
    vetteVertexPassFast[7] = 0x5168 - 0x510a;
    CacheClearU();
#ifdef VETTE_GAME_KERNEL_VERIFY
    if (!vetteCheckGameKernels((void (*)())vertexOriginal, (void (*)())vetteGeometryOriginal,
                              (void (*)())vettePointOriginal)) return false;
#endif
#ifdef VETTE_GAME_GEOMETRY
    absoluteJump(main + 0x50fc, vetteVertexDispatch, false);
    absoluteJump(main + 0x4ca2, vetteGeometryTransform, true);
    *(uint16_t*)(main + 0x4ca8) = 0x6000;
    *(uint16_t*)(main + 0x4caa) = 0x4d06 - 0x4caa;
    absoluteJump(main + 0x4bbe, vettePointTransform, false);
#endif
    CacheClearU();
    return true;
}
#endif
