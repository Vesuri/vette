#!/usr/bin/env python3
"""Fail if the gameplay coverage matrix refers to missing observers/switches."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
DOC = (ROOT / "docs/gameplay-coverage.md").read_text()

observers = sorted(set(re.findall(r"`([a-z0-9_-]+\.gdb)`", DOC)))
missing = [name for name in observers if not (ROOT / "amiga" / name).is_file()]
if missing:
    raise SystemExit("coverage matrix names missing observers: " + ", ".join(missing))

switches = sorted(set(re.findall(r"`([A-Z][A-Z0-9_]+)(?:=[^`]*)?`", DOC)))
makefile = (ROOT / "amiga/Makefile").read_text()
build_switches = [name for name in switches if name not in ("EXTRA_ARGS", "GDBSCRIPT")]
missing = [name for name in build_switches if name not in makefile]
if missing:
    raise SystemExit("coverage matrix names missing build switches: " + ", ".join(missing))

required_phrases = (
    "GARAGE_COURSE=1..4", "GARAGE_CAR=1..4", "GARAGE_OPPONENT=1..4",
    "GARAGE_DIFFICULTY=1..3", "Communications", "Tour Mode",
    "city → freeway", "far freeway → city", "persistent scores",
    "three contexts and four Paula voices",
)
missing = [phrase for phrase in required_phrases if phrase not in DOC]
if missing:
    raise SystemExit("coverage matrix lost required scope: " + ", ".join(missing))

print(f"PASS: gameplay coverage matrix names {len(observers)} existing observers and "
      f"{len(build_switches)} build switches")
