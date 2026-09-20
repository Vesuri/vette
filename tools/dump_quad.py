#!/usr/bin/env python3
"""Validate and summarize VETTE!.Data QUAD map-cell descriptor records."""

import argparse
import csv
import re
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


def runtime_responses(raw, a5, bounds):
    """Decode special rectangle pointers and their above-A5 jump-table handlers."""
    base = a5 - len(raw)
    offset = lambda address: address - base
    bounds_pointers = [
        struct.unpack_from(">I", raw, offset(a5 - 0x424e) + selector * 4)[0]
        for selector in range(108)
    ]
    locations = {}
    for selector, (pointer, rectangles) in enumerate(zip(bounds_pointers, bounds)):
        for ordinal in range(len(rectangles)):
            locations.setdefault(pointer + ordinal * 8, []).append((selector, ordinal))

    pointer_table = offset(a5 - 0x30c0)
    handler_table = offset(a5 - 0x300c)
    responses = []
    index = 0
    while struct.unpack_from(">I", raw, pointer_table + index * 4)[0] != 0xffffffff:
        pointer = struct.unpack_from(">I", raw, pointer_table + index * 4)[0]
        handler = struct.unpack_from(">I", raw, handler_table + index * 4)[0]
        if pointer not in locations:
            raise ValueError(f"response {index} does not point at a collision rectangle")
        if handler < a5 + 34 or (handler - a5 - 34) % 8:
            raise ValueError(f"response {index} handler is not an above-A5 jump entry")
        responses.append((locations[pointer], (handler - a5 - 34) // 8))
        index += 1
    return responses


def entrypoint_owners(path):
    """Map a jump-table export number to its segment and CODE offset."""
    owners = {}
    with path.open(newline="") as source:
        for row in csv.reader(source):
            if len(row) < 4:
                continue
            match = re.search(r"jump-table export (\d+)", row[3])
            if match:
                owners[int(match.group(1))] = (int(row[0]), int(row[1], 0), row[2])
    return owners


def runtime_dispatch(raw, a5, records):
    """Decode the QUAD command/factory dispatch table at A5-$409E."""
    used = set()
    for record in records:
        for key in ("setup_words", "object_words"):
            words = record[key]
            # Descriptor 191's setup list is not command-aligned.  Do not invent
            # a grammar for its trailing words; all ordinary lists are quartets.
            if len(words) % 4:
                continue
            used.update(words[pos] for pos in range(0, len(words), 4))
    if not used or min(used) < 0:
        raise ValueError("QUAD dispatch indices are missing or negative")

    count = max(used) + 1
    base = a5 - len(raw)
    table = a5 - 0x409e - base
    exports = []
    for index in range(count):
        pointer = struct.unpack_from(">I", raw, table + index * 4)[0]
        if pointer < a5 + 34 or (pointer - a5 - 34) % 8:
            raise ValueError(f"dispatch {index} is not an above-A5 jump entry")
        exports.append((pointer - a5 - 34) // 8)
    return used, exports


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's QUAD resource to be byte-identical")
    parser.add_argument("--runtime-globals", type=Path,
                        help="captured initialized below-A5 globals")
    parser.add_argument("--runtime-a5", type=lambda value: int(value, 0),
                        help="A5 address belonging to --runtime-globals")
    parser.add_argument("--entrypoints", type=Path,
                        help="entrypoints.csv used to classify runtime dispatch exports")
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
        responses = runtime_responses(args.runtime_globals.read_bytes(), args.runtime_a5, bounds)
        print(f"runtime collision responses: rectangles={len(responses)} "
              f"handlers={len({handler for _locations, handler in responses})} "
              f"jump-exports={sorted({handler for _locations, handler in responses})}")
        for index, (locations, handler) in enumerate(responses):
            where = ",".join(f"{selector}:{ordinal}" for selector, ordinal in locations)
            print(f"  response={index:>2} bounds={where:<6} export={handler}")

        used, dispatch = runtime_dispatch(args.runtime_globals.read_bytes(),
                                          args.runtime_a5, records)
        print(f"runtime QUAD dispatch: entries={len(dispatch)} used={len(used)} "
              f"unused={len(dispatch) - len(used)} unique-exports={len(set(dispatch))}")
        if args.entrypoints:
            owners = entrypoint_owners(args.entrypoints)
            unknown = sorted(set(dispatch) - set(owners))
            if unknown:
                raise ValueError(f"dispatch exports absent from entrypoint map: {unknown}")
            by_segment = Counter(owners[export][0] for export in dispatch)
            unique_by_segment = Counter(owners[export][0] for export in set(dispatch))
            print("runtime QUAD dispatch by segment: "
                  + " ".join(f"CODE-{segment}={by_segment[segment]} "
                             f"({unique_by_segment[segment]} unique)"
                             for segment in sorted(by_segment)))
            fred_exports = {export for export, owner in owners.items() if owner[0] == 7}
            used_fred = set(dispatch) & fred_exports
            print(f"runtime QUAD dispatch FRED coverage: {len(used_fred)}/{len(fred_exports)} "
                  f"exports; absent={sorted(fred_exports - used_fred)}")


if __name__ == "__main__":
    main()
