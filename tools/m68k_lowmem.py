#!/usr/bin/env python3
"""Inventory reachable absolute references to Macintosh low memory ($0000-$0BFF).

The scan follows control flow from every CODE 0 jump-table entry.  It deliberately
does not linearly decode data.  Reported offsets include each CODE resource's four-byte
near-model header, matching the runtime loud-stop `(segment, offset)` convention.

Usage: python3 tools/m68k_lowmem.py [tmp/seg_color]
"""
import os
import re
import struct
import sys
from collections import Counter

from capstone import Cs, CS_ARCH_M68K, CS_MODE_M68K_000, CsError
from capstone.m68k import (M68K_AM_ABSOLUTE_DATA_LONG, M68K_AM_ABSOLUTE_DATA_SHORT,
                           M68K_OP_MEM)

from m68k_sweep import BRANCH, STOP, jump_table, target_of

md = Cs(CS_ARCH_M68K, CS_MODE_M68K_000)
md.detail = True


def references(code, roots):
    seen, todo, found, blind = set(), list(roots), [], 0
    while todo:
        pc = todo.pop()
        while 0 <= pc < len(code) and pc not in seen:
            word = struct.unpack_from(">H", code, pc)[0] if pc + 2 <= len(code) else 0
            if 0xA000 <= word <= 0xAFFF:
                seen.add(pc); seen.add(pc + 1); pc += 2
                continue
            insn = next(iter(md.disasm(code[pc:pc + 16], pc, count=1)), None)
            if insn is None or insn.size == 0 or insn.mnemonic.lower() == "dc.w":
                break
            for byte in range(insn.size):
                seen.add(pc + byte)
            try:
                operands = insn.operands
            except CsError:
                operands = []
            for operand in operands:
                if operand.type == M68K_OP_MEM and operand.address_mode in (
                        M68K_AM_ABSOLUTE_DATA_SHORT, M68K_AM_ABSOLUTE_DATA_LONG):
                    # Capstone exposes the absolute effective address through the
                    # operand union's `imm` member (not mem.disp) for both forms.
                    address = operand.imm & 0xffffffff
                    if address < 0x0c00:
                        found.append((pc, address, insn.mnemonic, insn.op_str,
                                      code[pc:pc + insn.size].hex()))
            mnemonic = insn.mnemonic.lower().split(".")[0]
            if BRANCH.match(mnemonic):
                target = target_of(insn)
                if target is not None and 0 <= target < len(code):
                    if target not in seen: todo.append(target)
                else:
                    blind += 1
            if mnemonic in STOP:
                break
            pc += insn.size
    return found, blind


def selftest():
    code = bytes.fromhex("20380156 207809de 20390000016a 202d0004 7001 4e75")
    found, _ = references(code, [0])
    got = [(address, mnemonic) for _, address, mnemonic, _, _ in found]
    expected = [(0x0156, "move.l"), (0x09de, "movea.l"), (0x016a, "move.l")]
    if got != expected:
        raise SystemExit(f"self-test failed: expected {expected!r}, got {got!r}")


def scan(directory):
    segments = {}
    for filename in sorted(os.listdir(directory)):
        match = re.match(r"CODE_(\d+)", filename)
        if match:
            with open(os.path.join(directory, filename), "rb") as source:
                segments[int(match.group(1))] = (filename, source.read())
    entries, _, clean = jump_table(segments[0][1])
    if not clean:
        raise SystemExit("CODE 0 is not an intact unloaded jump table")
    roots = {}
    for segment, offset in entries:
        roots.setdefault(segment, set()).add(offset)

    all_found = []
    total_blind = 0
    for segment in sorted(segments):
        if segment == 0:
            continue
        filename, resource = segments[segment]
        found, blind = references(resource[4:], sorted(roots.get(segment, set())))
        total_blind += blind
        for pc, address, mnemonic, operands, encoding in found:
            all_found.append((segment, filename, pc + 4, address,
                              mnemonic, operands, encoding))

    print(f"{directory}: {len(all_found)} reachable low-memory references; "
          f"{total_blind} indirect/unresolved control transfers")
    counts = Counter(reference[3] for reference in all_found)
    locations = ", ".join(f"${address:04X} x{counts[address]}" for address in sorted(counts))
    print(f"  {len(counts)} distinct locations: {locations}")
    for segment, filename, offset, address, mnemonic, operands, encoding in all_found:
        print(f"  seg {segment:2d} {filename}+${offset:04X}  -> ${address:04X}  "
              f"{encoding:<16} {mnemonic:<9} {operands}")
    return all_found


if __name__ == "__main__":
    selftest()
    scan(sys.argv[1] if len(sys.argv) > 1 else "tmp/seg_color")
