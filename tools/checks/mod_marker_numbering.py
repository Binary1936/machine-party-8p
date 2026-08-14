#!/usr/bin/env python3
"""spawn_expand.py mis-parse detector: _MOD numbering must start at 5.

spawn_expand.py names its clones <source>_MOD<i+len(originals)+1> after
finding the four shipped markers, so a healthy expansion always produces
_MOD5.._MOD8. When the tool mis-parses a scene (its transform lookahead can
run past the next [node] header and attribute a neighbouring node's
transform to a marker), it finds fewer "originals" and the numbering starts
below 5 - which is exactly how chisel_gauntlet.tscn's spectate markers ended
up carrying a Label3D's transform (found in the 2026-08-12 audit).

This script flags any _MOD-suffixed node in mod/**/*.tscn whose number is
below 5, except a small whitelist of hand-authored nodes that legitimately
use low numbers (green_pea's hidden chairs, documented in MINIGAMES.md).

Exit 0: clean. Exit 1: any suspicious numbering, each printed.
"""
import glob
import os
import re
import sys

NODE = re.compile(r'\[node name="([^"]*_MOD(\d+))"')

# (tscn path relative to repo root, node name) pairs that are legitimate.
WHITELIST = {
    ("mod/minigames/green_pea/green_pea.tscn", "chair playerleft_MOD3"),
    ("mod/minigames/green_pea/green_pea.tscn", "chair playerleft_MOD4"),
    ("mod/minigames/green_pea/green_pea.tscn", "chair playerright_MOD3"),
    ("mod/minigames/green_pea/green_pea.tscn", "chair playerright_MOD4"),
}


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..")
    root = os.path.abspath(root)
    suspicious = []
    total = 0
    for f in sorted(glob.glob(os.path.join(root, "mod", "**", "*.tscn"), recursive=True)):
        rel = os.path.relpath(f, root)
        with open(f, encoding="utf-8", errors="replace") as fh:
            for n, line in enumerate(fh, 1):
                m = NODE.search(line)
                if not m:
                    continue
                total += 1
                name, num = m.group(1), int(m.group(2))
                if num < 5 and (rel, name) not in WHITELIST:
                    suspicious.append(
                        f"{rel}:{n}: node \"{name}\" - _MOD numbering below 5 "
                        "means spawn_expand.py found fewer than 4 originals")

    if suspicious:
        for s in suspicious:
            print("FAIL:", s)
        print(f"\n{len(suspicious)} suspicious _MOD node(s). A mis-parse "
              "attributes a NEIGHBOURING node's transform to a marker - "
              "inspect the transform against the shipped markers, and check "
              "spawn_expand.py's transform lookahead stops at the next "
              "[node] header. Legitimate hand-authored low numbers belong "
              "in this script's WHITELIST.")
        return 1

    print(f"OK: all {total} _MOD-suffixed nodes are numbered 5-8 "
          f"(or whitelisted)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
