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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's OBJS resources to be byte-identical")
    args = parser.parse_args()

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


if __name__ == "__main__":
    main()
