#!/usr/bin/env python3
"""Check and summarize two matching 120-frame PAL runs of each optimization stage."""
import argparse
import re
from pathlib import Path
from statistics import mean

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('folder', nargs='?', type=Path, default=Path('tmp/optimization'))
args = parser.parse_args()
rows = []
workload = None
for stage, label in [('legacy', 'Full-frame copy baseline'), ('direct', 'Direct C2P'),
                     ('port', 'Plus port bookkeeping fixes'), ('game', 'Plus game copy-loop optimization')]:
    times = []
    for repeat in (1, 2):
        path = args.folder / f'{stage}-{repeat}.log'
        text = path.read_text()
        if 'PASS parked benchmark' not in text or 'FAIL' in text:
            raise SystemExit(f'Incomplete or failed benchmark: {path}')
        lines = re.findall(r'^BENCH (.+)$', text, re.M)
        if len(lines) != 1:
            raise SystemExit(f'Expected one measured window: {path}')
        values = dict(item.split('=') for item in lines[0].split())
        key = tuple(values[k] for k in ('iterations', 'frames', 'x', 'z', 'objects'))
        if key[:2] != ('120', '120') or workload is not None and key != workload:
            raise SystemExit(f'Unmatched workload: {path}: {key} vs {workload}')
        workload = key
        times.append(float(values['ms_per_frame']))
    rows.append((label, times))
baseline = mean(rows[0][1])
print('| Version | Mean ms/frame | FPS | Frame time reduction | Repeat range (ms) |')
print('| --- | ---: | ---: | ---: | ---: |')
for label, times in rows:
    elapsed = mean(times)
    print(f'| {label} | {elapsed:.3f} | {1000/elapsed:.3f} | '
          f'{100*(baseline-elapsed)/baseline:.2f}% | {min(times):.3f}–{max(times):.3f} |')
