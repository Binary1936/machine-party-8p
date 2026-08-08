#!/usr/bin/env python3
"""Read the identifier and constant pools out of Godot 4.4+ .gdc files.

.gdc layout:  'GDSC' | u32 version | u32 decompressed_size | zstd stream
Decompressed: u32 identifier_count, u32 constant_count, u32 token_line_count,
              u32 token_count
              identifiers: u32 char_count, then char_count * u32, each char
                           XOR 0xB6B6B6B6
              constants:   standard Godot binary Variant encoding
              ...token stream follows
"""
import compression.zstd as zstd
import os
import struct
import sys

MASK = 0xB6B6B6B6


def read_ident(buf, off):
    (n,) = struct.unpack_from("<I", buf, off)
    off += 4
    chars = []
    for _ in range(n):
        (c,) = struct.unpack_from("<I", buf, off)
        chars.append(chr(c ^ MASK))
        off += 4
    return "".join(chars), off


def read_variant(buf, off):
    """Minimal Godot binary Variant decoder - enough for script constant pools."""
    (raw,) = struct.unpack_from("<I", buf, off)
    off += 4
    t = raw & 0xFFFF
    wide = bool(raw & 0x10000)  # ENCODE_FLAG_64
    if t == 0:
        return None, off
    if t == 1:  # bool
        (v,) = struct.unpack_from("<I", buf, off)
        return bool(v), off + 4
    if t == 2:  # int
        if wide:
            return struct.unpack_from("<q", buf, off)[0], off + 8
        return struct.unpack_from("<i", buf, off)[0], off + 4
    if t == 3:  # float
        if wide:
            return struct.unpack_from("<d", buf, off)[0], off + 8
        return struct.unpack_from("<f", buf, off)[0], off + 4
    if t == 4:  # string
        (n,) = struct.unpack_from("<I", buf, off)
        off += 4
        s = buf[off:off + n].split(b"\0")[0].decode("utf-8", "replace")
        off += n + ((-n) % 4)
        return s, off
    if t == 21:  # StringName
        (n,) = struct.unpack_from("<I", buf, off)
        off += 4
        s = buf[off:off + n].split(b"\0")[0].decode("utf-8", "replace")
        off += n + ((-n) % 4)
        return s, off
    raise ValueError(f"unhandled variant type {t} at {off}")


def parse(path):
    d = open(path, "rb").read()
    if d[:4] != b"GDSC":
        raise ValueError("not a gdc")
    version, declen = struct.unpack_from("<II", d, 4)
    buf = zstd.decompress(d[12:]) if declen else d[12:]
    ic, cc, lc, tc = struct.unpack_from("<IIII", buf, 0)
    off = 16
    idents = []
    for _ in range(ic):
        s, off = read_ident(buf, off)
        idents.append(s)
    consts = []
    for _ in range(cc):
        try:
            v, off = read_variant(buf, off)
        except (ValueError, struct.error):
            break
        consts.append(v)
    return {"version": version, "identifiers": idents, "constants": consts,
            "token_count": tc, "line_count": lc, "buf": buf, "tokens_at": off}


if __name__ == "__main__":
    for p in sys.argv[1:]:
        try:
            r = parse(p)
        except Exception as e:
            print(f"!! {p}: {e}", file=sys.stderr)
            continue
        print(f"=== {p}  ({r['token_count']} tokens) ===")
        print("-- identifiers --")
        for s in r["identifiers"]:
            print(f"   {s}")
        print("-- constants --")
        for c in r["constants"]:
            print(f"   {c!r}")
