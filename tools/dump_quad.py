#!/usr/bin/env python3
"""Validate and summarize VETTE!.Data QUAD map-cell descriptor records."""

import argparse
import struct
import sys
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's QUAD resource to be byte-identical")
    args = parser.parse_args()

    rid, name, body = quad_resource(args.resource_fork)
    if args.compare:
        other = quad_resource(args.compare)
        if (rid, name, body) != other:
            raise SystemExit("QUAD resource differs between the two forks")
        print(f"PASS: QUAD is byte-identical in {args.resource_fork} and {args.compare}")

    records = decode(body)
    print(f"id={rid} name={name!r} bytes={len(body)} records={len(records)}")
    print("index header0 header1 setup_words object_words aligned")
    for index, record in enumerate(records):
        print(f"{index:>5} {record['header'][0]:>7} {record['header'][1]:>7} "
              f"{len(record['setup_words']):>11} "
              f"{len(record['object_words']):>12} "
              f"{'yes' if record['render_aligned'] else 'NO'}")


if __name__ == "__main__":
    main()
