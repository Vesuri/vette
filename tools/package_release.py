#!/usr/bin/env python3
"""Create the minimal deterministic Amiga LHA distribution (LH5)."""
import argparse
from pathlib import Path
import _amigaxdev  # noqa: F401
from amigaxdev import release
from amigaxdev.release import crc16  # noqa: F401  (check_release.py imports it from here)

ORIGINAL_HASHES = {
    "77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b",
    "e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f",
}
PREFIX = "Vette! Install"
STAMP = release.dos_stamp(2026, 9, 25)
ICONS = Path(__file__).resolve().parent.parent / "release/icons"

def installer_icon(game=False):
    # Vette!.inf is distributed as is, renamed and configured by Installer, exactly
    # as RoF.inf in the reference package. No synthetic replacement artwork.
    return release.installer_icon(ICONS, "Vette!", game=game)

def drawer_icon():
    return release.template_icon(ICONS, "drawer.info.b64")

def readme_icon():
    return release.template_icon(ICONS, "readme.info.b64")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    version = (root / "VERSION").read_text().strip()
    files = {
        "Vette!": args.executable.read_bytes(),
        "Vette!.slave": (root / "build/whdload/Vette!.slave").read_bytes(),
        "Vette!.inf": installer_icon(game=True),
        "VetteInstallData": (root / "build/install-data/VetteInstallData.exe").read_bytes(),
        "Install": (root / "release/Install").read_bytes(),
        "Install.info": installer_icon(),
        "ReadMe.info": readme_icon(),
        "ReadMe": (root / "release/ReadMe").read_bytes(),
        "LICENSE.LGPL.txt": (root / "tools/install-data/COPYING.LIB").read_bytes(),
    }
    release.refuse_originals(files, ORIGINAL_HASHES)
    archive = release.write(args.output_directory / f"Vette-{version}.lha",
                            release.archive(PREFIX, files, drawer_icon(), STAMP))
    print(f"{archive}: {len(files)} drawer contents plus drawer icon, {archive.stat().st_size} bytes")

if __name__ == "__main__":
    main()
