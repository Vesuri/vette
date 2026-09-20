#!/usr/bin/env python3
"""Validate and summarize VETTE!.Data COLL orientation-hull resources."""

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hfs_extract import resources  # noqa: E402


IDS = tuple(range(100, 106))
SAMPLES = 91


def coll_resources(path: Path):
    return resources(path.read_bytes()).get("COLL", [])


def decode(records):
    if tuple(rid for rid, _name, _body in records) != IDS:
        raise ValueError("expected COLL IDs 100..105 in order")
    decoded = []
    for rid, name, body in records:
        if len(body) != SAMPLES * 4:
            raise ValueError(f"COLL {rid}: expected {SAMPLES} four-byte samples")
        values = struct.unpack(f">{len(body)}b", body)
        samples = tuple(zip(values[0::4], values[1::4], values[2::4], values[3::4]))
        if samples[0] != samples[-1]:
            raise ValueError(f"COLL {rid}: 0/360-degree samples differ")
        decoded.append((rid, name, samples))
    return decoded


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's COLL set to be byte-identical")
    args = parser.parse_args()

    records = coll_resources(args.resource_fork)
    if args.compare:
        other = coll_resources(args.compare)
        if records != other:
            raise SystemExit("COLL resources differ between the two forks")
        print(f"PASS: COLL are byte-identical in {args.resource_fork} and {args.compare}")

    for rid, name, samples in decode(records):
        extrema = (min(min(s) for s in samples), max(max(s) for s in samples))
        print(f"id={rid} name={name!r} bytes={len(samples) * 4} "
              f"samples={len(samples)} step=4deg sample0={samples[0]} "
              f"signed-byte-range={extrema[0]}..{extrema[1]}")


if __name__ == "__main__":
    main()
