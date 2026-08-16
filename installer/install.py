#!/usr/bin/env python3
"""Machine Party - 8 Player Mod installer.

Patches your own copy of the game in place. Nothing here contains the game's
assets: it reads the .pck you already own, swaps in the mod's files, and writes
the result back.

    python3 install.py              install (auto-detects the game)
    python3 install.py --uninstall  report the state and how to get back
    python3 install.py --game-dir "/path/to/Machine Party_Linux"

No backup is kept: the .pck is patched in place, straight from whatever is
installed right now. Steam's "Verify integrity of game files" is the way back
to the original, and the installer refuses to patch an already-patched .pck
because without a pristine base the result would be wrong either way.
"""
import argparse
import glob
import hashlib
import os
import platform
import re
import struct
import sys

MAGIC = b"GDPC"
PACK_DIR_ENCRYPTED = 1
PACK_REL_FILEBASE = 2
PCK_NAME = "Machine Party.pck"
# Older installer versions kept a copy of the original here. Nothing reads it
# any more - it only survives as something to offer to clean up.
BACKUP_NAME = "Machine Party.pck.vanilla"
SUPPORTED_VERSION = "v2.1.2"

# Files the mod ADDS rather than replaces. These have nothing to displace in a
# stock .pck, so they must not count towards the "game was updated" check.
# Keep in sync with the overlay - see UPDATING.md section 7.
ADDED_FILES = {
    "modules/multiplayer_lobby/mod_player_name_list.gd",
}

# A mod-supplied source file replaces these compiled/remap siblings.
SUPERSEDES = {
    ".gd": [".gd.remap", ".gdc"],
    ".tscn": [".tscn.remap", ".scn"],
    ".tres": [".tres.remap", ".res"],
}

HERE = os.path.dirname(os.path.abspath(__file__))
OVERLAY = os.path.join(HERE, "mod")
if not os.path.isdir(OVERLAY):
    # running from the source repo, where the overlay is at the repo root
    OVERLAY = os.path.normpath(os.path.join(HERE, "..", "mod"))


# --------------------------------------------------------------------------
# Godot 4.5 PCK (format v3)
# --------------------------------------------------------------------------

class Entry:
    __slots__ = ("path", "offset", "size", "md5", "flags")

    def __init__(self, path, offset, size, md5, flags):
        self.path, self.offset, self.size = path, offset, size
        self.md5, self.flags = md5, flags


def read_index(path):
    f = open(path, "rb")
    h = f.read(0x60)
    if h[:4] != MAGIC:
        die(f"{path} is not a Godot pack file.")
    flags, file_base = struct.unpack_from("<IQ", h, 0x14)
    dir_off = struct.unpack_from("<I", h, 0x20)[0]
    if flags & PACK_DIR_ENCRYPTED:
        die("This .pck has an encrypted index; the installer cannot patch it.")
    if not (flags & PACK_REL_FILEBASE):
        file_base = 0

    f.seek(dir_off)
    count = struct.unpack("<I", f.read(4))[0]
    entries = []
    for _ in range(count):
        plen = struct.unpack("<I", f.read(4))[0]
        p = f.read(plen).rstrip(b"\0").decode("utf-8")
        off, size = struct.unpack("<QQ", f.read(16))
        md5 = f.read(16)
        eflags = struct.unpack("<I", f.read(4))[0]
        entries.append(Entry(p, off + file_base, size, md5, eflags))
    return f, entries


def write_pck(out_path, sources, ver=(3, 4, 5, 1)):
    """sources: ordered [(res_path, ('disk', path) | ('pck', handle, off, size))]"""
    file_base = 0x60
    offsets, sizes = {}, {}
    cur = file_base
    for res, src in sources:
        cur = (cur + 15) & ~15
        offsets[res] = cur
        sizes[res] = os.path.getsize(src[1]) if src[0] == "disk" else src[3]
        cur += sizes[res]
    dir_off = (cur + 15) & ~15

    with open(out_path, "wb") as o:
        o.write(MAGIC)
        o.write(struct.pack("<IIII", *ver))
        o.write(struct.pack("<IQ", PACK_REL_FILEBASE, file_base))
        o.write(struct.pack("<I", dir_off))
        o.write(b"\0" * (0x60 - o.tell()))

        md5s = {}
        for res, src in sources:
            o.seek(offsets[res])
            h = hashlib.md5()
            if src[0] == "disk":
                with open(src[1], "rb") as i:
                    for chunk in iter(lambda: i.read(1 << 20), b""):
                        h.update(chunk)
                        o.write(chunk)
            else:
                _, fh, off, size = src
                fh.seek(off)
                left = size
                while left:
                    chunk = fh.read(min(1 << 20, left))
                    if not chunk:
                        break
                    h.update(chunk)
                    o.write(chunk)
                    left -= len(chunk)
            md5s[res] = h.digest()

        o.seek(dir_off)
        o.write(struct.pack("<I", len(sources)))
        for res, _ in sources:
            b = res.encode("utf-8")
            pad = (-len(b)) % 4
            o.write(struct.pack("<I", len(b) + pad))
            o.write(b + b"\0" * pad)
            o.write(struct.pack("<QQ", offsets[res] - file_base, sizes[res]))
            o.write(md5s[res])
            o.write(struct.pack("<I", 0))


# --------------------------------------------------------------------------
# Locating the game
# --------------------------------------------------------------------------

def steam_roots():
    home = os.path.expanduser("~")
    sysname = platform.system()
    if sysname == "Windows":
        cands = [r"C:\Program Files (x86)\Steam", r"C:\Program Files\Steam"]
    elif sysname == "Darwin":
        cands = [os.path.join(home, "Library/Application Support/Steam")]
    else:
        cands = [os.path.join(home, ".local/share/Steam"),
                 os.path.join(home, ".steam/steam"),
                 os.path.join(home, ".var/app/com.valvesoftware.Steam/data/Steam")]
    roots = []
    for c in cands:
        if not os.path.isdir(c):
            continue
        roots.append(c)
        vdf = os.path.join(c, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            try:
                text = open(vdf, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            for m in re.finditer(r'"path"\s+"([^"]+)"', text):
                roots.append(m.group(1).replace("\\\\", os.sep))
    return roots


def find_game():
    hits = []
    for root in steam_roots():
        common = os.path.join(root, "steamapps", "common")
        if not os.path.isdir(common):
            continue
        for depth in ("*", "*/*"):
            hits += glob.glob(os.path.join(common, depth, PCK_NAME))
    seen, out = set(), []
    for h in hits:
        d = os.path.dirname(os.path.abspath(h))
        if d not in seen:
            seen.add(d)
            out.append(d)
    return out


# --------------------------------------------------------------------------

def die(msg):
    print(f"\n  ERROR: {msg}\n")
    sys.exit(1)


def collect_overlay():
    if not os.path.isdir(OVERLAY):
        die(f"missing mod files - expected a 'mod' folder next to this script "
            f"at {OVERLAY}")
    out = {}
    for dirpath, _, names in os.walk(OVERLAY):
        for n in names:
            full = os.path.join(dirpath, n)
            rel = os.path.relpath(full, OVERLAY).replace(os.sep, "/")
            out[rel] = full
    if not out:
        die("the 'mod' folder is empty.")
    return out


def norm(res_path):
    """Godot writes pack paths with or without the res:// prefix; unify them."""
    return res_path[6:] if res_path.startswith("res://") else res_path


def victims_for(rel):
    """The compiled/remap siblings a mod file at `rel` should displace."""
    stem, ext = os.path.splitext(rel)
    return [stem + suffix for suffix in SUPERSEDES.get(ext, [])]


def check_compatible(base, overlay):
    """Every mod file must have something in the .pck to displace.

    That is a far better compatibility signal than reading a version string -
    the version lives inside a zstd-compressed script blob, and if a future
    patch moves or renames these files the mod would not apply cleanly anyway.

    ADDED_FILES are exempt: they are new files the mod contributes rather than
    replacements, so they legitimately have nothing to displace. Without this
    exemption the "game was updated" warning fired on every single install,
    including correct ones - which trained users to ignore the one message that
    is supposed to stop them patching a version the mod was not built for.
    """
    missing = []
    for rel in overlay:
        if rel in ADDED_FILES:
            continue
        if not any(v in base for v in victims_for(rel)):
            missing.append(rel)
    return missing


def mod_state(entries, overlay):
    """Classify a .pck index against the overlay.

    Returns (state, applied, leftover) with state one of "clean", "patched" or
    "partial". Shared by --verify and by install()'s refusal to patch anything
    that is not pristine, so the two can never disagree about what they see.
    """
    present = {norm(e.path) for e in entries}
    applied = sorted(rel for rel in overlay if rel in present)
    leftover = sorted(v for rel in overlay for v in victims_for(rel) if v in present)
    if len(applied) == len(overlay) and not leftover:
        return "patched", applied, leftover
    if not applied:
        return "clean", applied, leftover
    return "partial", applied, leftover


def offer_stale_backup_removal(game_dir, force=False):
    """Offer to delete a "<pck>.vanilla" left behind by an older installer.

    It is never read, let alone restored from: it was copied whenever the mod
    was first installed, so after a Steam game update it holds an *older*
    version of the game and putting it back silently downgrades (issue #9).
    """
    backup = os.path.join(game_dir, BACKUP_NAME)
    if not os.path.isfile(backup):
        return
    size_gb = os.path.getsize(backup) / float(1 << 30)
    print(f"\n  Found {BACKUP_NAME} ({size_gb:.1f} GB) in the game folder.")
    print("  That copy comes from an older installer version. It is no longer "
          "used,\n  and after a game update it holds an outdated version of "
          "the game, so it\n  is never restored from. Steam's 'Verify "
          "integrity of game files' is the\n  way back to the original now.")
    if force:
        print("  Delete it? [y/N] y")
        reply = "y"
    else:
        reply = input("  Delete it? [y/N] ").strip().lower()
    if reply == "y":
        os.remove(backup)
        print(f"  Deleted {BACKUP_NAME}")
    else:
        print(f"  Kept {BACKUP_NAME} - you can delete it yourself at any time.")


def install(game_dir, force=False):
    pck = os.path.join(game_dir, PCK_NAME)
    if not os.path.isfile(pck):
        die(f"no {PCK_NAME} in {game_dir}")

    offer_stale_backup_removal(game_dir, force=force)

    overlay = collect_overlay()
    handle, entries = read_index(pck)

    # Patch the live .pck, and only ever a pristine one. With no backup kept,
    # an already-patched .pck has no pristine base to rebuild from: patching it
    # again would stack the overlay on top of itself, and the mod files it
    # already contains are the wrong thing to build on. This check is
    # deliberately not skippable with --force.
    state, applied, _leftover = mod_state(entries, overlay)
    if state != "clean":
        handle.close()
        label = ("already patched" if state == "patched"
                 else f"partially patched ({len(applied)} of {len(overlay)} "
                      f"mod files present)")
        die(f"this .pck is {label}.\n"
            f"  The installer keeps no backup, so there is no original left "
            f"here to patch.\n"
            f"  To reinstall or update the mod, restore the original first:\n"
            f"    Steam -> Properties -> Installed Files -> Verify integrity "
            f"of game files\n"
            f"  then run the installer again.")

    # Match whatever prefix convention this .pck already uses for new entries.
    prefix = "res://" if entries and entries[0].path.startswith("res://") else ""
    base = {norm(e.path): e for e in entries}

    missing = check_compatible(base, overlay)
    if missing:
        print(f"\n  WARNING: {len(missing)} of {len(overlay)} mod files have "
              f"nothing to replace in this .pck, e.g.:")
        for rel in missing[:3]:
            print(f"    {rel}")
        print(f"  This usually means the game was updated and the mod "
              f"(built for {SUPPORTED_VERSION}) is out of date.")
        if not force:
            reply = input("  Continue anyway? [y/N] ").strip().lower()
            if reply != "y":
                print("  Aborted. Nothing was changed.")
                return

    files = dict(base)
    dropped = 0
    for rel, disk in overlay.items():
        files[rel] = disk
        for victim in victims_for(rel):
            if files.pop(victim, None) is not None:
                dropped += 1

    sources = []
    for rel in sorted(files):
        v = files[rel]
        if isinstance(v, str):
            sources.append((prefix + rel, ("disk", v)))
        else:
            sources.append((v.path, ("pck", handle, v.offset, v.size)))

    tmp = pck + ".new"
    print(f"  writing {len(sources)} files "
          f"({len(overlay)} from the mod, {dropped} originals replaced)...")
    try:
        write_pck(tmp, sources)
    except Exception as exc:
        if os.path.exists(tmp):
            os.remove(tmp)
        die(f"failed while writing: {exc}")
    handle.close()
    os.replace(tmp, pck)

    print(f"\n  Done. 8-player mod installed to:\n    {game_dir}")
    print("\n  Lobbies of 5-8 need everyone on this same mod release."
          "\n  Playing with unmodded friends works in lobbies up to 4.")
    print("  To undo: Steam -> Properties -> Installed Files -> Verify "
          "integrity of game files.")


def verify(game_dir):
    """Report whether the .pck in `game_dir` currently has the mod applied."""
    pck = os.path.join(game_dir, PCK_NAME)
    if not os.path.isfile(pck):
        die(f"no {PCK_NAME} in {game_dir}")

    overlay = collect_overlay()
    handle, entries = read_index(pck)
    handle.close()
    state, applied, leftover = mod_state(entries, overlay)

    print(f"\n  {pck}")
    if state == "patched":
        print(f"\n  PATCHED - all {len(overlay)} mod files present, "
              f"originals correctly removed.")
        print(f"  In game, the main menu should read {SUPPORTED_VERSION}-8P-v1.5")
        return 0
    if state == "clean":
        print("\n  NOT PATCHED - this is the original game.")
        print("  Run:  python3 install.py")
        return 1

    print(f"\n  PARTIALLY PATCHED - {len(applied)} of {len(overlay)} mod files "
          f"present, {len(leftover)} originals still shadowing them.")
    for rel in sorted(set(overlay) - set(applied))[:5]:
        print(f"    missing: {rel}")
    print("  Re-run the installer to fix:  python3 install.py")
    return 1


def uninstall(game_dir, force=False):
    """Report the state and point at Steam - nothing here restores anything.

    The installer no longer keeps a copy of the original, so it has nothing to
    put back. Steam re-downloads exactly the version you are meant to have,
    which is what the old backup could not promise after a game update.
    """
    verify(game_dir)
    print("\n  The installer keeps no backup - it patches the game in place.")
    print("  To restore the original game files, use Steam:")
    print("    Properties -> Installed Files -> Verify integrity of game files")
    print("  (a Steam update overwrites the mod the same way.)")
    offer_stale_backup_removal(game_dir, force=force)


def main():
    ap = argparse.ArgumentParser(description="Machine Party 8-Player Mod installer")
    ap.add_argument("--game-dir", help="folder containing 'Machine Party.pck'")
    ap.add_argument("--uninstall", action="store_true")
    ap.add_argument("--verify", action="store_true",
                    help="report whether the mod is currently installed")
    ap.add_argument("--force", action="store_true",
                    help="answer yes to all prompts (non-interactive use)")
    args = ap.parse_args()

    print("\n  Machine Party - 8 Player Mod\n  " + "-" * 30)

    game_dir = args.game_dir
    autodetected = False
    if game_dir is not None and not game_dir.strip():
        # An empty --game-dir is a caller mistake (usually an unexpanded shell
        # variable). Falling through to auto-detect here would silently modify
        # whatever install happens to be found, which is not what was asked.
        die("--game-dir was given but empty.")

    if game_dir is None:
        autodetected = True
        found = find_game()
        if not found:
            die("could not find Machine Party automatically.\n"
                "  Re-run with:  python3 install.py --game-dir \"<folder "
                "containing Machine Party.pck>\"")
        if len(found) > 1:
            print("  Multiple installs found:")
            for i, d in enumerate(found, 1):
                print(f"    {i}) {d}")
            choice = input(f"  Which one? [1-{len(found)}] ").strip()
            if not choice.isdigit() or not 1 <= int(choice) <= len(found):
                die("invalid selection.")
            game_dir = found[int(choice) - 1]
        else:
            game_dir = found[0]
        print(f"  Found game: {game_dir}")

    if args.verify:
        sys.exit(verify(game_dir))

    # Always confirm the exact directory before writing, even when it was named
    # explicitly: a mistyped or wrongly-expanded path is the failure mode that
    # actually happens, and printing the resolved path is what catches it.
    # --force skips this for scripted use.
    if not args.force:
        action = "Report the mod state in" if args.uninstall else "Install the mod to"
        origin = "auto-detected" if autodetected else "as given"
        print(f"\n  {action} ({origin}):\n    {os.path.abspath(game_dir)}")
        if input("  Proceed? [y/N] ").strip().lower() != "y":
            print("  Aborted. Nothing was changed.")
            return

    if args.uninstall:
        uninstall(game_dir, force=args.force)
    else:
        install(game_dir, force=args.force)


if __name__ == "__main__":
    main()
