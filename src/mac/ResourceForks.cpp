#include "ResourceForks.h"

static uint16_t resourceBe16(const uint8_t* p)
{
    return (uint16_t)(((uint16_t)p[0] << 8) | p[1]);
}

static uint32_t resourceBe24(const uint8_t* p)
{
    return ((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | p[2];
}

static uint32_t resourceBe32(const uint8_t* p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16)
         | ((uint32_t)p[2] << 8) | p[3];
}

static bool resourceRange(uint32_t offset, uint32_t length, uint32_t size)
{
    return offset <= size && length <= size - offset;
}

void ResourceForks::close()
{
    m_count = 0;
    m_open = false;
}

bool ResourceForks::before(const Item& a, const Item& b)
{
    if (a.fork != b.fork) return a.fork < b.fork;
    if (a.type != b.type) return a.type < b.type;
    return a.id < b.id;
}

bool ResourceForks::appendFork(uint16_t fork, const uint8_t* bytes, uint32_t size)
{
    if (!bytes || size < 16) return false;
    const uint32_t dataOffset = resourceBe32(bytes);
    const uint32_t mapOffset = resourceBe32(bytes + 4);
    const uint32_t dataLength = resourceBe32(bytes + 8);
    const uint32_t mapLength = resourceBe32(bytes + 12);
    if (!resourceRange(dataOffset, dataLength, size)
        || !resourceRange(mapOffset, mapLength, size) || mapLength < 30)
        return false;

    const uint8_t* map = bytes + mapOffset;
    // A resource map begins with a copy of the fork header.  Requiring the
    // offsets and lengths to agree catches wrong files and truncated copies
    // before any game code or hardware takeover is attempted.
    for (uint16_t i = 0; i < 16; ++i)
        if (map[i] != bytes[i]) return false;

    const uint32_t typeListOffset = resourceBe16(map + 24);
    const uint32_t nameListOffset = resourceBe16(map + 26);
    if (!resourceRange(typeListOffset, 2, mapLength)
        || nameListOffset > mapLength)
        return false;
    const uint8_t* typeList = map + typeListOffset;
    uint32_t typeCount = (uint32_t)resourceBe16(typeList) + 1;
    if (!typeCount || typeCount > 4096
        || !resourceRange(typeListOffset + 2, typeCount * 8, mapLength))
        return false;

    for (uint32_t typeIndex = 0; typeIndex < typeCount; ++typeIndex) {
        const uint8_t* typeEntry = typeList + 2 + typeIndex * 8;
        const uint32_t type = resourceBe32(typeEntry);
        const uint32_t referenceCount = (uint32_t)resourceBe16(typeEntry + 4) + 1;
        const uint32_t referenceOffset = resourceBe16(typeEntry + 6);
        if (!referenceCount || referenceCount > kMaximumResources
            || referenceOffset > mapLength - typeListOffset
            || !resourceRange(typeListOffset + referenceOffset,
                              referenceCount * 12, mapLength))
            return false;
        const uint8_t* references = typeList + referenceOffset;

        for (uint32_t reference = 0; reference < referenceCount; ++reference) {
            if (m_count == kMaximumResources) return false;
            const uint8_t* entry = references + reference * 12;
            const uint32_t resourceOffset = resourceBe24(entry + 5);
            if (!resourceRange(resourceOffset, 4, dataLength)) return false;
            const uint8_t* lengthWord = bytes + dataOffset + resourceOffset;
            const uint32_t resourceLength = resourceBe32(lengthWord);
            if (!resourceRange(resourceOffset + 4, resourceLength, dataLength))
                return false;

            const int16_t nameOffset = (int16_t)resourceBe16(entry + 2);
            const uint8_t* name = 0;
            uint8_t nameLength = 0;
            if (nameOffset != -1) {
                const uint32_t namePosition = nameListOffset + (uint16_t)nameOffset;
                if (!resourceRange(namePosition, 1, mapLength)) return false;
                nameLength = map[namePosition];
                if (!resourceRange(namePosition + 1, nameLength, mapLength)) return false;
                name = map + namePosition + 1;
            }

            Item& item = m_items[m_count++];
            item.fork = fork;
            item.id = (int16_t)resourceBe16(entry);
            item.type = type;
            item.attrs = entry[4];
            item.name = name;
            item.nameLength = nameLength;
            item.data = lengthWord + 4;
            item.size = resourceLength;
        }
    }
    return true;
}

bool ResourceForks::open(const uint8_t* application, uint32_t applicationSize,
                         const uint8_t* data, uint32_t dataSize)
{
    close();
    if (!appendFork(0, application, applicationSize)
        || !appendFork(1, data, dataSize)) {
        close();
        return false;
    }

    // Native resource maps are normally ordered, but that ordering is not a
    // Resource Manager contract.  Sort our small pointer-only directory once
    // so lookup remains logarithmic without rewriting either original fork.
    for (uint16_t i = 1; i < m_count; ++i) {
        Item item = m_items[i];
        uint16_t j = i;
        while (j && before(item, m_items[j - 1])) {
            m_items[j] = m_items[j - 1];
            --j;
        }
        m_items[j] = item;
    }
    for (uint16_t i = 1; i < m_count; ++i)
        if (!before(m_items[i - 1], m_items[i])) {
            close();
            return false;
        }
    m_open = true;
    return true;
}

bool ResourceForks::item(uint32_t index, Item& out) const
{
    if (!m_open || index >= m_count) return false;
    out = m_items[index];
    return true;
}

bool ResourceForks::find(uint16_t fork, uint32_t type, int16_t id, Item& out,
                         uint32_t* index) const
{
    if (!m_open) return false;
    Item wanted = {};
    wanted.fork = fork;
    wanted.type = type;
    wanted.id = id;
    uint16_t first = 0, last = m_count;
    while (first < last) {
        const uint16_t middle = (uint16_t)(first + ((last - first) >> 1));
        if (before(m_items[middle], wanted)) first = (uint16_t)(middle + 1);
        else last = middle;
    }
    if (first >= m_count) return false;
    const Item& found = m_items[first];
    if (found.fork != fork || found.type != type || found.id != id) return false;
    out = found;
    if (index) *index = first;
    return true;
}
