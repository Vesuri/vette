#!/usr/bin/env python3
"""List classic MENU resource titles and item labels from a Macintosh fork."""

import argparse
from pathlib import Path

from hfs_extract import resources


def decode_menu(body: bytes):
    if len(body) < 16:
        raise ValueError("MENU resource is shorter than its fixed header")
    title_length = body[14]
    offset = 15 + title_length
    if offset >= len(body):
        raise ValueError("MENU title extends beyond the resource")
    title = body[15:offset].decode("mac_roman")
    items = []
    while body[offset]:
        length = body[offset]
        end = offset + 5 + length
        if end > len(body):
            raise ValueError("MENU item extends beyond the resource")
        items.append(body[offset + 1:offset + 1 + length].decode("mac_roman"))
        offset = end
    return title, items


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("resource_fork", type=Path)
    args = parser.parse_args()
    menus = resources(args.resource_fork.read_bytes()).get("MENU", [])
    if not menus:
        raise SystemExit("resource fork contains no MENU resources")
    for resource_id, _, body in menus:
        title, items = decode_menu(body)
        print(f"MENU {resource_id}: {title!r}")
        for index, item in enumerate(items, 1):
            print(f"  {index}: {item}")


if __name__ == "__main__":
    main()
