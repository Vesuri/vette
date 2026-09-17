#!/usr/bin/env python3
"""The host half of the Stage A acceptance test: the checksum of a .planes blob.

⭐ Rotate-then-xor, NOT a plain sum, and the choice is the whole point.  A sum is blind to
byte ORDER, and every plausible failure of this asset path -- the wrong interleave stride,
the two halves of a word swapped, a plane copied in the wrong order -- puts exactly the
right bytes in the wrong places.  A sum would pass all of them.

The algorithm is duplicated in VetteScreen.cpp's rotXorChecksum().  ⚠ Change one and the
test stops testing anything; it will simply report a mismatch forever.
"""
import sys

if len(sys.argv) != 2:
    sys.exit("usage: planes_checksum.py <file.planes>")

data = open(sys.argv[1], "rb").read()
c = 0
for b in data:
    c = ((c << 1) | (c >> 31)) & 0xFFFFFFFF
    c ^= b
print("%s: %d bytes, checksum 0x%08X" % (sys.argv[1], len(data), c))
