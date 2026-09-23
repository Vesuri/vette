#!/usr/bin/env python3
"""End-to-end, corruption and transaction tests. Original archive stays local."""
import hashlib
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "tmp/VETTE__1.02_and_extras.sit"
EXPECTED = {
    "Color VETTE!": "77e80078116e6aef0f257381466cf9cfc77108c75404138c002c68fbde7b896b",
    "VETTE!.Data": "e3db29fcc7b51a5275857bb06ff4ffb082d9aebb9f4045eb71ce23ba243a075f",
}

def crc16(data):
    crc = 0
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ (0xa001 if crc & 1 else 0)
    return crc

def stored_archive(resource, data):
    """A tiny independent StuffIt 5 encoder for malformed NDIF fixtures."""
    entry=bytearray(58)
    entry[:4]=b"\xa5"*4; entry[4]=1
    struct.pack_into(">H",entry,6,len(entry))
    struct.pack_into(">H",entry,30,10)
    struct.pack_into(">IIH",entry,34,len(data),len(data),crc16(data))
    entry[48:58]=b"VETTE!.img"
    struct.pack_into(">H",entry,32,crc16(entry))
    extra=bytearray(36); extra[1]=1
    extra+=struct.pack(">IIHHBB",len(resource),len(resource),crc16(resource),0,0,0)
    header=bytearray(100); header[:16]=b"StuffIt (c)1997-"; header[82]=5
    struct.pack_into(">I",header,84,len(header)+len(entry)+len(extra)+len(resource)+len(data))
    struct.pack_into(">HI",header,92,1,100)
    return header+entry+extra+resource+data

def ndif_resource(kind, compressed_length, sectors=1):
    blockmap=bytearray(128)
    struct.pack_into(">H",blockmap,0,11)
    struct.pack_into(">I",blockmap,68,sectors)
    struct.pack_into(">I",blockmap,124,2)
    blockmap+=struct.pack(">IIIIII",kind,0,compressed_length,(sectors<<8)|255,0,0)
    payload=struct.pack(">I",len(blockmap))+blockmap
    resource=bytearray(256)+payload
    resource[:16]=struct.pack(">IIII",256,len(resource),len(payload),50)
    resource_map=bytearray(50); struct.pack_into(">H",resource_map,24,28)
    resource_map[30:34]=b"bcem"; struct.pack_into(">H",resource_map,36,10)
    struct.pack_into(">H",resource_map,38,128)
    return resource+resource_map

def image_entry(data):
    pos = struct.unpack_from(">I", data, 94)[0]
    for _ in range(4096):
        assert data[pos:pos+4] == b"\xa5" * 4
        hs, nl = struct.unpack_from(">H", data, pos+6)[0], struct.unpack_from(">H", data, pos+30)[0]
        if data[pos+9] & 64 and data[pos+34:pos+38] == b"\xff"*4:
            pos += 48
            continue
        ext = pos + hs
        payload = ext + (36 if data[pos+4] == 1 else 32)
        resource = bool(struct.unpack_from(">H", data, ext)[0] & 1)
        rc = struct.unpack_from(">I", data, payload+4)[0] if resource else 0
        if resource:
            payload += 14
        dc = 0 if data[pos+9] & 64 else struct.unpack_from(">I", data, pos+38)[0]
        if data[pos+48:pos+48+nl] == b"VETTE!.img":
            return pos, hs, payload, rc, dc
        pos = payload + rc + dc
    raise AssertionError("No image entry")

def main():
    exe = Path(sys.argv[1]).resolve()
    if not SOURCE.exists():
        raise SystemExit("Original archive required locally: " + str(SOURCE))
    original = SOURCE.read_bytes()
    pos, hs, payload, rc, dc = image_entry(original)
    with tempfile.TemporaryDirectory(prefix="vette-install-test-") as temp:
        base = Path(temp)
        dest = base / "destination with spaces"
        scratch = base / "temporary with spaces"
        scratch.mkdir()
        def run(source, destination=dest, good=False):
            p = subprocess.run([str(exe), str(source), str(destination), str(scratch)], capture_output=True, text=True, timeout=45)
            assert p.returncode == (0 if good else 20), (p.returncode, p.stdout, p.stderr)
            assert not list(destination.glob(".vette-install-*")), p.stdout
            assert not list(destination.glob(".vette-publish-*")), p.stdout
            assert not list(scratch.iterdir()), p.stdout
            if not good:
                assert not (destination / "VETTE!.Data").exists(), p.stdout
            return p.stdout
        run(SOURCE, good=True)
        for name, digest in EXPECTED.items():
            assert hashlib.sha256((dest/name).read_bytes()).hexdigest() == digest
        before = {p.name: p.stat().st_mtime_ns for p in dest.iterdir()}
        run(SOURCE, good=True)
        assert before == {p.name: p.stat().st_mtime_ns for p in dest.iterdir()}
        bad_dest = base / "bad-destination"
        bad_dest.mkdir()
        sentinel = bad_dest / "Color VETTE!"
        sentinel.write_bytes(b"do not overwrite existing files")
        run(SOURCE, bad_dest)
        assert sentinel.read_bytes() == b"do not overwrite existing files"
        bad = base / "bad.sit"
        failed_dest = base / "failed"
        cases = []
        cases += [("truncated-header", original[:99]), ("truncated-payload", original[:payload+rc+40])]
        x = bytearray(original); x[pos+32] ^= 1; cases.append(("bad-header-crc", x))
        x = bytearray(original); x[payload+rc+dc//2] ^= 1; cases.append(("bad-data-crc", x))
        x = bytearray(original); x[payload] = 0xf0; cases.append(("bad-code-table", x))
        x = bytearray(original); x[payload+rc] = 0; x[payload+rc+1:payload+rc+40] = b"\xff"*39
        cases.append(("bad-dynamic-huffman", x))
        x = bytearray(original); struct.pack_into(">I",x,pos+38,0xffffffff)
        x[pos+32:pos+34] = b"\0\0"; struct.pack_into(">H",x,pos+32,crc16(x[pos:pos+hs]))
        cases.append(("payload-offset-overflow", x))
        for label, data in cases:
            bad.write_bytes(data); run(bad, failed_dest); print("PASS:",label)
        # Every sampled single-byte corruption must fail cleanly, never hang/crash.
        for delta in range(0,160,7):
            x=bytearray(original); x[payload+rc+delta] ^= 0x81; bad.write_bytes(x)
            run(bad, failed_dest)
        for label, rsrc, data, expected_error in (
            ("adc-before-history",ndif_resource(131,2),b"\0\0","back-reference"),
            ("adc-truncated-literal",ndif_resource(131,1),b"\xff","Truncated compressed"),
            ("ndif-unknown-method",ndif_resource(129,1),b"\0","Unsupported NDIF chunk"),
            ("ndif-raw-size",ndif_resource(2,1),b"\0","raw NDIF chunk size"),
            ("ndif-resource-header",b"\xff"*780,b"\0","resource map"),
            ("hfs-invalid-signature",ndif_resource(2,2048,4),bytes(2048),"HFS volume signature"),
        ):
            bad.write_bytes(stored_archive(rsrc,data))
            report=run(bad,failed_dest)
            assert expected_error in report, (label,report)
            print("PASS:",label)
        print("PASS: exact original files, repeat install, existing-file preservation, cleanup, 30 corrupt archives")

if __name__ == "__main__":
    main()
