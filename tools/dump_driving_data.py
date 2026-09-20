#!/usr/bin/env python3
"""Validate the proved outer shapes of VETTE!.Data driving tables."""

import argparse
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from hfs_extract import resources  # noqa: E402


TYPES = ("CLST", "FREE", "FWTP", "JHPF", "FWTM", "TIME", "CURV", "PHAZ", "TURN")


def selected(path: Path):
    fork = resources(path.read_bytes())
    return {kind: fork.get(kind, []) for kind in TYPES}


def one(records, kind, rid):
    matches = [(name, body) for found_id, name, body in records if found_id == rid]
    if len(matches) != 1:
        raise ValueError(f"expected exactly one {kind} {rid}, found {len(matches)}")
    return matches[0]


def counted(body: bytes, width: int, kind: str):
    if len(body) < 2:
        raise ValueError(f"{kind}: missing count word")
    count = struct.unpack_from(">H", body)[0]
    if len(body) != 2 + count * width:
        raise ValueError(
            f"{kind}: count {count} at width {width} predicts {2 + count * width} bytes, "
            f"found {len(body)}"
        )
    return count


def validate(found):
    clst = found["CLST"]
    expected_clst_ids = (100, 101, 102, 104, 200, 201, 202, 203, 204, 300, 301, 400, 401, 1200)
    if tuple(rid for rid, _name, _body in clst) != expected_clst_ids:
        raise ValueError("unexpected CLST resource IDs/order")

    _name, free = one(found["FREE"], "FREE", 1)
    if len(free) != 45 * 64:
        raise ValueError("FREE 1 is not 45 64-byte paths")

    _name, fwtp = one(found["FWTP"], "FWTP", 100)
    fwtp_count = counted(fwtp, 8, "FWTP 100")

    _name, jhpf = one(found["JHPF"], "JHPF", 100)
    if len(jhpf) != 39 * 8:
        raise ValueError("JHPF 100 is not 39 8-byte records")

    _name, fwtm = one(found["FWTM"], "FWTM", 100)
    fwtm_count = counted(fwtm, 6, "FWTM 100")

    time = found["TIME"]
    if tuple(rid for rid, _name, _body in time) != (128, 129, 130, 131):
        raise ValueError("expected TIME IDs 128..131")
    if any(len(body) != 10 * 30 for _rid, _name, body in time):
        raise ValueError("TIME resources are not ten 30-byte records each")

    _name, curv = one(found["CURV"], "CURV", 100)
    if len(curv) != 4 * 256:
        raise ValueError("CURV 100 is not four 256-byte direction blocks")

    _name, phaz = one(found["PHAZ"], "PHAZ", 128)
    if len(phaz) != 20 * 2:
        raise ValueError("PHAZ 128 is not 20 words")

    _name, turn = one(found["TURN"], "TURN", 1)
    if len(turn) != 29 * 2:
        raise ValueError("TURN 1 is not 29 words")

    return fwtp_count, fwtm_count


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    parser.add_argument("--compare", type=Path,
                        help="require the selected resource sets to be byte-identical")
    args = parser.parse_args()

    found = selected(args.resource_fork)
    fwtp_count, fwtm_count = validate(found)
    if args.compare:
        other = selected(args.compare)
        validate(other)
        if found != other:
            raise SystemExit("selected driving resources differ between the two forks")
        print("PASS: selected driving resources are byte-identical")

    print("type  resources bytes outer-shape")
    for kind in TYPES:
        records = found[kind]
        size = sum(len(body) for _rid, _name, body in records)
        shape = {
            "CLST": "14 variable command streams",
            "FREE": "45 x 64-byte signed-delta paths",
            "FWTP": f"count={fwtp_count}, 8-byte records",
            "JHPF": "39 x 8-byte records",
            "FWTM": f"count={fwtm_count}, 6-byte records",
            "TIME": "4 x (10 x 30-byte records)",
            "CURV": "4 x 256-byte direction blocks",
            "PHAZ": "20 words; no application request",
            "TURN": "29 words; loaded but unread",
        }[kind]
        print(f"{kind:<5} {len(records):>9} {size:>5} {shape}")


if __name__ == "__main__":
    main()
