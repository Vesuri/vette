#!/usr/bin/env python3
"""Compare direct GWorld rows with retained CopyBits or materialized screen bytes."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--shadow', type=int, help='number of paired moving-frame captures')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1] / 'tmp'
pairs = [(root / 'direct-c2p-source.raw', root / 'direct-c2p-screen.raw')]
if args.shadow is not None:
    assert args.shadow > 0
    pairs = [(root / f'direct-shadow-source-{i}.raw',
              root / f'direct-shadow-screen-{i}.raw') for i in range(args.shadow)]
for source_path, screen_path in pairs:
    source, screen = source_path.read_bytes(), screen_path.read_bytes()
    assert len(source) == 83200 and len(screen) == 81920
    packed = b''.join(source[y * 260:y * 260 + 256] for y in range(320))
    assert packed == screen, f'{source_path.name}: publication differs from direct source'
print(f'PASS: {len(pairs)} complete 512x320 publications match byte for byte')
