#!/usr/bin/env python3
"""Compare corresponding packed 4-bpp frames in a driving capture sequence."""

import argparse
import csv
import re
from collections import Counter
from pathlib import Path

from compare_mac_chunky import compare_surfaces, format_bounds


STATE_FIELDS = ("rpm", "gear", "speed", "x", "y", "heading")


def numbered_frames(prefix: Path) -> dict[int, Path]:
    pattern = re.compile(rf"^{re.escape(prefix.name)}-(\d+)\.raw$")
    frames: dict[int, Path] = {}
    for path in prefix.parent.glob(f"{prefix.name}-*.raw"):
        match = pattern.match(path.name)
        if match:
            frames[int(match.group(1))] = path
    return frames


def read_manifest(path: Path) -> dict[int, dict[str, int]]:
    if not path.exists():
        return {}
    lines = path.read_text().splitlines()
    try:
        header = next(i for i, line in enumerate(lines) if line.startswith("capture\t"))
    except StopIteration as error:
        raise SystemExit(f"{path}: missing capture column") from error
    rows = csv.DictReader(lines[header:], delimiter="\t")
    if rows.fieldnames is None or "capture" not in rows.fieldnames:
        raise SystemExit(f"{path}: missing capture column")
    missing = [field for field in STATE_FIELDS if field not in rows.fieldnames]
    if missing:
        raise SystemExit(f"{path}: missing state columns {missing}")
    result = {}
    for row in rows:
        if not row["capture"].isdigit():
            continue
        capture = int(row["capture"])
        result[capture] = {
            field: int(row[field], 16 if field in ("x", "y") else 10)
            for field in STATE_FIELDS
        }
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare numbered Macintosh and Amiga driving surfaces")
    parser.add_argument("reference_prefix", type=Path)
    parser.add_argument("amiga_prefix", type=Path)
    parser.add_argument("--width", type=int, default=512)
    parser.add_argument("--height", type=int, default=342)
    parser.add_argument("--reference-row-bytes", type=int, default=260)
    parser.add_argument("--amiga-row-bytes", type=int, default=260)
    parser.add_argument("--reference-manifest", type=Path)
    parser.add_argument("--amiga-manifest", type=Path)
    parser.add_argument(
        "--require-exact", action="store_true",
        help="exit unsuccessfully when any active pixel differs")
    parser.add_argument(
        "--match-state", action="store_true",
        help="pair frames by the complete state tuple instead of capture ordinal")
    args = parser.parse_args()

    reference = numbered_frames(args.reference_prefix)
    amiga = numbered_frames(args.amiga_prefix)
    reference_manifest_path = (
        args.reference_manifest
        or args.reference_prefix.parent / "driving-sequence.tsv")
    amiga_manifest_path = (
        args.amiga_manifest
        or args.amiga_prefix.parent / "driving-sequence.tsv")
    reference_manifest = read_manifest(reference_manifest_path)
    amiga_manifest = read_manifest(amiga_manifest_path)
    if bool(reference_manifest) != bool(amiga_manifest):
        raise SystemExit(
            "state manifests must be present for both sequences or neither: "
            f"{reference_manifest_path}, {amiga_manifest_path}")
    if not reference:
        raise SystemExit(f"no frames match {args.reference_prefix}-N.raw")
    if not amiga:
        raise SystemExit(f"no frames match {args.amiga_prefix}-N.raw")
    if not args.match_state and reference.keys() != amiga.keys():
        missing_amiga = sorted(reference.keys() - amiga.keys())
        missing_reference = sorted(amiga.keys() - reference.keys())
        details = []
        if missing_amiga:
            details.append(f"missing Amiga frames {missing_amiga}")
        if missing_reference:
            details.append(f"missing reference frames {missing_reference}")
        raise SystemExit("sequence frame sets differ: " + "; ".join(details))

    if args.match_state:
        if not reference_manifest or not amiga_manifest:
            raise SystemExit("--match-state requires both state manifests")

        def index_states(frames, manifest, label):
            result = {}
            for capture in sorted(frames.keys() & manifest.keys()):
                state = tuple(manifest[capture][field] for field in STATE_FIELDS)
                if state in result:
                    raise SystemExit(
                        f"{label}: duplicate state in captures "
                        f"{result[state]} and {capture}: {state}")
                result[state] = capture
            return result

        reference_states = index_states(reference, reference_manifest, "reference")
        amiga_states = index_states(amiga, amiga_manifest, "Amiga")
        common_states = reference_states.keys() & amiga_states.keys()
        pairs = [
            (reference_states[state], amiga_states[state], state)
            for state in sorted(common_states, key=lambda state: reference_states[state])
        ]
        if not pairs:
            raise SystemExit("no complete game states occur in both sequences")
        missing_amiga_states = reference_states.keys() - amiga_states.keys()
        missing_reference_states = amiga_states.keys() - reference_states.keys()
        print(
            f"state coverage: {len(pairs)} common, "
            f"{len(missing_amiga_states)} reference-only, "
            f"{len(missing_reference_states)} Amiga-only")
        for state in sorted(missing_amiga_states, key=lambda item: reference_states[item]):
            print(
                f"  reference-only frame {reference_states[state]}: "
                + ", ".join(f"{field}={value}" for field, value in zip(STATE_FIELDS, state)))
        for state in sorted(missing_reference_states, key=lambda item: amiga_states[item]):
            print(
                f"  Amiga-only frame {amiga_states[state]}: "
                + ", ".join(f"{field}={value}" for field, value in zip(STATE_FIELDS, state)))
    else:
        pairs = [(frame, frame, None) for frame in sorted(reference)]

    changed_total = 0
    pixel_total = 0
    first_difference: int | None = None
    state_mismatches = 0
    all_transitions: Counter[tuple[int, int]] = Counter()
    print(
        f"driving sequence: {len(pairs)} paired frames, "
        f"{args.width}x{args.height} active pixels")
    for reference_frame, amiga_frame, matched_state in pairs:
        try:
            comparison = compare_surfaces(
                reference[reference_frame].read_bytes(),
                amiga[amiga_frame].read_bytes(),
                width=args.width,
                height=args.height,
                left_row_bytes=args.reference_row_bytes,
                right_row_bytes=args.amiga_row_bytes,
            )
        except ValueError as error:
            raise SystemExit(
                f"reference frame {reference_frame} / Amiga frame {amiga_frame}: {error}") \
                from error
        changed_total += comparison.changed
        pixel_total += comparison.total
        all_transitions.update(comparison.transitions)
        state_differences = []
        if reference_manifest and not args.match_state:
            if reference_frame not in reference_manifest or amiga_frame not in amiga_manifest:
                raise SystemExit(f"frame {reference_frame}: missing state-manifest row")
            for field in STATE_FIELDS:
                left = reference_manifest[reference_frame][field]
                right = amiga_manifest[amiga_frame][field]
                if left != right:
                    state_differences.append(f"{field} {left}!={right}")
        state_matches = not state_differences
        if not state_matches:
            state_mismatches += 1
        if state_matches and comparison.changed and first_difference is None:
            first_difference = reference_frame
        status = "exact" if not comparison.changed else (
            f"{comparison.changed} different "
            f"({comparison.changed * 100 / comparison.total:.6f}%), "
            f"bounds {format_bounds(comparison.bounds)}")
        if state_differences:
            status += "; state mismatch: " + ", ".join(state_differences)
            status += " [pixel result is not a fidelity comparison]"
        if args.match_state:
            state_label = ", ".join(
                f"{field}={value}" for field, value in zip(STATE_FIELDS, matched_state))
            print(
                f"reference frame {reference_frame} / Amiga frame {amiga_frame} "
                f"({state_label}): {status}")
        else:
            print(f"frame {reference_frame}: {status}")

    print(
        f"sequence total: {changed_total} / {pixel_total} differing pixels "
        f"({changed_total * 100 / pixel_total:.6f}%)")
    if first_difference is None:
        print("first state-aligned divergence: none")
    else:
        print(f"first state-aligned divergence: frame {first_difference}")
        for (left, right), count in all_transitions.most_common(16):
            print(f"  {left:X}->{right:X}: {count}")

    if state_mismatches:
        print(f"state alignment: {state_mismatches} / {len(pairs)} frames mismatched")
    elif reference_manifest:
        print("state alignment: exact")

    if args.require_exact and (changed_total or state_mismatches):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
