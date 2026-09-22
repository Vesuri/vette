#!/usr/bin/env python3
"""Gate the live three-context Paula regression captured by GDB."""

import argparse
import re
from pathlib import Path


TRIPLE = re.compile(
    r"^overlap triple .* level=(\d+) contexts=(\d+)/(\d+)/(\d+) "
    r"channels=(\d+)/(\d+)/(\d+) volumes=(\d+)/(\d+)/(\d+)/(\d+)",
    re.MULTILINE,
)
SETTLED = re.compile(
    r"^overlap replacement settled .* replaced-context=(\d+) level=(\d+) "
    r"contexts=(\d+)/(\d+)/(\d+) channels=(\d+)/(\d+)/(\d+) "
    r"playing=(\d+)/(\d+)/(\d+) volumes=(\d+)/(\d+)/(\d+)/(\d+)",
    re.MULTILINE,
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    args = parser.parse_args()
    text = args.log.read_text(errors="replace")

    if "overlap loud stop" in text:
        raise SystemExit("FAIL: loud stop during audio overlap regression")

    triple = TRIPLE.search(text)
    if not triple:
        raise SystemExit("FAIL: no engine/skid/crash triple-overlap checkpoint")
    triple_values = tuple(map(int, triple.groups()))
    level = triple_values[0]
    contexts = triple_values[1:4]
    channels = triple_values[4:7]
    volumes = triple_values[7:11]
    if level != 300:
        raise SystemExit(f"FAIL: shipped Bogas level is {level}, expected 300")
    if contexts != (4, 6, 8):
        raise SystemExit(f"FAIL: overlap contexts are {contexts}, expected (4, 6, 8)")
    if channels != (0, 3, 2):
        raise SystemExit(f"FAIL: context channels are {channels}, expected (0, 3, 2)")
    if volumes != (64, 64, 64, 64):
        raise SystemExit(f"FAIL: Paula volumes are {volumes}, expected four voices at 64")

    settled = SETTLED.search(text)
    if not settled:
        raise SystemExit("FAIL: no independent context-replacement checkpoint")
    settled_values = tuple(map(int, settled.groups()))
    replaced = settled_values[0]
    settled_level = settled_values[1]
    settled_channels = settled_values[5:8]
    playing = settled_values[8:11]
    settled_volumes = settled_values[11:15]
    if replaced not in (1, 2):
        raise SystemExit(f"FAIL: invalid replaced context {replaced}")
    if settled_level != 300 or settled_channels != (0, 3, 2):
        raise SystemExit("FAIL: Bogas level or fixed Paula ownership changed after replacement")
    if playing != (1, 1, 1):
        raise SystemExit(f"FAIL: replacement disturbed a context: playing={playing}")
    if settled_volumes != (64, 64, 64, 64):
        raise SystemExit(f"FAIL: replacement changed Paula volumes: {settled_volumes}")

    print("PASS: engine/horn/crash occupy contexts 0/1/2 on AUD0+1/AUD3/AUD2")
    print("PASS: Bogas level 300 maps to Paula volume 64 on all four active voices")
    print(f"PASS: replacing context {replaced} leaves all three contexts active")


if __name__ == "__main__":
    main()
