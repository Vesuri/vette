#!/usr/bin/env python3
"""Gate completed-frame cadence from state-capture manifests."""

import argparse
import csv
import math
import statistics
from pathlib import Path


def read_ticks(path: Path) -> list[int]:
    lines = path.read_text().splitlines()
    try:
        header = next(i for i, line in enumerate(lines) if line.startswith("capture\t"))
    except StopIteration as error:
        raise SystemExit(f"{path}: missing capture header") from error
    rows = csv.DictReader(lines[header:], delimiter="\t")
    ticks = [int(row["ticks"]) for row in rows if row.get("capture", "").isdigit()]
    if len(ticks) < 3:
        raise SystemExit(f"{path}: need at least three completed-frame captures")
    if any(right <= left for left, right in zip(ticks, ticks[1:])):
        raise SystemExit(f"{path}: ticks are not strictly increasing")
    return ticks


def percentile(values: list[int], fraction: float) -> int:
    ordered = sorted(values)
    return ordered[math.ceil(fraction * len(ordered)) - 1]


def describe(label: str, ticks: list[int]) -> tuple[list[int], float, int, int]:
    intervals = [right - left for left, right in zip(ticks, ticks[1:])]
    median = statistics.median(intervals)
    p95 = percentile(intervals, 0.95)
    maximum = max(intervals)
    print(
        f"{label}: {len(intervals)} completed-frame intervals; "
        f"median={median:g}, p95={p95}, max={maximum} Macintosh ticks")
    return intervals, median, p95, maximum


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compare original-Macintosh and target-A1200 completed-frame cadence")
    parser.add_argument("reference_manifest", type=Path)
    parser.add_argument("target_manifest", type=Path)
    parser.add_argument("--max-target-median", type=float, default=12.0)
    parser.add_argument("--max-target-p95", type=int, default=15)
    parser.add_argument("--max-median-ratio", type=float, default=2.0)
    args = parser.parse_args()

    _, reference_median, _, _ = describe(
        "Macintosh reference", read_ticks(args.reference_manifest))
    _, target_median, target_p95, _ = describe(
        "A1200 target", read_ticks(args.target_manifest))
    ratio = target_median / reference_median
    print(f"median target/reference ratio: {ratio:.3f}")

    failures = []
    if target_median > args.max_target_median:
        failures.append(
            f"target median {target_median:g} exceeds {args.max_target_median:g} ticks")
    if target_p95 > args.max_target_p95:
        failures.append(
            f"target p95 {target_p95} exceeds {args.max_target_p95} ticks")
    if ratio > args.max_median_ratio:
        failures.append(
            f"median ratio {ratio:.3f} exceeds {args.max_median_ratio:.3f}")
    if failures:
        raise SystemExit("cadence regression: " + "; ".join(failures))
    print("cadence gate: PASS")


if __name__ == "__main__":
    main()
