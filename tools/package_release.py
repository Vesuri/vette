#!/usr/bin/env python3
"""Create the minimal deterministic Amiga LHA distribution (portable LH0)."""
import argparse
import hashlib
import struct
from pathlib import Path
from installer_icon import installer_icon

ORIGINAL_HASHES = {
    "77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b",
    "e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f",
}
PREFIX = "Vette! Install"

def crc16(data):
    crc = 0
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ (0xa001 if crc & 1 else 0)
    return crc

def member(name, data):
    # Generic level-zero header, stored data; no host archiver dependency.
    name = (PREFIX + "/" + name).replace("/", "\\").encode("ascii")
    stamp = (((2026 - 1980) << 9) | (9 << 5) | 23) << 16
    body = b"-lh0-" + struct.pack("<III", len(data), len(data), stamp)
    body += bytes((0x20, 0, len(name))) + name + struct.pack("<H", crc16(data))
    return bytes((len(body), sum(body) & 255)) + body + data

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    version = (root / "VERSION").read_text().strip()
    files = {
        "Vette": args.executable.read_bytes(),
        "Vette.info": installer_icon(game=True),
        "VetteInstallData": (root / "build/install-data/VetteInstallData.exe").read_bytes(),
        "Install": (root / "release/Install").read_bytes(),
        "Install.info": installer_icon(),
        # Keep the helper's license with its binary without adding another file.
        "README.txt": (root / "release/README.txt").read_bytes()
            + b"\n\nINSTALLER HELPER LICENSE\n\n"
            + (root / "tools/install-data/COPYING.LIB").read_bytes(),
    }
    for name, data in files.items():
        if hashlib.sha256(data).hexdigest() in ORIGINAL_HASHES:
            raise SystemExit("refusing to package original game data: " + name)
    args.output_directory.mkdir(parents=True, exist_ok=True)
    archive = args.output_directory / f"Vette-{version}.lha"
    temporary = archive.with_suffix(".lha.part")
    temporary.write_bytes(b"".join(member(name, data) for name, data in sorted(files.items())) + b"\0")
    temporary.replace(archive)
    print(f"{archive}: {len(files)} files, {archive.stat().st_size} bytes")

if __name__ == "__main__":
    main()
