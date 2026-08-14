#!/usr/bin/env python3
"""Pitfall 30 guard: every mod-added @rpc must be named zz_*.

Godot assigns RPC wire ids from the sorted set of @rpc method names in a
node's script chain. A mod RPC named mod_* sorts before most vanilla names
and silently renumbers vanilla's ids, misrouting RPCs in any mixed lobby at
any roster size - this is the whole basis of vanilla-compat. Nothing in
vanilla begins with "zz", so zz_-prefixed names sort after every vanilla
name and leave vanilla's ids untouched.

Mod-added functions are identifiable by the project's own naming convention:
they start with mod_ or contain _mod_. This script finds every @rpc-annotated
function in mod/**/*.gd whose name matches that convention and fails unless
it starts with zz_. (Vanilla RPCs in the overlay files carry vanilla names
and are ignored; "mode" does not match the convention.)

Exit 0: all mod RPCs are zz_-prefixed. Exit 1: any violation, each printed.
"""
import glob
import os
import re
import sys

FUNC = re.compile(r"^\s*func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
RPC_ANNOTATION = re.compile(r"^\s*@rpc\b")
MOD_NAME = re.compile(r"(^mod_)|(_mod_)")


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..")
    root = os.path.abspath(root)
    violations = []
    rpc_count = 0
    for f in sorted(glob.glob(os.path.join(root, "mod", "**", "*.gd"), recursive=True)):
        with open(f, encoding="utf-8", errors="replace") as fh:
            lines = fh.readlines()
        pending_rpc = False
        for n, line in enumerate(lines, 1):
            if RPC_ANNOTATION.match(line):
                pending_rpc = True
                continue
            m = FUNC.match(line)
            if m:
                if pending_rpc:
                    name = m.group(1)
                    if MOD_NAME.search(name) and not name.startswith("zz_"):
                        violations.append(
                            f"{os.path.relpath(f, root)}:{n}: @rpc func "
                            f"\"{name}\" is mod-added but not zz_-prefixed")
                    if name.startswith("zz_"):
                        rpc_count += 1
                pending_rpc = False
            elif line.strip() and not line.strip().startswith("#"):
                # any other non-blank, non-comment line breaks the
                # annotation->func adjacency
                pending_rpc = False

    if violations:
        for v in violations:
            print("FAIL:", v)
        print("\nRename with a zz_ prefix - see pitfall 30 in UPDATING.md. "
              "An unprefixed mod @rpc renumbers vanilla's RPC ids and breaks "
              "vanilla-compat silently.")
        return 1

    print(f"OK: all {rpc_count} mod-added @rpc function(s) are zz_-prefixed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
