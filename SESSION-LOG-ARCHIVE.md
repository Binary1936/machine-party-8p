# Session log archive — entries compressed out of the session log

Verbatim text of the session-log entries that were condensed into the digest
table in `UPDATING.md` on 2026-08-04, when that file was split and trimmed —
plus any **later** entry moved here since, once its conclusions were fully folded
into that file's live sections. Each move leaves a stub in the session log naming
the section that now owns the material.

**In git since 2026-08-08** — but the archive, not git history, is the intended
reading surface for old reasoning: a future session can grep this file and will
never think to excavate a commit.
Nothing here is required reading: every durable fact from these entries is
already folded into `MINIGAMES.md`'s numbered sections and the pitfalls list.
It is kept because the *reasoning* — including the theories that turned out to
be wrong — is occasionally worth re-reading, and because deleting the only copy
of something is not a decision a compression pass should make silently.

Newest first, same order as the original.

---

### 2026-08-05 — Duck Hunt's `START=1` hang fixed; a "benign" call overturned

**The user found this by watching a run instead of reading its log**, and it
invalidated three days of documentation plus one of my own conclusions from the
same afternoon.

On 2026-08-02 the black "YOU ARE THE HUNTER." overlay under `START=1` was traced
to a skipped presentation state and written up as **"Nothing is wrong."** The
state path was checked — `Round -> Countdown -> Play` — and read as proof the
minigame was running normally behind a stale overlay. What went unasked was
whether the skipped state did anything **load-bearing**. It did:
`role_reveal_state.gd:78` is the only online caller of
`hunter_player.set_can_aim_rpc(true)`, and `can_aim` defaults to `false`. So the
hunter could never aim or fire; no duck could die; `check_game_end()` could never
pass its `duck_players` guard; and with no turn timer, the minigame hung forever.

**It survived scrutiny because every `START=1` run was killed by `localtest.sh`'s
duration before anything needed Duck Hunt to *finish*.** The traces fired at
scene load, got collected, and the session died. The bug lived entirely past the
point where the method stopped looking.

**Fix:** `_mod_apply_skipped_reveal()` + `mod_clear_role_overlay_rpc()` in
`duck_hunt.gd`, gated on `Globals.debug_skip_brief`, called from the end of
`spawn_players()` — which `reset_state.gd` re-runs for every hunter turn, so each
new hunter is covered, not just the first. Both touched files were already in the
overlay, so nothing new has to be re-derived on a game update. Verified at 8:
`overlay_visible=false alpha=0.00` on the host **and all seven clients** (the
trace deliberately lives inside the RPC, because a host-only line would prove
nothing about the other seven).

**And a claim of mine that the fix did NOT deliver.** When proposing it I said it
would unblock `START=1` rotation runs. It does not. Measured after the fix: still
zero `Reset`, zero `Finished`, zero shots in 200s. There are **two independent
causes** and only one is fixable in code — ducks leave `duck_players` only by
reaching the finish corridor or being shot, and idle instances neither move nor
fire. **Duck Hunt therefore blocks every unattended rotation run under `FLOW=1`
too**, and pinning with `MINIGAME=` remains the only full-coverage method. What
the fix actually buys is that a *person* can now playtest Duck Hunt on the fast
path; before, even a human sat behind a black screen holding a disabled rifle.

### 2026-08-02 — Duck Hunt rifle animations fitted to the faster cycle

Follow-up to the uncapping below: the shortened bolt cycle outran the rifle
animations, which the user spotted in play. **The window an animation gets is
`cycle_time + 0.5`, not `cycle_time`** — nothing touches `anim_rig` at the moment
of a shot, so the bolt runs until the next `play()` half a second after the next
shot. Every shipped duck count fits in that window; every mod-added one does not,
which is precisely why vanilla looked right.

`_mod_play_to_fit()` scales playback only when the animation genuinely overruns,
so at <= 4 players it passes exactly 1.0 and the call is vanilla. Worst
correction is 1.281x at seven ducks. The reload had the same defect (1.057x) and
got the same treatment. Lengths are read at runtime, not hardcoded.

Verified `bolt_speed=1.000` at four players and `1.281` at eight, host and
clients, zero errors — with the engine's `bolt_len=1.2167` matching the offline
binary measurement exactly. **Visually confirmed good by the user** in an
8-instance `FLOW=1` session, which is the half a log cannot show.

**Playtesting the rifle:** the hunter is drawn at random and only one localtest
window takes input, so tab between windows to find the one holding the rifle.
Use `FLOW=1`; under `START=1` the role overlay never clears (see Testing). At
seven ducks the magazine is 18, so emptying it for the reload animation takes
~17s of continuous fire; the bolt cycles after every shot.

Also added: "Reading a property out of a shipped binary resource", the `RSCC`/
`RSRC` technique used to measure the animation lengths before writing any code.

### 2026-08-02 — Duck Hunt uncapped to 8 players

**The cap rested on a wrong premise.** This file described Duck Hunt as
"asymmetric: 3 duck slots + 1 hunter; magazine size derived from duck count". It
is **1 hunter + (N-1) ducks** — the hunter is popped from a shuffled pool and
everyone else is a duck, so the duck count always scaled by itself. The "3" was
only the spawn-marker count. Full detail in **section 19**.

Changed: markers built at runtime above four players (host-only, gated, so 1-4
keeps the shipped three and avoids the shuffle deviation); magazine and reload
curves extended from 3 ducks to 7 along the shipped slope; `5-8: 1` added to
`MinigameRoundsByPlayerCount` so eight players run 8 hunter turns rather than 16;
splitscreen `Layouts` extended past 4; and two pre-existing vanilla bugs fixed
(`duck_player_count` decremented on *hunter* removal, and an unguarded
`hunter_player.player_presence` deref).

**Verified:** 8 players — `markers=7 added=4` all inside the finish gate,
`ducks=7 magazine=18 cycle=0.45` on host and clients, reached `Play`, zero script
errors on all eight. 4 players — `markers=3 added=0 magazine=10 cycle=0.80`,
bit-identical to vanilla. Seven ducks spawning was confirmed visually at the
time and is now measured by `[DUCK8] spawned` on every peer.

**Open:** the round-count change is unverified — Duck Hunt has no round timer, so
idle instances never finish a round. And `[DUCK8]` should grow a positive duck
count, the same gap just closed for Stable Footing.

**A testing trap worth knowing before it costs anyone else an hour:** under
`START=1` every Duck Hunt client sits on a black "YOU ARE THE HUNTER." overlay
and looks hung. That is a shipped placeholder plus `debug_skip_brief` skipping
the RoleReveal state — not a mod fault, and identical at 4 players. See
"`START=1` skips Duck Hunt's role reveal" in Testing.

### 2026-08-02 — Stable Footing re-verified; a documented "fix" did not reproduce

Prompted by the user noticing that this file's Stable Footing note read as if
players 5-8 were still missing. They are not — but chasing it down turned up
something worse than a wording problem.

**Stable Footing (`DiscoDodge`) is fine at 8.** Added a `[DISCO8]` trace (the
only 8-verified minigame that had none) which counts the spawned player nodes on
every peer. Result: `roster=8 markers=8 spawned=8` with all eight nodes named, on
the host **and all seven clients**.

**The `spawn_limit` fix has no measurable effect.** This file claimed it was
"proven with a control run" — that players 5-8 never appeared at
`spawn_limit = 4` and client logs quadrupled. A fresh matched pair of 90s
8-player runs differing only in that value:

| | log lines | ERROR lines | missing-synchroniser | `spawned` |
|---|---|---|---|---|
| `spawn_limit = 8` | 847 | 212 | 0 | **8** |
| `spawn_limit = 4` | 845 | 211 | 0 | **8** |

The deployed pck was grepped to confirm it really carried `spawn_limit = 4`, so
the control was valid. The raise to 8 is **kept** as defence-in-depth — Godot
documents it as a cap and matching it to the roster is correct on its face — but
section 10 and pitfall 11 are corrected: it is no longer presented as a proven
fix. The original conclusion was inferred from client log volume in the same
session that fixed `blood_trail.gd` (~380 errors/round), which is the likely
confound.

**The lesson, which is the reusable part:** "no errors appeared" was the *only*
evidence Stable Footing ever had, and absence-of-error is exactly the proxy this
file warns against everywhere else. A trace that prints a positive count would
have caught both the real state and the bad attribution years sooner. Every
8-verified minigame now has one.

### 2026-08-02 (later) — Spine Breaker kill pace scaled to roster

**The mod's first gameplay *tuning* change** - everything before it was a
capacity fix. At the user's request, the spider's fuse and the dead time between
victims now scale by `3 / (roster - 1)`, clamped to 1.0, so an 8-player round no
longer runs 2.5x as long as a 4-player one. Full rationale, the two non-obvious
mechanics it rests on, and the per-roster table are in **section 18**.

**One file, already in the overlay** (`spine_breaker.gd`), two host-only sites,
no new overlay files, no RPC. Exactly **one** vanilla line is modified - the
hardcoded `create_timer(3.0)`; everything else is inserted.

**Vanilla parity is by construction, not by an `if`:** at four players the
factor is exactly `3/3 = 1.0`, so the assignments are bit-identical to the
shipped values. Confirmed on the gate trace:
`roster=4 active=2 factor=1.000 fuse=20.000 dead=3.000 vanilla_fuse=20.000`.
Note `active=2` while `factor` stays `1.000` - that is the deliberate use of the
stable `player_count` rather than the shrinking `active_players.size()`.

**Measured at 8 players, 280s:** 11 kills / 2 rounds before -> **21 kills / 3
rounds** after (three complete 7-elimination rounds); ~190s -> ~93s per round.
All 8 peers logged the same 3 round advances, so nothing desynced. Zero script
errors at either roster size; the 8-player error classes are the same
pre-existing families documented under pitfall 12.

**A trap worth remembering:** the obvious lever - making the spider *chase*
faster - would have done nothing at all, because travel happens inside the fuse
window. The fuse is the only real term.

### 2026-08-02 — wheat-field cutscene removed from the rotation

**Removed `MinigameIdentifier.CutsceneTest` from `default_playlist`**
(`mod/autoloads/globals.gd`). One line. It is the wheat-field cutscene: a fenced
field and farmhouse where a *resident* peeks out, slams the door and kills the
lights, after which SENTINEL declares `Foreign modifications detected. / Preset
is not in accordance with KETAS protocol. / Exit immediately.` It scores nothing
(`game.gd:470-475` zeroes cutscene scores) and interrupts the session's pace.

That one deletion closes every path: all three branches of
`generate_session_playlist()` - default, custom, and the empty-list fallback -
read `default_playlist`, and the fallback is the only one that skips
`CustomMinigamesWhitelist`.

**This deliberately breaks the 1-4-stays-vanilla rule**, with the user's
explicit go-ahead after the alternative (`modded_minigame_player_cap:
{CutsceneTest: 4}`, which would have preserved it at 1-4) was offered and
declined. Written up under that rule's own heading so it is not reverted as a
bad merge.

**The bigger find, made while verifying it:** the debug lobby has always
declared itself a **custom** game, so `-localtest` had never exercised the
non-custom playlist branch that real sessions use - and the cutscene is
invisible in a default localtest run for that reason alone. Added the
`-original` flag; see "The debug lobby is a *custom* game" in Testing. Anything
touching `default_playlist` or `supports_player_count()` must now be verified
with it.

**Evidence.** With `-original`, before -> after: 8 players 12 -> 11 entries,
4 players 16 -> 15, and in both cases `diff` of the sorted playlist shows
**exactly one** removed line, `CutsceneTest`. A 420s `FLOW=1 -original` run at 8
played seven minigames through the full loop with **zero**
`MinigameCutsceneTransition` entries, score and briefing screens at `rows=8` on
a client, all 8 peers auto-readying, and no script errors. Error classes at 8
match 4 apart from two transient replication-churn entries that were already in
the pre-change 4-player set.

**Not touched:** the cutscene scene, `MinigamePaths`,
`CutsceneMinigameIdentifiers`, the `MinigameCutsceneTransition` state, and the
mod's four extra spawn markers in `cutscene_test.tscn` - so `-debug-tools` can
still launch it at up to eight players. `CutsceneGame02` (an unfinished stub in
no playlist, reachable only via `-debug-tools`) was out of scope and is
untouched.

### 2026-08-01 (later) — the last four untested minigames

**Played at 8 players for the first time:** Tunnel Hazard (`TrainRace`), Inside
Job (`KnifeAtTheOffice`), Spine Breaker (`SpineBreaker`), Lethal Rebound
(`DvdRoomba`). That clears the "never actually played" list. All four spawn
eight players correctly on host *and* clients, run full rounds, and advance to
the next round; landing audits show every player within 0.6u of a marker.

**Two of the four needed no gameplay change at all**, which is worth knowing
before assuming an expansion is due:

- **Tunnel Hazard** already ships **eight** nooks (`Left/1-4` + `Right/5-8`)
  despite vanilla capping at four players, and `nook_handler.cycle()` opens
  `max((player_count + 2) - rounds_passed, 1)` of them with no hardcoded count.
  At eight that starts at 10, clamps naturally to the 8 that exist and
  converges.
- **Spine Breaker** and **Lethal Rebound** pick victims with `pick_random()`
  over `active_players` and index nothing per slot.

**Bugs found and fixed:**

| Bug | How it surfaced |
|---|---|
| Inside Job: `guaranteed_search_result` can exceed the containers that exist | static audit; the office holds 36 searchables, each searchable once, but the target scales to 26-52 at eight players - above 36 the syringe is never found and **the round never ends** |
| Inside Job: `alive_indicator_icons` capped at 4 | the hunt HUD showed four "alive" icons however many humans remained. **Silent** - see pitfall 23 |
| Score screen: negative pitch on the reverb speaker | the 4-vs-8 error diff (pitfall 12). Vanilla code; only reachable once score totals are big enough to run the countdown to its 0.1 pitch floor |

**Added:** `[TRAIN8]`, `[KATO8]`, `[SPINE8]`, `[ROOMBA8]` traces, each with a
per-peer **landing audit** (every player's distance to the nearest marker, with
`DISPLACED` / `FELL_THROUGH` / `DEAD_OR_HIDDEN` verdicts); `ARGS=` pass-through
in `localtest.sh`; `-kato-target=` and `-kato-hunt=` test aids.

**A wrong theory, corrected by measurement.** The `alive_indicator_icons` cap
was first written up here as a hard break - out-of-bounds aborting
`set_active_rpc` before `timer.start()`, so the hunt countdown never ran. A
control run with the fix removed showed **identical timings and zero errors**,
and a direct probe against the real binary showed why (pitfall 23). The bug is
real but cosmetic. Rebuilding the claim from the probe rather than from
reasoning is the only reason this file is accurate.

**Still not proven at 8:** nobody plays, so Tunnel Hazard's nook contention
(idle players are run over during the first cycle, so the elimination ramp
never runs) and Inside Job's search economy in real play remain unexercised.
See "What the local test still is not".

**Open, not fixed:** one 8-only error class, `Parameter "data.tree" is null`,
1-3 lines per run at the instant a round ends - a vanilla coroutine resuming
after its node left the tree. Benign and deliberately left alone rather than
adding a file to the overlay to silence it.

**Pre-existing deviation from the 1-4 vanilla rule, found in passing and NOT
fixed** - see "Spawn markers are visible to 1-4 player games too" below. Worth
a decision before the next release.

### 2026-08-01 — v1.0.7 rebuild + Escalator Pit + Smoke Break

**Rebuilt against v1.0.7.** The patch changed exactly one script line
(`game_version`) plus localisation; 33 of 35 overlay files had byte-identical
upstream source, proven with a `filecmp` sweep, so only `globals.gd` was
re-derived. See "The last update, and how it was verified" above.

**Verified at 8 players (new this session):** Debris Platforms
(`JunkPlatform`), Wrong Way (`EscalatorPit`), Stable Footing (`DiscoDodge`),
Smoke Break (`SmokeBreak`), plus the intermission **score screen** and
**briefing screen**.

**Bugs found and fixed:**

| Bug | How it surfaced |
|---|---|
| Score + briefing screens showed only the top 4 of 8 | filled from a *sorted* list bounded by array size - silently dropped players, no crash |
| `disco_dodge` `spawn_limit` still 4 | documented as fixed but **missing from the overlay**; caught by a scene audit, proven with a control run |
| `spawn_expand.py` displaced clones along raw local X | three Escalator Pit markers are laid on their side, so clones went 1.2 *under* their neighbour |
| Escalator Pit: 8 players on 4 lanes | split each trough into two stair strips, cloned the CRT screens, hid the handrails |
| Smoke Break: 4 seat-capped arrays | gun aimed at nothing, players never fell - see section 14 |
| `install.py` "game updated" warning fired on every install | the one mod-*added* file always had nothing to displace, training users to ignore it |
| `diff -rq --include="*.gd"` reported zero changes when there was one | `--include` filters directories, so recursion never descends |

**Added:** `FLOW=1` full-session-flow test mode; `[PLATFORM]`, `[SCORE8]`,
`[BRIEF8]`, `[LANES8]`, `[SMOKE8]`, `[ART]`, `[FLOW]` traces; the layout viewer.

**Two engine gotchas worth knowing** (pitfalls 18, 19): `get_transformed_aabb()`
returns **null** in the release template and assigning it to a typed variable
aborts the function *with no error printed*; and identifying a mesh by name or
listed position misled twice - toggle it and look.

**Still untested at 8:** Tunnel Hazard (`TrainRace`), Inside Job
(`KnifeAtTheOffice`), Spine Breaker, Lethal Rebound (`DvdRoomba`). Both
minigames exercised this session turned up real bugs the moment they were
actually played, so "loads clean" is a poor proxy for "works".

**Accepted limitation:** some player-model clipping on Smoke Break's left four
seats. Cause is facing, not spacing; the fix is blocked by pinned seats and the
camera frame. Section 14 has the numbers.

---

