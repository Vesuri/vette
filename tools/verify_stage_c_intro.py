#!/usr/bin/env python3
"""Verify the Stage C Amiga capture against the measured Macintosh intro."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / "tmp"


def pixels(data):
    return [value for byte in data for value in (byte >> 4, byte & 15)]


live = (TMP / "amiga_intro.raw").read_bytes()
reference_screen = (ROOT / "ref/mame/snap/intro/fb_screen.raw").read_bytes()
reference = b"".join(reference_screen[y * 320 + 32:y * 320 + 288]
                     for y in range(91, 411))
planes = (TMP / "amiga_intro.planes").read_bytes()
front = (TMP / "amiga_intro.front").read_bytes()
palette_bytes = (TMP / "amiga_intro.palette").read_bytes()
reference_palette_bytes = (ROOT / "amiga/assets/intro.palbin").read_bytes()
copper = (TMP / "amiga_intro.copper_colors").read_bytes()

assert len(live) == len(reference) == len(planes) == len(front) == 81920
assert len(palette_bytes) == len(reference_palette_bytes) == 32
assert len(copper) == 64

live_palette = [int.from_bytes(palette_bytes[i:i + 2], "big") for i in range(0, 32, 2)]
reference_palette = [int.from_bytes(reference_palette_bytes[i:i + 2], "big")
                     for i in range(0, 32, 2)]
live_pixels, reference_pixels = pixels(live), pixels(reference)
color_differences = sum(live_palette[a] != reference_palette[b]
                        for a, b in zip(live_pixels, reference_pixels))

expected_planes = bytearray()
for y in range(320):
    row = live_pixels[y * 512:(y + 1) * 512]
    for plane in range(4):
        for word in range(32):
            value = 0
            for x in range(16):
                value |= ((row[word * 16 + x] >> plane) & 1) << (15 - x)
            expected_planes += value.to_bytes(2, "big")

copper_words = [int.from_bytes(copper[i:i + 4], "big") for i in range(0, 64, 4)]
copper_palette = b"".join((word & 0xffff).to_bytes(2, "big") for word in copper_words)
copper_registers = [word >> 16 for word in copper_words]

checks = {
    "displayed Macintosh colors": color_differences == 0,
    "chunky-to-planar conversion": planes == expected_planes,
    "post-VBI front buffer": front == planes,
    "post-VBI copper palette": copper_palette == palette_bytes,
    "COLOR00..COLOR15 register order": copper_registers == list(range(0x180, 0x1a0, 2)),
}
for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}  {name}")
if not all(checks.values()):
    raise SystemExit(1)
print("PASS  163840/163840 displayed pixels match the Macintosh reference")
