#!/usr/bin/env python3
"""Overlay-count drift check.

The overlay file counts are stated in two docs (UPDATING.md's manifest
header and README.md's overview) and have drifted before (50 -> 53 -> 56).
This script counts what is actually in mod/ and compares it against the
numbers each doc claims, so a stale count fails CI instead of waiting for
the next reconciliation pass.

Expected doc formats (regexes below tolerate emphasis/backticks):
  UPDATING.md: "56 files: 40 `.gd`, 16 `.tscn`"
  README.md:   "overlay of 56 files (40 `.gd`, 16 `.tscn`)"

Exit 0: both docs match reality. Exit 1: any mismatch or unparsable claim.
"""
import os
import re
import sys

CLAIM = re.compile(
    r"(\d+)\s+files\D{0,4}(\d+)\s+`?\.gd`?,\s*(\d+)\s+`?\.tscn`?")


def actual_counts(root):
    gd = tscn = other = 0
    for dirpath, _, files in os.walk(os.path.join(root, "mod")):
        for f in files:
            if f.endswith(".gd"):
                gd += 1
            elif f.endswith(".tscn"):
                tscn += 1
            else:
                other += 1
    return gd, tscn, other


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..")
    root = os.path.abspath(root)

    gd, tscn, other = actual_counts(root)
    total = gd + tscn + other
    failures = []

    if other:
        failures.append(
            f"mod/ contains {other} file(s) that are neither .gd nor .tscn - "
            "the manifest convention assumes only those two types")

    for doc in ("UPDATING.md", "README.md"):
        path = os.path.join(root, doc)
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        m = CLAIM.search(text)
        if not m:
            failures.append(f"{doc}: could not find an overlay count claim "
                            "matching 'N files: N .gd, N .tscn'")
            continue
        c_total, c_gd, c_tscn = (int(x) for x in m.groups())
        if (c_total, c_gd, c_tscn) != (total, gd, tscn):
            failures.append(
                f"{doc} claims {c_total} files ({c_gd} .gd, {c_tscn} .tscn) "
                f"but mod/ actually holds {total} ({gd} .gd, {tscn} .tscn)")

    if failures:
        for f in failures:
            print("FAIL:", f)
        print("\nUpdate the stale count(s) - or if mod/ changed shape, "
              "update the overlay manifest in UPDATING.md too.")
        return 1

    print(f"OK: mod/ holds {total} files ({gd} .gd, {tscn} .tscn), "
          "matching UPDATING.md and README.md")
    return 0


if __name__ == "__main__":
    sys.exit(main())
