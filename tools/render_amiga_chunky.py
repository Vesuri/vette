#!/usr/bin/env python3
"""Render Vette's packed 512x320 4-bpp surface with a 16-word OCS palette."""

import argparse
from pathlib import Path

from PIL import Image


parser = argparse.ArgumentParser()
parser.add_argument("surface", type=Path)
parser.add_argument("palette", type=Path)
parser.add_argument("output", type=Path)
args = parser.parse_args()

surface = args.surface.read_bytes()
palette_data = args.palette.read_bytes()
if len(surface) != 512 * 320 // 2 or len(palette_data) != 32:
    raise SystemExit("expected an 81920-byte surface and a 32-byte palette")

palette = []
for offset in range(0, 32, 2):
    word = int.from_bytes(palette_data[offset:offset + 2], "big")
    palette.append((((word >> 8) & 15) * 17,
                    ((word >> 4) & 15) * 17,
                    (word & 15) * 17))

image = Image.new("RGB", (512, 320))
pixels = image.load()
for y in range(320):
    for x in range(512):
        byte = surface[y * 256 + x // 2]
        pixels[x, y] = palette[byte & 15 if x & 1 else byte >> 4]
image.save(args.output)
