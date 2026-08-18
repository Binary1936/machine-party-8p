#!/bin/sh
# Machine Party 8-Player Mod installer (macOS / Linux)
cd "$(dirname "$0")" || exit 1

# A file manager launches this with no terminal attached, so install.py's
# confirmation prompt reads EOF and the run dies unseen. Relaunch in a
# terminal emulator so the prompts have somewhere to go. Running from a
# terminal already (stdin is a tty) skips this entirely.
if [ ! -t 0 ]; then
	self="$PWD/$(basename "$0")"
	for t in x-terminal-emulator konsole gnome-terminal ptyxis xfce4-terminal \
	         mate-terminal lxterminal kitty foot alacritty xterm; do
		command -v "$t" >/dev/null 2>&1 || continue
		case "$t" in
			gnome-terminal|ptyxis) exec "$t" -- "$self" "$@" ;;
			kitty|foot)            exec "$t" "$self" "$@" ;;
			*)                     exec "$t" -e "$self" "$@" ;;
		esac
	done
	# No terminal emulator found: fall through. install.py reports the
	# missing terminal rather than dying on EOF halfway through a prompt.
fi

if command -v python3 >/dev/null 2>&1; then
	python3 install.py "$@"
else
	echo "Python 3 is required but was not found. Install it with your"
	echo "package manager (e.g. 'sudo pacman -S python' or 'sudo apt install python3')."
	exit 1
fi
printf "\nPress Enter to close..."
read -r _
