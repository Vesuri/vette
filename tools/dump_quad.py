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
        header = words[pos:pos + 2]
        if len(header) != 2:
            raise ValueError("truncated QUAD record header")
        pos += 2
        command_lists = []
        for _ in range(2):
            commands = []
            while words[pos] != -1:
                command = words[pos:pos + 4]
                if len(command) != 4:
                    raise ValueError("truncated four-word QUAD command")
                commands.append(command)
                pos += 4
            pos += 1
            command_lists.append(commands)
        records.append({
            "header": header,
            "setup_commands": command_lists[0],
            "object_commands": command_lists[1],
        })

    # The final object's list terminator is followed by two more -1 words.
    if words[pos:] != (-1, -1):
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
    print("index header0 header1 setup object")
    for index, record in enumerate(records):
        print(f"{index:>5} {record['header'][0]:>7} {record['header'][1]:>7} "
              f"{len(record['setup_commands']):>5} "
              f"{len(record['object_commands']):>6}")


if __name__ == "__main__":
    main()
