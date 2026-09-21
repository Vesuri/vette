#!/usr/bin/env python3
"""Compare active pixels in two packed 4-bpp surfaces, ignoring row padding."""

import argparse
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


def pixel(data: bytes, row_bytes: int, x: int, y: int) -> int:
    value = data[y * row_bytes + x // 2]
    return value & 15 if x & 1 else value >> 4


@dataclass(frozen=True)
class Comparison:
    changed: int
    total: int
    bounds: tuple[int, int, int, int] | None
    transitions: Counter[tuple[int, int]]


def compare_surfaces(
    left: bytes,
    right: bytes,
    *,
    width: int,
    height: int,
    left_row_bytes: int,
    right_row_bytes: int,
) -> Comparison:
    """Compare two packed surfaces and return active-pixel differences."""
    if width <= 0 or height <= 0:
        raise ValueError("surface dimensions must be positive")
    active_bytes = (width + 1) // 2
    if left_row_bytes < active_bytes or right_row_bytes < active_bytes:
        raise ValueError("rowBytes is too small for the requested width")

    left_needed = left_row_bytes * height
    right_needed = right_row_bytes * height
    if len(left) < left_needed or len(right) < right_needed:
        raise ValueError(
            f"surface is truncated (need {left_needed} and {right_needed} bytes, "
            f"got {len(left)} and {len(right)})")

    changed = 0
    bounds = [width, height, -1, -1]
    transitions: Counter[tuple[int, int]] = Counter()
    for y in range(height):
        for x in range(width):
            a = pixel(left, left_row_bytes, x, y)
            b = pixel(right, right_row_bytes, x, y)
            if a == b:
                continue
            changed += 1
            bounds[0] = min(bounds[0], x)
            bounds[1] = min(bounds[1], y)
            bounds[2] = max(bounds[2], x)
            bounds[3] = max(bounds[3], y)
            transitions[(a, b)] += 1

    result_bounds = tuple(bounds) if changed else None
    return Comparison(changed, width * height, result_bounds, transitions)


def format_bounds(bounds: tuple[int, int, int, int] | None) -> str:
    if bounds is None:
        return "empty"
    left, top, right, bottom = bounds
    return f"({left},{top})-({right + 1},{bottom + 1})"


def print_comparison(comparison: Comparison) -> None:
    print(
        f"differing pixels: {comparison.changed} / {comparison.total} "
        f"({comparison.changed * 100 / comparison.total:.6f}%)")
    print(f"difference bounds: {format_bounds(comparison.bounds)}")
    for (a, b), count in comparison.transitions.most_common(16):
        print(f"  {a:X}->{b:X}: {count}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("left", type=Path)
    parser.add_argument("right", type=Path)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--left-row-bytes", type=int, required=True)
    parser.add_argument("--right-row-bytes", type=int, required=True)
    args = parser.parse_args()

    left = args.left.read_bytes()
    right = args.right.read_bytes()
    try:
        comparison = compare_surfaces(
            left,
            right,
            width=args.width,
            height=args.height,
            left_row_bytes=args.left_row_bytes,
            right_row_bytes=args.right_row_bytes,
        )
    except ValueError as error:
        raise SystemExit(str(error)) from error
    print_comparison(comparison)


if __name__ == "__main__":
    main()
