#!/usr/bin/env python3
"""Read an HFS (not HFS+) volume image: list it, extract forks, list resources.

Why this exists: macOS dropped HFS-standard support in 10.15, so a classic Mac
volume cannot be mounted on the dev host at all.  And per CLAUDE.md, Ghidra 12.1
has no resource-fork loader either, so the `CODE` segments have to come out of
the resource map by hand whatever else happens.  This is that tool.

    hfs_extract.py <image.raw> list
    hfs_extract.py <image.raw> extract <out-dir>     # every fork, one file each
    hfs_extract.py <image.raw> resources <path-in-volume>
    hfs_extract.py <image.raw> segments <path-in-volume> <out-dir>

`segments` is the one the port cares about: it writes one file per `CODE`
resource, named `CODE_<id>_<segname>.bin`, ready to import into Ghidra as a raw
68000:BE:32 binary.  ** Remember what CLAUDE.md says about addresses: each file
is ONE SEGMENT, so an address is (segment, offset) and every symbol must record
which segment it belongs to. **  `CODE 0` is not code - it is the jump table.
"""
import os, struct, sys

# ---------------------------------------------------------------- HFS volume

class HFS:
    def __init__(self, data):
        self.d = data
        mdb = data[1024:1024 + 162]
        if mdb[:2] != b'BD':
            raise SystemExit("not an HFS volume: MDB signature is %r, expected 'BD'.  "
                             "An HFS+ volume ('H+') or a still-compressed NDIF image "
                             "both land here -- run ndif2raw.py first." % mdb[:2])
        self.nmAlBlks, self.alBlkSiz, _, self.alBlSt = struct.unpack('>HIIH', mdb[18:30])
        nl = mdb[36]
        self.name = mdb[37:37 + nl].decode('mac-roman')
        self.nmFls, = struct.unpack('>H', mdb[12:14])
        self.freeBks, = struct.unpack('>H', mdb[34:36])
        # Extents overflow B-tree first: the catalog itself could need it.
        self.overflow = {}
        for key, rec in self._leaves(self._fork(mdb[134:146])):
            if len(key) < 7:
                continue
            forkType = key[0]
            fileID, = struct.unpack('>I', key[1:5])
            self.overflow.setdefault((fileID, forkType), []).extend(_extents(rec[:12]))
        self.dirs, self.files = [], []
        for key, rec in self._leaves(self._fork(mdb[150:162])):
            if not rec:
                continue
            parent, = struct.unpack('>I', key[1:5])
            nl = key[5]
            name = key[6:6 + nl].decode('mac-roman', 'replace')
            if rec[0] == 1:                                   # directory record
                cnid, = struct.unpack('>I', rec[6:10])
                self.dirs.append((parent, cnid, name))
            elif rec[0] == 2 and len(rec) >= 98:              # file record
                cnid, = struct.unpack('>I', rec[20:24])
                self.files.append(dict(
                    parent=parent, name=name, cnid=cnid,
                    type=rec[4:8].decode('mac-roman', 'replace'),
                    creator=rec[8:12].decode('mac-roman', 'replace'),
                    dataLen=struct.unpack('>I', rec[26:30])[0],
                    rsrcLen=struct.unpack('>I', rec[36:40])[0],
                    dataExt=_extents(rec[74:86]), rsrcExt=_extents(rec[86:98])))
        self._up = {c: p for p, c, _ in self.dirs}
        self._nm = {c: n for _, c, n in self.dirs}

    def _ab(self, n):
        return self.alBlSt * 512 + n * self.alBlkSiz

    def _fork(self, extrec, cnid=None, forkType=None, length=None):
        exts = list(_extents(extrec)) if isinstance(extrec, bytes) else list(extrec)
        if cnid is not None:
            exts += self.overflow.get((cnid, forkType), [])
        out = b''
        for start, count in exts:
            if count:
                out += self.d[self._ab(start):self._ab(start + count)]
        if length is not None:
            if len(out) < length:
                # Make the gap LOUD rather than returning a short fork that
                # parses as a truncated resource map and looks merely odd.
                raise SystemExit("fork is short: %d of %d bytes for cnid %d.  Either "
                                 "the extents overflow tree was not consulted or the "
                                 "image is incomplete -- do NOT use this output."
                                 % (len(out), length, cnid))
            out = out[:length]
        return out

    def _leaves(self, btree):
        firstLeaf, = struct.unpack('>I', btree[24:28])
        nodeSize, = struct.unpack('>H', btree[32:34])
        n = firstLeaf
        while n:
            nd = btree[n * nodeSize:(n + 1) * nodeSize]
            if len(nd) < 14:
                return
            fLink, _, _, _, numRecs = struct.unpack('>IIbbH', nd[0:12])
            offs = [struct.unpack('>H', nd[nodeSize - 2 * (i + 1):nodeSize - 2 * i])[0]
                    for i in range(numRecs + 1)]
            for i in range(numRecs):
                r = nd[offs[i]:offs[i + 1]]
                kl = r[0]
                yield r[1:1 + kl], r[1 + kl + ((kl + 1) % 2):]
            n = fLink

    def path(self, f):
        parts = [f['name']]
        p = f['parent']
        while p in self._nm:
            parts.append(self._nm[p])
            p = self._up.get(p, 0)
        return '/'.join(reversed(parts))

    def find(self, wanted):
        hits = [f for f in self.files if self.path(f) == wanted or f['name'] == wanted]
        if not hits:
            raise SystemExit("no such file in the volume: %r\nTry `list`." % wanted)
        if len(hits) > 1:
            raise SystemExit("ambiguous: %r matches\n  %s\nUse the full path."
                             % (wanted, '\n  '.join(self.path(h) for h in hits)))
        return hits[0]

    def data_fork(self, f):
        return self._fork(f['dataExt'], f['cnid'], 0x00, f['dataLen'])

    def rsrc_fork(self, f):
        return self._fork(f['rsrcExt'], f['cnid'], 0xff, f['rsrcLen'])


def _extents(rec):
    return [struct.unpack('>HH', rec[i:i + 4]) for i in range(0, 12, 4)]

# --------------------------------------------------------- resource fork map

def resources(rsrc):
    """-> {type: [(id, name, bytes), ...]} from a classic resource fork."""
    dOff, mOff, dLen, mLen = struct.unpack('>IIII', rsrc[:16])
    m = rsrc[mOff:mOff + mLen]
    typeOff, nameOff = struct.unpack('>HH', m[24:28])
    tl = m[typeOff:]
    ntypes, = struct.unpack('>h', tl[:2])
    out = {}
    for i in range(ntypes + 1):
        t = tl[2 + i * 8:10 + i * 8]
        typ = t[:4].decode('mac-roman')
        cnt, = struct.unpack('>h', t[4:6])
        ref, = struct.unpack('>H', t[6:8])
        lst = []
        for j in range(cnt + 1):
            e = tl[ref + j * 12:ref + j * 12 + 12]
            rid, = struct.unpack('>h', e[:2])
            nOff, = struct.unpack('>h', e[2:4])
            doff = struct.unpack('>I', b'\0' + e[5:8])[0]
            n, = struct.unpack('>I', rsrc[dOff + doff:dOff + doff + 4])
            name = ''
            if nOff != -1:
                nb = m[nameOff + nOff]
                name = m[nameOff + nOff + 1:nameOff + nOff + 1 + nb].decode('mac-roman', 'replace')
            lst.append((rid, name, rsrc[dOff + doff + 4:dOff + doff + 4 + n]))
        out[typ] = sorted(lst)
    return out

# ------------------------------------------------------------------ commands

def main(argv):
    if len(argv) < 3:
        raise SystemExit(__doc__)
    v = HFS(open(argv[1], 'rb').read())
    cmd = argv[2]

    if cmd == 'list':
        print("volume %r  %d alloc blocks of %d  %d free  %d files"
              % (v.name, v.nmAlBlks, v.alBlkSiz, v.freeBks, v.nmFls))
        print("%-52s %-5s %-5s %9s %9s" % ('path', 'type', 'crtr', 'data', 'rsrc'))
        for f in sorted(v.files, key=lambda f: v.path(f)):
            print("%-52s %-5s %-5s %9d %9d"
                  % (v.path(f), f['type'], f['creator'], f['dataLen'], f['rsrcLen']))

    elif cmd == 'extract':
        out = argv[3]
        for f in v.files:
            base = os.path.join(out, v.path(f))
            os.makedirs(os.path.dirname(base), exist_ok=True)
            if f['dataLen']:
                open(base, 'wb').write(v.data_fork(f))
            if f['rsrcLen']:
                open(base + '.rsrc', 'wb').write(v.rsrc_fork(f))
            print("%-52s data %8d  rsrc %8d" % (v.path(f), f['dataLen'], f['rsrcLen']))

    elif cmd == 'resources':
        f = v.find(argv[3])
        res = resources(v.rsrc_fork(f))
        print("%s  (%s/%s)  %d types, %d resources"
              % (v.path(f), f['type'], f['creator'], len(res), sum(len(x) for x in res.values())))
        for typ, lst in sorted(res.items()):
            print("  %-4s x%-4d %s" % (typ, len(lst),
                  ' '.join('%d%s' % (i, '(%s)' % n if n else '') for i, n, _ in lst)))

    elif cmd == 'segments':
        f = v.find(argv[3])
        out = argv[4]
        os.makedirs(out, exist_ok=True)
        code = resources(v.rsrc_fork(f)).get('CODE')
        if not code:
            raise SystemExit("%s has no CODE resources -- it is not a 68k application"
                             % v.path(f))
        for rid, name, body in code:
            safe = ''.join(c if c.isalnum() else '_' for c in name)
            fn = os.path.join(out, "CODE_%02d%s.bin" % (rid, '_' + safe if safe else ''))
            open(fn, 'wb').write(body)
            note = "jump table + Segment Loader header, NOT code" if rid == 0 else ""
            print("%-40s %8d bytes  %s" % (fn, len(body), note))
        print("\n%d segments.  Import each as raw 68000:BE:32:default.  An address in "
              "this program is (segment, offset)." % len(code))
    else:
        raise SystemExit(__doc__)

if __name__ == '__main__':
    main(sys.argv)
