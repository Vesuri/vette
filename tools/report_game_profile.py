#!/usr/bin/env python3
"""Summarize FS-UAE/Barto cycle traces, including disk-loaded original CODE.

Capture format follows grahambates/fs-uae remote_debugger_barto and
BartmanAbyss/vscode-amiga-debug src/backend/profile.ts (17 saved registers).
Use CODE_PROFILE=1 and amiga/parked_game_profile.gdb; no unwind file is needed.
"""
import argparse
from collections import Counter
import json
import mmap
from pathlib import Path
import re
import struct

NAMES = ['CODE0', 'MAIN', 'INITIALIZE', 'COMMUNICATION', 'LOAD', 'SCORE',
         'TRAFFIC', 'FRED', 'INTRO', 'SOUND', 'A5INIT']


def decode(path, output):
    counts = Counter()
    frame_totals = []
    with path.open('rb') as source, mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as data:
        offset = 0

        def word():
            nonlocal offset
            value = struct.unpack_from('<I', data, offset)[0]
            offset += 4
            return value

        def skip(size):
            nonlocal offset
            if size < 0 or offset + size > len(data):
                raise ValueError('truncated profile')
            offset += size

        frames = word()
        sections = [word() for _ in range(word())]
        if not sections or not 1 <= frames <= 100:
            raise ValueError('expected executable profile with 1..100 PAL fields')
        skip(16)  # stack bounds
        for _ in range(3):  # ROM, chip RAM, bogo RAM
            skip(word())
        clock, unit = word(), word()
        for frame in range(frames):
            custom = word()
            if custom != 520:
                raise ValueError(f'unsupported custom register layout: {custom}')
            skip(custom)
            aga = word()
            if aga not in (0, 1024):
                raise ValueError(f'unsupported AGA layout: {aga}')
            skip(aga)
            for _ in range(2):  # DMA and graphics-resource records
                size, count = word(), word()
                skip(size * count)
            cycles, idle, count = word(), word(), word()
            end = offset + 4 * count
            if end > len(data):
                raise ValueError('truncated instruction trace')
            pc = None
            accounted = 0
            while offset < end:
                value = word()
                if value < 0xffff0000:
                    if pc is None:
                        pc = value
                else:
                    cost = 0xffffffff - value
                    # PCs in the executable are offsets from its first hunk;
                    # Kickstart PCs and the IRQ marker are absolute/special.
                    absolute = pc
                    if pc is not None and pc != 0x7fffffff and not 0xf80000 <= pc < 0x1000000:
                        absolute += sections[0]
                    counts[absolute] += cost
                    accounted += cost
                    skip(17 * 4)
                    pc = None
            if offset != end or pc is not None:
                raise ValueError('invalid instruction record boundary')
            # Small boundary rounding differences are normal; reject a wrong parser.
            if abs(accounted - cycles) > max(100, cycles // 1000):
                raise ValueError(f'cycle accounting mismatch: {accounted} vs {cycles}')
            frame_totals.append(dict(cycles=cycles, accounted=accounted, idle=idle))
            size, kind = word(), word()
            if frame in (0, frames - 1):
                (output / f'field-{frame:03d}.{ "jpg" if kind == 0 else "png"}').write_bytes(data[offset:offset + size])
            skip(size)
        if offset != len(data):
            raise ValueError('unexpected trailing data')
    return counts, dict(fields=frames, sections=sections, base_clock=clock,
                        cycle_unit=unit, field_totals=frame_totals)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace', type=Path)
    parser.add_argument('log', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    log = args.log.read_text()
    if 'PASS parked original-code profile' not in log or 'FAIL:' in log:
        raise ValueError('capture log does not prove a successful stationary workload')
    segments = [(int(i), int(a), int(b)) for i, a, b in
                re.findall(r'^SEG (\d+) (\d+) (\d+)$', log, re.M)]
    if len(segments) != 11:
        raise ValueError('capture log must contain all eleven runtime segment ranges')
    pcs, metadata = decode(args.trace, args.output)
    total = sum(pcs.values())
    categories, blocks = Counter(), Counter()
    for pc, cycles in pcs.items():
        for segment, start, end in segments:
            if pc is not None and start <= pc < end:
                categories[NAMES[segment]] += cycles
                blocks[(segment, (pc - start) // 64 * 64)] += cycles
                break
        else:
            category = ('external/unrecorded' if pc is None else
                        'IRQ transition' if pc == 0x7fffffff else
                        'Kickstart' if 0xf80000 <= pc < 0x1000000 else
                        'port / other resident code')
            categories[category] += cycles
    original = sum(categories[n] for n in NAMES)
    if not original:
        raise ValueError('no original-code PCs captured; use CODE_PROFILE=1')
    lines = [f'# Original-game profile', '',
             f'{metadata["fields"]} PAL fields; {total:,} accounted emulator cycle units.', '',
             '| Code | Share of capture |', '| --- | ---: |']
    for name, cycles in categories.most_common():
        lines.append(f'| {name} | {100 * cycles / total:.2f}% |')
    lines += ['', f'Original CODE total: **{100 * original / total:.2f}%**.', '',
              'Top original-code 64-byte regions (self time, not inclusive call time):', '',
              '| Segment + offset | Whole capture | Original code |', '| --- | ---: | ---: |']
    for (segment, offset), cycles in blocks.most_common(25):
        lines.append(f'| {NAMES[segment]} + ${offset:04X} | {100 * cycles / total:.2f}% | {100 * cycles / original:.2f}% |')
    lines += ['', 'These are emulator cycle measurements from a diagnostic memory layout, not hardware benchmark timings.',
              'Each field is independently checked against its recorded elapsed cycles.']
    (args.output / 'report.md').write_text('\n'.join(lines) + '\n')
    metadata.update(total=total, original=original, categories=categories,
                    segments=segments, pcs={str(k): v for k, v in pcs.items()})
    (args.output / 'profile.json').write_text(json.dumps(metadata, indent=2) + '\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
