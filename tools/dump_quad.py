#!/usr/bin/env python3
"""Validate and summarize VETTE!.Data QUAD map-cell descriptor records."""

import argparse
import struct
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hfs_extract import resources  # noqa: E402


def quad_resource(path: Path):
    records = resources(path.read_bytes()).get("QUAD", [])
    if len(records) != 1:
        raise ValueError(f"{path} has {len(records)} QUAD resources, expected 1")
    return records[0]


def decode(body: bytes):
    if len(body) & 1:
        raise ValueError(f"odd QUAD byte size {len(body)}")
    words = struct.unpack(f">{len(body) // 2}h", body)
    if not words or words[0] != len(words) - 1:
        raise ValueError("first word is not the exact following-word count")

    pos = 1
    records = []
    while words[pos] != -1:
        word_lists = []
        for _ in range(2):
            values = []
            while words[pos] != -1:
                values.append(words[pos])
                pos += 1
            pos += 1
            word_lists.append(values)
        if len(word_lists[0]) < 2:
            raise ValueError("QUAD first list has no two-word header")
        first_commands = word_lists[0][2:]
        records.append({
            "header": tuple(word_lists[0][:2]),
            "setup_words": tuple(first_commands),
            "object_words": tuple(word_lists[1]),
            "render_aligned": not (len(first_commands) % 4 or len(word_lists[1]) % 4),
        })

    if words[pos:] != (-1, -1, -1):
        raise ValueError(f"unexpected QUAD trailer {words[pos:]}")
    return records


def road_handler(header):
    """Return the control-flow class selected by Traffic+$3D7C."""
    return {
        0: "flat",
        1: "u/v split",
        2: "v/8",
        3: "diagonal 2/6",
        4: "(u-256)/8",
        6: "(2048-u)/8",
        7: "diagonal 4/8",
        8: "(1792-v)/8",
    }.get(header, "diagonal 6/8")


def runtime_bounds(raw, a5):
    """Decode the 108 header-1 bounds lists initialized below A5."""
    base = a5 - len(raw)

    def offset(address):
        result = address - base
        if result < 0 or result >= len(raw):
            raise ValueError(f"runtime pointer {address:#x} is outside captured globals")
        return result

    table = offset(a5 - 0x424e)
    lists = []
    for selector in range(108):
        pointer = struct.unpack_from(">I", raw, table + selector * 4)[0]
        pos = offset(pointer)
        rectangles = []
        while struct.unpack_from(">h", raw, pos)[0] != -1:
            rectangles.append(struct.unpack_from(">4h", raw, pos))
            pos += 8
        lists.append(tuple(rectangles))
    return lists


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's QUAD resource to be byte-identical")
    parser.add_argument("--runtime-globals", type=Path,
                        help="captured initialized below-A5 globals")
    parser.add_argument("--runtime-a5", type=lambda value: int(value, 0),
                        help="A5 address belonging to --runtime-globals")
    args = parser.parse_args()
    if (args.runtime_globals is None) != (args.runtime_a5 is None):
        parser.error("--runtime-globals and --runtime-a5 must be supplied together")

    rid, name, body = quad_resource(args.resource_fork)
    if args.compare:
        other = quad_resource(args.compare)
        if (rid, name, body) != other:
            raise SystemExit("QUAD resource differs between the two forks")
        print(f"PASS: QUAD is byte-identical in {args.resource_fork} and {args.compare}")

    records = decode(body)
    print(f"id={rid} name={name!r} bytes={len(body)} records={len(records)}")
    print("index header0 header1 setup_words object_words aligned road-handler")
    for index, record in enumerate(records):
        print(f"{index:>5} {record['header'][0]:>7} {record['header'][1]:>7} "
              f"{len(record['setup_words']):>11} "
              f"{len(record['object_words']):>12} "
              f"{'yes' if record['render_aligned'] else 'NO':>7} "
              f"{road_handler(record['header'][0])}")

    if args.runtime_globals:
        bounds = runtime_bounds(args.runtime_globals.read_bytes(), args.runtime_a5)
        counts = Counter(len(rectangles) for rectangles in bounds)
        inverted = sum(1 for rectangles in bounds for low_v, low_u, high_v, high_u in rectangles
                       if low_v > high_v or low_u > high_u)
        selectors = {record["header"][1] for record in records}
        if not selectors <= set(range(len(bounds))):
            raise ValueError(f"QUAD header-1 selector outside 0..107: {max(selectors)}")
        print(f"runtime collision bounds: selectors={len(bounds)} "
              f"used={len(selectors)} rectangles={sum(map(len, bounds))} "
              f"inverted={inverted} "
              f"count-distribution={dict(sorted(counts.items()))}")


if __name__ == "__main__":
    main()
