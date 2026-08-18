#!/usr/bin/env python3
"""Build the release zip, and refuse to build a broken one.

Building and checking are the same command on purpose. The previous recipe
was a snippet in UPDATING.md plus a separate verification step, and both
could be skipped - which mattered because the failure is silent: `os.walk`
over a missing `installer/python/` returns nothing without erroring, so
packaging without the Windows runtime produced a perfectly valid ~21 MB zip
(the old release size, so it looks right) whose `WindowsInstall.bat` quietly
falls back to `py -3`. Windows users would be back to needing Python
installed with nothing anywhere to notice it.

So: the runtime is fetched if absent, and the finished zip is re-opened and
checked against the tree it was built from before this exits 0.

    python3 tools/package_release.py            build + verify
    python3 tools/package_release.py --verify   check an existing zip only
"""
import argparse
import hashlib
import os
import shutil
import sys
import zipfile

# Reproducible builds: zip records each member's mtime and permissions, so a
# re-fetched runtime or a different umask changed the archive's hash without
# changing a byte of what installs - which makes "does this zip match the one
# that was scanned and published" unanswerable. Pin both. 1980-01-01 is the
# earliest timestamp the zip format can store.
ZIP_EPOCH = (1980, 1, 1, 0, 0, 0)
MODE_EXEC = 0o755
MODE_PLAIN = 0o644
CREATE_SYSTEM_UNIX = 3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INSTALLER = os.path.join(ROOT, "installer")
MOD = os.path.join(ROOT, "mod")
RUNTIME = os.path.join(INSTALLER, "python")
OUT = os.path.join(ROOT, "dist", "machine-party-8p-mod.zip")

# These land at the zip root, alongside mod/ and python/.
ROOT_FILES = ("install.sh", "README.txt", "install.py", "WindowsInstall.bat")
# install.sh is double-clicked on Linux, so its exec bit has to survive.
EXEC_FILES = {"install.sh"}


def die(msg):
    print(f"\n  ERROR: {msg}\n", file=sys.stderr)
    sys.exit(1)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.digest()


def ensure_runtime():
    """Fetch the Windows runtime if it is not already extracted.

    Kept automatic rather than an instruction to run first: a step that can be
    forgotten is the whole failure mode this script exists to remove.
    """
    if os.path.isfile(os.path.join(RUNTIME, "python.exe")):
        return
    print("  installer/python/ missing - fetching it")
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import fetch_embed_python
    fetch_embed_python.main()


def walk(base):
    """Every file under `base`, sorted, as (absolute path, relative path)."""
    out = []
    for dirpath, dirnames, names in os.walk(base):
        dirnames.sort()
        for n in sorted(names):
            full = os.path.join(dirpath, n)
            out.append((full, os.path.relpath(full, base).replace(os.sep, "/")))
    return out


def build():
    ensure_runtime()
    for f in ROOT_FILES:
        if not os.path.isfile(os.path.join(INSTALLER, f)):
            die(f"missing installer/{f}")
    if not os.path.isdir(MOD):
        die(f"missing {MOD}")

    members = [(os.path.join(INSTALLER, f), f) for f in ROOT_FILES]
    members += [(full, "mod/" + rel) for full, rel in walk(MOD)]
    members += [(full, "python/" + rel) for full, rel in walk(RUNTIME)]

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
        for full, arcname in members:
            info = zipfile.ZipInfo(arcname, date_time=ZIP_EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = CREATE_SYSTEM_UNIX
            mode = MODE_EXEC if arcname in EXEC_FILES else MODE_PLAIN
            info.external_attr = mode << 16
            with open(full, "rb") as src, z.open(info, "w") as dst:
                shutil.copyfileobj(src, dst, 1 << 20)
    print(f"  built {os.path.relpath(OUT, ROOT)}")


def verify():
    if not os.path.isfile(OUT):
        die(f"no zip at {OUT} - build it first")
    with zipfile.ZipFile(OUT) as z:
        names = set(z.namelist())

        missing = [f for f in ROOT_FILES if f not in names]
        if missing:
            die(f"zip is missing at the root: {', '.join(missing)}")

        if "python/python.exe" not in names:
            die("zip has no python/python.exe - the bundled Windows runtime is\n"
                "  absent, so WindowsInstall.bat would fall back to 'py -3' and\n"
                "  Windows users would need Python installed. Delete\n"
                "  installer/python/ and re-run this script to rebuild it.")

        # The overlay is what actually patches the game: every file, byte for
        # byte, or the zip installs something other than what was tested.
        for full, rel in walk(MOD):
            member = "mod/" + rel
            if member not in names:
                die(f"zip is missing {member}")
            if hashlib.sha256(z.read(member)).digest() != sha256(full):
                die(f"{member} in the zip differs from the file on disk")
        extra = [n for n in names
                 if n.startswith("mod/") and not n.endswith("/")
                 and n not in {"mod/" + r for _, r in walk(MOD)}]
        if extra:
            die(f"zip carries {len(extra)} mod/ file(s) not in the overlay, "
                f"e.g. {extra[0]}")

        for f in EXEC_FILES:
            mode = (z.getinfo(f).external_attr >> 16) & 0o777
            if not mode & 0o111:
                die(f"{f} lost its exec bit in the zip (mode {mode:o}) - it is "
                    f"double-clicked on Linux")

        n_mod = sum(1 for n in names if n.startswith("mod/"))
        n_py = sum(1 for n in names if n.startswith("python/"))
        size = os.path.getsize(OUT)
        print(f"  verified {len(names)} entries "
              f"({len(ROOT_FILES)} root, {n_mod} mod/, {n_py} python/), "
              f"{size:,} bytes")
        print(f"  sha256 {hashlib.sha256(open(OUT, 'rb').read()).hexdigest()}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--verify", action="store_true",
                    help="check an existing zip without rebuilding")
    args = ap.parse_args()
    if not args.verify:
        build()
    verify()


if __name__ == "__main__":
    main()
