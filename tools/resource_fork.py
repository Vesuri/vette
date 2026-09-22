#!/usr/bin/env python3
"""Strict reader for an unmodified classic Macintosh resource fork."""

from __future__ import annotations

import struct
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Resource:
    rid: int
    kind: bytes
    attrs: int
    name: str
    body: bytes


def read_resource_fork(path: Path) -> list[Resource]:
    raw = path.read_bytes()
    return parse_resource_fork(raw, str(path))


def parse_resource_fork(raw: bytes, label: str = "resource fork") -> list[Resource]:
    if len(raw) < 16:
        raise ValueError(f"{label}: resource fork is shorter than its header")
    data_offset, map_offset, data_length, map_length = struct.unpack_from(">IIII", raw)
    if (data_offset + data_length > len(raw)
            or map_offset + map_length > len(raw) or map_length < 30):
        raise ValueError(f"{label}: resource data/map extends past end of fork")
    resource_map = raw[map_offset:map_offset + map_length]
    if resource_map[:16] != raw[:16]:
        raise ValueError(f"{label}: resource map header does not match fork header")
    type_offset, name_offset = struct.unpack_from(">HH", resource_map, 24)
    if type_offset + 2 > map_length or name_offset > map_length:
        raise ValueError(f"{label}: invalid type/name list offset")
    type_count = struct.unpack_from(">H", resource_map, type_offset)[0] + 1
    if type_count > 4096 or type_offset + 2 + type_count * 8 > map_length:
        raise ValueError(f"{label}: invalid resource type count")

    result = []
    for type_index in range(type_count):
        type_entry = type_offset + 2 + type_index * 8
        kind, count_minus_one, references = struct.unpack_from(">4sHH", resource_map,
                                                               type_entry)
        reference_count = count_minus_one + 1
        reference_base = type_offset + references
        if reference_base + reference_count * 12 > map_length:
            raise ValueError(f"{label}: truncated reference list for {kind!r}")
        for reference_index in range(reference_count):
            entry = reference_base + reference_index * 12
            rid, name_relative = struct.unpack_from(">hH", resource_map, entry)
            attrs = resource_map[entry + 4]
            body_relative = int.from_bytes(resource_map[entry + 5:entry + 8], "big")
            length_offset = data_offset + body_relative
            if length_offset + 4 > data_offset + data_length:
                raise ValueError(f"{label}: invalid data offset for {kind!r} {rid}")
            body_length = struct.unpack_from(">I", raw, length_offset)[0]
            body_offset = length_offset + 4
            if body_offset + body_length > data_offset + data_length:
                raise ValueError(f"{label}: truncated payload for {kind!r} {rid}")
            name = ""
            if name_relative != 0xFFFF:
                position = name_offset + name_relative
                if position >= map_length:
                    raise ValueError(f"{label}: invalid name for {kind!r} {rid}")
                name_length = resource_map[position]
                if position + 1 + name_length > map_length:
                    raise ValueError(f"{label}: truncated name for {kind!r} {rid}")
                name = resource_map[position + 1:position + 1 + name_length].decode(
                    "mac_roman", "replace")
            result.append(Resource(rid, kind, attrs, name,
                                   raw[body_offset:body_offset + body_length]))
    return result


def find_resource(resources: list[Resource], kind: bytes, rid: int) -> Resource:
    matches = [item for item in resources if item.kind == kind and item.rid == rid]
    if len(matches) != 1:
        raise ValueError(f"expected one {kind.decode('mac_roman')} {rid}, got {len(matches)}")
    return matches[0]
