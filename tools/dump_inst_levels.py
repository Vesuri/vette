#!/usr/bin/env python3
"""Report signed PCM ranges for every INST in a packed VRS1 archive."""

import argparse
import struct
from pathlib import Path


HEADER = struct.Struct(">4sHHII")
ENTRY = struct.Struct(">Hh4sBBHIII")


def instruments(path: Path):
    archive = path.read_bytes()
    if len(archive) < HEADER.size:
        raise ValueError("resource archive is shorter than its header")
    magic, version, _, count, directory = HEADER.unpack_from(archive)
    if magic != b"VRS1" or version != 1:
        raise ValueError("not a VRS1 resource archive")
    if directory + count * ENTRY.size > len(archive):
        raise ValueError("resource directory extends past the archive")

    for index in range(count):
        entry = ENTRY.unpack_from(archive, directory + index * ENTRY.size)
        _, rid, kind, _, name_length, _, name_offset, data_offset, data_length = entry
        if kind != b"INST":
            continue
        if name_offset + name_length > len(archive) or data_offset + data_length > len(archive):
            raise ValueError(f"INST {rid} extends past the archive")
        name = archive[name_offset:name_offset + name_length].decode("mac_roman")
        body = archive[data_offset:data_offset + data_length]
        if (len(body) > 8 and body[:4] == b"\0\0\0\0"
                and struct.unpack_from(">H", body, 6)[0] == len(body) - 8):
            body = body[8:]
        yield rid, name, body


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()

    global_peak = 0
    print("   id name               bytes       signed range peak")
    for rid, name, body in instruments(args.archive):
        if not body:
            raise ValueError(f"INST {rid} {name!r} has no PCM data")
        low = min(value - 128 for value in body)
        high = max(value - 128 for value in body)
        peak = max(abs(low), abs(high))
        global_peak = max(global_peak, peak)
        print(f"{rid:5d} {name:<18} {len(body):7d} {low:4d}..{high:3d} {peak:4d}")
    print(f"global absolute peak: {global_peak}")


if __name__ == "__main__":
    main()
