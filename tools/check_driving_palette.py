#!/usr/bin/env python3
"""Derive a System 6 device palette from shipped pltt data and gate a capture."""

import argparse
import struct
from pathlib import Path


HEADER = struct.Struct(">4sHHII")
ENTRY = struct.Struct(">Hh4sBBHIII")
ALLOCATIONS = {
    130: (0, 2, 15, 3, 14, 13, 7, 8, 9, 10, 11, 12, 6, 5, 4, 1),
    131: (0, 9, 3, 2, 15, 14, 13, 12, 4, 11, 6, 10, 7, 8, 5, 1),
    140: (0, 2, 4, 5, 15, 14, 7, 8, 13, 10, 11, 12, 3, 9, 6, 1),
    150: (0, 2, 15, 4, 14, 13, 6, 8, 9, 10, 11, 12, 7, 5, 3, 1),
}


def resource(archive: bytes, kind: bytes, resource_id: int) -> bytes:
    if len(archive) < HEADER.size:
        raise SystemExit("resource archive is truncated")
    magic, version, _, count, directory = HEADER.unpack_from(archive)
    if magic != b"VRS1" or version != 1:
        raise SystemExit("not a VRS1 resource archive")
    for index in range(count):
        entry = ENTRY.unpack_from(archive, directory + index * ENTRY.size)
        _, rid, entry_kind, _, _, _, _, offset, length = entry
        if rid == resource_id and entry_kind == kind:
            if offset + length > len(archive):
                raise SystemExit(f"{kind!r} {resource_id}: payload is truncated")
            return archive[offset:offset + length]
    raise SystemExit(f"missing {kind.decode()} {resource_id}")


def expected_palette(body: bytes, resource_id: int) -> bytes:
    if len(body) < 16 + 16 * 16 or struct.unpack_from(">H", body)[0] != 16:
        raise SystemExit(f"pltt {resource_id}: expected sixteen entries")
    output = bytearray()
    thresholds = (2, 10, 20, 32, 46, 61, 77, 95, 113, 133, 153, 175, 197, 220, 243)

    def gamma_to_ocs(component: int) -> int:
        value = component >> 8
        return sum(value >= threshold for threshold in thresholds)

    for entry_index in ALLOCATIONS[resource_id]:
        offset = 16 + entry_index * 16
        red, green, blue = struct.unpack_from(">HHH", body, offset)
        word = (gamma_to_ocs(red) << 8) | (gamma_to_ocs(green) << 4) | gamma_to_ocs(blue)
        output += word.to_bytes(2, "big")
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("resource_id", type=int, choices=sorted(ALLOCATIONS))
    parser.add_argument("captured_palette", type=Path)
    args = parser.parse_args()
    expected = expected_palette(
        resource(args.archive.read_bytes(), b"pltt", args.resource_id), args.resource_id)
    actual = args.captured_palette.read_bytes()
    if len(actual) != 32:
        raise SystemExit(f"{args.captured_palette}: expected 32 bytes, got {len(actual)}")
    if actual != expected:
        differences = [
            index for index in range(16)
            if actual[index * 2:index * 2 + 2] != expected[index * 2:index * 2 + 2]
        ]
        raise SystemExit(
            f"pltt {args.resource_id}: physical pens differ at {differences}")
    print(
        f"palette gate: PASS: pltt {args.resource_id}, 16/16 physical pens "
        f"match {args.captured_palette}")


if __name__ == "__main__":
    main()
