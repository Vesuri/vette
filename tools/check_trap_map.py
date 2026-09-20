#!/usr/bin/env python3
"""Require every exact live Macintosh trap site in the static CODE maps."""

import argparse
import csv
from pathlib import Path


SEGMENTS = {
    "Main": 1,
    "Initialize": 2,
    "Communication": 3,
    "load": 4,
    "Score": 5,
    "Traffic": 6,
    "FRED": 7,
    "Intro": 8,
    "sound": 9,
    "%A5Init": 10,
}


def read_live(path: Path):
    sites = {segment: {} for segment in SEGMENTS.values()}
    for line in path.read_text().splitlines():
        fields = line.split()
        if (len(fields) < 5 or fields[0] != "VP" or fields[1] not in SEGMENTS
                or not fields[2].startswith("+")):
            continue
        segment = SEGMENTS[fields[1]]
        offset = int(fields[2][1:], 16)
        word = int(fields[3], 16)
        previous = sites[segment].get(offset)
        if previous is not None and previous != word:
            raise ValueError(
                f"live site {fields[1]}+{offset:04X} changed "
                f"from {previous:04X} to {word:04X}"
            )
        sites[segment][offset] = word
    if not any(sites.values()):
        raise ValueError(f"{path} contains no exact live-site table")
    return sites


def read_static(path: Path, expected_segment: int):
    sites = {}
    with path.open(newline="") as source:
        for row in csv.DictReader(source):
            segment = int(row["segment"])
            if segment != expected_segment:
                raise ValueError(
                    f"{path}: row says segment {segment}, expected {expected_segment}"
                )
            offset = int(row["offset"], 0)
            word = int(row["word"], 0)
            previous = sites.get(offset)
            if previous is not None and previous != word:
                raise ValueError(
                    f"{path}: static site +{offset:04X} has both "
                    f"{previous:04X} and {word:04X}"
                )
            sites[offset] = word
    return sites


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("live_report", nargs="?", type=Path,
                        default=Path("ref/mame/traps.txt"))
    parser.add_argument("--static-dir", type=Path, default=Path("tmp"))
    args = parser.parse_args()

    live = read_live(args.live_report)
    failed = False
    print("seg name           static live missing mismatched")
    for name, segment in SEGMENTS.items():
        path = args.static_dir / f"CODE_{segment:02d}_traps.csv"
        static = read_static(path, segment)
        missing = sorted(set(live[segment]) - set(static))
        mismatched = sorted(
            offset for offset in set(live[segment]) & set(static)
            if live[segment][offset] != static[offset]
        )
        print(f"{segment:>3} {name:<14} {len(static):>6} {len(live[segment]):>4} "
              f"{len(missing):>7} {len(mismatched):>10}")
        for offset in missing:
            print(f"    missing {name}+{offset:04X} word {live[segment][offset]:04X}")
        for offset in mismatched:
            print(f"    mismatch {name}+{offset:04X}: live {live[segment][offset]:04X}, "
                  f"static {static[offset]:04X}")
        failed |= bool(missing or mismatched)
    if failed:
        raise SystemExit(1)
    print("PASS: every exact live trap site occurs in the static maps with the same word")


if __name__ == "__main__":
    main()
