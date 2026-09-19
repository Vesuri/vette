#!/usr/bin/env python3
"""Render a packed 4-bpp Macintosh surface through a binary ColorTable."""

import argparse
import struct
from pathlib import Path

from PIL import Image


def read_color_table(path: Path) -> tuple[int, list[tuple[int, int, int]]]:
    data = path.read_bytes()
    if len(data) < 8:
        raise SystemExit(f"{path}: truncated ColorTable header")

    seed, _flags, last_index = struct.unpack_from(">IHH", data)
    count = last_index + 1
    expected = 8 + count * 8
    if len(data) != expected:
        raise SystemExit(
            f"{path}: expected {expected} bytes for {count} colors, got {len(data)}")

    palette = [(0, 0, 0)] * count
    for entry in range(count):
        value, red, green, blue = struct.unpack_from(">HHHH", data, 8 + entry * 8)
        index = value & 0xFF if value < count else entry
        if index >= count:
            raise SystemExit(f"{path}: ColorSpec {entry} selects invalid index {index}")
        palette[index] = (red >> 8, green >> 8, blue >> 8)
    return seed, palette


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("surface", type=Path)
    parser.add_argument("color_table", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--row-bytes", type=int, required=True)
    args = parser.parse_args()

    if args.width <= 0 or args.height <= 0:
        raise SystemExit("surface dimensions must be positive")
    if args.row_bytes < (args.width + 1) // 2:
        raise SystemExit("rowBytes is too small for the requested width")

    surface = args.surface.read_bytes()
    expected = args.row_bytes * args.height
    if len(surface) != expected:
        raise SystemExit(f"{args.surface}: expected {expected} bytes, got {len(surface)}")

    seed, palette = read_color_table(args.color_table)
    image = Image.new("RGB", (args.width, args.height))
    pixels = image.load()
    for y in range(args.height):
        row = y * args.row_bytes
        for x in range(args.width):
            byte = surface[row + x // 2]
            index = byte & 15 if x & 1 else byte >> 4
            pixels[x, y] = palette[index]

    image.save(args.output)
    print(
        f"wrote {args.output}: {args.width}x{args.height}, "
        f"rowBytes={args.row_bytes}, ctSeed={seed}, colors={len(palette)}")


if __name__ == "__main__":
    main()
