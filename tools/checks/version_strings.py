#!/usr/bin/env python3
"""Version-label agreement check (UPDATING.md, update procedure step 6).

The display label lives in three places that must agree - globals.gd,
install.py's --verify message, and installer/README.txt - and the docs call
the last one "the one that goes stale silently" (it once shipped three
minigames stale). The wire constants are a separate pair that only
globals.gd holds. This script enforces:

  1. globals.gd internal consistency:
     game_version == MOD_NETWORK_GAME_VERSION + "-" + MOD_SUFFIX
  2. install.py: SUPPORTED_VERSION == MOD_NETWORK_GAME_VERSION, and the
     --verify message resolves to the full display string.
  3. installer/README.txt: contains both the full display string and a
     "Built for Machine Party <game version>" line.

Exit 0: all agree. Exit 1: any disagreement, each printed.
"""
import os
import re
import sys


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def grab(pattern, text, path, what):
    m = re.search(pattern, text)
    if not m:
        print(f"FAIL: could not find {what} in {path} (pattern: {pattern})")
        return None
    return m.group(1)


def main() -> int:
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..")
    root = os.path.abspath(root)

    globals_gd = os.path.join(root, "mod", "autoloads", "globals.gd")
    install_py = os.path.join(root, "installer", "install.py")
    readme_txt = os.path.join(root, "installer", "README.txt")

    g = read(globals_gd)
    ins = read(install_py)
    rdm = read(readme_txt)

    game_version = grab(r'game_version\s*:\s*String\s*=\s*"([^"]+)"', g,
                        "globals.gd", "game_version")
    net_version = grab(r'MOD_NETWORK_GAME_VERSION\s*:?=\s*"([^"]+)"', g,
                       "globals.gd", "MOD_NETWORK_GAME_VERSION")
    suffix = grab(r'MOD_SUFFIX\s*:?=\s*"([^"]+)"', g, "globals.gd", "MOD_SUFFIX")
    supported = grab(r'SUPPORTED_VERSION\s*=\s*"([^"]+)"', ins,
                     "install.py", "SUPPORTED_VERSION")
    if None in (game_version, net_version, suffix, supported):
        return 1

    failures = []

    expected_display = f"{net_version}-{suffix}"
    if game_version != expected_display:
        failures.append(
            f"globals.gd: game_version is \"{game_version}\" but "
            f"MOD_NETWORK_GAME_VERSION + '-' + MOD_SUFFIX is \"{expected_display}\"")

    if supported != net_version:
        failures.append(
            f"install.py SUPPORTED_VERSION is \"{supported}\" but globals.gd "
            f"MOD_NETWORK_GAME_VERSION is \"{net_version}\"")

    # The --verify message builds the display string as
    # f"...{SUPPORTED_VERSION}-8P-vX.Y" - resolve any {SUPPORTED_VERSION}
    # interpolation, then require the full display string to appear.
    ins_resolved = ins.replace("{SUPPORTED_VERSION}", supported)
    if game_version not in ins_resolved:
        failures.append(
            f"install.py: the --verify message never resolves to the display "
            f"string \"{game_version}\" - its hardcoded suffix is stale")

    if game_version not in rdm:
        failures.append(
            f"installer/README.txt does not contain the display string "
            f"\"{game_version}\" (the DID IT WORK example is stale)")
    if f"Built for Machine Party {net_version}" not in rdm:
        failures.append(
            f"installer/README.txt does not say \"Built for Machine Party "
            f"{net_version}\" (the header line is stale)")

    if failures:
        for f in failures:
            print("FAIL:", f)
        print(f"\n{len(failures)} version-string disagreement(s). "
              "See UPDATING.md, update procedure step 6.")
        return 1

    print(f"OK: version label \"{game_version}\" agrees across globals.gd, "
          "install.py and installer/README.txt "
          f"(wire: \"{net_version}\" + mod8p \"{suffix}\")")
    return 0


if __name__ == "__main__":
    sys.exit(main())
