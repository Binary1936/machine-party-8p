#!/usr/bin/env python3
"""Expand a minigame's player spawn markers from 4 to N.

Every minigame ships exactly 4 spawn markers and the spawn code does
`spawn_positions[counter]`, so player 5 is an out-of-bounds crash.

An earlier version of this tool assumed the 4 markers were collinear and
resampled along the line between the first and last. That is false in 11 of the
15 scenes - they are facing rows, rings, arcs and scattered stations, with
deviations from a straight line of up to 26 world units - so it placed players
along diagonals through the level.

What it does now:

* The original 4 markers are left EXACTLY as they are, so 1-4 player games are
  unchanged from vanilla.
* Each new marker is a clone of an existing one, displaced sideways along that
  marker's own local X axis and inheriting its full rotation. Sitting next to a
  known-good spawn, facing the same way, is far safer than interpolating a
  position out of thin air.
* Positions are taken nearest-first: the closest displacement that still clears
  every other spawn by MIN_CLEARANCE wins. Nearest-first matters - a clone one
  step from a real spawn is very likely on solid, in-bounds ground, whereas
  maximising clearance flings players across the level and through walls.

OFFSET=<units> sets the sideways step (default 1.2, about one character width),
CLEARANCE=<units> the minimum spacing (default 1.0), TARGET=<n> the player
count.

INWARD MODE (opt-in, third field in spawn_targets.txt: `path::container::inward`)

  Both signs of the sideways step are always generated, but the ranking key is
  (times-source-used, step) - which ties +offset against -offset, and Python's
  stable sort then hands it to whichever was appended first. That is always +1,
  so every clone in every scene is displaced the SAME way in world space,
  whatever is over there.

  In Tunnel Hazard that put the two right-hand clones at x=4.62 and x=5.31,
  outboard of shipped extremes of 3.42 and 4.11, standing inside the right wall
  - while the two left-hand clones, displaced by the identical +1.2, happened to
  move toward the middle of the corridor and were fine. Reported by the user
  from a screenshot on 2026-08-05; every trace read OK throughout, because the
  players were exactly on their markers and the wall art has no collider (see
  MINIGAMES.md section 16).

  `inward` adds the direction as a tiebreak: of two candidates that are equal on
  source-usage and step, prefer the one that ends up CLOSER to the centroid of
  the shipped markers. Levels are built around their contents, so "toward the
  middle of the shipped spawns" is a good proxy for "into the room rather than
  into a wall".

  It is opt-in rather than the default because flipping a clone's side changes
  where players stand in every expanded scene, and the other fourteen are
  verified as they are. Turn it on per level, look at the result, keep it.
"""
import math
import os
import re
import sys

NODE_RE = re.compile(r'^\[node name="([^"]+)" type="([^"]+)" parent="([^"]+)"\]$')
XFORM_RE = re.compile(r'^transform = Transform3D\(([^)]*)\)$')

DEFAULT_OFFSET = 1.2
# A clone must end up at least this far from every other spawn, or characters
# interpenetrate on the first frame.
MIN_CLEARANCE = 1.0


class Marker:
    def __init__(self, name, line_idx, basis, origin):
        self.name, self.line_idx = name, line_idx
        self.basis, self.origin = basis, origin

    @property
    def local_x(self):
        """The marker's own 'right', flattened to horizontal.

        The raw first basis column is NOT safe to use directly. Escalator Pit
        ships three markers with the basis (0,-1,0, 1,0,0, 0,0,1), whose first
        column is world +Y - so displacing along it buried players 1.2 units
        *underneath* their neighbour at identical x/z rather than beside them.
        That reads in-game as players doubled up on one lane with their input
        prompts drawn on top of each other, and nothing in the logs says so.

        Spawns are laid out on the ground, so the sideways step must be
        horizontal. Drop the Y component and renormalise; if the axis was
        purely vertical there is no meaningful 'right', so fall back to the
        marker's local Z (its forward) flattened, and finally to world X.
        """
        for axis in ((self.basis[0], self.basis[1], self.basis[2]),
                     (self.basis[6], self.basis[7], self.basis[8])):
            flat = (axis[0], 0.0, axis[2])
            if math.sqrt(flat[0] ** 2 + flat[2] ** 2) > 1e-6:
                return flat
        return (1.0, 0.0, 0.0)


def parse(lines, container):
    markers = []
    for i, line in enumerate(lines):
        m = NODE_RE.match(line.rstrip("\n"))
        if not m or m.group(3) != container or m.group(2) != "Marker3D":
            continue
        # A marker's properties end at the next section header, and Godot omits
        # the transform line entirely when it is the identity - so the search
        # must stop at '[' rather than run on into the next node's transform,
        # and a marker with no transform of its own is identity, not absent.
        basis, origin = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0], [0.0, 0.0, 0.0]
        for j in range(i + 1, len(lines)):
            line_j = lines[j].rstrip("\n")
            if line_j.startswith("["):
                break
            x = XFORM_RE.match(line_j)
            if x:
                nums = [float(v) for v in x.group(1).split(",")]
                basis, origin = nums[:9], nums[9:12]
                break
        markers.append(Marker(m.group(1), i, basis, origin))
    return markers


def dist(a, b):
    return math.sqrt(sum((a[k] - b[k]) ** 2 for k in range(3)))


def normalise(v):
    n = math.sqrt(sum(c * c for c in v))
    return [c / n for c in v] if n > 1e-9 else [1.0, 0.0, 0.0]


def expand(path, container, target, offset=DEFAULT_OFFSET,
           min_clearance=MIN_CLEARANCE, dry_run=False, inward=False):
    lines = open(path, encoding="utf-8").readlines()
    originals = parse(lines, container)
    if not originals:
        return f"  !! no Marker3D children under {container!r}"
    if len(originals) >= target:
        return f"  -- {len(originals)} markers already >= {target}, skipped"

    # Candidate pool: every marker displaced sideways by whole steps, both ways.
    # Picking greedily from the pool (rather than forcing one clone per marker)
    # matters for tightly packed layouts: on a line of 4 markers 1.5 apart, the
    # interior positions are already full, so the good spots are off the ends.
    candidates = []
    for src in originals:
        axis = normalise(src.local_x)
        for step in range(1, target):
            for sign in (1.0, -1.0):
                pos = [src.origin[k] + axis[k] * offset * step * sign
                       for k in range(3)]
                candidates.append((step, src, pos))
    # Nearest-first: a clone one step from a real spawn is far likelier to be on
    # solid, in-bounds ground than one flung seven steps across the level.
    placed = [list(m.origin) for m in originals]
    added, block = [], []
    used = {id(m): 0 for m in originals}

    # Centroid of the SHIPPED markers only, so the reference point cannot drift
    # as clones are added.
    centroid = [sum(m.origin[k] for m in originals) / len(originals)
                for k in range(3)]

    def inward_rank(src, pos):
        """0 if this displacement moves toward the centroid, else 1."""
        return 0 if dist(pos, centroid) < dist(src.origin, centroid) else 1

    for i in range(len(originals), target):
        # Spread across source markers before doubling up on any one, then
        # prefer the nearest step. Forklift Certified's four markers are the
        # corners of a 32x32 yard: purely nearest-first piles every new player
        # onto two corners and leaves the other two with one each.
        #
        # `inward` appends a third key, so the +offset/-offset tie is settled by
        # geometry instead of by list order. Without it the tie is broken by
        # whichever sign was generated first, which is how Tunnel Hazard's
        # right-hand clones ended up inside the wall.
        if inward:
            ranked = sorted(candidates, key=lambda c: (used[id(c[1])], c[0],
                                                       inward_rank(c[1], c[2])))
        else:
            ranked = sorted(candidates, key=lambda c: (used[id(c[1])], c[0]))

        best, best_src, best_clear = None, None, -1.0
        fallback, fb_src, fb_clear = None, None, -1.0
        for _step, src, pos in ranked:
            clear = min(dist(pos, q) for q in placed)
            if clear > fb_clear:
                fallback, fb_src, fb_clear = pos, src, clear
            if clear >= min_clearance:
                best, best_src, best_clear = pos, src, clear
                break
        if best is None:
            best, best_src, best_clear = fallback, fb_src, fb_clear
        if best is None:
            break
        used[id(best_src)] += 1

        name = f"{best_src.name}_MOD{i + 1}"
        added.append((name, best_clear))
        placed.append(best)
        candidates = [c for c in candidates if c[2] is not best]
        nums = best_src.basis + best
        block.append(f'\n[node name="{name}" type="Marker3D" parent="{container}"]\n')
        block.append("transform = Transform3D(%s)\n" % ", ".join(f"{v:g}" for v in nums))

    ins = originals[-1].line_idx + 1
    while ins < len(lines) and not lines[ins].startswith("["):
        ins += 1
    lines[ins:ins] = block

    prefix = "" if container == "." else container + "/"
    for i, line in enumerate(lines):
        if "NodePath(" not in line or "= [" not in line:
            continue
        if f'NodePath("{prefix}{originals[0].name}")' not in line:
            continue
        extra = ", ".join(f'NodePath("{prefix}{n}")' for n, _ in added)
        lines[i] = line.rstrip("\n").rstrip("]") + ", " + extra + "]\n"

    if not dry_run:
        open(path, "w", encoding="utf-8").writelines(lines)

    tightest = min(c for _, c in added)
    return (f"  {len(originals)} -> {target} markers, originals untouched; "
            f"closest pair {tightest:.2f}u ({', '.join(n for n, _ in added)})")


if __name__ == "__main__":
    target = int(os.environ.get("TARGET", "8"))
    offset = float(os.environ.get("OFFSET", DEFAULT_OFFSET))
    clearance = float(os.environ.get("CLEARANCE", MIN_CLEARANCE))
    dry = "--dry-run" in sys.argv
    for pair in [a for a in sys.argv[1:] if not a.startswith("--")]:
        parts = pair.split("::")
        path, container = parts[0], parts[1]
        # Optional third field, currently only `inward` - see the module docstring.
        mode = parts[2].strip().lower() if len(parts) > 2 else ""
        if mode not in ("", "inward"):
            sys.exit(f"unknown mode {mode!r} for {path} (expected 'inward')")
        print(os.path.basename(path) + ("  [inward]" if mode == "inward" else ""))
        print(expand(path, container, target, offset, clearance, dry,
                     inward=(mode == "inward")))
