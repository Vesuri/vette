#!/usr/bin/env python3
"""Render a packed 4-bpp Vette surface with a 16-word OCS palette."""

import argparse
from pathlib import Path

from PIL import Image


parser = argparse.ArgumentParser()
parser.add_argument("surface", type=Path)
parser.add_argument("palette", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--width", type=int, default=512)
parser.add_argument("--height", type=int, default=320)
parser.add_argument("--row-bytes", type=int, default=256)
args = parser.parse_args()

surface = args.surface.read_bytes()
palette_data = args.palette.read_bytes()
if args.width <= 0 or args.height <= 0 or args.row_bytes < (args.width + 1) // 2:
    raise SystemExit("invalid surface geometry")
if len(surface) != args.row_bytes * args.height or len(palette_data) != 32:
    raise SystemExit(
        f"expected a {args.row_bytes * args.height}-byte surface and a 32-byte palette")

palette = []
for offset in range(0, 32, 2):
    word = int.from_bytes(palette_data[offset:offset + 2], "big")
    palette.append((((word >> 8) & 15) * 17,
                    ((word >> 4) & 15) * 17,
                    (word & 15) * 17))

image = Image.new("RGB", (args.width, args.height))
pixels = image.load()
for y in range(args.height):
    for x in range(args.width):
        byte = surface[y * args.row_bytes + x // 2]
        pixels[x, y] = palette[byte & 15 if x & 1 else byte >> 4]
image.save(args.output)
