#!/usr/bin/env python3
"""Compare corresponding packed 4-bpp frames in a driving capture sequence."""

import argparse
import re
from collections import Counter
from pathlib import Path

from compare_mac_chunky import compare_surfaces, format_bounds


def numbered_frames(prefix: Path) -> dict[int, Path]:
    pattern = re.compile(rf"^{re.escape(prefix.name)}-(\d+)\.raw$")
    frames: dict[int, Path] = {}
    for path in prefix.parent.glob(f"{prefix.name}-*.raw"):
        match = pattern.match(path.name)
        if match:
            frames[int(match.group(1))] = path
    return frames


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare numbered Macintosh and Amiga driving surfaces")
    parser.add_argument("reference_prefix", type=Path)
    parser.add_argument("amiga_prefix", type=Path)
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=342)
    parser.add_argument("--reference-row-bytes", type=int, default=260)
    parser.add_argument("--amiga-row-bytes", type=int, default=260)
    parser.add_argument(
        "--require-exact", action="store_true",
        help="exit unsuccessfully when any active pixel differs")
    args = parser.parse_args()

    reference = numbered_frames(args.reference_prefix)
    amiga = numbered_frames(args.amiga_prefix)
    if not reference:
        raise SystemExit(f"no frames match {args.reference_prefix}-N.raw")
    if not amiga:
        raise SystemExit(f"no frames match {args.amiga_prefix}-N.raw")
    if reference.keys() != amiga.keys():
        missing_amiga = sorted(reference.keys() - amiga.keys())
        missing_reference = sorted(amiga.keys() - reference.keys())
        details = []
        if missing_amiga:
            details.append(f"missing Amiga frames {missing_amiga}")
        if missing_reference:
            details.append(f"missing reference frames {missing_reference}")
        raise SystemExit("sequence frame sets differ: " + "; ".join(details))

    changed_total = 0
    pixel_total = 0
    first_difference: int | None = None
    all_transitions: Counter[tuple[int, int]] = Counter()
    print(
        f"driving sequence: {len(reference)} frames, "
        f"{args.width}x{args.height} active pixels")
    for frame in sorted(reference):
        try:
            comparison = compare_surfaces(
                reference[frame].read_bytes(),
                amiga[frame].read_bytes(),
                width=args.width,
                height=args.height,
                left_row_bytes=args.reference_row_bytes,
                right_row_bytes=args.amiga_row_bytes,
            )
        except ValueError as error:
            raise SystemExit(f"frame {frame}: {error}") from error
        changed_total += comparison.changed
        pixel_total += comparison.total
        all_transitions.update(comparison.transitions)
        if comparison.changed and first_difference is None:
            first_difference = frame
        status = "exact" if not comparison.changed else (
            f"{comparison.changed} different "
            f"({comparison.changed * 100 / comparison.total:.6f}%), "
            f"bounds {format_bounds(comparison.bounds)}")
        print(f"frame {frame}: {status}")

    print(
        f"sequence total: {changed_total} / {pixel_total} differing pixels "
        f"({changed_total * 100 / pixel_total:.6f}%)")
    if first_difference is None:
        print("first divergence: none")
    else:
        print(f"first divergence: frame {first_difference}")
        for (left, right), count in all_transitions.most_common(16):
            print(f"  {left:X}->{right:X}: {count}")

    if args.require_exact and changed_total:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
