#!/usr/bin/env python3
"""Give every Green Pea player their own chair.

The dinner scene ships four chairs (`chair player0..3`) for four diners. With
eight seats there are twice as many players as chairs, so half of them sit on
air.

This rewrites all eight chairs from the spawn markers themselves, so the chairs
follow wherever spawn_expand.py put the players:

* Position: the marker's own position, plus the small inward offset the
  original chairs had relative to their markers (the chair sits fractionally
  closer to the table than the diner's origin). Height is kept at the shipped
  y - derived, not guessed.
* Rotation: the side's original chair rotation (180 degrees apart across the
  table).
* Scale: narrowed along the table only. Seats are now 1.2 apart instead of
  ~2.0, so a full-width chair would overlap its neighbour. Scaling just that
  one basis column keeps seat height and chair depth intact - a uniform shrink
  would drop the seat and leave characters floating above it.

CHAIR_SCALE=<f> overrides the narrowing (default 0.6).
"""
import os
import re
import sys

SCENE = "mod/minigames/green_pea/green_pea.tscn"
CHAIR_PARENT = "pea dinner scene4/walls"
MARKER_PARENT = "Networked/MultiplayerSpawner/PlayerSpawnPositions"

NODE_RE = re.compile(r'^\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"\]$')
XFORM_RE = re.compile(r'^transform = Transform3D\(([^)]*)\)$')


def read_nodes(lines, parent, name_filter=None):
    out = []
    for i, line in enumerate(lines):
        m = NODE_RE.match(line.rstrip("\n"))
        if not m or m.group(3) != parent:
            continue
        if name_filter and not name_filter(m.group(1)):
            continue
        for j in range(i + 1, min(i + 4, len(lines))):
            x = XFORM_RE.match(lines[j].rstrip("\n"))
            if x:
                nums = [float(v) for v in x.group(1).split(",")]
                out.append({"name": m.group(1), "decl": i, "xform_line": j,
                            "basis": nums[:9], "origin": nums[9:12]})
                break
    return out


def fmt(basis, origin):
    return "transform = Transform3D(%s)\n" % ", ".join(
        f"{v:g}" for v in list(basis) + list(origin))


def scale_along_table(basis, s):
    """Scale the third basis COLUMN (indices 2, 5, 8) - the chair's width."""
    b = list(basis)
    for idx in (2, 5, 8):
        b[idx] *= s
    return b


def main():
    scale = float(os.environ.get("CHAIR_SCALE", "0.6"))
    lines = open(SCENE, encoding="utf-8").readlines()

    chairs = read_nodes(lines, CHAIR_PARENT,
                        lambda n: n.startswith("chair player"))
    markers = read_nodes(lines, MARKER_PARENT)
    if len(chairs) != 4:
        sys.exit(f"expected 4 player chairs, found {len(chairs)}")
    if len(markers) < 8:
        sys.exit(f"expected >= 8 markers, found {len(markers)} - run "
                 f"spawn_expand.py first")

    # Learn each side's chair template + marker->chair offset from the shipped
    # four, by pairing every chair with its nearest marker.
    sides = {}
    for ch in chairs:
        near = min(markers, key=lambda m: (m["origin"][0] - ch["origin"][0]) ** 2
                   + (m["origin"][2] - ch["origin"][2]) ** 2)
        key = "left" if ch["origin"][0] < 0 else "right"
        s = sides.setdefault(key, {"basis": ch["basis"], "y": ch["origin"][1],
                                   "dx": [], "dz": [], "chairs": []})
        s["dx"].append(ch["origin"][0] - near["origin"][0])
        s["dz"].append(ch["origin"][2] - near["origin"][2])
        s["chairs"].append(ch)

    for key, s in sides.items():
        s["dx"] = sum(s["dx"]) / len(s["dx"])
        s["dz"] = sum(s["dz"]) / len(s["dz"])
        print(f"  {key:5} chairs: offset from marker "
              f"dx={s['dx']:+.3f} dz={s['dz']:+.3f}  y={s['y']:.3f}")

    # Every marker gets a chair, on whichever side it sits.
    wanted = []
    for m in markers:
        key = "left" if m["origin"][0] < 0 else "right"
        s = sides[key]
        wanted.append((key, [m["origin"][0] + s["dx"], s["y"],
                             m["origin"][2] + s["dz"]]))

    # Reuse the four existing chair nodes for the first four positions on each
    # side, then append new ones. Sorting by z keeps the pairing tidy.
    per_side = {"left": [], "right": []}
    for key, pos in wanted:
        per_side[key].append(pos)
    for key in per_side:
        per_side[key].sort(key=lambda p: p[2])

    edits = {}
    new_nodes = []
    for key, positions in per_side.items():
        s = sides[key]
        basis = scale_along_table(s["basis"], scale)
        existing = sorted(s["chairs"], key=lambda c: c["origin"][2])
        for i, pos in enumerate(positions):
            if i < len(existing):
                edits[existing[i]["xform_line"]] = fmt(basis, pos)
            else:
                name = f"chair player{key}_MOD{i + 1}"
                new_nodes.append(
                    f'\n[node name="{name}" type="MeshInstance3D" '
                    f'parent="{CHAIR_PARENT}"]\n'
                    + fmt(basis, pos)
                    + "layers = 9\nlod_bias = 41.6\n"
                    + f'mesh = {mesh_of(lines, existing[0])}\n'
                    + 'skeleton = NodePath("")\n')

    for ln, text in edits.items():
        lines[ln] = text

    last = max(c["decl"] for c in chairs)
    ins = last + 1
    while ins < len(lines) and not lines[ins].startswith("["):
        ins += 1
    lines[ins:ins] = new_nodes

    open(SCENE, "w", encoding="utf-8").writelines(lines)
    print(f"  {len(chairs)} -> {len(wanted)} chairs, narrowed to {scale:g}x "
          f"along the table ({len(new_nodes)} added)")


def mesh_of(lines, chair):
    for j in range(chair["decl"], chair["decl"] + 8):
        if lines[j].startswith("mesh = "):
            return lines[j].split("=", 1)[1].strip()
    return 'SubResource("ArrayMesh_50eab")'


if __name__ == "__main__":
    main()
