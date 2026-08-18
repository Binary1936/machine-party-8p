#!/usr/bin/env python3
"""Fetch the Windows embeddable Python bundled into the release zip.

The release zip ships a Python runtime so Windows players do not have to
install one - `WindowsInstall.bat` prefers `python\\python.exe` next to it and
only falls back to a system `py -3`. `install.py` is pure stdlib, so the
embeddable distribution (no pip, no site-packages) is all it needs.

The runtime is NOT committed: 21 MB of third-party binaries do not belong in
the repo, and it is reproducible from this script. It lands in
`installer/python/`, which `.gitignore` blocks. Run this before packaging a
release (UPDATING.md step 8).

The archive is pinned by SHA-256. If the hash check fails, do NOT bypass it -
that is the one signal that the download is not what we tested against.

    python3 tools/fetch_embed_python.py           # fetch + extract
    python3 tools/fetch_embed_python.py --verify  # check an existing copy
"""
import argparse
import hashlib
import io
import os
import shutil
import sys
import urllib.request
import zipfile

VERSION = "3.13.1"
URL = (f"https://www.python.org/ftp/python/{VERSION}/"
       f"python-{VERSION}-embed-amd64.zip")
# sha256 of the archive above (2026-08-18). python.org publishes only an MD5
# on its release page, so the pin was corroborated in two steps: that page's
# MD5 for "Windows embeddable package (64-bit)" is d5c8030976b5eaf55ed6b321c073dda7
# and matches the downloaded file, whose sha256 is the value below. Redo both
# steps whenever VERSION is bumped - and note the page is served compressed,
# so a scripted fetch needs `curl --compressed` or it silently reads as binary.
SHA256 = "7b7923ff0183a8b8fca90f6047184b419b108cb437f75fc1c002f9d2f8bcec16"

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "installer", "python")
# Presence of these is what WindowsInstall.bat and the packaging step rely on.
# LICENSE.txt is the PSF licence the distribution must keep when redistributed.
_TAG = "".join(VERSION.split(".")[:2])          # 3.13.1 -> "313"
MARKERS = ("python.exe", f"python{_TAG}.dll", "LICENSE.txt")


def die(msg):
    print(f"\n  ERROR: {msg}\n", file=sys.stderr)
    sys.exit(1)


def verify_dest():
    if not os.path.isdir(DEST):
        return False, f"missing {DEST}"
    missing = [m for m in MARKERS if not os.path.isfile(os.path.join(DEST, m))]
    if missing:
        return False, f"{DEST} is incomplete: no {', '.join(missing)}"
    return True, f"{DEST} looks complete ({len(os.listdir(DEST))} files)"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--verify", action="store_true",
                    help="only check an already-extracted copy")
    args = ap.parse_args()

    if args.verify:
        ok, msg = verify_dest()
        print(f"  {msg}")
        sys.exit(0 if ok else 1)

    print(f"  downloading {URL}")
    try:
        with urllib.request.urlopen(URL) as r:
            blob = r.read()
    except OSError as exc:
        die(f"download failed: {exc}")

    got = hashlib.sha256(blob).hexdigest()
    if got != SHA256:
        die(f"sha256 mismatch for python-{VERSION}-embed-amd64.zip\n"
            f"    expected {SHA256}\n"
            f"    got      {got}\n"
            f"  Refusing to extract. If python.org legitimately republished "
            f"this file,\n  re-verify against their checksum and update "
            f"SHA256 in this script.")
    print(f"  sha256 OK ({len(blob):,} bytes)")

    if os.path.isdir(DEST):
        shutil.rmtree(DEST)
    os.makedirs(DEST, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        z.extractall(DEST)

    ok, msg = verify_dest()
    if not ok:
        die(f"extraction incomplete - {msg}")
    print(f"  extracted -> {DEST}")
    print(f"  {msg}")


if __name__ == "__main__":
    main()
