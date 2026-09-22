#!/usr/bin/env python3
"""NDIF (Disk Copy 6.x) compressed disk image -> raw sector image.

Why this exists: macOS 26 / hdiutil no longer recognise NDIF at all
("image not recognised"), `unar` does not parse it, and the shipped
`VETTE!.img` is NDIF.  Every emulator we might use for the reference loop
wants a raw image, so this is the one conversion nothing off the shelf does.

The block map lives in the image's RESOURCE FORK, as `bcem` 128.  The data
fork holds the chunk payloads back to back.  Chunk types seen here:
  0x02  stored raw
  0x83  ADC (Apple Data Compression) - byte-oriented LZSS
Sectors past the last mapped chunk are free space and are zero filled.
[DERIVED] the covered sector count agrees with the volume's own drFreeBks.

[ASSUMED] the uint32 at bcem+80 is a whole-image checksum.  `vers` labels it
"CRC" and this file reports it, but THE ALGORITHM IS UNIDENTIFIED - the Disk
Copy add-then-rotate-right, its byte/long/little-endian variants and CRC-32
all disagree with the recorded $0580C874.  ** A MISMATCH HERE IS THEREFORE NOT
EVIDENCE OF A BAD CONVERSION. ** Validate structurally instead, with
hfs_extract.py: if the MDB, both B-trees, the catalog, every file's extents and
the applications' resource maps all parse, the chunks decoded correctly.  Five
agreeing structures beat one checksum whose definition we do not have.
(Note that a whole zero sector is a no-op for the add-then-ROR family, because
256 rotations is the identity on 32 bits - so that family cannot distinguish
our zero fill from anything else in the free space either.)
"""
import struct, sys

def adc_decompress(src, want):
    """Apple Data Compression.  Three opcodes, distinguished by the top bits."""
    out = bytearray()
    i = 0
    while i < len(src) and len(out) < want:
        b = src[i]; i += 1
        if b & 0x80:                      # literal run
            n = (b & 0x7f) + 1
            out += src[i:i + n]; i += n
        elif b & 0x40:                    # long match: 3-byte opcode
            n = (b & 0x3f) + 4
            off = struct.unpack('>H', src[i:i + 2])[0] + 1; i += 2
            for _ in range(n): out.append(out[-off])
        else:                             # short match: 2-byte opcode
            n = ((b >> 2) & 0x0f) + 3
            off = ((b & 3) << 8 | src[i]) + 1; i += 1
            for _ in range(n): out.append(out[-off])
    return bytes(out)

def resource(rsrc, want_type, want_id):
    dOff, mOff, dLen, mLen = struct.unpack('>IIII', rsrc[:16])
    m = rsrc[mOff:mOff + mLen]
    typeOff, = struct.unpack('>H', m[24:26])
    tl = m[typeOff:]
    ntypes, = struct.unpack('>h', tl[:2])
    for i in range(ntypes + 1):
        t = tl[2 + i * 8:10 + i * 8]
        typ = t[:4].decode('mac-roman')
        cnt, = struct.unpack('>h', t[4:6])
        ref, = struct.unpack('>H', t[6:8])
        for j in range(cnt + 1):
            e = tl[ref + j * 12:ref + j * 12 + 12]
            rid, = struct.unpack('>h', e[:2])
            doff = struct.unpack('>I', b'\0' + e[5:8])[0]
            if typ == want_type and rid == want_id:
                n, = struct.unpack('>I', rsrc[dOff + doff:dOff + doff + 4])
                return rsrc[dOff + doff + 4:dOff + doff + 4 + n]
    raise SystemExit("no %r %d resource in the resource fork" % (want_type, want_id))

def dc_checksum(data):
    """The Disk Copy add-then-rotate-right checksum over big-endian 16-bit
    words.  Reported for information only - see the module docstring: this does
    NOT reproduce the value NDIF records, so do not gate anything on it."""
    s = 0
    for (w,) in struct.iter_unpack('>H', data):
        s = (s + w) & 0xffffffff
        s = ((s >> 1) | ((s & 1) << 31)) & 0xffffffff
    return s

def named_resource_fork(src):
    try:
        return open(src + '/..namedfork/rsrc', 'rb').read()
    except OSError:
        raise SystemExit("%s has no resource fork - the bcem block map is in it, "
                         "so a copy that lost the fork cannot be converted" % src)


def decode_ndif(data, rsrc, verbose=True):
    bcem = resource(rsrc, 'bcem', 128)

    nl = bcem[4]
    name = bcem[5:5 + nl].decode('mac-roman')
    sectors, = struct.unpack('>I', bcem[68:72])
    crc, = struct.unpack('>I', bcem[80:84])
    nchunks, = struct.unpack('>I', bcem[124:128])
    if verbose:
        print("volume %r  %d sectors (%d bytes)  checksum $%08X  %d map entries"
              % (name, sectors, sectors * 512, crc, nchunks))

    out = bytearray(sectors * 512)
    covered = 0
    for i in range(nchunks):
        w0, off, ln = struct.unpack('>III', bcem[128 + i * 12:140 + i * 12])
        start, typ = w0 >> 8, w0 & 0xff
        if ln == 0:
            continue                      # free-space / terminator entry
        if typ == 0x02:
            blk = data[off:off + ln]
        elif typ == 0x83:
            blk = adc_decompress(data[off:off + ln], 512 * 512)
        else:
            raise SystemExit("chunk %d: unhandled type 0x%02x at sector %d - "
                             "make this LOUD rather than emitting a hole" % (i, typ, start))
        out[start * 512:start * 512 + len(blk)] = blk
        covered = max(covered, start + len(blk) // 512)
        if verbose:
            print("  chunk %2d  type 0x%02x  sector %6d  %7d -> %7d"
                  % (i, typ, start, ln, len(blk)))

    got = dc_checksum(out)
    if verbose:
        print("covered %d of %d sectors; rest zero filled" % (covered, sectors))
        print("recorded checksum $%08X, add-then-ROR over this image $%08X%s"
              % (crc, got, "" if got == crc else "  (algorithm unidentified -- "
                 "NOT a corruption signal; validate with hfs_extract.py)"))
    return bytes(out)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: ndif2raw.py <image.img> <out.raw>\n"
                         "       (reads <image.img>/..namedfork/rsrc)")
    src, dst = sys.argv[1], sys.argv[2]
    data = open(src, 'rb').read()
    out = decode_ndif(data, named_resource_fork(src))
    open(dst, 'wb').write(out)
    print("wrote %s (%d bytes)" % (dst, len(out)))
    return 0

if __name__ == '__main__':
    sys.exit(main())
