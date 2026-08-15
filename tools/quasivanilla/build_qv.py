#!/usr/bin/env python3
"""Build the quasi-vanilla test pck.

Same recipe as tools/build.py - pristine `extracted/` as the base, an overlay on
top, drop the compiled/remap siblings of anything overlaid - but the overlay is
`tools/quasivanilla/overlay/` and the output is `tools/quasivanilla/qv.pck`.

The point of this build is to be WIRE-IDENTICAL to the stock game: it reports
the vanilla game_version (globals is deliberately not overlaid), stamps no "mod8p"
key, and keeps every @rpc set exactly as shipped. The only additions are the
local-test harness entry points (`-localtest`, `-startgame`, window titling), so
this copy can play the vanilla side of a mixed lobby against the 8-player mod
without Steam or a second machine.
"""
import os
import sys

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import pck

ROOT = os.path.dirname(TOOLS)
BASE = os.path.join(ROOT, "extracted")
MOD = os.path.join(ROOT, "tools", "quasivanilla", "overlay")
OUT = os.path.join(ROOT, "tools", "quasivanilla", "qv.pck")

# A source file supplied by the overlay supersedes these compiled/remap siblings.
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


if __name__ == "__main__":
    main()
