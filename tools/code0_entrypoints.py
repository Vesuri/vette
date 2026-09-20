#!/usr/bin/env python3
"""Generate or verify Ghidra entrypoints.csv from an unloaded classic-Mac CODE 0.

CODE 0 contains a 16-byte header followed by eight-byte unloaded jump-table
entries: routineOffset:w, MOVE.W #segment,-(SP), segment:w, _LoadSeg.  Ghidra
imports the complete resource, including each target segment's four-byte
near-model header, so the address seeded in that program is routineOffset + 4.
"""
import argparse
import pathlib
import struct
import sys

SEGMENT_NAMES = {
    1: "Main", 2: "Initialize", 3: "Communication", 4: "load", 5: "Score",
    6: "Traffic", 7: "FRED", 8: "Intro", 9: "sound", 10: "A5Init",
}


def generate(code0: bytes) -> str:
    if len(code0) < 16:
        raise ValueError("CODE 0 is shorter than its 16-byte header")
    above, below, table_size, table_offset = struct.unpack_from(">IIII", code0)
    if table_size % 8 or len(code0) != 16 + table_size:
        raise ValueError(
            f"CODE 0 size mismatch: header says {table_size} table bytes, file has {len(code0)}")
    rows = ["segment,addr,name,note"]
    for index, position in enumerate(range(16, len(code0), 8)):
        offset, push, segment, trap = struct.unpack_from(">HHHH", code0, position)
        if push != 0x3F3C or trap != 0xA9F0:
            raise ValueError(f"entry {index} is not an unloaded jump-table stub")
        if segment not in SEGMENT_NAMES:
            raise ValueError(f"entry {index} names invalid segment {segment}")
        address = offset + 4
        name = f"seg{segment:02d}_{SEGMENT_NAMES[segment]}_{address:04X}"
        rows.append(
            f"{segment},0x{address:04X},{name},jump-table export {index:03d}; "
            f"CODE 0 routine offset 0x{offset:04X}")
    if table_offset != 32:
        raise ValueError(f"unexpected A5 jump-table offset {table_offset}, expected 32")
    print(f"CODE 0: above-A5={above} below-A5={below} entries={len(rows)-1}", file=sys.stderr)
    return "\n".join(rows) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("code0", type=pathlib.Path)
    parser.add_argument("--check", type=pathlib.Path,
                        help="fail unless this file exactly matches generated output")
    args = parser.parse_args()
    generated = generate(args.code0.read_bytes())
    if args.check:
        actual = args.check.read_text()
        if actual != generated:
            raise SystemExit(f"{args.check} is stale or belongs to another CODE 0")
        print(f"verified {args.check}", file=sys.stderr)
    else:
        sys.stdout.write(generated)


if __name__ == "__main__":
    main()
