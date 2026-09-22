#!/usr/bin/env python3
"""Compare Macintosh and target Bogas traces without equating machine speed."""

import argparse
import re
from pathlib import Path


EVENT = re.compile(r"^(MACAUDIO|AUDIO) (load|play) tick=(\d+)(.*)$")
FIELD = re.compile(r"([a-zA-Z0-9]+)=([$][0-9a-fA-F]+|\d+)")


def value(text):
    return int(text[1:], 16) if text.startswith("$") else int(text)


def read_trace(path, wanted_prefix):
    loads = []
    plays = []
    for line in path.read_text(errors="replace").splitlines():
        match = EVENT.match(line)
        if not match or match.group(1) != wanted_prefix:
            continue
        _, kind, tick_text, rest = match.groups()
        fields = {key: value(text) for key, text in FIELD.findall(rest)}
        tick = int(tick_text)
        if kind == "load":
            loads.append((tick, fields["context"], fields["duration"],
                          fields["options"], fields["instrument"]))
        elif fields["context"] == 0:
            plays.append((tick, fields["pitch"]))
    if not loads or not plays:
        raise ValueError(f"{path} has no complete {wanted_prefix} driving trace")
    return loads, plays


def compressed(values):
    result = []
    for item in values:
        if not result or result[-1] != item:
            result.append(item)
    return result


def is_subsequence(needle, haystack):
    position = 0
    for item in needle:
        while position < len(haystack) and haystack[position] != item:
            position += 1
        if position == len(haystack):
            return False
        position += 1
    return True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reference", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--allow-additional-target-loads", action="store_true",
                        help="require the reference Load sequence in order, while allowing "
                             "additional source-driven target cues")
    args = parser.parse_args()

    reference_loads, reference_plays = read_trace(args.reference, "MACAUDIO")
    target_loads, target_plays = read_trace(args.target, "AUDIO")
    reference_signatures = [row[1:] for row in reference_loads]
    target_signatures = [row[1:] for row in target_loads]
    loads_match = (is_subsequence(reference_signatures, target_signatures)
                   if args.allow_additional_target_loads
                   else reference_signatures == target_signatures)
    if not loads_match:
        raise SystemExit(f"FAIL: Load sequences differ\nreference={reference_signatures}"
                         f"\ntarget={target_signatures}")

    reference_pitch = compressed([row[1] for row in reference_plays])
    target_pitch = compressed([row[1] for row in target_plays])
    if not is_subsequence(target_pitch, reference_pitch):
        raise SystemExit("FAIL: target engine-pitch progression is not a subsequence "
                         "of the faster Macintosh progression")

    reference_zero = reference_loads[0][0]
    target_zero = target_loads[0][0]
    if args.allow_additional_target_loads:
        print(f"PASS: all {len(reference_loads)} reference Load signatures occur exactly "
              f"and in order ({len(target_loads) - len(reference_loads)} additional target cues)")
    else:
        print(f"PASS: {len(reference_loads)} Load signatures are exact")
    print("  ordinal context/duration/options/instrument  Macintosh-delta  target-delta")
    display_targets = target_loads
    if args.allow_additional_target_loads:
        display_targets = []
        position = 0
        for reference in reference_loads:
            while target_loads[position][1:] != reference[1:]:
                position += 1
            display_targets.append(target_loads[position])
            position += 1
    for index, (reference, target) in enumerate(zip(reference_loads, display_targets), 1):
        signature = reference[1:]
        print(f"  {index:7d} {signature!s:<36} "
              f"{reference[0] - reference_zero:16d} {target[0] - target_zero:13d}")
    print(f"PASS: target engine progression ({len(target_plays)} Play calls, "
          f"{len(target_pitch)} distinct steps) is a source-ordered subsequence of "
          f"Macintosh ({len(reference_plays)} calls, {len(reference_pitch)} steps)")
    print("  elapsed ticks are diagnostic only: completed-frame cadence differs by machine")


if __name__ == "__main__":
    main()
