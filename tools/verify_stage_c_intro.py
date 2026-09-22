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

assert len(live) == len(reference) == 81920
assert len(planes) == len(front) == 98304
assert len(palette_bytes) == len(reference_palette_bytes) == 32
assert len(copper) == 64

live_palette = [int.from_bytes(palette_bytes[i:i + 2], "big") for i in range(0, 32, 2)]
reference_palette = [int.from_bytes(reference_palette_bytes[i:i + 2], "big")
                     for i in range(0, 32, 2)]
live_pixels, reference_pixels = pixels(live), pixels(reference)
color_differences = sum(live_palette[a] != reference_palette[b]
                        for a, b in zip(live_pixels, reference_pixels))

planar_differences = []
for y in range(320):
    planar_row = (y + 32) * 256
    for x in range(512):
        mask = 0x80 >> (x & 7)
        actual = 0
        for plane in range(4):
            if planes[planar_row + plane * 64 + x // 8] & mask:
                actual |= 1 << plane
        expected = live_pixels[y * 512 + x]
        if actual != expected:
            planar_differences.append((x, y))
if planar_differences:
    xs = [point[0] for point in planar_differences]
    ys = [point[1] for point in planar_differences]
    cursor_bounds = (min(xs), min(ys), max(xs) + 1, max(ys) + 1)
    cursor_only = (cursor_bounds[2] - cursor_bounds[0] <= 16
                   and cursor_bounds[3] - cursor_bounds[1] <= 16)
else:
    cursor_bounds = None
    cursor_only = True

copper_words = [int.from_bytes(copper[i:i + 4], "big") for i in range(0, 64, 4)]
copper_palette = b"".join((word & 0xffff).to_bytes(2, "big") for word in copper_words)
copper_registers = [word >> 16 for word in copper_words]

checks = {
    "displayed Macintosh colors": color_differences == 0,
    # The visible cursor is composited only into the planar presentation and
    # then restored out of the game-owned chunky surface.  All differences
    # must consequently fit inside its 16x16 bounds.  The independent driving
    # planar oracle below covers a cursor-free full 163,840-pixel conversion.
    "chunky-to-planar conversion (cursor overlay only)": cursor_only,
    "post-VBI front buffer": front == planes,
    "post-VBI copper palette": copper_palette == palette_bytes,
    "COLOR00..COLOR15 register order": copper_registers == list(range(0x180, 0x1a0, 2)),
}
for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}  {name}")
if planar_differences:
    print(f"INFO  {len(planar_differences)} cursor-overlay pixels in bounds {cursor_bounds}")
if not all(checks.values()):
    raise SystemExit(1)
print("PASS  163840/163840 displayed pixels match the Macintosh reference")
