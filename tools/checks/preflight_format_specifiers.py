#!/usr/bin/env python3
"""Pitfall 16 guard: invalid % format specifiers in GDScript string literals.

A stray %r (a Python habit) in a .gd string is a Parse Error that the boot
test does not catch - the script parses only when its minigame loads, and the
minigame then comes up as a black screen with the music still looping.

This is the committed form of the pre-flight recipe in UPDATING.md
("Working environment" / "Testing"). Scans mod/**/*.gd only.

Exit 0: clean. Exit 1: at least one invalid specifier, each printed as
path:line: invalid %X.
"""
import glob
import os
import re
import sys

STRLIT = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
SPEC = re.compile(r"%[-+ 0#]*[\d*]*(?:\.[\d*]+)?([a-zA-Z%])")
OK = set("scdoxXfv%")


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..")
    root = os.path.abspath(root)
    bad = 0
    for f in sorted(glob.glob(os.path.join(root, "mod", "**", "*.gd"), recursive=True)):
        with open(f, encoding="utf-8", errors="replace") as fh:
            for n, line in enumerate(fh, 1):
                for s in STRLIT.findall(line):
                    for m in SPEC.finditer(s):
                        if m.group(1) not in OK:
                            print(f"{os.path.relpath(f, root)}:{n}: invalid %{m.group(1)}")
                            bad += 1
    if bad:
        print(f"\nFAIL: {bad} invalid format specifier(s). "
              "Valid GDScript specifiers are: s c d o x X f v %")
        return 1
    print("OK: no invalid % format specifiers in mod/**/*.gd")
    return 0


if __name__ == "__main__":
    sys.exit(main())
