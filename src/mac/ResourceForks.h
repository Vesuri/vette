#ifndef VETTE_RESOURCE_FORKS_H
#define VETTE_RESOURCE_FORKS_H

/*
 * Read-only views of the two original Macintosh resource forks.
 *
 * The release executable contains no game data.  Platform startup reads the
 * raw resource fork of `Color VETTE!` and the raw resource fork of
 * `VETTE!.Data` into Fast RAM, then this class validates their native classic
 * Resource Manager maps and presents one stable, fork-qualified directory.
 */
class ResourceForks {
public:
    static const uint16_t kForkCount = 2;
    static const uint16_t kMaximumResources = 768;

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

    bool open(const uint8_t* application, uint32_t applicationSize,
              const uint8_t* data, uint32_t dataSize);
    void close();
    uint16_t forkCount() const { return m_open ? kForkCount : 0; }
    uint32_t resourceCount() const { return m_count; }
    bool item(uint32_t index, Item& out) const;
    bool find(uint16_t fork, uint32_t type, int16_t id, Item& out,
              uint32_t* index = 0) const;

private:
    bool appendFork(uint16_t fork, const uint8_t* bytes, uint32_t size);
    static bool before(const Item& a, const Item& b);

    Item m_items[kMaximumResources];
    uint16_t m_count = 0;
    bool m_open = false;
};

#endif
