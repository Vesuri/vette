#!/usr/bin/env python3
"""Turn a Macintosh framebuffer dump into Amiga bitplanes + an Amiga palette, and
price every lossy step of the conversion.

⭐⭐ THIS TOOL IS THE PIXEL DIFFERENTIAL Target 1 is judged by (docs/open-work.md
Stage A).  It answers, before a line of Amiga code runs, the only question Stage A
can answer on its own: *if the Amiga displays exactly the right indices through the
best 4-bit palette it can hold, how far from the Macintosh is it?*  Anything worse
than that on hardware is the port's bug, not the format's.

Three transformations, and they are NOT equally trustworthy -- so each is reported
separately rather than as one "it matches" number:

  1. chunky 4 bpp -> 4 interleaved bitplanes.  ⭐ LOSSLESS, and asserted so: the
     planes are unpacked again and compared index-for-index with the source.  A
     round trip is the only check that catches a plane-order or bit-order flip,
     because both produce a plausible-looking image.
  2. pmTable -> the colour the player actually SAW.  ⚠⚠ A gamma table sits between
     QuickDraw's CLUT and the DAC (gamma=1.435, docs/mac-hardware.md), so the
     requested colour is NOT the displayed one -- index 4 is (43,43,43) requested
     and (74,74,74) on the glass.  Deriving the Amiga palette from pmTable directly
     is a ~30-level error per channel that looks like a plausible dark grey.
  3. displayed 8-bit -> OCS 4-bit COLORxx.  ⚠ LOSSY and unavoidable: OCS holds 4
     bits per channel.  The error is measured and printed, per channel and per
     pixel, so it can be compared against a later hardware capture instead of
     being waved at.  [ASSUMED] the Amiga's own DAC is linear in the register
     value -- untested, and the FS-UAE screenshot diff is what will test it.

  python3 tools/mac_fb_to_amiga.py <raw> <clut> <rowbytes> <rows> <out-base> \
      [--crop L,T,W,H] [--gamma 1.435] [--reference <MAME.png>]

⭐ PASS `--reference` WHENEVER THERE IS A SCREENSHOT OF THE SAME FRAME.  It diffs
the reconstructed Macintosh image against MAME's own output, which is what makes
step 2 a measurement rather than a formula copied out of a doc: the gamma fit is
confirmed only if the worst channel error is <= 1/255 (pure rounding).

Writes <out-base>.planes (interleaved bitplanes, ready for .incbin),
<out-base>.pal (16 Amiga COLORxx words, one per line, as text),
<out-base>.palbin (the same 16 words, big-endian binary, for .incbin), and
<out-base>_amiga.png (what the Amiga will show, simulated) next to
<out-base>_mac.png (what the Macintosh showed).
"""
import sys, argparse
from PIL import Image, ImageChops

ap = argparse.ArgumentParser(add_help=True)
ap.add_argument("raw"); ap.add_argument("clut")
ap.add_argument("rowbytes", type=int); ap.add_argument("rows", type=int)
ap.add_argument("outbase")
ap.add_argument("--crop", default=None, help="L,T,W,H in pixels (default: the whole dump)")
ap.add_argument("--gamma", type=float, default=1.435,
                help="pmTable -> DAC gamma, measured in docs/mac-hardware.md")
ap.add_argument("--reference", default=None,
                help="MAME screenshot of the same frame; the crop is applied to it too")
a = ap.parse_args()

# ---------------------------------------------------------------- the source
data = open(a.raw, "rb").read()
need = a.rowbytes * a.rows
if len(data) < need:
    sys.exit(f"*** {a.raw} is {len(data)} bytes, need {need} for {a.rowbytes}x{a.rows}")
SRC_W = a.rowbytes * 2                                  # 4 bpp: two pixels per byte

if a.crop:
    cl, ct, cw, ch = (int(v) for v in a.crop.split(","))
else:
    cl, ct, cw, ch = 0, 0, SRC_W, a.rows
if cl + cw > SRC_W or ct + ch > a.rows:
    sys.exit(f"*** crop {cl},{ct},{cw},{ch} falls outside the {SRC_W}x{a.rows} dump")
# ⚠ The blitter and the copper both address bitplanes in WORDS.  A crop whose left
# edge is not word-aligned would need a shift the Amiga side has no reason to pay,
# and silently shifting it here would make the differential lie about position.
if cl % 16 or cw % 16:
    sys.exit(f"*** crop x/width must be multiples of 16 px (word-aligned): got {cl},{cw}")

idx = [[0] * cw for _ in range(ch)]                     # [y][x] -> CLUT index
for y in range(ch):
    row = data[(ct + y) * a.rowbytes:]
    for x in range(cw):
        byte = row[(cl + x) >> 1]
        idx[y][x] = (byte >> 4) if ((cl + x) & 1) == 0 else (byte & 15)

# ---------------------------------------------------------------- 2. the palette
# pmTable holds 16-bit channels; the gamma table sits between it and the DAC.
requested, displayed, amiga = [], [], []
for line in open(a.clut):
    i, value, r, g, b = (int(v) for v in line.split())
    req = (r >> 8, g >> 8, b >> 8)
    dis = tuple(round(255.0 * (c / 255.0) ** (1.0 / a.gamma)) for c in req)
    reg = tuple(round(c * 15.0 / 255.0) for c in dis)   # OCS: 4 bits per channel
    requested.append(req); displayed.append(dis); amiga.append(reg)
if len(amiga) != 16:
    sys.exit(f"*** {a.clut} has {len(amiga)} entries; a 4 bpp screen has 16")

print("idx  pmTable        displayed      COLORxx  back as 8-bit   err")
for i in range(16):
    back = tuple(round(c * 255.0 / 15.0) for c in amiga[i])
    err = max(abs(back[c] - displayed[i][c]) for c in range(3))
    print("%3d  %3d,%3d,%3d  ->  %3d,%3d,%3d  ->  $%X%X%X  ->  %3d,%3d,%3d   %+d"
          % (i, *requested[i], *displayed[i], *amiga[i], *back, err))
palerr = max(max(abs(round(c * 255.0 / 15.0) - d) for c, d in zip(amiga[i], displayed[i]))
             for i in range(16))
print(f"palette quantisation: worst channel error {palerr}/255 "
      f"({100.0 * palerr / 255:.1f}%) -- this is the FLOOR Stage A can reach")

# ---------------------------------------------------------------- 1. the planes
# Interleaved: all 4 planes of row y, then all 4 planes of row y+1.  That is what
# the vendored framework's Bitmap(interleaved=true) and CopperList::showBitmap
# expect, and it is the layout a blitter blit of a windowed rect wants.
words = cw // 16
planes = bytearray()
for y in range(ch):
    for p in range(4):
        bit = 1 << p
        for w in range(words):
            hi = lo = 0
            for b in range(8):
                if idx[y][w * 16 + b] & bit:      hi |= 0x80 >> b
                if idx[y][w * 16 + 8 + b] & bit:  lo |= 0x80 >> b
            planes += bytes((hi, lo))
open(a.outbase + ".planes", "wb").write(planes)
print(f"wrote {a.outbase}.planes  {len(planes)} bytes  "
      f"({cw}x{ch}, 4 interleaved bitplanes, {words} words/row/plane)")

# ⭐ The round trip.  A plane-order or bit-order flip still produces an image; only
# an index-for-index comparison catches it.
stride = words * 2 * 4
bad = 0
for y in range(ch):
    for x in range(cw):
        v = 0
        for p in range(4):
            byte = planes[y * stride + p * words * 2 + (x >> 3)]
            if byte & (0x80 >> (x & 7)): v |= 1 << p
        if v != idx[y][x]: bad += 1
if bad:
    sys.exit(f"*** PLANAR ROUND TRIP FAILED on {bad} pixels — the packing is wrong")
print(f"planar round trip: {cw*ch} pixels, index-for-index identical  [LOSSLESS]")

# ---------------------------------------------------------------- the palette file
with open(a.outbase + ".pal", "w") as f:
    for i, (r, g, b) in enumerate(amiga):
        f.write("0x%03X\n" % ((r << 8) | (g << 4) | b))
print(f"wrote {a.outbase}.pal  16 COLORxx words")

# ⭐ ...and the same 16 words as BINARY, big-endian, for .incbin.  Two files rather
# than one on purpose: the text .pal is what a human diffs against the table in
# docs/mac-hardware.md, and the .palbin is what the Amiga loads.  Generating both
# from the same `amiga` list is the only way they cannot drift apart.
with open(a.outbase + ".palbin", "wb") as f:
    for (r, g, b) in amiga:
        w = (r << 8) | (g << 4) | b
        f.write(bytes((w >> 8, w & 0xFF)))
print(f"wrote {a.outbase}.palbin  32 bytes")

# ---------------------------------------------------------------- 3. the images
def flat(img):
    d = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
    return list(d)

def render(pal, path):
    img = Image.new("RGB", (cw, ch)); px = img.load()
    for y in range(ch):
        for x in range(cw): px[x, y] = pal[idx[y][x]]
    img.save(path); return img
mac = render(displayed, a.outbase + "_mac.png")
ami = render([tuple(round(c * 255.0 / 15.0) for c in e) for e in amiga],
             a.outbase + "_amiga.png")
print(f"wrote {a.outbase}_mac.png and {a.outbase}_amiga.png  ({cw}x{ch})")

diff = ImageChops.difference(mac, ami)
vals = flat(diff)
worst = max(max(p) for p in vals)
mean = sum(sum(p) for p in vals) / (3.0 * len(vals))
nonzero = sum(1 for p in vals if p != (0, 0, 0))
print(f"mac vs amiga: {nonzero}/{cw*ch} pixels differ, worst channel {worst}/255, "
      f"mean channel error {mean:.2f}/255")
# ---------------------------------------------- the cross-check on step 2
# ⭐ Without this, "displayed = requested^(1/gamma)" is a formula taken on trust.
# With it, the gamma table is re-measured on every run against the emulator's own
# output, and a wrong gamma shows up as a worst-case error in the tens, not the
# ones.  ⚠ The screenshot must be of the SAME frame as the dump -- a screenshot
# taken during the intro animation differs by 40% of the screen and reads as a
# broken palette rather than as two different moments (docs/mac-hardware.md).
if a.reference:
    ref = Image.open(a.reference).convert("RGB").crop((cl, ct, cl + cw, ct + ch))
    if ref.size != mac.size:
        sys.exit(f"*** reference crop is {ref.size}, the dump crop is {mac.size}")
    rv = flat(ImageChops.difference(ref, mac))
    rworst = max(max(p) for p in rv)
    rbad = sum(1 for p in rv if p != (0, 0, 0))
    print(f"reference vs reconstructed Macintosh: {rbad}/{cw*ch} pixels differ, "
          f"worst channel {rworst}/255")
    if rworst <= 1:
        print("⭐ GAMMA CONFIRMED against MAME's own output (worst error is rounding only)")
    else:
        print(f"*** GAMMA NOT CONFIRMED: worst channel error {rworst}/255.  Either the")
        print("    screenshot is a different frame than the dump, or gamma is not "
              f"{a.gamma}.")
        sys.exit(1)

print("⭐ THIS IS THE ACCEPTANCE FLOOR for Stage A: a correct Amiga frame differs")
print("   from the Macintosh by exactly this much and no more.  A bigger difference")
print("   is a port bug; a smaller one means the palette derivation is not what ran.")
