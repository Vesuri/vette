#!/usr/bin/env python3
"""Gate the checked-in Vette static map against the locally extracted Color build.

The copyrighted CODE bytes and generated listings remain local.  This check
therefore validates them against the curated, distributable map instead of
copying either source material or disassembly into the repository.
"""

import csv
import contextlib
import io
import re
import struct
from pathlib import Path

from code0_entrypoints import generate
from m68k_lowmem import scan as scan_low_memory


ROOT = Path(__file__).resolve().parent.parent
SEGMENTS = {
    0: ("CODE_00.bin", 4088, 509),
    1: ("CODE_01_Main.bin", 24994, 130),
    2: ("CODE_02_Initialize.bin", 7032, 16),
    3: ("CODE_03_Communication.bin", 9110, 16),
    4: ("CODE_04_load.bin", 1668, 1),
    5: ("CODE_05_Score.bin", 4628, 9),
    6: ("CODE_06_Traffic.bin", 27958, 80),
    7: ("CODE_07_FRED.bin", 6508, 242),
    8: ("CODE_08_Intro.bin", 3442, 2),
    9: ("CODE_09_sound.bin", 732, 12),
    10: ("CODE_10__A5Init.bin", 28732, 1),
}
TRAP_SITES = {1: 537, 2: 290, 3: 184, 4: 118, 5: 113,
              6: 40, 7: 0, 8: 146, 9: 1, 10: 1}
LISTING_CODE_BYTES = {1: 22882, 2: 6194, 3: 8682, 4: 1428, 5: 3260,
                      6: 27504, 7: 6504, 8: 2762, 9: 622, 10: 276}


def fail(message):
    raise SystemExit(f"static-map: {message}")


def extracted_segments():
    directory = ROOT / "tmp/seg_color"
    result = {}
    for segment, (name, expected_size, _) in SEGMENTS.items():
        path = directory / name
        if not path.is_file():
            fail(f"missing local extraction {path}")
        data = path.read_bytes()
        if len(data) != expected_size:
            fail(f"{name}: expected {expected_size} bytes, found {len(data)}")
        result[segment] = data
    return result


def check_jump_table(segments):
    with contextlib.redirect_stderr(io.StringIO()):
        generated = generate(segments[0])
    checked_in = (ROOT / "ghidra_scripts/entrypoints.csv").read_text()
    if generated != checked_in:
        fail("ghidra_scripts/entrypoints.csv is stale")
    counts = {segment: 0 for segment in range(1, 11)}
    rows = list(csv.DictReader(checked_in.splitlines()))
    for row in rows:
        segment = int(row["segment"])
        address = int(row["addr"], 0)
        if segment not in counts or not 4 <= address < len(segments[segment]):
            fail(f"invalid jump-table target {segment}:{address:#x}")
        counts[segment] += 1
    expected = {segment: values[2] for segment, values in SEGMENTS.items() if segment}
    if counts != expected or len(rows) != 509:
        fail(f"jump-table counts differ: {counts}")


def check_near_headers(segments):
    first_jump_byte = 0
    for segment in range(1, 11):
        first, count = struct.unpack_from(">HH", segments[segment])
        if count != SEGMENTS[segment][2]:
            fail(f"segment {segment}: near-header count {count}")
        if first != first_jump_byte:
            fail(f"segment {segment}: first jump-table byte is {first}, "
                 f"expected {first_jump_byte}")
        first_jump_byte += count * 8
    if first_jump_byte != 4072:
        fail(f"near headers cover {first_jump_byte} jump-table bytes")


def check_traps(segments):
    total = 0
    for segment, expected in TRAP_SITES.items():
        path = ROOT / f"tmp/CODE_{segment:02d}_traps.csv"
        if not path.is_file():
            fail(f"missing generated trap map {path}")
        rows = list(csv.DictReader(path.open()))
        if len(rows) != expected:
            fail(f"segment {segment}: expected {expected} trap sites, found {len(rows)}")
        seen = set()
        for row in rows:
            offset = int(row["offset"], 0)
            word = int(row["word"], 0)
            if offset in seen or not (0xA000 <= word <= 0xAFFF):
                fail(f"segment {segment}: invalid trap row at {offset:#x}")
            if offset + 2 > len(segments[segment]) \
                    or int.from_bytes(segments[segment][offset:offset + 2], "big") != word:
                fail(f"segment {segment}: trap bytes differ at {offset:#x}")
            seen.add(offset)
        total += len(rows)
    if total != 1430:
        fail(f"expected 1430 total trap sites, found {total}")


def check_listing_coverage(segments):
    instruction = re.compile(r"^[0-9a-fA-F]{8}  ((?:[0-9A-F]{2} )+)")
    classified_code = 0
    non_initializer_bytes = 0
    for segment in range(1, 11):
        path = ROOT / f"tmp/CODE_{segment:02d}_listing.txt"
        if not path.is_file():
            fail(f"missing generated listing {path}")
        code_bytes = 0
        for line in path.read_text().splitlines():
            match = instruction.match(line)
            if match:
                code_bytes += len(match.group(1).split())
        if code_bytes != LISTING_CODE_BYTES[segment]:
            fail(f"segment {segment}: listing defines {code_bytes} instruction bytes, "
                 f"expected {LISTING_CODE_BYTES[segment]}")
        classified_code += code_bytes
        if segment != 10:
            non_initializer_bytes += len(segments[segment]) - 4

    # CODE 10 consists of the measured 276-byte decoder followed by its packed
    # %A5Init stream.  CODE 0 and every four-byte near header are structural.
    unclassified = non_initializer_bytes - sum(
        LISTING_CODE_BYTES[segment] for segment in range(1, 10))
    classified = sum(len(data) for data in segments.values()) - unclassified
    return classified_code, unclassified, classified


def check_symbols(segments):
    path = ROOT / "disasm/symbols.csv"
    rows = list(csv.DictReader(path.open()))
    required = {"space", "segment", "offset", "name", "type", "evidence", "note"}
    if not rows or set(rows[0]) != required:
        fail("disasm/symbols.csv has the wrong schema")
    keys, names = set(), set()
    for row in rows:
        key = (row["space"], row["segment"], row["offset"])
        if key in keys or row["name"] in names:
            fail(f"duplicate symbol {row['name']} or location {key}")
        keys.add(key)
        names.add(row["name"])
        if row["evidence"] not in ("DERIVED", "MEASURED", "INFERRED"):
            fail(f"{row['name']}: invalid evidence class")
        if row["space"] == "code":
            segment = int(row["segment"])
            offset = int(row["offset"], 0)
            if segment not in segments or not 4 <= offset < len(segments[segment]):
                fail(f"{row['name']}: code location outside segment")
        elif row["space"] == "a5":
            offset = int(row["offset"], 0)
            if not -31272 <= offset < 4104:
                fail(f"{row['name']}: A5 offset outside shipped world")
        elif row["space"] == "lowmem":
            if not 0 <= int(row["offset"], 0) < 0x0C00:
                fail(f"{row['name']}: low-memory offset outside Page 0")
        else:
            fail(f"{row['name']}: unknown address space {row['space']}")
    if len(rows) < 40:
        fail(f"naming pass is unexpectedly small ({len(rows)} rows)")
    return len(rows)


def main():
    segments = extracted_segments()
    check_jump_table(segments)
    check_near_headers(segments)
    check_traps(segments)
    with contextlib.redirect_stdout(io.StringIO()):
        low_memory = scan_low_memory(str(ROOT / "tmp/seg_color"))
    if len(low_memory) != 108 or len({row[3] for row in low_memory}) != 17:
        fail("reachable low-memory inventory changed")
    code_bytes, unclassified, classified = check_listing_coverage(segments)
    symbols = check_symbols(segments)
    total = sum(len(data) for data in segments.values())
    print(f"PASS: 11 CODE resources, 509 exports, 1430 trap sites, "
          f"108 low-memory references, {symbols} curated symbols")
    print(f"      {classified}/{total} bytes classified ({100*classified/total:.1f}%); "
          f"{unclassified} bytes remain mixed inline data/padding")
    print(f"      Ghidra defines {code_bytes} instruction bytes; CODE 10's remaining "
          f"28452 bytes are its packed %A5Init stream")


if __name__ == "__main__":
    main()
