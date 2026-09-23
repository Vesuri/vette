#!/usr/bin/env python3
"""Audit a Vette Amiga release ZIP and its embedded checksum manifest."""

import argparse
import hashlib
import zipfile
from pathlib import PurePosixPath


ORIGINAL_HASHES = {
    "77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b",
    "e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f",
}
REQUIRED = {
    "Vette", "Vette.info", "README.txt", "Vette.fs-uae", "SHA256SUMS",
    "VetteInstallData", "Install", "Install.info",
    "fs-uae/dh0/s/startup-sequence", "docs/install-original-data.md",
    "host-tools/install_original_data.py", "host-tools/ndif2raw.py",
    "host-tools/hfs_extract.py", "host-tools/resource_fork.py",
}
REQUIRED |= {"installer-source/" + name for name in (
    "COPYING.LIB", "Makefile", "README.md", "install.c", "io.h", "io_unix.c",
    "io_amiga.c", "sha256.c", "sha256.h", "sit13_tables.h", "start.s",
    "test_install.py", "test_amiga.py", "test_icon.c", "test_installer_script.py",
)}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive")
    args = parser.parse_args()
    with zipfile.ZipFile(args.archive) as source:
        bad = source.testzip()
        if bad:
            raise SystemExit(f"ZIP integrity failure: {bad}")
        names = source.namelist()
        roots = {PurePosixPath(name).parts[0] for name in names}
        if len(roots) != 1:
            raise SystemExit(f"release must have one root directory, got {sorted(roots)}")
        root = next(iter(roots))
        relative = {str(PurePosixPath(name).relative_to(root)) for name in names}
        if relative != REQUIRED:
            raise SystemExit(f"unexpected release members: missing={sorted(REQUIRED-relative)}, "
                             f"extra={sorted(relative-REQUIRED)}")
        payloads = {str(PurePosixPath(name).relative_to(root)): source.read(name)
                    for name in names}
        for name, data in payloads.items():
            if sha256(data) in ORIGINAL_HASHES:
                raise SystemExit(f"copyrighted original resource fork included as {name}")
        if payloads["Vette"][:4] != b"\x00\x00\x03\xf3":
            raise SystemExit("Vette is not an Amiga HUNK executable")
        if payloads["VetteInstallData"][:4] != b"\x00\x00\x03\xf3":
            raise SystemExit("VetteInstallData is not an Amiga HUNK executable")
        if payloads["Install.info"][:4] != b"\xe3\x10\x00\x01":
            raise SystemExit("Installer Workbench icon is missing or invalid")
        if payloads["Vette.info"][:4] != b"\xe3\x10\x00\x01" or payloads["Vette.info"][48] != 3:
            raise SystemExit("Game Workbench tool icon is missing or invalid")
        declared = {}
        for line in payloads["SHA256SUMS"].decode().splitlines():
            value, name = line.split("  ", 1)
            declared[name] = value
        actual = {name: sha256(data) for name, data in payloads.items()
                  if name != "SHA256SUMS"}
        if declared != actual:
            raise SystemExit("SHA256SUMS does not describe every packaged payload exactly")
    print(f"PASS: release archive has {len(REQUIRED)} expected files, valid checksums, "
          "an Amiga HUNK executable, and no original resource forks")


if __name__ == "__main__":
    main()
