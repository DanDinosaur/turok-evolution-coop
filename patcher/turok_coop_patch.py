#!/usr/bin/env python3
"""Turok: Evolution (Xbox, USA) 2-player split-screen co-op mod - patcher.

Applies the co-op patch (.tecp) to YOUR OWN copy of the game. Contains no game data.

  python turok_coop_patch.py <input> [--out <output>] [--in-place]

<input> can be:
  * an Xbox game ISO (XISO, or a full redump-style ISO)
  * an extracted default.xbe file, or a game folder that contains default.xbe
  * a GOD package: the 41430004 folder, its 00005000 folder, or the GOD header file

Without --in-place, the input is left untouched:
  * ISO         -> written to --out (default: <name>_coop.iso next to the input)
  * default.xbe -> written to --out (default: default_coop.xbe next to the input)
  * GOD         -> the whole package is copied to --out (default: ./GOD_coop/41430004)
                   and the copy is patched (GOD block hashes are rebuilt).
Python 3.6+, no extra packages needed.
"""
import argparse, hashlib, os, shutil, struct, sys

PATCH_NAME = 'turok_evolution_coop_v1.0.tecp'
BLOCK = 0x1000
BPP = 0xA1C4          # data blocks per Data#### file
BPS = 0xCC            # data blocks per sub-part
SUBPART = BLOCK + BPS * BLOCK
XDVD_OFFSETS = (0, 0x18300000, 0xFD90000, 0x2080000)   # plain XISO / redump-style images

def sha1(b): return hashlib.sha1(b).digest()
def die(msg): print('ERROR: ' + msg); sys.exit(1)

# ---------------------------------------------------------------- patch file
def load_patch(path):
    d = open(path, 'rb').read()
    if d[:8] != b'TECOOP01': die('not a co-op patch file: ' + path)
    size, = struct.unpack_from('<I', d, 8)
    old_sha, new_sha = d[12:32], d[32:52]
    n, = struct.unpack_from('<I', d, 52)
    pos, recs = 56, []
    for _ in range(n):
        off, ln = struct.unpack_from('<II', d, pos); pos += 8
        recs.append((off, d[pos:pos + ln])); pos += ln
    return size, old_sha, new_sha, recs

def patch_xbe(xbe, patch):
    size, old_sha, new_sha, recs = patch
    if len(xbe) != size or sha1(xbe) != old_sha:
        if sha1(xbe) == new_sha: die('this default.xbe already has the co-op mod.')
        die('default.xbe does not match the original Turok: Evolution (USA) XBE '
            '(expected SHA-1 %s, got %s).' % (old_sha.hex(), sha1(xbe).hex()))
    out = bytearray(xbe)
    for off, data in recs: out[off:off + len(data)] = data
    out = bytes(out)
    assert sha1(out) == new_sha, 'internal error: result hash mismatch'
    return out

# ---------------------------------------------------------------- GOD package
def loc(b):
    part, r = divmod(b, BPP)
    sub, k = divmod(r, BPS)
    return part, sub, k, BLOCK + sub * SUBPART + BLOCK + k * BLOCK

class God:
    def __init__(self, header, datadir):
        self.header, self.dir = header, datadir
    def path(self, part): return os.path.join(self.dir, 'Data%04d' % part)
    def read(self, off, n):
        out = bytearray()
        while n:
            b, o = divmod(off, BLOCK)
            part, sub, k, fo = loc(b)
            take = min(n, BLOCK - o)
            with open(self.path(part), 'rb') as fh:
                fh.seek(fo + o); out += fh.read(take)
            off += take; n -= take
        return bytes(out)

def find_god(p):
    """Return (header_file, data_dir) for a GOD path."""
    p = os.path.abspath(p)
    if os.path.isfile(p) and os.path.isdir(p + '.data'): return p, p + '.data'
    for root in (p, os.path.join(p, '00005000')):
        if not os.path.isdir(root): continue
        for f in os.listdir(root):
            h = os.path.join(root, f)
            if os.path.isfile(h) and os.path.isdir(h + '.data'): return h, h + '.data'
    return None

class Iso:
    def __init__(self, path): self.p = path
    def read(self, off, n):
        with open(self.p, 'rb') as fh:
            fh.seek(off); b = fh.read(n)
        if len(b) != n: raise OSError('short read')
        return b

def patch_iso(path, patch):
    iso = Iso(path)
    hit = xdvdfs_find(iso, 'default.xbe')
    if not hit: die('this file is not an Xbox game ISO (no Xbox file system found).')
    start, size = hit
    new = patch_xbe(iso.read(start, size), patch)
    with open(path, 'r+b') as fh:
        for off, data in patch[3]:
            fh.seek(start + off); fh.write(data)
    if iso.read(start, size) != new: die('verification failed after writing.')

def xdvdfs_find(g, name):
    for base in XDVD_OFFSETS:
        try: hdr = g.read(base + 32 * 2048, 2048)
        except (OSError, struct.error): continue
        if hdr[:20] != b'MICROSOFT*XBOX*MEDIA': continue
        root_sec, root_size = struct.unpack_from('<II', hdr, 20)
        tbl = g.read(base + root_sec * 2048, root_size)
        seen, todo = set(), [0]
        while todo:
            o = todo.pop()
            if o in seen or o * 4 + 14 > len(tbl): continue
            seen.add(o)
            l, r, sec, size, attr, nl = struct.unpack_from('<HHIIBB', tbl, o * 4)
            if l == 0xFFFF: continue
            if tbl[o * 4 + 14:o * 4 + 14 + nl].decode('latin1').lower() == name.lower():
                return base + sec * 2048, size
            if l: todo.append(l)
            if r: todo.append(r)
    return None

def patch_god(header, datadir, patch):
    g = God(header, datadir)
    hit = xdvdfs_find(g, 'default.xbe')
    if not hit: die('could not find default.xbe inside the GOD package.')
    start, size = hit
    new = patch_xbe(g.read(start, size), patch)
    # changed 4 KB blocks
    blocks = {}
    for off, data in patch[3]:
        a, z = start + off, start + off + len(data)
        for b in range(a // BLOCK, (z - 1) // BLOCK + 1):
            blocks[b] = None
    touched = {}
    for b in sorted(blocks):
        blk = bytearray(g.read(b * BLOCK, BLOCK))
        lo, hi = max(start, b * BLOCK), min(start + size, (b + 1) * BLOCK)
        blk[lo - b * BLOCK:hi - b * BLOCK] = new[lo - start:hi - start]
        part, sub, k, fo = loc(b)
        with open(g.path(part), 'r+b') as fh:
            fh.seek(fo); fh.write(blk)
        touched.setdefault((part, sub), {})[k] = sha1(bytes(blk))
    # sub-part hash tables
    mht_upd = {}
    for (part, sub), ks in touched.items():
        sh_off = BLOCK + sub * SUBPART
        with open(g.path(part), 'r+b') as fh:
            fh.seek(sh_off); sh = bytearray(fh.read(BLOCK))
            for k, h in ks.items(): sh[k * 20:k * 20 + 20] = h
            fh.seek(sh_off); fh.write(sh)
        mht_upd.setdefault(part, {})[sub] = sha1(bytes(sh))
    # master hash tables, chained down to part 0
    top = max(mht_upd); nxt = None
    for p in range(top, -1, -1):
        with open(g.path(p), 'r+b') as fh:
            m = bytearray(fh.read(BLOCK))
            for sub, h in mht_upd.get(p, {}).items(): m[sub * 20:sub * 20 + 20] = h
            if nxt is not None: m[0xCB * 20:0xCB * 20 + 20] = nxt
            fh.seek(0); fh.write(m)
        nxt = sha1(bytes(m))
    # CON header
    with open(header, 'r+b') as fh:
        hb = bytearray(fh.read())
        hb[0x37D:0x37D + 20] = nxt
        hb[0x32C:0x32C + 20] = sha1(bytes(hb[0x344:0x344 + 0xACBC]))
        fh.seek(0); fh.write(hb)
    if g.read(start, size) != new: die('verification failed after writing.')

def main():
    ap = argparse.ArgumentParser(description='Turok: Evolution co-op mod patcher')
    ap.add_argument('input'); ap.add_argument('--out'); ap.add_argument('--in-place', action='store_true')
    ap.add_argument('--patch', default=os.path.join(os.path.dirname(os.path.abspath(__file__)), PATCH_NAME))
    a = ap.parse_args()
    patch = load_patch(a.patch)
    inp = os.path.abspath(a.input)
    xbe = inp if os.path.isfile(inp) and inp.lower().endswith('.xbe') else os.path.join(inp, 'default.xbe')
    if os.path.isfile(xbe):
        out = xbe if a.in_place else (a.out or os.path.join(os.path.dirname(xbe), 'default_coop.xbe'))
        data = patch_xbe(open(xbe, 'rb').read(), patch)
        open(out, 'wb').write(data)
        print('Done: ' + out)
        return
    if os.path.isfile(inp) and find_god(inp) is None:            # an ISO image
        if xdvdfs_find(Iso(inp), 'default.xbe') is None:
            die('this file is not an Xbox game ISO (no Xbox file system found).')
        patch_xbe(Iso(inp).read(*xdvdfs_find(Iso(inp), 'default.xbe')), patch)   # check before copying
        if a.in_place: out = inp
        else:
            stem, ext = os.path.splitext(inp)
            out = os.path.abspath(a.out or stem + '_coop' + (ext or '.iso'))
            if os.path.exists(out): die('output file already exists: ' + out)
            print('Copying ISO to ' + out + ' (please wait)...')
            shutil.copyfile(inp, out); os.chmod(out, 0o644)
        patch_iso(out, patch)
        print('Done: ' + out)
        return
    god = find_god(inp)
    if not god: die('no Xbox ISO, default.xbe or GOD package found at ' + inp)
    header, datadir = god
    if not a.in_place:
        title_dir = os.path.dirname(os.path.dirname(header))       # .../41430004
        out = os.path.abspath(a.out or os.path.join(os.getcwd(), 'GOD_coop', os.path.basename(title_dir)))
        if os.path.exists(out): die('output folder already exists: ' + out)
        print('Copying GOD package to ' + out + ' (a few GB, please wait)...')
        shutil.copytree(title_dir, out)
        header = os.path.join(out, os.path.relpath(header, title_dir))
        datadir = header + '.data'
        for root, _, files in os.walk(out):                          # copies of read-only files
            for f in files: os.chmod(os.path.join(root, f), 0o644)
    patch_god(header, datadir, patch)
    print('Done: ' + os.path.dirname(os.path.dirname(header)))

if __name__ == '__main__':
    main()
