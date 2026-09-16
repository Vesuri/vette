#!/usr/bin/env python3
"""Wrap a macOS file (data fork + resource fork + Finder info) as MacBinary II.

WHY this exists: `hfsutils`' `hcopy -m` is the only way to put a file on an HFS
volume with BOTH forks intact, and it takes MacBinary as input -- but nothing on a
modern macOS produces MacBinary.  `unar` unpacks a .sit into real forked files
(resource fork in the `com.apple.ResourceFork` xattr, type/creator in
`com.apple.FinderInfo`), and this turns one of those back into MacBinary.

    python3 tools/macbin.py "tmp/macsbug/MacsBug 6.2.2/MacsBug" tmp/macbin/
    hcopy -m tmp/macbin/MacsBug ":MacsBug"

WARNING: a Mac application's code lives in the RESOURCE fork.  Copy one without
its fork and you get a file that exists, has the right size on the data side, and
cannot be launched -- the same silent-loss failure `CLAUDE.md` warns about for the
source archive.  This script fails loudly if the fork is missing rather than
writing a MacBinary with a zero-length resource fork.
"""
import os, struct, subprocess, sys

MAC_EPOCH_DELTA = 2082844800          # 1904-01-01 .. 1970-01-01, in seconds


def crc16_ccitt(data: bytes) -> int:
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def mac_time(unix_time: float) -> int:
    return max(0, min(0xFFFFFFFF, int(unix_time) + MAC_EPOCH_DELTA))


def encode(path: str, require_rsrc: bool = True) -> bytes:
    name = os.path.basename(path).encode("mac-roman")
    if not 1 <= len(name) <= 63:
        raise SystemExit(f"{path}: name must be 1-63 bytes as MacRoman, got {len(name)}")

    with open(path, "rb") as f:
        data = f.read()
    # macOS python has no os.getxattr (it is Linux-only), and the two forks/attrs
    # are reachable another way on HFS+/APFS: the resource fork as a named fork in
    # the filesystem, the Finder info through the `xattr` tool.
    try:
        with open(os.path.join(path, "..namedfork", "rsrc"), "rb") as f:
            rsrc = f.read()
    except OSError:
        rsrc = b""
    finfo = b"\0" * 32
    try:
        hexed = subprocess.run(["xattr", "-px", "com.apple.FinderInfo", path],
                               capture_output=True, text=True, check=True).stdout
        finfo = bytes.fromhex(hexed.replace("\n", " ").replace(" ", "")).ljust(32, b"\0")
    except (subprocess.CalledProcessError, ValueError, FileNotFoundError):
        pass
    if require_rsrc and not rsrc and finfo[0:4] in (b"APPL", b"dbgr", b"DATA"):
        raise SystemExit(f"{path}: type {finfo[0:4]!r} but NO resource fork -- refusing to "
                         f"write a MacBinary that would silently lose the code")

    st = os.stat(path)
    h = bytearray(128)
    h[1] = len(name)
    h[2:2 + len(name)] = name
    h[65:73] = finfo[0:8]                       # type + creator
    h[73] = finfo[8]                            # Finder flags, high byte
    h[75:81] = finfo[10:16]                      # icon position + folder id
    struct.pack_into(">II", h, 83, len(data), len(rsrc))
    struct.pack_into(">II", h, 91, mac_time(st.st_birthtime if hasattr(st, "st_birthtime")
                                            else st.st_mtime), mac_time(st.st_mtime))
    h[101] = finfo[9]                            # Finder flags, low byte
    h[122] = h[123] = 129                        # MacBinary II
    struct.pack_into(">H", h, 124, crc16_ccitt(bytes(h[0:124])))

    pad = lambda b: b + b"\0" * (-len(b) % 128)
    return bytes(h) + pad(data) + pad(rsrc)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(__doc__)
    *srcs, out_dir = sys.argv[1:]
    os.makedirs(out_dir, exist_ok=True)
    for src in srcs:
        blob = encode(src)
        dst = os.path.join(out_dir, os.path.basename(src))
        with open(dst, "wb") as f:
            f.write(blob)
        print(f"{src} -> {dst}  ({len(blob)} B)")
