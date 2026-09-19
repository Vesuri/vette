#!/usr/bin/env python3
"""Compare active pixels in two packed 4-bpp surfaces, ignoring row padding."""

import argparse
from collections import Counter
from pathlib import Path


def pixel(data: bytes, row_bytes: int, x: int, y: int) -> int:
    value = data[y * row_bytes + x // 2]
    return value & 15 if x & 1 else value >> 4


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("left", type=Path)
    parser.add_argument("right", type=Path)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--left-row-bytes", type=int, required=True)
    parser.add_argument("--right-row-bytes", type=int, required=True)
    args = parser.parse_args()

    if args.width <= 0 or args.height <= 0:
        raise SystemExit("surface dimensions must be positive")
    active_bytes = (args.width + 1) // 2
    if args.left_row_bytes < active_bytes or args.right_row_bytes < active_bytes:
        raise SystemExit("rowBytes is too small for the requested width")

    left = args.left.read_bytes()
    right = args.right.read_bytes()
    left_needed = args.left_row_bytes * args.height
    right_needed = args.right_row_bytes * args.height
    if len(left) < left_needed or len(right) < right_needed:
        raise SystemExit(
            f"surface is truncated (need {left_needed} and {right_needed} bytes, "
            f"got {len(left)} and {len(right)})")

    changed = 0
    bounds = [args.width, args.height, -1, -1]
    transitions: Counter[tuple[int, int]] = Counter()
    for y in range(args.height):
        for x in range(args.width):
            a = pixel(left, args.left_row_bytes, x, y)
            b = pixel(right, args.right_row_bytes, x, y)
            if a == b:
                continue
            changed += 1
            bounds[0] = min(bounds[0], x)
            bounds[1] = min(bounds[1], y)
            bounds[2] = max(bounds[2], x)
            bounds[3] = max(bounds[3], y)
            transitions[(a, b)] += 1

    total = args.width * args.height
    if changed:
        bbox = f"({bounds[0]},{bounds[1]})-({bounds[2] + 1},{bounds[3] + 1})"
    else:
        bbox = "empty"
    print(f"differing pixels: {changed} / {total} ({changed * 100 / total:.6f}%)")
    print(f"difference bounds: {bbox}")
    for (a, b), count in transitions.most_common(16):
        print(f"  {a:X}->{b:X}: {count}")


if __name__ == "__main__":
    main()
