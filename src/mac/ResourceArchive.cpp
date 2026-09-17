#include "ResourceArchive.h"

static uint16_t be16(const uint8_t* p)
{
    return (uint16_t)(((uint16_t)p[0] << 8) | p[1]);
}

static uint32_t be32(const uint8_t* p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16)
         | ((uint32_t)p[2] << 8) | p[3];
}

bool ResourceArchive::open(const uint8_t* bytes, uint32_t size)
{
    m_bytes = 0; m_size = 0; m_directory = 0; m_count = 0; m_forks = 0;
    if (!bytes || size < 16 || be32(bytes) != 0x56525331UL || be16(bytes + 4) != 1)
        return false;
    uint16_t forks = be16(bytes + 6);
    uint32_t count = be32(bytes + 8);
    uint32_t directory = be32(bytes + 12);
    if (directory > size || count > 0x0aaaaaaaUL || count * 24 > size - directory)
        return false;
    m_bytes = bytes; m_size = size; m_directory = directory;
    m_count = count; m_forks = forks;
    Item check;
    for (uint32_t i = 0; i < count; ++i)
        if (!item(i, check) || check.fork >= forks) {
            m_bytes = 0; m_count = 0; m_forks = 0;
            return false;
        }
    return true;
}

bool ResourceArchive::item(uint32_t index, Item& out) const
{
    if (!m_bytes || index >= m_count) return false;
    const uint8_t* p = m_bytes + m_directory + index * 24;
    uint32_t nameOffset = be32(p + 12);
    uint32_t dataOffset = be32(p + 16);
    uint32_t dataSize = be32(p + 20);
    uint8_t nameLength = p[9];
    if ((nameLength && (nameOffset > m_size || nameLength > m_size - nameOffset))
        || dataOffset > m_size || dataSize > m_size - dataOffset)
        return false;
    out.fork = be16(p);
    out.id = (int16_t)be16(p + 2);
    out.type = be32(p + 4);
    out.attrs = p[8];
    out.name = nameLength ? m_bytes + nameOffset : 0;
    out.nameLength = nameLength;
    out.data = m_bytes + dataOffset;
    out.size = dataSize;
    return true;
}

bool ResourceArchive::find(uint16_t fork, uint32_t type, int16_t id, Item& out) const
{
    for (uint32_t i = 0; i < m_count; ++i) {
        Item candidate;
        if (!item(i, candidate)) return false;
        if (candidate.fork == fork && candidate.type == type && candidate.id == id) {
            out = candidate;
            return true;
        }
    }
    return false;
}
