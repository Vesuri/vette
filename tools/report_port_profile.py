#!/usr/bin/env python3
"""Resolve non-original PCs using the exact ELF saved with a game profile.

All percentages are self time. The decoder reports PCs relative to the first
code hunk; use its captured relocation base, never a later build's addresses.
This is an execution-location breakdown, not a Macintosh slowdown estimate.
"""
import argparse
from bisect import bisect_right
from collections import Counter
import json
from pathlib import Path
import re
import subprocess


def text_symbols(elf, objdump):
    headers = subprocess.check_output([objdump, '-h', str(elf)], text=True)
    match = re.search(r'^\s*\d+\s+\.text\s+([0-9a-f]+)\s+([0-9a-f]+)', headers, re.M)
    if not match:
        raise ValueError('ELF has no .text section')
    size, origin = (int(v, 16) for v in match.groups())
    if origin != 0:
        raise ValueError('expected the port executable with .text linked at zero')
    symbols = {}
    table = subprocess.check_output([objdump, '-t', '-C', str(elf)], text=True)
    for line in table.splitlines():
        match = re.match(r'^([0-9a-f]+)\s+(.+?)\s+\.text\s+([0-9a-f]+)\s+(.+)$', line)
        if not match:
            continue
        address, flags, length, name = match.groups()
        address, length = int(address, 16), int(length, 16)
        if 'd' in flags.split() or (length and 'F' not in flags.split()):
            continue
        symbols[address] = (length, name)
    starts = sorted(symbols)
    ranges = []
    for i, start in enumerate(starts):
        length, name = symbols[start]
        # Assembly entry points have no ELF size. Their following symbol (or
        # the section end) bounds them; do not extend sized C++ functions.
        end = start + length if length else (starts[i + 1] if i + 1 < len(starts) else size)
        ranges.append((start, end, name))
    return starts, ranges


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', type=Path)
    parser.add_argument('elf', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--objdump', default='m68k-amiga-elf-objdump')
    args = parser.parse_args()
    data = json.loads(args.profile.read_text())
    base = data['sections'][0]
    starts, ranges = text_symbols(args.elf, args.objdump)
    costs, pcs = Counter(), {}
    for key, cycles in data['pcs'].items():
        if key == 'None':
            continue
        pc = int(key)
        if pc == 0x7fffffff or 0xf80000 <= pc < 0x1000000:
            continue
        if any(start <= pc < end for _, start, end in data['segments']):
            continue
        relative = pc - base
        index = bisect_right(starts, relative) - 1
        name = 'unmapped resident code'
        if index >= 0:
            start, end, candidate = ranges[index]
            if start <= relative < end:
                name = candidate
        costs[name] += cycles
        pcs.setdefault(name, []).append((relative, cycles))
    port_total = data['categories']['port / other resident code']
    if sum(costs.values()) != port_total:
        raise ValueError('function totals do not match the recorded resident-code category')
    rows = [dict(name=name, cycles=cycles, total_pct=100 * cycles / data['total'],
                 port_pct=100 * cycles / port_total, pcs=sorted(pcs[name]))
            for name, cycles in costs.most_common()]
    lines = ['# Port and resident-code self time', '',
             'Resolved against the diagnostic ELF saved with this capture. ',
             'This partitions Amiga execution time; it does not measure slowdown versus Macintosh.', '',
             '| Function | Whole capture | Resident port category |', '| --- | ---: | ---: |']
    for row in rows:
        lines.append(f'| `{row["name"]}` | {row["total_pct"]:.3f}% | {row["port_pct"]:.2f}% |')
    lines += ['', 'Callees are counted separately, so these rows can be added without double counting.',
              'System/unknown and original-segment time remain in the main report.',
              'Inlined work, including diagnostic counters, is charged to its enclosing function.',
              'Memory access delays are charged to the executing instructions; this does not isolate bus stalls.']
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'port-functions.json').write_text(json.dumps(rows, indent=2) + '\n')
    (args.output / 'port-report.md').write_text('\n'.join(lines) + '\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
