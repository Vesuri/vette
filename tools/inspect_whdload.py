#!/usr/bin/env python3
"""Inspect Exec task wait states in a WHDLoad COREDUMP (local diagnostics)."""
import re
import struct
import sys
from pathlib import Path

p = Path(sys.argv[1])
chip = (p / '.whdl_memory').read_bytes()
fast = (p / '.whdl_expmem').read_bytes()
report = (p / '.whdl_register').read_text(encoding='latin1')
base = int(re.findall(r'ExpMem\s+([0-9A-F]+)', report)[-1], 16)

def data(a, n):
    b, o = (chip, a) if a < len(chip) else (fast, a - base)
    if o < 0 or o + n > len(b):
        raise ValueError(f'Address outside dump: {a:x}')
    return b[o:o+n]

def u(a):
    return struct.unpack('>I', data(a, 4))[0]

def name(a):
    return data(a, 80).split(b'\0')[0].decode('latin1')

s = u(4)
print(f'ExecBase={s:08x} ThisTask={u(s+276):08x}')
for label, offset in [('Ready', 406), ('Wait', 420)]:
    t = u(s+offset)
    seen = set()
    while t and u(t):
        if t in seen:
            raise ValueError('Cycle in task list')
        seen.add(t)
        sp = u(t+54)
        print(f'{label}: {t:08x} {name(u(t+10))!r} '
              f'sigwait={u(t+22):08x} sp={sp:08x}')
        for a in range(sp, min(sp+160, u(t+62)), 16):
            print(f'  {a:08x}: ' + ' '.join(f'{u(a+i):08x}' for i in range(0,16,4)))
        t = u(t)
