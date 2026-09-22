#!/usr/bin/env python3
"""Install Vette's two original resource forks from the shipped disk image.

The input may be the original NDIF ``VETTE!.img`` (with its resource fork
preserved) or a raw HFS image previously produced by ``ndif2raw.py``.  The
output files are the unmodified resource forks consumed by the Amiga program;
no game data is copied into the executable or repacked into a custom archive.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
from pathlib import Path

from hfs_extract import HFS
from ndif2raw import decode_ndif, named_resource_fork
from resource_fork import parse_resource_fork


FILES = (
    ("VETTE!/VETTE! Folder/(Folder) Color VETTE!/Color VETTE!",
     "Color VETTE!", 1_587_389,
     "77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b", 341),
    ("VETTE!/VETTE! Folder/(Folder) Color VETTE!/VETTE!.Data",
     "VETTE!.Data", 577_498,
     "e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f", 231),
)


def image_bytes(path: Path) -> bytes:
    data = path.read_bytes()
    raw_size = 0
    if len(data) >= 1186 and data[1024:1026] == b"BD":
        blocks, block_size, _, allocation_start = struct.unpack(">HIIH", data[1042:1054])
        raw_size = allocation_start * 512 + blocks * block_size
    # NDIF leaves the early sectors literal, including a convincing MDB.  Its
    # data fork is nevertheless much shorter than the volume geometry recorded
    # in that MDB; only a raw image covers the complete allocation area.
    if raw_size and len(data) >= raw_size:
        print(f"{path}: raw HFS image")
        return data
    print(f"{path}: NDIF image; decoding in memory")
    return decode_ndif(data, named_resource_fork(str(path)), verbose=False)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path, help="original VETTE!.img or converted raw HFS image")
    parser.add_argument("destination", type=Path,
                        help="directory containing the Amiga Vette executable")
    args = parser.parse_args()

    volume = HFS(image_bytes(args.image))
    installed = []
    for source, name, expected_size, expected_hash, expected_count in FILES:
        item = volume.find(source)
        body = volume.rsrc_fork(item)
        digest = hashlib.sha256(body).hexdigest()
        resources = parse_resource_fork(body, source)
        if (len(body) != expected_size or digest != expected_hash
                or len(resources) != expected_count):
            raise SystemExit(
                f"{source}: unsupported original data (size {len(body)}, "
                f"SHA-256 {digest}, resources {len(resources)})")
        installed.append((name, body, digest, len(resources)))

    args.destination.mkdir(parents=True, exist_ok=True)
    for name, body, digest, count in installed:
        target = args.destination / name
        target.write_bytes(body)
        print(f"installed {target}: {len(body)} bytes, {count} resources, "
              f"SHA-256 {digest}")
if __name__ == "__main__":
    main()
