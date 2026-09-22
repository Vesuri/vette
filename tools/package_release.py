#!/usr/bin/env python3
"""Create a deterministic, copyright-clean Vette Amiga release ZIP."""

from __future__ import annotations

import argparse
import hashlib
import stat
import zipfile
from pathlib import Path


ORIGINAL_HASHES = {
    "77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b",
    "e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f",
}
HOST_TOOLS = (
    "install_original_data.py",
    "ndif2raw.py",
    "hfs_extract.py",
    "resource_fork.py",
)
FIXED_TIME = (2026, 1, 1, 0, 0, 0)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def add_file(files: dict[str, tuple[bytes, int]], archive_name: str,
             source: Path, mode: int = 0o644) -> None:
    data = source.read_bytes()
    if digest(data) in ORIGINAL_HASHES:
        raise SystemExit(f"refusing to package copyrighted original data: {source}")
    files[archive_name] = (data, mode)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent
    version = (root / "VERSION").read_text().strip()
    prefix = f"Vette-Amiga-{version}"
    archive = args.output_directory / f"{prefix}.zip"
    files: dict[str, tuple[bytes, int]] = {}

    add_file(files, f"{prefix}/Vette", args.executable, 0o755)
    add_file(files, f"{prefix}/README.txt", root / "release/README.txt")
    add_file(files, f"{prefix}/Vette.fs-uae", root / "release/Vette.fs-uae")
    add_file(files, f"{prefix}/fs-uae/dh0/s/startup-sequence",
             root / "release/fs-uae/dh0/s/startup-sequence")
    add_file(files, f"{prefix}/docs/install-original-data.md",
             root / "docs/install-original-data.md")
    for tool in HOST_TOOLS:
        mode = 0o755 if tool in ("install_original_data.py", "ndif2raw.py",
                                "hfs_extract.py") else 0o644
        add_file(files, f"{prefix}/host-tools/{tool}", root / "tools" / tool, mode)

    manifest_lines = [
        f"{digest(data)}  {name.removeprefix(prefix + '/')}"
        for name, (data, _) in sorted(files.items())
    ]
    files[f"{prefix}/SHA256SUMS"] = (("\n".join(manifest_lines) + "\n").encode(), 0o644)

    args.output_directory.mkdir(parents=True, exist_ok=True)
    temporary = archive.with_suffix(".zip.part")
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as target:
        for name, (data, mode) in sorted(files.items()):
            info = zipfile.ZipInfo(name, FIXED_TIME)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.create_system = 3
            target.writestr(info, data)
    temporary.replace(archive)
    print(f"{archive}: {len(files)} files, {archive.stat().st_size} bytes")
    print(f"SHA-256 {digest(archive.read_bytes())}")


if __name__ == "__main__":
    main()
