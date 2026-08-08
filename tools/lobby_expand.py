#!/usr/bin/env python3
"""Expand the lobby's character preview slots from 4 to N.

`lobby_handler.gd` indexes `customization_assigners[counter]` by lobby seat, and
lobby_scene.tscn wires exactly four preview characters - so a fifth player is an
index-out-of-bounds crash, not merely a cramped layout.

Player1 has its customization assigner expanded inline (~22 nodes); Player2-4
use a compact `instance=ExtResource(...)` assigner (~8 nodes). Player2 is
therefore the clone template. All internal NodePaths in that block are relative
("../..."), so a copy needs only its node name and parent paths rewritten.

New slots are spread across the same span the original four occupied, so the
lobby camera framing still contains everyone.
"""
import os
import re
import sys

# Override with PARENT=... for scenes that nest the preview differently.
# multiplayer_menu.tscn (the debug lobby) also contains a dead "Old/..." copy;
# matching the parent path exactly is what keeps this off it.
PARENT = os.environ.get("PARENT", "LobbyPreviewViewport/LobbyViewport/Players")
TEMPLATE = "Player2"
ARRAYS = ["players", "player_models", "customization_assigners", "nametags"]
NODE_RE = re.compile(r'^\[node name="([^"]+)"(?: type="([^"]+)")? parent="([^"]+)"')
XFORM_RE = re.compile(r'^transform = Transform3D\(([^)]*)\)$')


def slot_decl(lines, name):
    """Index of the `[node name="<name>" ... parent="<PARENT>"]` line."""
    want = f'[node name="{name}" type="Node3D" parent="{PARENT}"]'
    for i, line in enumerate(lines):
        if line.rstrip("\n") == want:
            return i
    raise SystemExit(f"could not find slot {name}")


def block_end(lines, start, name):
    """End of a slot's subtree: the next [node] that is not a descendant."""
    prefix = f"{PARENT}/{name}"
    i = start + 1
    while i < len(lines):
        m = NODE_RE.match(lines[i].rstrip("\n"))
        if m:
            p = m.group(3)
            if not (p == prefix or p.startswith(prefix + "/")):
                return i
        i += 1
    return len(lines)


def origin_of(lines, decl):
    for j in range(decl + 1, min(decl + 4, len(lines))):
        m = XFORM_RE.match(lines[j].rstrip("\n"))
        if m:
            return j, [float(v) for v in m.group(1).split(",")]
    raise SystemExit("slot has no transform")


def expand(path, target, dry_run=False):
    lines = open(path, encoding="utf-8").readlines()

    existing = []
    n = 1
    while True:
        name = f"Player{n}"
        try:
            existing.append((name, slot_decl(lines, name)))
        except SystemExit:
            break
        n += 1
    if len(existing) >= target:
        return f"  -- {len(existing)} slots already >= {target}, skipped"

    # Clone template block.
    t_start = slot_decl(lines, TEMPLATE)
    t_end = block_end(lines, t_start, TEMPLATE)
    template = lines[t_start:t_end]

    added = []
    new_blocks = []
    for i in range(len(existing), target):
        name = f"Player{i + 1}"
        added.append(name)
        blk = []
        for line in template:
            line = line.replace(f"{PARENT}/{TEMPLATE}", f"{PARENT}/{name}")
            line = line.replace(f'[node name="{TEMPLATE}" type="Node3D"',
                                f'[node name="{name}" type="Node3D"')
            blk.append(line)
        new_blocks.extend(blk)

    # Insert after the last existing slot's block.
    last_name, last_decl = existing[-1]
    ins = block_end(lines, last_decl, last_name)
    lines[ins:ins] = new_blocks

    # Re-read positions (indices shifted) and spread all slots across the span.
    decls = [(f"Player{i+1}", slot_decl(lines, f"Player{i+1}")) for i in range(target)]
    first = origin_of(lines, decls[0][1])[1]
    last = origin_of(lines, decls[len(existing) - 1][1])[1]
    for idx, (name, decl) in enumerate(decls):
        j, nums = origin_of(lines, decl)
        t = idx / (target - 1)
        for k in range(3):
            nums[9 + k] = first[9 + k] + (last[9 + k] - first[9 + k]) * t
        lines[j] = "transform = Transform3D(%s)\n" % ", ".join(f"{v:g}" for v in nums)

    # Extend the exported NodePath arrays that list the slots.
    for i, line in enumerate(lines):
        key = line.split(" = ", 1)[0]
        if key not in ARRAYS or "NodePath(" not in line:
            continue
        entries = re.findall(r'NodePath\("([^"]+)"\)', line)
        tmpl = next((e for e in entries if f"/{last_name}" in e), None)
        if tmpl is None:
            continue
        extra = [f'NodePath("{tmpl.replace("/" + last_name, "/" + a)}")' for a in added]
        lines[i] = line.rstrip("\n").rstrip("]") + ", " + ", ".join(extra) + "]\n"

    if not dry_run:
        open(path, "w", encoding="utf-8").writelines(lines)
    span = max(abs(last[9 + k] - first[9 + k]) for k in range(3))
    return (f"  {len(existing)} -> {target} preview slots across span {span:.2f} "
            f"(added {', '.join(added)}; {len(template)}-line template)")


if __name__ == "__main__":
    target = int(os.environ.get("TARGET", "8"))
    dry = "--dry-run" in sys.argv
    for path in [a for a in sys.argv[1:] if not a.startswith("--")]:
        print(os.path.basename(path))
        print(expand(path, target, dry))
