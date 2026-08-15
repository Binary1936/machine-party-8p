#!/bin/sh
# SIGKILL one localtest joiner the instant the host starts loading a minigame,
# simulating a player whose game crashes DURING the load (pitfall 32: the
# vanilla load gate is re-evaluated only on arrivals, so this is the trigger
# for issues #10/#12 and the case tools/localtest.sh cannot produce on its own).
#
#   tools/kill_slot_at_load.sh <slot> [MinigameIdentifier]  &
#   START=1 MINIGAME=<Identifier> tools/localtest.sh <N> <game-dir> <secs>
#
# Arm it FIRST, in the background, then launch the harness. It clears the log
# directory itself before waiting - a stale p1.log from the previous run
# already contains the load line and would fire the trigger before any client
# exists (the run then silently becomes a no-kill control). It kills by pid
# from a `pgrep -f` whose pattern uses a bracketed slot number, because a
# plain `pkill -f "-localtest 4 join"` also matches the shell running it and
# kills the launcher instead of the client. Both cost a run on 2026-08-15.
#
# The killed slot's log stops at the briefing; the host's [BRIEF8] players=
# drops by one once ENet times the peer out (~15 s locally), after the other
# clients have loaded. Expected on the current mod: Game: SessionIntro ->
# MinigameStart -> MinigamePlaying then <minigame>: Empty -> Round; the
# pre-fix signature was Empty -> Reset with no Game transition. See "Simulating
# a peer crash during a minigame load" in UPDATING.md (Testing).
set -u
slot="${1:?usage: $0 <slot> [MinigameIdentifier]}"
minigame="${2:-DuckHunt}"
LOGS=/tmp/mp-localtest

rm -rf "$LOGS"
until grep -q "load minigame=$minigame" "$LOGS/p1.log" 2>/dev/null; do sleep 0.05; done
pid=$(pgrep -f "x86_64 -localtest [${slot}] join")
echo "load line for $minigame seen at $(date +%T.%N); slot $slot pid=${pid:-NONE}"
if [ -n "$pid" ]; then
	kill -9 $pid && echo "SIGKILL sent to $pid at $(date +%T.%N)"
else
	echo "no running joiner for slot $slot - nothing killed"; exit 1
fi
echo "p$slot.log lines at kill: $(wc -l <"$LOGS/p$slot.log" 2>/dev/null || echo 0)"
