#!/bin/sh
# Make one localtest joiner QUIT gracefully the instant the host starts loading
# a minigame, while another joiner is frozen so its player_loaded cannot arrive:
# the host then processes the disconnect BEFORE the load gate can pass and the
# minigame's player_disconnected() runs against an unspawned game (pitfall 33,
# the trigger for the section-23 guards). The sibling of kill_slot_at_load.sh:
# that one is a crash (ENet timeout, noticed after everyone has loaded); this
# one is Alt-F4 / the pause menu (noticed on the host's next poll).
#
#   tools/leave_slot_at_load.sh <leave_slot> <freeze_slot> [Identifier] [freeze_secs] &
#   START=1 MINIGAME=<Identifier> tools/localtest.sh 4 <game-dir> <secs>
#
# Arm it FIRST, in the background. It clears the log directory itself (a stale
# p1.log would fire the trigger early), waits for the host's load line,
# SIGSTOPs <freeze_slot>, sends <leave_slot>'s X11 window WM_DELETE_WINDOW via
# tools/graceful_close.py (Godot's default close request -> quit -> ENet
# disconnect_now), sleeps freeze_secs (default 5: longer than any minigame's
# 1-4 s finish timer, but a FROZEN peer is dropped by the host at ~7-8 s, sooner
# than a killed one's ~15 s), then SIGCONTs the frozen slot. It also
# stamps wall-clock times of the host log's key lines, since the game logs carry
# no timestamps: "host saw players=N-1" within ~1 s of the load line is the quit
# signature (a kill takes ~15 s). Pids are found with a bracketed slot number so
# the pgrep cannot match its own command line. See "Simulating a peer QUITTING
# during a minigame load" in UPDATING.md (Testing).
set -u
leave="${1:?usage: $0 <leave_slot> <freeze_slot> [Identifier] [freeze_secs]}"
freeze="${2:?usage: $0 <leave_slot> <freeze_slot> [Identifier] [freeze_secs]}"
mg="${3:-DuckHunt}"; fsecs="${4:-5}"
LOGS=/tmp/mp-localtest
HERE=$(cd "$(dirname "$0")" && pwd)
rm -rf "$LOGS"
until grep -q "load minigame=$mg" "$LOGS/p1.log" 2>/dev/null; do sleep 0.02; done
n=$(grep -o "load minigame=$mg players=[0-9]*" "$LOGS/p1.log" | head -1 | grep -o '[0-9]*$')
want=$((${n:-4} - 1))
fpid=$(pgrep -f "x86_64 -localtest [${freeze}] join")
lpid=$(pgrep -f "x86_64 -localtest [${leave}] join")
echo "load line for $mg at $(date +%T.%N); freeze slot $freeze pid=${fpid:-NONE}; leave slot $leave pid=${lpid:-NONE}"
[ -n "$fpid" ] && kill -STOP $fpid && echo "SIGSTOP $fpid at $(date +%T.%N)"
[ -n "$lpid" ] && DISPLAY=${DISPLAY:-:0} python3 "$HERE/graceful_close.py" $lpid "P$leave" && echo "close sent at $(date +%T.%N)"
# stamp the host log while frozen
( for i in $(seq 1 400); do
	if [ -z "${sd:-}" ] && grep -q "\[BRIEF8\].*players=$want " "$LOGS/p1.log"; then sd=1; echo "host saw players=$want at $(date +%T.%N)"; fi
	if [ -z "${sm:-}" ] && grep -q "to MinigameStart" "$LOGS/p1.log"; then sm=1; echo "host MinigameStart at $(date +%T.%N)"; fi
	if [ -z "${lg:-}" ] && ! kill -0 $lpid 2>/dev/null; then lg=1; echo "leaver pid gone at $(date +%T.%N)"; fi
	[ -n "${sd:-}" ] && [ -n "${sm:-}" ] && [ -n "${lg:-}" ] && break
	sleep 0.05
  done ) &
sleep "$fsecs"
[ -n "$fpid" ] && kill -CONT $fpid && echo "SIGCONT $fpid at $(date +%T.%N)"
wait
