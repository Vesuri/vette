#!/usr/bin/env python3
"""Render a diagnostic Bogas event log as the commanded Paula voice output."""

import argparse
import math
import re
import struct
import wave
from dataclasses import dataclass
from pathlib import Path


HEADER = struct.Struct(">4sHHII")
ENTRY = struct.Struct(">Hh4sBBHIII")
PAULA_CLOCK = 3_546_895
MAC_TICKS = 60
ORDINAL_NAMES = (
    "opening song", "mic", "signature", "cable car bell", "engine", "heli",
    "horn", "skid", "crash", "kill", "beep1", "beep2", "police", "thud",
    "joel", "splash",
)
EVENT = re.compile(r"^AUDIO (load|play|start|stop|deactivate|ceiling) tick=(\d+)(.*)$")
FIELD = re.compile(r"([a-zA-Z0-9]+)=(\$[0-9a-fA-F]+|\d+)")


@dataclass
class Instrument:
    name: str
    pcm: tuple
    period: int
    sample_rate: int
    loop_start: int
    loop_end: int


@dataclass
class Voice:
    instrument: Instrument
    period: int
    phase: float = 0.0
    attack: bool = True
    end_tick: int = 0
    finished: bool = False

    def sample(self, output_rate):
        if self.finished:
            return 0
        index = int(self.phase)
        value = self.instrument.pcm[index]
        self.phase += PAULA_CLOCK / (self.period * output_rate)
        size = len(self.instrument.pcm)
        if self.attack and self.phase >= size:
            self.attack = False
            if self.instrument.loop_end > self.instrument.loop_start:
                length = self.instrument.loop_end - self.instrument.loop_start
                self.phase = self.instrument.loop_start + (self.phase - size) % length
            else:
                self.finished = True
        elif not self.attack:
            start = self.instrument.loop_start
            end = self.instrument.loop_end
            if end > start and self.phase >= end:
                self.phase = start + (self.phase - end) % (end - start)
            elif end <= start and self.phase >= size:
                self.phase %= size
        return value


def parse_value(text):
    return int(text[1:], 16) if text.startswith("$") else int(text)


def load_instruments(path):
    archive = path.read_bytes()
    magic, version, _, count, directory = HEADER.unpack_from(archive)
    if magic != b"VRS1" or version != 1:
        raise ValueError("not a VRS1 resource archive")
    found = {}
    for index in range(count):
        entry = ENTRY.unpack_from(archive, directory + index * ENTRY.size)
        _, _, kind, _, name_length, _, name_offset, data_offset, data_length = entry
        if kind != b"INST":
            continue
        name = archive[name_offset:name_offset + name_length].decode("mac_roman").lower()
        body = archive[data_offset:data_offset + data_length]
        loop_start = loop_end = 0
        sample_rate = 0
        if len(body) > 8 and struct.unpack_from(">H", body, 6)[0] == len(body) - 8:
            loop_start, loop_end, sample_rate, _ = struct.unpack_from(">HHHH", body)
            body = body[8:]
        if not body:
            raise ValueError(f"empty INST {name!r}")
        period = PAULA_CLOCK // sample_rate if sample_rate else 319
        found[name] = Instrument(name, tuple(value - 128 for value in body), period,
                                 sample_rate, loop_start, loop_end)
    result = []
    for name in ORDINAL_NAMES:
        if name not in found:
            raise ValueError(f"missing INST {name!r}")
        result.append(found[name])
    return result


def load_events(path):
    events = []
    for line in path.read_text(errors="replace").splitlines():
        match = EVENT.match(line)
        if not match:
            continue
        kind, tick_text, rest = match.groups()
        fields = {key: parse_value(value) for key, value in FIELD.findall(rest)}
        events.append((int(tick_text), kind, fields))
    if not events or not any(kind == "ceiling" for _, kind, _ in events):
        raise ValueError("audio log has no complete ceiling")
    return events


def bogas_period(base_period, pitch):
    if not pitch:
        pitch = 0x10000
    period = (base_period * 0x10000 + pitch // 2) // pitch
    return max(124, min(65535, period))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("events", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--rate", type=int, default=48000)
    args = parser.parse_args()

    instruments = load_instruments(args.archive)
    events = load_events(args.events)
    first_tick = min(tick for tick, kind, _ in events if kind == "load")
    end_tick = next(tick for tick, kind, _ in events if kind == "ceiling")
    event_index = 0
    while event_index < len(events) and events[event_index][0] < first_tick:
        event_index += 1
    contexts = [None, None, None]
    started = True
    frames = round((end_tick - first_tick) * args.rate / MAC_TICKS)
    output = bytearray(frames * 4)

    for frame in range(frames):
        tick = first_tick + frame * MAC_TICKS / args.rate
        while event_index < len(events) and events[event_index][0] <= tick:
            event_tick, kind, fields = events[event_index]
            event_index += 1
            if kind == "load":
                context = fields["context"]
                instrument = instruments[fields["instrument"]]
                period = (bogas_period(319, fields["options"])
                          if context == 0 else instrument.period)
                duration = fields["duration"]
                contexts[context] = Voice(instrument, period, end_tick=(
                    0 if duration == 0x7FFFFFFF else event_tick + duration))
            elif kind == "play":
                context = fields["context"]
                if contexts[context] is not None:
                    contexts[context].period = bogas_period(319, fields["pitch"])
            elif kind == "start":
                started = True
            elif kind in ("stop", "deactivate"):
                started = False

        left = right = 0
        if started:
            for context, voice in enumerate(contexts):
                if voice is None:
                    continue
                if voice.end_tick and tick >= voice.end_tick:
                    contexts[context] = None
                    continue
                sample = voice.sample(args.rate)
                if context == 0:
                    left += sample
                    right += sample
                elif context == 1:       # AUD3, left
                    left += sample
                else:                    # AUD2, right
                    right += sample
        left = max(-32768, min(32767, left * 128))
        right = max(-32768, min(32767, right * 128))
        struct.pack_into("<hh", output, frame * 4, left, right)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(args.output), "wb") as target:
        target.setnchannels(2)
        target.setsampwidth(2)
        target.setframerate(args.rate)
        target.writeframes(output)
    print(f"{args.output}: {frames / args.rate:.3f} s from ticks "
          f"{first_tick}..{end_tick}, {len(events)} source events")
    engine_errors = []
    direct_errors = []
    for _, kind, fields in events:
        if kind == "play" and fields["context"] == 0:
            expected = 11127.0 * fields["pitch"] / 0x10000
            actual = PAULA_CLOCK / bogas_period(319, fields["pitch"])
            engine_errors.append(1200.0 * math.log2(actual / expected))
        elif kind == "load" and fields["context"] != 0:
            instrument = instruments[fields["instrument"]]
            if instrument.sample_rate:
                actual = PAULA_CLOCK / instrument.period
                direct_errors.append((instrument.name,
                                      1200.0 * math.log2(actual / instrument.sample_rate)))
    if engine_errors:
        print(f"engine pitch error: {min(engine_errors):+.3f}.."
              f"{max(engine_errors):+.3f} cents over {len(engine_errors)} Play calls")
    if direct_errors:
        worst_name, worst = max(direct_errors, key=lambda item: abs(item[1]))
        print(f"direct-effect worst pitch error: {worst:+.3f} cents "
              f"({worst_name}, {len(direct_errors)} Load calls)")


if __name__ == "__main__":
    main()
