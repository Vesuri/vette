#!/usr/bin/env python3
"""Validate and summarize the five VETTE!.Data MAPS resources."""

import argparse
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hfs_extract import resources  # noqa: E402


WIDTH = 52
HEIGHT = 47


def maps_resources(path: Path):
    return resources(path.read_bytes()).get("MAPS", [])


def words(body: bytes):
    if len(body) & 1:
        raise ValueError(f"odd MAPS byte size {len(body)}")
    return struct.unpack(f">{len(body) // 2}H", body)


def signed_word(value):
    return value if value < 0x8000 else value - 0x10000


def road_fields(value):
    """Return the projections used by the shipped MAPS-word consumers."""
    return {
        "upper": (value & 0xE000) >> 13,
        "middle": (value & 0x1C00) >> 10,
        "variant": (value & 0x0300) >> 8,
        "fine": value & 0x00FF,
        "draw_index": ((value & 0xE000) >> 13) + ((value & 0x0300) >> 5),
        "vertical": signed_word((value * -224) & 0xFFFF),
    }


def decode(records):
    by_id = {rid: (name, body) for rid, name, body in records}
    if set(by_id) != {1000, 1100, 3333, 4444, 4445}:
        raise ValueError(f"unexpected MAPS IDs {sorted(by_id)}")

    result = {}
    for rid in (1000, 1100):
        name, body = by_id[rid]
        data = words(body)
        if data[0] != len(data) - 1:
            raise ValueError(f"MAPS {rid}: bad following-word count {data[0]}")
        cells = tuple(zip(data[1::2], data[2::2]))
        if len(cells) != WIDTH * HEIGHT:
            raise ValueError(f"MAPS {rid}: expected {WIDTH * HEIGHT} cells")
        result[rid] = (name, cells)

    name, body = by_id[3333]
    nav = tuple(zip(words(body)[0::2], words(body)[1::2]))
    if len(nav) != WIDTH * HEIGHT:
        raise ValueError("MAPS 3333: expected a 52x47 grid of two-word cells")
    result[3333] = (name, nav)

    for rid, height in ((4444, 47), (4445, 46)):
        name, body = by_id[rid]
        if len(body) != WIDTH * height * 2:
            raise ValueError(f"MAPS {rid}: expected a {WIDTH}x{height} byte-pair grid")
        result[rid] = (name, tuple(zip(body[0::2], body[1::2])))

    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's MAPS set to be byte-identical")
    args = parser.parse_args()

    records = maps_resources(args.resource_fork)
    if args.compare:
        other = maps_resources(args.compare)
        if records != other:
            raise SystemExit("MAPS resources differ between the two forks")
        print(f"PASS: MAPS are byte-identical in {args.resource_fork} and {args.compare}")

    decoded = decode(records)
    for rid in (1000, 1100):
        name, cells = decoded[rid]
        quad = Counter(cell[0] for cell in cells)
        packed = Counter(cell[1] for cell in cells)
        print(f"id={rid} name={name!r} grid=52x47 cells={len(cells)} "
              f"QUAD={min(quad)}..{max(quad)} ({len(quad)} values) "
              f"packed-road-words={len(packed)}")
        decoded_fields = [road_fields(value) for value in packed]
        for field in ("upper", "middle", "variant", "fine", "draw_index", "vertical"):
            values = sorted({decoded[field] for decoded in decoded_fields})
            print(f"  {field}={','.join(map(str, values))}")

    name, cells = decoded[3333]
    print(f"id=3333 name={name!r} grid=52x47 cells={len(cells)} words/cell=2")
    for rid, height in ((4444, 47), (4445, 46)):
        name, cells = decoded[rid]
        print(f"id={rid} name={name!r} grid=52x{height} cells={len(cells)} bytes/cell=2")


if __name__ == "__main__":
    main()
