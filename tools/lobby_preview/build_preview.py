#!/usr/bin/env python3
"""Lobby PREVIEW build: the mod pck plus a live seat-placement mode for the
Steam lobby's eight character previews.

The real lobby only renders preview slots that are occupied, and only the
Steam lobby scene (`scenes/lobby/lobby_scene.tscn`) has the eight slots — the
`-localtest` debug lobby never shows them. So placing players 5-8 by hand
needs a build where one person hosting alone sees all eight, can nudge a
slot in the real renderer, and can print the resulting `.tscn` lines. This
script produces that build:

  * base `extracted/` + overlay `mod/` exactly as `tools/build.py` does, then
  * `scenes/lobby/scripts/lobby_scene.gd` is replaced by a patched copy of the
    mod's file: all eight previews forced visible in `update_player_list()`,
    a `pv_process(_delta)` hook at the end of `_process()`, and the contents of
    `lobby_preview.gd.inc` appended (the key handling, auto-place and export).

Nothing here touches `mod/` or `dist/`. Output goes to `testgame/` (or the
folder given as the first argument). Rebuild `testgame/` from `dist/` after
use — `tools/build.py` then `cp dist/"Machine Party.pck" testgame/`.

Keys, once a Steam lobby is hosted (see UPDATING.md, Testing):
  F5-F8 select P5-P8 · F10 auto-place on the host's lap · arrows X/Z ·
  PgUp/PgDn Y · Home/End yaw · Ins/Del nametag · Shift fine ·
  F9 print the .tscn lines to the log and clipboard · F11 reset the slot.

Both anchors below are asserted; if a future rebuild changes them the build
fails loudly instead of producing a preview that silently lacks the mode.
"""
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
ROOT = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
import pck                      # noqa: E402
import build as mod_build       # noqa: E402

BASE = os.path.join(ROOT, "extracted")
MOD = os.path.join(ROOT, "mod")
LOBBY_GD = "scenes/lobby/scripts/lobby_scene.gd"
INC = os.path.join(HERE, "lobby_preview.gd.inc")

ANCHOR_PROCESS = (
    "func _process(_delta: float) -> void :\n"
    "\n"
    "\tif Input.is_action_just_pressed(\"lobby_toggle_debug_player\"):\n"
    "\t\tif multiplayer and not multiplayer.is_server():\n"
    "\t\t\trequest_player_debug_rpc.rpc_id(1, multiplayer.get_unique_id())\n"
)
ANCHOR_LIST = "\tlobby_handler.update_player_list(player_order_by_seat.values())\n"

FORCE_VISIBLE = (
    "\n"
    "\t# LOBBY PREVIEW BUILD ONLY: force all eight previews visible so one\n"
    "\t# person hosting alone can see and place the lap layout.\n"
    "\tfor i in lobby_handler.players.size():\n"
    "\t\tlobby_handler.players[i].visible = true\n"
    "\t\tlobby_handler.nametags[i].text = \"P%d\" % (i + 1)\n"
)


def patched_lobby_script():
    src = open(os.path.join(MOD, LOBBY_GD), encoding="utf-8").read()
    assert src.count(ANCHOR_PROCESS) == 1, "lobby_scene.gd: _process() anchor not found"
    assert src.count(ANCHOR_LIST) == 1, "lobby_scene.gd: update_player_list anchor not found"
    src = src.replace(ANCHOR_PROCESS, ANCHOR_PROCESS + "\n\tpv_process(_delta)\n")
    src = src.replace(ANCHOR_LIST, ANCHOR_LIST + FORCE_VISIBLE)
    return src.rstrip("\n") + "\n\n" + open(INC, encoding="utf-8").read()


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "testgame")
    out = os.path.join(out_dir, "Machine Party.pck")
    assert os.path.isdir(out_dir), out_dir

    base = mod_build.collect(BASE)
    overlay = mod_build.collect(MOD)
    assert LOBBY_GD in overlay, LOBBY_GD

    with tempfile.TemporaryDirectory() as tmp:
        patched = os.path.join(tmp, LOBBY_GD)
        os.makedirs(os.path.dirname(patched))
        with open(patched, "w", encoding="utf-8") as f:
            f.write(patched_lobby_script())
        overlay[LOBBY_GD] = patched

        files = dict(base)
        dropped = 0
        for rel, full in overlay.items():
            stem, ext = os.path.splitext(rel)
            for sup in mod_build.SUPERSEDES.get(ext, []):
                if files.pop(stem + sup, None) is not None:
                    dropped += 1
            files[rel] = full
        pck.pack_files([("res://" + r, f) for r, f in files.items()], out)

    print("PREVIEW pck -> %s  (%d files, %d overlay, %d superseded siblings dropped)"
          % (out, len(files), len(overlay), dropped))
    print("This is NOT the mod build: rebuild testgame/ from dist/ when done.")


if __name__ == "__main__":
    main()
