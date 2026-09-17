#!/usr/bin/env python3
"""Convert classic Macintosh resource forks to Vette's Amiga resource archive.

Usage:
    rsrc_pack.py OUTPUT.vrs LABEL=INPUT.rsrc [LABEL=INPUT.rsrc ...]

The output is deliberately boring and 68000-friendly: all integers are big-endian,
the directory has fixed-size records, names and payloads are four-byte aligned, and
no compression or host pointers are present.  See docs/toolchain.md for the on-disk
layout.  The source forks and generated archive are copyrighted local build inputs;
neither belongs in git.
"""

from __future__ import annotations

import os
import struct
import sys
from dataclasses import dataclass


HEADER = struct.Struct(">4sHHII")
ENTRY = struct.Struct(">Hh4sBBHIII")
MAGIC = b"VRS1"


@dataclass(frozen=True)
class Resource:
    fork: int
    rid: int
    typ: bytes
    attrs: int
    name: bytes
    body: bytes


def _u24(b: bytes) -> int:
    return int.from_bytes(b, "big")


def parse_fork(path: str, fork: int) -> list[Resource]:
    raw = open(path, "rb").read()
    if len(raw) < 16:
        raise ValueError(f"{path}: resource fork is shorter than its header")
    data_off, map_off, data_len, map_len = struct.unpack_from(">IIII", raw)
    if data_off + data_len > len(raw) or map_off + map_len > len(raw):
        raise ValueError(f"{path}: resource data/map extends past end of fork")
    rmap = raw[map_off:map_off + map_len]
    if len(rmap) < 28:
        raise ValueError(f"{path}: resource map is truncated")
    type_off, name_off = struct.unpack_from(">HH", rmap, 24)
    if type_off + 2 > len(rmap) or name_off > len(rmap):
        raise ValueError(f"{path}: invalid type/name list offset")
    type_count = struct.unpack_from(">H", rmap, type_off)[0] + 1
    out: list[Resource] = []
    for ti in range(type_count):
        pos = type_off + 2 + ti * 8
        if pos + 8 > len(rmap):
            raise ValueError(f"{path}: truncated type entry {ti}")
        typ, count_m1, refs = struct.unpack_from(">4sHH", rmap, pos)
        for ri in range(count_m1 + 1):
            ref = type_off + refs + ri * 12
            if ref + 12 > len(rmap):
                raise ValueError(f"{path}: truncated reference for {typ!r}")
            rid, name_rel = struct.unpack_from(">hH", rmap, ref)
            attrs = rmap[ref + 4]
            body_rel = _u24(rmap[ref + 5:ref + 8])
            size_pos = data_off + body_rel
            if size_pos + 4 > data_off + data_len:
                raise ValueError(f"{path}: invalid data offset for {typ!r} {rid}")
            size = struct.unpack_from(">I", raw, size_pos)[0]
            body_pos = size_pos + 4
            if body_pos + size > data_off + data_len:
                raise ValueError(f"{path}: short payload for {typ!r} {rid}")
            name = b""
            if name_rel != 0xFFFF:
                np = name_off + name_rel
                if np >= len(rmap) or np + 1 + rmap[np] > len(rmap):
                    raise ValueError(f"{path}: invalid name for {typ!r} {rid}")
                name = rmap[np + 1:np + 1 + rmap[np]]
            out.append(Resource(fork, rid, typ, attrs, name, raw[body_pos:body_pos + size]))
    return out


def align4(buf: bytearray) -> None:
    buf.extend(b"\0" * (-len(buf) & 3))


def build(specs: list[tuple[str, str]]) -> bytes:
    resources: list[Resource] = []
    for index, (_, path) in enumerate(specs):
        resources.extend(parse_fork(path, index))
    resources.sort(key=lambda r: (r.fork, r.typ, r.rid))

    directory_bytes = ENTRY.size * len(resources)
    names = bytearray()
    name_offsets: list[int] = []
    names_base = HEADER.size + directory_bytes
    for r in resources:
        name_offsets.append(names_base + len(names) if r.name else 0)
        names.extend(r.name)
    align4(names)
    data_base = names_base + len(names)

    data = bytearray()
    data_offsets: list[int] = []
    for r in resources:
        align4(data)
        data_offsets.append(data_base + len(data))
        data.extend(r.body)

    out = bytearray(HEADER.pack(MAGIC, 1, len(specs), len(resources), HEADER.size))
    for r, noff, doff in zip(resources, name_offsets, data_offsets):
        out.extend(ENTRY.pack(r.fork, r.rid, r.typ, r.attrs, len(r.name), 0,
                              noff, doff, len(r.body)))
    out.extend(names)
    out.extend(data)
    return bytes(out)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        raise SystemExit(__doc__)
    specs: list[tuple[str, str]] = []
    for arg in argv[2:]:
        if "=" not in arg:
            raise SystemExit(f"expected LABEL=PATH, got {arg!r}")
        label, path = arg.split("=", 1)
        if not label or not os.path.isfile(path):
            raise SystemExit(f"invalid resource fork {arg!r}")
        specs.append((label, path))
    packed = build(specs)
    with open(argv[1], "wb") as f:
        f.write(packed)
    count = HEADER.unpack_from(packed)[3]
    print(f"{argv[1]}: {len(specs)} forks, {count} resources, {len(packed)} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
