#!/usr/bin/env python3
"""Summarize active passages in a PCM reference capture without audio libraries."""

import argparse
import array
import math
import sys
import wave
from pathlib import Path


def rms(samples, mean=0.0):
    if not samples:
        return 0.0
    return math.sqrt(sum((sample - mean) ** 2 for sample in samples) / len(samples))


def intervals(active, seconds_per_window, bridge_windows):
    result = []
    start = None
    last = None
    for index, enabled in enumerate(active):
        if enabled:
            if start is None:
                start = index
            last = index
        elif start is not None and index - last > bridge_windows:
            result.append((start * seconds_per_window, (last + 1) * seconds_per_window))
            start = None
            last = None
    if start is not None:
        result.append((start * seconds_per_window, (last + 1) * seconds_per_window))
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wav", type=Path)
    parser.add_argument("--window", type=float, default=0.25,
                        help="analysis-window duration in seconds (default: 0.25)")
    parser.add_argument("--threshold", type=float, default=64.0,
                        help="AC RMS required for an active window (default: 64)")
    parser.add_argument("--bridge", type=float, default=0.25,
                        help="merge silent gaps no longer than this many seconds (default: 0.25)")
    args = parser.parse_args()

    with wave.open(str(args.wav), "rb") as source:
        channels = source.getnchannels()
        rate = source.getframerate()
        width = source.getsampwidth()
        frames = source.getnframes()
        if width != 2:
            raise ValueError(f"expected 16-bit PCM, got {width * 8} bits")
        pcm = array.array("h", source.readframes(frames))
    if sys.byteorder != "little":
        pcm.byteswap()

    separated = [pcm[channel::channels] for channel in range(channels)]
    print(f"{args.wav}: {channels} channels, {rate} Hz, {frames / rate:.3f} s")
    for channel, samples in enumerate(separated, 1):
        mean = sum(samples) / len(samples) if samples else 0.0
        print(f"  channel {channel}: mean={mean:.2f} ac-rms={rms(samples, mean):.2f} "
              f"peak={max((abs(sample) for sample in samples), default=0)}")

    # MAME exposes the Macintosh mono device among several machine outputs.
    # Pick the channel with the greatest AC energy rather than assuming its
    # mixer position, and ignore a constant DAC/DC level when finding sound.
    chosen = max(range(channels), key=lambda index: rms(
        separated[index], sum(separated[index]) / len(separated[index])))
    samples = separated[chosen]
    window_frames = max(1, round(rate * args.window))
    active = []
    for offset in range(0, len(samples), window_frames):
        part = samples[offset:offset + window_frames]
        mean = sum(part) / len(part)
        active.append(rms(part, mean) >= args.threshold)
    spans = intervals(active, window_frames / rate,
                      max(0, round(args.bridge * rate / window_frames)))
    print(f"  activity channel: {chosen + 1}; threshold={args.threshold:g} AC RMS")
    if not spans:
        print("  active passages: none")
    else:
        print("  active passages:")
        for start, end in spans:
            print(f"    {start:8.3f} .. {min(end, frames / rate):8.3f} s "
                  f"({min(end, frames / rate) - start:7.3f} s)")


if __name__ == "__main__":
    main()
