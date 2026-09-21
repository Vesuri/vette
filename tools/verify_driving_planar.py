#!/usr/bin/env python3
"""Verify an Amiga driving planar capture against its 4-bpp chunky source."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
chunky = (ROOT / "tmp/driving-planar-chunky.raw").read_bytes()
planes = (ROOT / "tmp/driving-planar.planes").read_bytes()

if len(chunky) != 81920 or len(planes) != 98304:
    raise SystemExit(f"bad capture sizes: chunky={len(chunky)}, planes={len(planes)}")

bad = 0
first = None
for y in range(320):
    source = y * 256
    planar = (y + 32) * 256
    for x in range(512):
        packed = chunky[source + x // 2]
        expected = packed & 15 if x & 1 else packed >> 4
        mask = 0x80 >> (x & 7)
        actual = 0
        for plane in range(4):
            if planes[planar + plane * 64 + x // 8] & mask:
                actual |= 1 << plane
        if actual != expected:
            bad += 1
            if first is None:
                first = (x, y, expected, actual)

if bad:
    raise SystemExit(f"FAIL  {bad} pixels differ; first={first}")
print("PASS  163840/163840 driving pixels match after the covered-sync omission")
