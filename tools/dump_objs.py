#!/usr/bin/env python3
"""Validate and summarize VETTE!.Data OBJS model records."""

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hfs_extract import resources  # noqa: E402


def object_records(path: Path):
    records = resources(path.read_bytes()).get("OBJS", [])
    if len(records) != 160:
        raise ValueError(f"{path} has {len(records)} OBJS resources, expected 160")
    return records


def decode(body: bytes):
    if len(body) & 1:
        raise ValueError(f"odd OBJS byte size {len(body)}")
    words = struct.unpack(f">{len(body) // 2}h", body)
    if not words or words[0] != len(words) - 1:
        raise ValueError("first word is not the exact following-word count")

    pos = 1
    coordinate_last = words[pos]
    pos += 1
    coordinate_count = coordinate_last + 1
    if coordinate_count <= 0:
        raise ValueError(f"invalid coordinate last index {coordinate_last}")
    coordinates = [words[pos + i * 4:pos + (i + 1) * 4]
                   for i in range(coordinate_count)]
    pos += coordinate_count * 4

    record_count = words[pos] + 1
    pos += 1
    variable_records = []
    for _ in range(record_count):
        if pos + 2 >= len(words):
            raise ValueError("truncated variable-record header")
        payload_last = words[pos + 2]
        record_words = payload_last + 5
        if payload_last < 0 or pos + record_words > len(words):
            raise ValueError(f"invalid variable-record last index {payload_last}")
        variable_records.append(words[pos:pos + record_words])
        pos += record_words

    group_count = words[pos] + 1
    pos += 1
    groups = []
    for _ in range(group_count):
        reference_count = words[pos] + 1
        pos += 1
        refs = words[pos:pos + reference_count]
        pos += reference_count
        if len(refs) != reference_count:
            raise ValueError("truncated record-reference group")
        if any(ref < 0 or ref >= record_count for ref in refs):
            raise ValueError(f"record reference outside 0..{record_count - 1}")
        groups.append(refs)

    selectors = words[pos:pos + 8]
    pos += 8
    if len(selectors) != 8:
        raise ValueError("truncated eight-selector tail")
    if any(selector < 0 or selector >= group_count for selector in selectors):
        raise ValueError(f"group selector outside 0..{group_count - 1}")
    if pos != len(words):
        raise ValueError(f"parser ended at word {pos}, record ends at {len(words)}")

    return {
        "words": words,
        "coordinates": coordinates,
        # Initialize+$068A stores coordinate_last-4 in the runtime descriptor.
        "runtime_coordinate_last": coordinate_last - 4,
        "variable_records": variable_records,
        "groups": groups,
        "selectors": selectors,
    }


def runtime_lod_tables(globals_body: bytes, a5: int, records):
    """Find initialized model-LOD tables in a captured 31,272-byte A5 world."""
    if len(globals_body) != 31272:
        raise ValueError(
            f"runtime globals are {len(globals_body)} bytes, expected 31272")

    names = {rid: name for rid, name, _ in records}
    id_pos = len(globals_body) - 0x7614
    descriptor_pos = len(globals_body) - 0x5e06
    descriptors = {}
    index = 0
    while True:
        rid = struct.unpack_from(">h", globals_body, id_pos + index * 2)[0]
        if rid == -1:
            break
        descriptor = struct.unpack_from(
            ">I", globals_body, descriptor_pos + index * 4)[0]
        descriptors[descriptor] = (rid, names.get(rid, "?"))
        index += 1

    tables = []
    for pos in range(0, len(globals_body) - 24, 2):
        entries = []
        cursor = pos
        previous_threshold = -1
        while cursor + 12 <= len(globals_body):
            threshold, flags, shared, model = struct.unpack_from(
                ">hHII", globals_body, cursor)
            if model not in descriptors or shared == 0 or flags > 0xff:
                break
            entries.append((threshold, flags, shared, model))
            cursor += 12
            if threshold == -1:
                break
            if threshold < 0 or threshold <= previous_threshold:
                break
            previous_threshold = threshold

        if len(entries) < 2 or entries[-1][0] != -1:
            continue

        # Do not report suffixes of a table whose preceding 12-byte record is
        # itself a valid initialized model entry.
        if pos >= 12:
            _, prior_flags, prior_shared, prior_model = struct.unpack_from(
                ">hHII", globals_body, pos - 12)
            if (prior_model in descriptors and prior_shared != 0
                    and prior_flags <= 0xff):
                continue
        tables.append((a5 - len(globals_body) + pos, entries, descriptors))
    return tables


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's OBJS resources to be byte-identical")
    parser.add_argument("--runtime-globals", type=Path,
                        help="scan a 31,272-byte initialized A5-world capture for LOD tables")
    parser.add_argument("--runtime-a5", type=lambda value: int(value, 0),
                        help="A5 address belonging to --runtime-globals")
    args = parser.parse_args()

    if (args.runtime_globals is None) != (args.runtime_a5 is None):
        parser.error("--runtime-globals and --runtime-a5 must be supplied together")

    records = object_records(args.resource_fork)
    if args.compare:
        other = object_records(args.compare)
        left = {(rid, name): body for rid, name, body in records}
        right = {(rid, name): body for rid, name, body in other}
        if left != right:
            raise SystemExit("OBJS resources differ between the two forks")
        print(f"PASS: all 160 OBJS resources are byte-identical in "
              f"{args.resource_fork} and {args.compare}")

    print("     id name                 bytes coords runtime_last records groups refs selectors")
    for rid, name, body in records:
        model = decode(body)
        selectors = ",".join(str(value) for value in model["selectors"])
        print(f"{rid:>7} {name:<20} {len(body):>5} "
              f"{len(model['coordinates']):>6} "
              f"{model['runtime_coordinate_last']:>12} "
              f"{len(model['variable_records']):>7} "
              f"{len(model['groups']):>6} "
              f"{sum(len(group) for group in model['groups']):>4} {selectors}")

    if args.runtime_globals:
        print("\nruntime LOD tables:")
        for address, entries, descriptors in runtime_lod_tables(
                args.runtime_globals.read_bytes(), args.runtime_a5, records):
            rendered = []
            for threshold, flags, shared, model in entries:
                rid, name = descriptors[model]
                rendered.append(
                    f"{threshold}:{name}({rid}) flags=0x{flags:04x} "
                    f"shared=0x{shared:08x}")
            print(f"0x{address:08x}: " + " -> ".join(rendered))


if __name__ == "__main__":
    main()
