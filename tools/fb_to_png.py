#!/usr/bin/env python3
"""Re-render a raw Macintosh framebuffer dump through its own CLUT, and diff it
against MAME's screenshot of the same frame.

⭐ This is the PROOF behind the pixel-format claims in docs/mac-hardware.md.  A
pixel-exact diff against the emulator's own output validates, in one shot: the
base address, rowBytes, that 4 bpp means two pixels per byte, that the HIGH
nibble is the LEFT pixel, and that the CLUT index order is what the docs say.
Guess any one of them wrong and the image comes out visibly mangled -- which is
why this is a diff and not an eyeball.

  python3 tools/fb_to_png.py <raw> <clut> <width> <height> <rowbytes> <out.png> [reference.png]
"""
import sys
from PIL import Image, ImageChops

raw, clut, w, h, rowbytes, out = sys.argv[1:7]
w, h, rowbytes = int(w), int(h), int(rowbytes)

pal = []
for line in open(clut):
    i, value, r, g, b = (int(x) for x in line.split())
    pal.append((r >> 8, g >> 8, b >> 8))

data = open(raw, "rb").read()
img = Image.new("RGB", (w, h))
px = img.load()
for y in range(h):
    row = data[y * rowbytes:(y + 1) * rowbytes]
    for x in range(w):
        byte = row[x >> 1]
        idx = (byte >> 4) if (x & 1) == 0 else (byte & 15)   # high nibble = LEFT pixel
        px[x, y] = pal[idx]
img.save(out)
print(f"wrote {out}  {w}x{h} from {len(data)} bytes, {len(pal)}-entry CLUT")

if len(sys.argv) > 7:
    ref = Image.open(sys.argv[7]).convert("RGB")
    print(f"reference {ref.size}")
    if ref.size != img.size:
        print("SIZE MISMATCH — cannot diff"); sys.exit(1)
    diff = ImageChops.difference(ref, img)
    bbox = diff.getbbox()
    bad = sum(1 for p in diff.getdata() if p != (0, 0, 0))
    print(f"differing pixels: {bad} / {w*h}  ({100*bad/(w*h):.4f}%)   bbox={bbox}")
    print("PIXEL-EXACT MATCH" if bad == 0 else "MISMATCH")
