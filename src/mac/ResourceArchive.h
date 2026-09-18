#ifndef VETTE_RESOURCE_ARCHIVE_H
#define VETTE_RESOURCE_ARCHIVE_H

/* Read-only view of tools/rsrc_pack.py's big-endian, pointer-free archive. */
class ResourceArchive {
public:
    struct Item {
        uint16_t fork;
        int16_t id;
        uint32_t type;
        uint8_t attrs;
        const uint8_t* name;
        uint8_t nameLength;
        const uint8_t* data;
        uint32_t size;
    };

    bool open(const uint8_t* bytes, uint32_t size);
    uint16_t forkCount() const { return m_forks; }
    uint32_t resourceCount() const { return m_count; }
    bool item(uint32_t index, Item& out) const;
    bool find(uint16_t fork, uint32_t type, int16_t id, Item& out,
              uint32_t* index = 0) const;

private:
    const uint8_t* m_bytes = 0;
    uint32_t m_size = 0;
    uint32_t m_directory = 0;
    uint32_t m_count = 0;
    uint16_t m_forks = 0;
};

#endif
