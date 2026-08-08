#!/bin/sh
# Machine Party 8-Player Mod installer (macOS / Linux)
cd "$(dirname "$0")" || exit 1
if command -v python3 >/dev/null 2>&1; then
	python3 install.py "$@"
else
	echo "Python 3 is required but was not found. Install it from https://python.org"
	exit 1
fi
printf "\nPress Enter to close..."
read -r _
