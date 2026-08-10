#!/bin/sh
# Launch an N-instance local session over ENet on 127.0.0.1:25565.
#
# Requires a mod build with the -localtest flag (see UPDATING.md). Slot 1 hosts,
# slots 2..N join; each instance tiles itself into a 4xM grid and titles its
# window P1..PN once connected.
#
#   tools/localtest.sh [N] [game-dir] [seconds]
#
# Logs land in /tmp/mp-localtest/ , one per slot. All instances are killed when
# the run ends.
set -u
N="${1:-8}"
DIR="${2:-$(cd "$(dirname "$0")/.." && pwd)/testgame}"
SECS="${3:-45}"
LOGS=/tmp/mp-localtest
EXE="$DIR/Machine Party.x86_64"

[ -x "$EXE" ] || { echo "no game at $EXE"; exit 1; }
rm -rf "$LOGS"; mkdir -p "$LOGS"

cleanup() { pkill -f "Machine Party.x86_64" 2>/dev/null; }
trap cleanup EXIT INT TERM
cleanup; sleep 1

# START=1 makes the host launch the session (and everyone follow into a
# minigame) as soon as the lobby is full, skipping cutscenes and intermission.
START="${START:-0}"
# FLOW=1 keeps the *normal* session loop instead: intro cutscene -> briefing ->
# minigame -> score screen -> intermission picker -> next briefing, i.e. what a
# real player experiences. Each instance readies itself at the briefing, which
# is the only step in that loop that waits on input. Implies START=1, since
# something still has to kick the session off with nobody at a keyboard.
FLOW="${FLOW:-0}"
[ "$FLOW" = "1" ] && START=1
EXTRA=""
[ "$START" = "1" ] && EXTRA="-startgame $N"
[ "$FLOW" = "1" ] && EXTRA="$EXTRA -fullflow"
# MINIGAME=GreenPea pins the session to one minigame (identifier name).
[ -n "${MINIGAME:-}" ] && EXTRA="$EXTRA -minigame $MINIGAME"
# ARGS="..." appends arbitrary flags to every instance, for minigame-specific
# test aids (e.g. ARGS="-kato-target=2" to shorten Inside Job's search phase).
[ -n "${ARGS:-}" ] && EXTRA="$EXTRA $ARGS"

# Mixed-lobby testing: slots listed in VANILLA_SLOTS (space-separated numbers)
# launch from VANILLA_DIR - a quasi-vanilla build (see tools/quasivanilla/) that
# is wire-identical to unmodded v1.5.0. Any vanilla peer caps the session at 4,
# so mixed runs use N<=5 (5 only to test the over-cap refusal). FLOW=1 would
# hang a mixed run at the first briefing (quasi-vanilla never auto-readies);
# use the default START path. The cleanup pkill above matches the binary NAME,
# so it already covers instances from both directories.
VANILLA_DIR="${VANILLA_DIR:-}"
VANILLA_SLOTS="${VANILLA_SLOTS:-}"
if [ -n "$VANILLA_SLOTS" ] && [ ! -x "$VANILLA_DIR/Machine Party.x86_64" ]; then
	echo "VANILLA_SLOTS set but no game at $VANILLA_DIR"; exit 1
fi
exe_for_slot() {
	case " $VANILLA_SLOTS " in
		*" $1 "*) printf '%s' "$VANILLA_DIR/Machine Party.x86_64" ;;
		*) printf '%s' "$EXE" ;;
	esac
}

echo "host  -> slot 1${EXTRA:+ ($EXTRA)}"
[ -n "$VANILLA_SLOTS" ] && echo "mixed -> quasi-vanilla slots: $VANILLA_SLOTS"
[ "$FLOW" = "1" ] && echo "mode  -> full session flow (briefing/intermission NOT skipped)"
stdbuf -o0 -e0 "$(exe_for_slot 1)" -localtest 1 host $EXTRA --resolution 640x360 \
	>"$LOGS/p1.log" 2>&1 &

# Wait for the host to actually bind before starting clients.
i=0
while [ $i -lt 30 ]; do
	if ss -ltn 2>/dev/null | grep -q ':25565' || \
	   ss -lun 2>/dev/null | grep -q ':25565'; then
		echo "host listening on 25565 after ${i}s"
		break
	fi
	i=$((i + 1)); sleep 1
done

n=2
while [ "$n" -le "$N" ]; do
	echo "join  -> slot $n"
	stdbuf -o0 -e0 "$(exe_for_slot "$n")" -localtest "$n" join $EXTRA --resolution 640x360 \
		>"$LOGS/p$n.log" 2>&1 &
	n=$((n + 1))
	sleep 1
done

echo "running for ${SECS}s..."
sleep "$SECS"

echo
echo "=== errors ==="
grep -h -E "SCRIPT ERROR|Parse Error|out of bounds|Invalid access|Nonexistent" \
	"$LOGS"/*.log | grep -v "NO GRAB" | sort | uniq -c | sort -rn | head -20
echo "(none above means clean)"
echo
echo "=== per-slot: reached lobby? ==="
for f in "$LOGS"/p*.log; do
	printf "%-8s %s lines %s\n" "$(basename "$f" .log)" "$(wc -l <"$f")" \
		"$(grep -c -E 'SCRIPT ERROR|Parse Error' "$f") errors"
done
