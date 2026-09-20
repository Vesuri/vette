#!/usr/bin/env python3
"""Decode the proved outer structure of VETTE!.Data PERF resources."""

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hfs_extract import resources  # noqa: E402


EXPECTED = {
    100: "Stock",
    200: "ZR1",
    300: "TwinTurbo",
    400: "Sledge",
    500: "Porche",
    600: "Testa",
    700: "Lambo",
    800: "F40",
}


def perf_records(path: Path):
    fork = resources(path.read_bytes())
    records = fork.get("PERF", [])
    found = {rid: name for rid, name, _ in records}
    if found != EXPECTED:
        raise ValueError(f"unexpected PERF inventory in {path}: {found}")
    return records


def decode(body: bytes):
    if len(body) != 110:
        raise ValueError(f"PERF record is {len(body)} bytes, expected 110")
    words = struct.unpack(">55h", body)
    if words[0] != 54:
        raise ValueError(f"PERF count word is {words[0]}, expected 54")
    # Traffic+$06BE skips word 0 and copies words 1..37 inclusive to the
    # live car structure. Words 38..54 are outside that measured copy.
    return {
        "words": words,
        "template": words[1:38],
        "tail": words[38:55],
        "max_gear": words[16],       # live car +30
        "automatic_shift": words[24],  # live car +46
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require a second fork's PERF resources to be byte-identical")
    args = parser.parse_args()

    records = perf_records(args.resource_fork)
    if args.compare:
        other = perf_records(args.compare)
        left = {(rid, name): body for rid, name, body in records}
        right = {(rid, name): body for rid, name, body in other}
        if left != right:
            raise SystemExit("PERF resources differ between the two forks")
        print(f"PASS: PERF resources are byte-identical in {args.resource_fork} and {args.compare}")

    print(" id name        words copied max_gear automatic_shift unproven_tail_words_38_54")
    for rid, name, body in records:
        record = decode(body)
        tail = ",".join(str(value) for value in record["tail"])
        print(f"{rid:>3} {name:<11} {len(record['words']) - 1:>5} "
              f"{len(record['template']):>6} {record['max_gear']:>8} "
              f"{record['automatic_shift']:>15} {tail}")


if __name__ == "__main__":
    main()
