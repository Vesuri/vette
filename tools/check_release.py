#!/usr/bin/env python3
"""Audit the exact minimal LHA release and its header and payload checksums."""
import argparse
import hashlib
import struct
from pathlib import Path
from package_release import ORIGINAL_HASHES, PREFIX, crc16

REQUIRED = {"Vette", "Vette.slave", "Vette.info", "VetteInstallData", "Install", "Install.info", "README.txt"}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    raw = args.archive.read_bytes()
    pos = 0
    payloads = {}
    while pos < len(raw) and raw[pos]:
        size = raw[pos]
        header = raw[pos + 2:pos + 2 + size]
        assert len(header) == size and sum(header) & 255 == raw[pos + 1], "bad header checksum"
        assert header[:5] == b"-lh0-" and header[18] == 0, "unsupported header"
        packed, unpacked = struct.unpack_from("<II", header, 5)
        assert packed == unpacked
        n = header[19]
        assert size == 22 + n
        name = header[20:20 + n].decode("ascii").replace("\\", "/")
        if name == PREFIX + '.info':
            name = '@drawer'
        else:
            assert name.startswith(PREFIX + "/"), "wrong installation drawer"
            name = name[len(PREFIX) + 1:]
        assert name in REQUIRED | {'@drawer'} and name not in payloads, "unexpected or duplicate file"
        pos += size + 2
        data = raw[pos:pos + packed]
        assert len(data) == packed and crc16(data) == struct.unpack_from("<H", header, 20 + n)[0], "bad payload CRC"
        assert hashlib.sha256(data).hexdigest() not in ORIGINAL_HASHES
        payloads[name] = data
        pos += packed
    assert raw[pos:] == b"\0" and set(payloads) == REQUIRED | {'@drawer'}, "wrong archive contents"
    for name in ("Vette", "VetteInstallData", "Vette.slave"):
        assert payloads[name][:4] == b"\0\0\3\xf3", "not an Amiga HUNK executable"
    assert b'WHDLOADS' in payloads['Vette.slave'], 'missing WHDLoad slave header'
    for name, kind in (("Vette.info", 4), ("Install.info", 4), ('@drawer', 2)):
        assert payloads[name][:4] == b"\xe3\x10\0\1" and payloads[name][48] == kind
    assert b"$VER: Install 0.90 (23.09.2026)" in payloads["Install"]
    assert b'APPNAME=Vette!\0' in payloads['Install.info']
    assert b'Rescue on Fractalus' not in payloads['Install.info']
    assert b'WHDLoad\0' in payloads['Vette.info'] and b'SLAVE=Vette.slave\0' in payloads['Vette.info']
    assert b'PRELOAD\0' in payloads['Vette.info']
    print("PASS: WHDLoad release, seven files plus drawer icon, valid LHA CRCs, executables and icons")

if __name__ == "__main__":
    main()
