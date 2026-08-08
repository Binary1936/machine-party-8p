#!/usr/bin/env python3
"""Godot 4.5 PCK (format v3) reader/writer.

Format v3 layout:
  0x00 magic 'GDPC'
  0x04 u32 pack format version (3)
  0x08 u32 ver_major, 0x0C u32 ver_minor, 0x10 u32 ver_patch
  0x14 u32 pack_flags (1=dir encrypted, 2=file_base relative)
  0x18 u64 file_base
  0x20 u32 directory offset   (reserved[0] in older docs; v3 puts index at EOF)
  0x24..0x5F reserved
  file data ...
  directory at dir_offset:
    u32 file_count
    per entry: u32 path_len, path bytes (padded to 4), u64 offset, u64 size,
               16 bytes md5, u32 flags
"""
import hashlib
import os
import struct
import sys

MAGIC = b"GDPC"
PACK_DIR_ENCRYPTED = 1
PACK_REL_FILEBASE = 2


class Entry:
    __slots__ = ("path", "offset", "size", "md5", "flags")

    def __init__(self, path, offset, size, md5, flags):
        self.path, self.offset, self.size, self.md5, self.flags = (
            path, offset, size, md5, flags)


def read_index(path):
    f = open(path, "rb")
    h = f.read(0x60)
    if h[:4] != MAGIC:
        raise SystemExit("not a GDPC pack")
    ver, maj, mnr, pat = struct.unpack_from("<IIII", h, 4)
    flags, file_base = struct.unpack_from("<IQ", h, 0x14)
    dir_off = struct.unpack_from("<I", h, 0x20)[0]
    if flags & PACK_DIR_ENCRYPTED:
        raise SystemExit("encrypted directory - not supported")
    if not (flags & PACK_REL_FILEBASE):
        file_base = 0

    f.seek(dir_off)
    count = struct.unpack("<I", f.read(4))[0]
    entries = []
    for _ in range(count):
        plen = struct.unpack("<I", f.read(4))[0]
        raw = f.read(plen)
        p = raw.rstrip(b"\0").decode("utf-8")
        off, size = struct.unpack("<QQ", f.read(16))
        md5 = f.read(16)
        eflags = struct.unpack("<I", f.read(4))[0]
        entries.append(Entry(p, off + file_base, size, md5, eflags))
    return f, entries, (ver, maj, mnr, pat)


def cmd_list(pck):
    _, entries, v = read_index(pck)
    print(f"# godot {v[1]}.{v[2]}.{v[3]}  pack v{v[0]}  {len(entries)} files")
    for e in entries:
        print(f"{e.size:>10}  {e.flags}  {e.path}")


def cmd_extract(pck, outdir, prefix=None):
    f, entries, _ = read_index(pck)
    n = 0
    for e in entries:
        rel = e.path
        for pre in ("res://", "user://"):
            if rel.startswith(pre):
                rel = rel[len(pre):]
                break
        if prefix and not rel.startswith(prefix):
            continue
        dst = os.path.join(outdir, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        f.seek(e.offset)
        with open(dst, "wb") as o:
            remaining = e.size
            while remaining:
                chunk = f.read(min(1 << 20, remaining))
                if not chunk:
                    break
                o.write(chunk)
                remaining -= len(chunk)
        n += 1
    print(f"extracted {n} files -> {outdir}")


def cmd_pack(srcdir, outpck, ver=(3, 4, 5, 1)):
    """Rebuild a pck from a directory tree (inverse of extract)."""
    files = []
    for root, _, names in os.walk(srcdir):
        for name in names:
            full = os.path.join(root, name)
            rel = os.path.relpath(full, srcdir).replace(os.sep, "/")
            files.append(("res://" + rel, full))
    pack_files(files, outpck, ver)


def pack_files(files, outpck, ver=(3, 4, 5, 1)):
    """Pack an explicit [(res_path, on_disk_path), ...] list into a pck."""
    files = sorted(files)

    # Header is 0x60; align file data to 16 bytes like the engine does.
    file_base = 0x60
    offsets = {}
    cur = file_base
    for rel, full in files:
        cur = (cur + 15) & ~15
        offsets[rel] = cur
        cur += os.path.getsize(full)
    dir_off = (cur + 15) & ~15

    with open(outpck, "wb") as o:
        o.write(MAGIC)
        o.write(struct.pack("<IIII", ver[0], ver[1], ver[2], ver[3]))
        o.write(struct.pack("<IQ", PACK_REL_FILEBASE, file_base))
        o.write(struct.pack("<I", dir_off))
        o.write(b"\0" * (0x60 - o.tell()))

        md5s = {}
        for rel, full in files:
            o.seek(offsets[rel])
            h = hashlib.md5()
            with open(full, "rb") as i:
                while True:
                    chunk = i.read(1 << 20)
                    if not chunk:
                        break
                    h.update(chunk)
                    o.write(chunk)
            md5s[rel] = h.digest()

        o.seek(dir_off)
        o.write(struct.pack("<I", len(files)))
        for rel, full in files:
            b = rel.encode("utf-8")
            pad = (-len(b)) % 4
            o.write(struct.pack("<I", len(b) + pad))
            o.write(b + b"\0" * pad)
            o.write(struct.pack("<QQ", offsets[rel] - file_base,
                                os.path.getsize(full)))
            o.write(md5s[rel])
            o.write(struct.pack("<I", 0))
    print(f"packed {len(files)} files -> {outpck} ({os.path.getsize(outpck)} bytes)")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "list":
        cmd_list(sys.argv[2])
    elif cmd == "extract":
        cmd_extract(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
    elif cmd == "pack":
        cmd_pack(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit(__doc__)
