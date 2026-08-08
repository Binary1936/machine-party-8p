#!/usr/bin/env python3
"""Build the 8-player mod pck.

Takes the pristine extraction in `extracted/` as the base, lays the overlay in
`mod/` on top, and writes `dist/Machine Party.pck`.

Shipping a script as plain `.gd` source works because Godot's release template
still contains the GDScript parser. For each overridden script we drop the
`.gd.remap` (which points res://x.gd at the compiled res://x.gdc) and the
`.gdc` itself, so the loader falls through to the text file we supply. Same
idea for `.tscn` over `.scn`. This is what lets the mod build without the
4.5.1 export templates.
"""
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pck

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "extracted")
MOD = os.path.join(ROOT, "mod")
OUT = os.path.join(ROOT, "dist", "Machine Party.pck")

# A source file supplied by the mod supersedes these compiled/remap siblings.
SUPERSEDES = {
    ".gd": [".gd.remap", ".gdc"],
    ".tscn": [".tscn.remap", ".scn"],
    ".tres": [".tres.remap", ".res"],
}


def collect(root):
    out = {}
    for dirpath, _, names in os.walk(root):
        for n in names:
            full = os.path.join(dirpath, n)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            out[rel] = full
    return out


def main():
    base = collect(BASE)
    overlay = collect(MOD) if os.path.isdir(MOD) else {}

    files = dict(base)
    added, replaced, dropped = [], [], []

    for rel, full in sorted(overlay.items()):
        (replaced if rel in base else added).append(rel)
        files[rel] = full

        stem, ext = os.path.splitext(rel)
        for suffix in SUPERSEDES.get(ext, []):
            victim = stem + suffix
            if victim in files:
                del files[victim]
                dropped.append(victim)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    pck.pack_files([("res://" + r, f) for r, f in files.items()], OUT)

    for rel in replaced:
        print(f"  replaced  {rel}")
    for rel in added:
        print(f"  added     {rel}")
    for rel in dropped:
        print(f"  dropped   {rel}")
    print(f"\n{len(files)} files ({len(base)} base "
          f"{len(replaced)} replaced, {len(added)} added, {len(dropped)} dropped)")

    stage = os.environ.get("MP_DEPLOY")
    if stage:
        shutil.copy2(OUT, os.path.join(stage, "Machine Party.pck"))
        print(f"deployed -> {stage}")


if __name__ == "__main__":
    main()
