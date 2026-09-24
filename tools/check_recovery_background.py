#!/usr/bin/env python3
"""Check recovery_background.gdb captures for unintended background writes."""
import sys
from pathlib import Path

folder = Path(sys.argv[1])
before, dialog, picture = [
    (folder / f"recovery-{stage}.bin").read_bytes()
    for stage in ("before", "dialog", "picture")
]
assert len(before) == len(dialog) == len(picture) == 512 * 320 // 2
assert before == dialog, "DrawDialog changed pixels in the picture-only dialog"
assert picture != before, "Recovery picture was not drawn"

def pixel(data, x, y):
    return (data[y * 256 + x // 2] >> (0 if x & 1 else 4)) & 15

# The original recovery caller supplies (5,5)-(407,291), exclusive stop.
for y in range(320):
    for x in range(512):
        if not (5 <= x < 407 and 5 <= y < 291):
            assert pixel(before, x, y) == pixel(picture, x, y), (x, y)
print("PASS: DrawDialog preserved all pixels; DrawPicture preserved its surroundings, including the 9x268 strip")
