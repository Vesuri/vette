#!/usr/bin/env python3
"""Decode Vette's real planar buffers from a local WHDLoad memory dump.

Writes one PNG per distinct Copper-list view, combining adjacent even/odd
field starts when both are present. This does not substitute game imagery.
"""
import argparse
import struct
import sys
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('dump', type=Path)
parser.add_argument('--hires', action='store_true', help='decode an interlaced HIRES run')
args = parser.parse_args()
p = args.dump
width, height = (512, 384) if args.hires else (368, 283)
raw = (p/'.whdl_memory').read_bytes()
seen = set()
lists = []
for offset in range(0, len(raw)-176, 2):
    ops = struct.unpack_from('>88H', raw, offset)
    if ops[::2][:8] != tuple(range(0xe0, 0xf0, 2)) or ops[-2:] != (0xffff, 0xfffe):
        continue
    pointers = [(ops[i*4+1]<<16)|ops[i*4+3] for i in range(4)]
    if pointers != [pointers[0]+i*64 for i in range(4)]:
        continue
    lists.append((offset, ops, pointers))
starts = {pointers[0] for _, _, pointers in lists}
for offset, ops, pointers in lists:
    start = pointers[0]
    if args.hires and start-256 in starts:
        start -= 256
    if start in seen or start+(height-1)*256+3*64+width//8 > len(raw):
        continue
    seen.add(start)
    colors = ops[49:80:2]
    palette = [tuple(((c>>shift)&15)*17 for shift in (8,4,0)) for c in colors]
    pixels = bytearray()
    for y in range(height):
        for x in range(width):
            index = sum(((raw[start+y*256+plane*64+x//8]>>(7-x%8))&1)<<plane for plane in range(4))
            pixels.extend(palette[index])
    target = p/f'planar-{offset:06x}.png'
    Image.frombytes('RGB',(width,height),bytes(pixels)).save(target)
    print(target)
assert seen, 'No Vette Copper lists found in the memory dump'
