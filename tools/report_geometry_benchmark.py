#!/usr/bin/env python3
"""Validate and summarize matched geometry and cumulative optimization benchmark stages."""
import argparse
from pathlib import Path
import re
from statistics import mean


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', nargs='?', type=Path, default=Path('tmp/geometry-benchmark'))
    parser.add_argument('--combined', action='store_true',
                        help='include the full-copy baseline and report cumulative gains')
    args = parser.parse_args()
    stages = {}
    signatures = set()
    names = ('legacy', 'base', 'optimized') if args.combined else ('base', 'optimized')
    for stage in names:
        samples = []
        for run in (1, 2):
            log = (args.directory / f'{stage}-{run}.log').read_text()
            if 'PASS parked benchmark' not in log or 'FAIL' in log:
                raise ValueError(f'{stage}-{run}: missing successful observer result')
            match = re.search(r'^BENCH (.+)$', log, re.M)
            if not match:
                raise ValueError('missing BENCH record')
            data = dict(item.split('=') for item in match[1].split())
            if int(data['frames']) != 120 or int(data['iterations']) != 120:
                raise ValueError('expected exactly 120 complete frames and iterations')
            if (int(data['x']), int(data['z'])) != (45184, 66563):
                raise ValueError('wrong parked scene')
            signatures.add((data['x'], data['z'], data['objects']))
            samples.append(float(data['ms_per_frame']))
        stages[stage] = samples
    if len(signatures) != 1:
        raise ValueError('position/object-count checks differ across runs')
    baseline = mean(stages[names[0]])
    print('| Version | Mean ms/frame | FPS | Frame-time reduction | Repeat range (ms) |')
    print('| --- | ---: | ---: | ---: | ---: |')
    for name, values in stages.items():
        elapsed = mean(values)
        print(f'| {name} | {elapsed:.3f} | {1000/elapsed:.3f} | '
              f'{100*(1-elapsed/baseline):.2f}% | {min(values):.3f}–{max(values):.3f} |')


if __name__ == '__main__':
    main()
