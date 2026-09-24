#!/usr/bin/env python3
"""Report signed PCM ranges for every INST in a raw Macintosh resource fork."""

import argparse
from pathlib import Path

from resource_fork import read_resource_fork


def instruments(path: Path):
    for item in read_resource_fork(path):
        if item.kind != b"INST":
            continue
        body = item.body
        if (len(body) > 8
                and int.from_bytes(body[6:8], "big") == len(body) - 8):
            body = body[8:]
        yield item.rid, item.name, body


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    args = parser.parse_args()

    global_peak = 0
    print("   id name               bytes       signed range peak")
    for rid, name, body in instruments(args.resource_fork):
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
