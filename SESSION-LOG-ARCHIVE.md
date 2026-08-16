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
<!-- moved 2026-08-16 at the v1.5 release: entries older than v1.4 -->

### 2026-08-15 — Shipped as mod release v1.3: the disconnect-during-load fix (issues #10, #12)

**What ships:** the single fix from the entry below — `game.gd` re-runs the
minigame load gate when a peer drops during a load, and `duck_hunt.gd` no
longer starts a round through `Reset` before the game has begun (pitfall 32,
§19). `MOD_SUFFIX` → `8P-v1.3`, so v1.2 and v1.3 peers refuse each other
cleanly per pitfall 7; `MOD_NETWORK_GAME_VERSION` stays `v2.1.2` (no game
update); display `v2.1.2-8P-v1.3` at every step-6 site (`version_strings.py`
plus the prose sites: `README.md`, `CLAUDE.md`, `UPDATING.md` "Current
status", step 6 and the boot-test line, `installer/README.txt`).

Release integrity, all measured this day on the v1.3 strings:

| | |
|---|---|
| Static checks + `%` pre-flight | all five pass |
| Reproducible build | `dist` and deployed `testgame` pck both md5 `b3b6621803cad196c59ea5da949877ad`; engine `9bac4458…` |
| Boot | `Running version: v2.1.2-8P-v1.3`, zero parse/script errors |
| Handshake at 8 | all 8 boot `v2.1.2-8P-v1.3`, zero `VersionMismatch`/refusals, `[SEATS]` to `connected=8` |
| Regression on the release build | P8 `SIGKILL`ed at Duck Hunt's load: `[BRIEF8] players=7 → SessionIntro → MinigameStart → MinigamePlaying → Empty → Round`, `markers roster=7 added=3`, host and clients; a no-kill 8p run took the normal path; only `Parameter "node" is null` |
| Installer round-trip (clean v2.1.2 copy, `f5ea2339…`) | `NOT PATCHED` → install (**4206 files, 55 mod, 92 replaced**) → `PATCHED - all 55 mod files present` + `v2.1.2-8P-v1.3` → re-install **refused**, pck md5 unchanged → restored from the staged pristine copy, `f5ea2339…` again; no `.vanilla` created |
| Zip | rebuilt per step 8: **59 entries**, extracted `mod/` `diff -rq` clean, four root files `cmp`-identical; md5 **`0b2ba1f85f1092dcfb6a330ce60046ad`**, 21,304,073 bytes |

Two harness lessons folded into the Testing recipe: arm the kill-at-load
watcher **after** clearing `/tmp/mp-localtest` (a stale `p1.log` from the
previous run fired it before any client existed and silently turned one run
into a no-kill control), and never `pkill -f` a pattern that is also on your
own command line.

Tagged `v1.3`, `gh release create` with the zip attached; issues #10 and #12
closed as shipped, #11 (the crash itself) stays open. **Issue #13 opened** for
the follow-up the maintainer deferred to a later session: the other 14 rotation
minigames' `player_disconnected()` handlers, unaudited for the pre-spawn
ordering (open item 7). The kill-at-load watcher was then promoted from the
scratch script to **`tools/kill_slot_at_load.sh`** at the maintainer's request
(`<slot> [MinigameIdentifier]`, clears the log dir itself, kills by pid) and
re-verified from its new location: 4p, P4 killed at the load line, host went
`players=3 → MinigameStart → MinigamePlaying → Empty → Round`.

### 2026-08-15 — Duck Hunt's silent rifle and the black-screen wedge share one cause: a peer dropping DURING a minigame load leaves vanilla's load gate stuck (issues #10, #12). Reproduced at 4 players, fixed at every roster size

**Task:** playtest and bugfix last night's Duck Hunt issues, starting with an
8-player run to see whether the sound bug (#12) presents. It did not — and
the diagnosis that followed put #12 and #10 on the same root cause, which
turned out to be vanilla code and reproducible at four players.

**Run 1, unfixed build, 8 clients, `START=1 MINIGAME=DuckHunt`, maintainer at
the hunter window (P2 — five `ACH_11` headshots):** every sound audible, all
eight loaded (`[DUCK8] spawned ducks=7 hunters=1` on every peer), no client
died. So the shot RPC works at the full roster over ENet — "roster-dependent
by construction" is off the table, and one 8-player Duck Hunt load was clean
against #11.

**Diagnosis, from the code and the preserved session log:**

- The hunter's fire speaker (and every rifle/duck speaker) sits on the
  `MINIGAME_SFX` bus. Every minigame zeroes that bus at its end
  (`set_minigame_sfx_linear_volume_rpc.rpc(0.0)`); the **only** place it is
  restored is `Minigame.initialize()` (`minigame.gd:67`, `.rpc(1.0)`). A pinned
  local Duck Hunt is the first minigame, so the bus starts at its default and
  the harness cannot show the silence; in the real session Duck Hunt was game 5,
  after Escalator Pit had zeroed it.
- `initialize()` is reached only via `all_players_loaded()`, which vanilla
  `Minigame.player_loaded()` calls when `players_loaded.size() ==
  player_presences.size()` — evaluated **only when a `player_loaded` arrives**.
  (`game.gd`'s own `minigame_players_loaded == network_players_loaded` gate is
  dead code: `network_players_loaded` is never populated.)
- One peer crashed *during* Duck Hunt's load (#11). Its presence was removed by
  `_on_peer_disconnected` after the last live peer had reported in, so the
  numbers matched but nobody re-asked. Duck Hunt's vanilla
  `player_disconnected()` then ran `check_game_end()` 1 s later, which found no
  ducks and no hunter and started the round itself via `Reset` →
  `spawn_players()` — bypassing `initialize()`.
- **The tell is in the maintainer's client log:** before every other minigame
  the Game state machine goes `MinigamePick → MinigameStart → MinigamePlaying`
  (`_on_minigame_ready` fires both that transition and `initialize()`); before
  Duck Hunt it goes `MinigameEnd → MinigamePick` and then straight to
  `duck_hunt: Empty → Reset → Round`. `MinigamePlaying.enter()` is the only
  place `minigame_finished` gets a listener, so when the last turn reached
  `Finished` nobody moved it to `MinigameEnd` — the black screen on every peer,
  host included. The `Finished → Finished` cycling and `k_EResultNoConnection`
  spam are the ghost peer's noise on top, not the wedge.
- **The "ghost" was vanilla's designed wait:** mid-session joins are processed
  only while the briefing screen is up (`can_check_for_connect_requests` is set
  by `intermission_briefing_screen.gd`), so a rejoiner sits on the lobby scene
  eating the host's broadcasts (the 814 node-not-found lines) until the next
  briefing — which the wedge never reached.
- `check_game_end`, `player_disconnected`, `_on_peer_disconnected` are
  byte-identical to vanilla and `minigame.gd` is not in the overlay: **vanilla
  at any roster size**; a bigger roster only makes a drop-during-load likelier.

**Reproduction (run 3, unfixed build, 4 clients):** P4 `SIGKILL`ed the instant
the host printed `[ROUNDS8] load minigame=DuckHunt` (recipe: Testing,
"Simulating a peer crash during a minigame load"). Host: `[BRIEF8] players=3`
(disconnect processed ~15 s later, after the other two had loaded), **no
`Game: MinigameStart`/`MinigamePlaying`**, `duck_hunt: Empty → Reset → Round`;
the maintainer played three hunter turns to `Play → Finished`; **`MinigameEnd`
0 occurrences on any peer; black screen on all three windows, seen.** Same
signature as the session log, at four players, on the vanilla path.

**Fix (maintainer's decision: all roster sizes, the §19 precedent), no new
`@rpc`, both files already in the overlay:**

- `game.gd::_on_peer_disconnected` (host, before `minigame.player_disconnected`
  is called): while the current minigame has not started
  (`not minigame.is_all_player_loaded` — every one of the 20 minigame scripts
  sets it in `all_players_loaded()` before emitting `minigame_ready`, verified),
  erase the dead peer from `minigame.players_loaded` and, if
  `players_loaded.size() >= player_presences.size()`, call
  `all_players_loaded()`. Guarded with `is_instance_valid(minigame)` because
  `load_minigame()` holds the previous, `queue_free`d instance for a second.
  Ordering matters: run before Duck Hunt's handler so `spawn_players()`'s 1 s
  timer is created ahead of `check_game_end()`'s.
- `duck_hunt.gd::player_disconnected`: `if not is_all_player_loaded: return`
  after `remove_player_rpc.rpc()` (the dead peer must still leave
  `possible_hunters`) — before the first spawn there is nothing to end, and
  the `Reset` side door would race the real start.

**Verification:**

| Run | Build | Scenario | Result |
|---|---|---|---|
| A | fixed | 4p, P4 killed at load, played to the end | `[BRIEF8] players=3` then `SessionIntro → MinigameStart → MinigamePlaying`, `duck_hunt: Empty → Round` (no `Reset`), three turns, `Play → Finished → Game: MinigamePlaying → MinigameEnd`, `[SCORE8] players=3` — on the host **and both clients**; score screen seen |
| B | fixed | 8p, P8 killed at load | same healthy path on host and clients; `[DUCK8] markers roster=7 ducks_needed=6 markers=6 added=3` — the roster-scaled logic followed the shrunken roster |
| C8, C4 | fixed | no kill | identical to run 1 / the pre-fix 4p control: `Empty → Round`, `ducks=7/3`, `magazine=18/10`, `bolt_speed=1.281/1.000`, spawned counts exact |
| errors | all | filtered per Testing | only `Parameter "node" is null` (documented, both rosters) plus, in run A after the score screen, the documented teardown churn and the vanilla `update_playlist_state_rpc` arity line |
| static | — | five checks + preflight | all pass; RPC count still 8; boot prints `v2.1.2-8P-v1.2` |

**What this does NOT claim:** the audio half is established from the code
path (the bus is restored by `initialize()` alone) and the log ordering, not by
ear in a multi-minigame local run — a pinned run cannot go silent. Doing that
needs an unpinned rotation (Duck Hunt 5th) with the kill at its load and a
listener; offered, not done. **#11 (the crash itself) stays open** — cause
unknown, one clean 8-player load. The kill-at-load helper started as a scratch
script and became `tools/kill_slot_at_load.sh` later the same day at the
maintainer's request (release entry above).

**Two harness lessons.** `pkill -f "-localtest 4 join"` matched the *tool
shell* that contained the pattern and killed the launcher, not the client —
use `pgrep -f "x86_64 -localtest [4] join"` (the `[4]` cannot match its own
command line) and `kill -9` the pid. And the `[DUCK8] spawned` audit fires at a
fixed 6 s after `_ready`, so under a late start it prints `ducks=0 hunters=0`
plus its mismatch warning — that is a **tell of a late start**, not a spawn
bug (pitfall 32).

Docs: pitfall 32 appended; §19 gains the third vanilla fix; manifest rows for
`game.gd` and `duck_hunt/*`; Testing gains the kill-at-load recipe; "Current
status" updated. Issues #10 and #12 commented with the diagnosis; #11 left
open. Archived logs: scratchpad `run1-logs/`, `run3-logs/`, `runA-logs/`,
`runB-logs/`, `runC8-logs/`, `runC4-logs/`.

### 2026-08-14 — first real 8P-modded Steam session on v2.1.2: black-screen incident, issues #10 and #11

The maintainer played a real 6-player Steam session (5-game custom playlist)
the same evening as the rebuild — the first real multi-human session on the
v2.1.2 build. Four minigames played cleanly. The fifth and final one, Duck
Hunt, surfaced two defects, diagnosed from six preserved logs (locations in
`NOTES-LOCAL.md`; they carry player identifiers so they stay out of the repo):

- **Issue #11 — a client hard-crashed loading Duck Hunt.** Their log ends
  mid-write at the scene transition: no script error, no shutdown lines —
  the pitfall-23 signature (a release-build OOB method call SIGSEGVs with a
  clean log) or a driver one-off; undetermined. The mod's client-side load
  path read clean on inspection. Reproduction queued: pinned 8-client Duck
  Hunt on v2.1.2 (the v1.5.0-era pinned runs were crash-free, but Duck Hunt
  has not been re-run pinned since the rebuild — the 2026-08-14 baseline
  series drew ExplodingCollarRace and ChiselGauntlet only).
- **Issue #10 — the crashed player rejoined mid-minigame and became a ghost**:
  their relaunched client sat on the lobby scene while duck_hunt replication
  streamed at it (814 node-not-found errors client-side). The session played
  on correctly without them — 5 hunter turns for 5 remaining players, the
  mod's turn-per-player pacing exact — and the final turn ended by the hunter
  eliminating every duck (the first total-elimination ending ever observed at
  >4 players). At `Finished`, the session-end transition wedged on the dead
  ghost connection: `k_EResultNoConnection` send spam and `Finished →
  Finished` cycling on every peer, **host included** — black screen for all
  six. Nothing recoverable; everyone restarted.

What the evidence does and does not say: the wedge is downstream of the
ghost peer, not proven downstream of the total-elimination ending — that
ending had simply never occurred before, and whether it wedges on its own is
untested. The mid-minigame rejoin path is host-authoritative vanilla code
(the mod overlays its edges in the backends), so vanilla-vs-mod attribution
for both #10 halves is open. Also confirmed by the same logs, incidentally:
the friend's pre-session update dance exercised three refusal paths for real
(old-mod v1.0 refused, bare v2.1.2 refused into a 6-player lobby, current
v1.2 accepted) — all behaved as designed.

**Issue #12 — no gunshot audio for anyone in the same Duck Hunt round**,
hunter included. Desk analysis exonerated every mod-touched surface (the
mod's hunter delta has no audio code and zero delta residue; the shot RPC is
vanilla `any_peer`/`call_local`; the speaker node, stream and bus are
byte-identical across versions in a scene the mod does not overlay; the
headshot volume-duck restores correctly). Remaining candidates need ears:
vanilla v2.1.2 regression (the update shipped that day), something
roster-dependent above 4, or never-played-at-5-8-and-nobody-listened. The
two-minute solo-listen test that splits it is in the issue.

Where to pick up: reproduce #11 with `START=1 MINIGAME=DuckHunt` at 8 on the
current build; if clean, drive the hunter to a total-elimination win with a
human at one window (FLOW=1) to test #10's ending half; the ghost-rejoin half
needs a mid-minigame kill-and-rejoin of one harness client, which the
harness does not currently script — by hand is fine. For #12, the
maintainer's solo listen decides which side of the fence it is before any
harness time is spent.

### 2026-08-14 — installer: backup feature removed entirely (issue #9)

Maintainer's decision, same session as the rebuild below: the game is a small
download, so the `.pck.vanilla` backup wasn't worth its failure mode — after a
Steam game update the backup is stale, and both re-install (rebuilds the old
version over the new) and `--uninstall` (restores the old version) silently
downgraded the game. Rather than version-checking the backup, it is gone:

- `install()` patches the **live** pck, and **refuses** (not `--force`-able)
  when the pck is not pristine — a shared `mod_state()` classifier keeps the
  guard and `--verify` in exact agreement. Path guards (pitfall 5) untouched.
- `--uninstall` restores nothing: it reports the state and points at Steam's
  *Verify integrity of game files*, which is now the documented uninstall.
- A leftover `.vanilla` from older installer versions is never read; both
  paths offer to delete it (prompted; `--force` answers yes).
- `installer/README.txt`, `README.md` and the Testing round-trip recipe
  updated to match; release zip rebuilt (extraction diff empty).

Evidence: implemented and command-verified by a subagent, reviewed here —
eight-step suite on `testgame_new` (pristine `f5ea2339…`): NOT PATCHED →
install (no `.vanilla` created) → PATCHED `v2.1.2-8P-v1.2` → re-install
refused twice with pck MD5 unchanged → `--uninstall` exit 0, pck untouched →
stale-backup migration exercised in all three answer paths (kept on `n`,
deleted on `y` and under `--force`) → final state byte-identical pristine.
The partial-state refusal branch was exercised via the classifier in-process
(no e2e path can produce a partial pck). `py_compile` and all five static
checks pass. Closes **issue #9**.

### 2026-08-14 — REBUILT AGAINST GAME v2.1.2 (largest patch yet); overlay 56 → 55 files

The game updated v1.5.0 → v2.1.2 and the mod was rebuilt per the update
procedure, steps 1-8 complete. "The last update, and how it was verified" in
`UPDATING.md` is the worked example for this rebuild (the v1.5.0 one moved
verbatim to `SESSION-LOG-ARCHIVE.md`); this entry is the evidence record.

**The patch:** 101 changed / 33 added / 2 removed files at the raw-pck level;
counts 368→371 `.gd`, 140→141 `.tscn`; pck **shrank** ~535 KB
(`f5ea2339e870cc507a58de63e4b78908`, 634,798,100 bytes); engine binary
unchanged (`9bac4458…`, still Godot 4.5.2). Theme: couch/local-multiplayer
features (`GameManager.local_game` branches threaded through many minigames,
new local-lobby character-select UI) plus a custom-playlist shuffle option
(`custom_shuffled`, new ShuffleButton in the playlist UI). **No new minigame**
— the marker rescan found no new spawn containers and all 14 recorded paths
still resolve.

**Steam patched over a modded install.** The real install still carried the
mod (its `Machine Party.pck.vanilla` backup sits beside the new pck); the
updated pck verified vanilla-shaped (no mod files, remaps intact) and 4,109 of
its files are byte-identical to the pristine v1.5.0 extraction, so the delta
patch came out clean. **The stale v1.5.0 backup in the Steam install is now a
live hazard** — see the installer bug below.

**Sweep result: 25 of 56 overlay files re-derived** (30 byte-identical
upstream and carried; `mod_player_name_list.gd` mod-added). Re-derivation was
done by five parallel subagents (per-file upstream-change summaries, delta
re-application, delta-of-deltas checks), then independently re-verified here —
every content-line residue is one of: the intended version constants, the
junk_platform marker rotation (below), or a named adaptation. Notable events,
each also condensed into the worked example:

- `duck_hunt_local_handler.gd`'s delta became **obsolete** (upstream deleted
  the roster-indexed `Layouts` it guarded; new `setup()` is
  roster-independent) — file came out byte-identical to vanilla and **left the
  overlay: 56 → 55 files (39 `.gd`, 16 `.tscn`)**.
- `junk_platform.gd`'s `spawn_players()` was rewritten upstream; online path
  re-verified to walk markers in child order (the 2-per-deck property).
  Upstream also rotated two shipped `junk_platform.tscn` markers 180°; the
  expander clones inherit the flip (displacement flips with local X) — traced
  arithmetically, still 1.2u from their source markers on radius-6 decks.
- `burn_recycle.gd`: upstream's new couch hide-tag call landed inside the
  block the mod's per-room `eliminate_players()` replaces; re-inserted per
  victim inside the mod's loop, matching vanilla semantics.
- **Tool trap — `lobby_expand.py` moves the shipped Player2-4 preview slots**
  (spread interpolation), but the shipped v1.2 scene has them at vanilla
  positions, and `lobby_scene.gd` snapshots the baked positions at load as its
  ≤4-player home layout (rule 3). Restored by hand post-run; the added-line
  set then matched the shipped v1.2 delta exactly (modulo resource ids). The
  tool itself is still unfixed — see open note below.
- **Tool trap — `spawn_expand.py` must never run on `smoke_break.tscn`**
  (§14 hand-authored seats; a supervised run this session produced wrong
  markers and was reverted). Its `spawn_targets.txt` entry is now commented
  out with the reason, duck_hunt/forklift style.
- Stale "v1.5.0" prose in shipped mod comments made version-agnostic
  (globals, network_manager, both backends, quasivanilla) so it cannot go
  stale at the next bump; historical mentions kept.

**Version sites:** `MOD_NETWORK_GAME_VERSION` → `"v2.1.2"` (copied from the
new decompile), `MOD_SUFFIX` carried as `"8P-v1.2"` (maintainer's decision:
this ships as a REBUILD of v1.2, not a new release — the v1.2 GitHub
Release's zip asset was replaced with the v2.1.2 build and its notes updated,
tag untouched), display `v2.1.2-8P-v1.2`; install.py `SUPPORTED_VERSION`,
README.txt labels, and all doc prose bumped — `version_strings.py` and the
other four static checks all pass. Quasivanilla: 2 of its 4 overlay files
re-derived (delta-of-deltas exact), `qv.pck` rebuilt and deployed to
`testgame2/`.

**Validation evidence:**

| Check | Result |
|---|---|
| Five static checks (`tools/checks/`) | all pass |
| `-validate-scenes` in the real release binary | **55/55 OK, failures=0** |
| Boot test | `Running version: v2.1.2-8P-v1.2`, zero script/parse errors |
| 8-client `START=1` baseline | version print on all 8; `[SEATS]` to `connected=8`; 15-entry playlist; ChiselGauntlet `[STATIONS]` cloning positive on host **and all 7 clients** (24 lines each, `is_server=false`) |
| 4-client parity | `player_count=4`, zero clone lines on host, zero `[STATIONS]` on clients — roster gate dormant |
| Pitfall-12 error-class diff 4 vs 8 | only `Parameter "data.tree" is null` at 8 — the documented benign entry; nothing new |
| Mixed lobby, modded host + vanilla joiners | all 4 connect, no refusals, versions `v2.1.2-8P-v1.2`/`v2.1.2` per slot, checksum-failed prints as documented |
| Mixed lobby, vanilla host + modded joiners | all 4 connect, minigames load on every peer (host-authoritative mod traces absent by construction — vanilla host carries no mod code) |
| Installer round-trip on clean v2.1.2 copy | NOT PATCHED → install (55 files) → PATCHED `v2.1.2-8P-v1.2` → uninstall → **byte-identical restore** (`f5ea2339…`) |
| Release zip | rebuilt; extracted `mod/` diffs empty against working tree |

One unlisted-but-benign-shaped log line seen at 4p only (`Ignoring sync data
from non-authority or for missing node`, 4×) — same replication-churn family
as the documented noise, not new-at-8, not chased. Archived logs:
scratchpad `v212-baseline/run{1-4}/`.

**Found this session, needs a decision — installer stale-backup bug.**
`install.py install()` uses an existing `Machine Party.pck.vanilla` as its
patch base with no staleness check, and `--uninstall` restores it blindly. A
user who updates the game and re-runs the installer gets the OLD game silently
rebuilt over the new one (the compatibility warning cannot fire — the old
backup satisfies it), and an `--uninstall` after a game update "restores" the
previous version. The maintainer's own install is in exactly this state (stale
v1.5.0 backup beside the v2.1.2 pck — delete it by hand; rule 1 forbids the
assistant touching that folder). Candidate fix: refresh the backup from the
live pck whenever the live pck verifies NOT PATCHED and differs from the
backup; warn on uninstall version mismatch. Filed as **issue #9** (with the
delete-the-backup workaround); the fix itself awaits the maintainer's go.

**Also unfixed, recorded:** `lobby_expand.py`'s current spread step moves the
shipped preview slots — its output no longer matches the shipped scene without
the hand restore above. Fix the tool before the next lobby regeneration, or
repeat the restore.

**What this rebuild does NOT claim:** the per-minigame 8-player verification
in "Current status" was measured on v1.5.0 and carries forward on the sweep's
proof plus this session's two-minigame baseline (ExplodingCollarRace,
ChiselGauntlet at 4/8/mixed). The other thirteen minigames have not been
re-run at 8 on v2.1.2; open item 1 (nobody has *played* an 8-human session)
is untouched. Arcade remains unproven (no local harness reaches it) — its
filter re-anchored and re-read, nothing more.

### 2026-08-14 — UPDATING.md split: pitfalls to `PITFALLS.md`, session log to this file

Requested by the maintainer. `UPDATING.md` had regrown past one read
(3,404 lines) — the same problem that split out `MINIGAMES.md` on
2026-08-04 — so its two largest sections moved to their own files:

- **`PITFALLS.md`** now holds the numbered failure modes, **numbering 1-31
  unchanged** — *pitfall N* citations in code and docs still resolve, and the
  file's header restates the never-renumber rule and the other citation
  conventions. New pitfalls append there.
- **`SESSION-LOG.md`** (this file) now holds the live session log; **new
  entries are recorded here**, newest first. The archive flow is unchanged:
  fully-folded entries still move verbatim to `SESSION-LOG-ARCHIVE.md`,
  leaving a stub.
- `UPDATING.md` keeps a short pointer stub at each old section position, and
  its instructions were updated everywhere they named the old locations:
  the intro, the "What is where" table, the citation-scheme note (*pitfall N*
  now means `PITFALLS.md`; *rule N* still means `UPDATING.md`),
  documentation-policy rule 3, the paste-in prompt, update-procedure step 6,
  and the Layout listing. `CLAUDE.md`, `MINIGAMES.md`'s header and
  `SESSION-LOG-ARCHIVE.md`'s title got the matching one-line updates.
- Moved text is otherwise **verbatim**; the only body edits were references
  the move made wrong (five "this file"/"above"/"below" phrasings now naming
  `UPDATING.md` or the pitfalls list explicitly, and pitfall 16's pre-flight
  pointer now naming the committed check script).

**Deliberately unchanged: everything under `mod/`.** Two code comments cite
"the pitfalls list in UPDATING.md" — editing a shipped `.gd` for a doc pointer
would change the built pck for zero player-facing effect, and the stub in
`UPDATING.md` redirects anyone who follows the stale pointer. Also unchanged:
`SESSION-LOG-ARCHIVE.md`'s entries (append-only), and all five
`tools/checks/` scripts, none of which read the moved sections
(`manifest_counts.py` reads `UPDATING.md`'s overlay manifest, which stayed).

**Verification:**

| Check | Result |
|---|---|
| `tools/checks/*.py`, all five | pass |
| Pitfall numbering in `PITFALLS.md` | 1 through 31, order intact, none renumbered |
| Entries in this file | all 20 dated entries carried over, order intact |
| Dangling references | repo-wide grep: no quoted-section "Pitfalls"/"Session log" references remain outside the stubs; no "entry above/below" phrasing left in `UPDATING.md` |
| `UPDATING.md` size | 3,404 → ~1,900 lines |

**One thing this session cannot update:** any orchestrator prompt or project
memory *outside* the repo (the dev machine's `~/Documents/Claude` prompts and
the `machine-party-8p` memory entry) that says the pitfalls or the session log
are sections of `UPDATING.md`. Update those by hand next session there.

### 2026-08-14 — the checks wired into the working docs, plus a pre-push hook

Follow-up to the CI entry below, closing the gap between "the checks exist"
and "the process uses them": the goal is that a push never reaches origin
red, because history there is append-only and a failed run can only be fixed
forward with another commit.

- The two identical `%`-specifier pre-flight heredocs (Working environment,
  Testing) replaced by `python3 tools/checks/preflight_format_specifiers.py` —
  the logic now lives only in the committed script, so the copies cannot
  drift (~30 lines of duplicated code out of `UPDATING.md`).
- New Version-control rule: **run the static checks before every push**; a
  local pass guarantees a green run on origin (same scripts, same tracked
  files, stdlib-only).
- Step 6 now ends with `version_strings.py` verifying all five label sites;
  step 7 and Handy commands carry the run-all one-liner
  (`for s in tools/checks/*.py; do python3 "$s" || break; done`).
- **`tools/checks/install_hook.sh`** (new) installs a `pre-push` git hook
  that runs all five and blocks the push on any failure. Hooks live in the
  untracked `.git/hooks/`, so it is a once-per-clone step; the emergency
  bypass is `git push --no-verify`.

Verified: all five checks pass on this tree; the hook's failure path was
exercised by dropping a deliberately-failing script into `tools/checks/`
(run blocked, failing script named, then removed) — and the pass path is
proven by this entry being on origin at all, since this commit's own push
went through the installed hook. Also in this commit's parent:
`checkout@v4 → v5` cleared the Node 20 deprecation warning, so runs are
green with zero annotations.

### 2026-08-13 — CI: five static checks committed as scripts, run by GitHub Actions on every push and PR

Five paste-in recipes and prose rules became committed scripts under
`tools/checks/`, run automatically by `.github/workflows/checks.yml` on every
push and pull request (the repo's first CI). Each also runs standalone —
`python3 tools/checks/<name>.py [repo-root]`, exit 0/1 — so they slot into the
local pre-flight habit. **They need only tracked files; the update-procedure
checks that need decompiles or the game binary (filecmp sweep, `.tscn` audit,
marker rescan, `-validate-scenes`) stay local-only by design, and game content
must never be uploaded to CI.**

| Script | Guards |
|---|---|
| `preflight_format_specifiers.py` | pitfall 16 — invalid `%` specifiers in `mod/**/*.gd` (the committed form of the Working-environment pre-flight) |
| `version_strings.py` | step 6 — `game_version` = `MOD_NETWORK_GAME_VERSION` + `-` + `MOD_SUFFIX`, install.py's `SUPPORTED_VERSION` and `--verify` string, and README.txt's two labels all agree |
| `manifest_counts.py` | the overlay-count claims (total / `.gd` / `.tscn`) in `UPDATING.md`'s manifest header and README.md vs what `mod/` actually holds — note it matches the FIRST claim-shaped string in each doc, so never quote one verbatim above the manifest |
| `rpc_prefix.py` | pitfall 30 — any `@rpc` func named `mod_*`/`*_mod_*` must be `zz_`-prefixed |
| `mod_marker_numbering.py` | `spawn_expand.py` mis-parse tell — `_MOD` numbering below 5 (green_pea's four hand-authored chairs whitelisted) |

**Verification:** all five pass against this tree (the marker check passes
because the 2026-08-13 chisel fix landed first — against the pre-fix tree it
correctly flagged the three `_MOD2-4` spectate markers). Each check was also
mutation-tested against a scratch copy: an injected `%r` string, a bumped
`MOD_SUFFIX`, a deleted overlay file, and an unprefixed `mod_test_rpc` each
turned exactly their check red. Origin: the 2026-08-12 independent audit's
recommendation to convert documented manual checks into CI-enforced ones.

On GitHub, every commit and PR now shows a green check / red X in the Actions
tab; a red X means one of the five invariants above broke — read the failing
step's log, it names the file and line.

### 2026-08-13 — Shipped as mod release v1.2, a FULL release: open item 3a closed by a real Steam mixed session

**What ships:** the four fixes since v1.1 — the playlist 9-connection
dead-end (issue #6), the spectate markers (issue #7), the corner barrels
(issue #8), and the station clone-list cleanup (plus the expander parse fix,
pitfall 31). `MOD_SUFFIX` bumped to `8P-v1.2`, so v1.1 and v1.2 peers refuse
each other cleanly per pitfall 7; `MOD_NETWORK_GAME_VERSION` stays `v1.5.0`
(no game update).

**Experimental de-flagged — maintainer's decision, on new evidence:** a real
Steam mixed session with unmodded players confirmed **both join directions**
(modded host + vanilla joiner, vanilla host + modded joiner) — the half of
open item 3a only real Steam lobby callbacks could prove. The two other
enumerated sub-checks (vanilla 5th-join refusal, cutscene in the mixed
rotation) were not exercised in that session and rest on the 2026-08-09
local ENet evidence plus backend symmetry. 3a is **closed**; item 3 (the
Steam lobby's 8 previews at 8 players) is untouched — a mixed session caps
at 4.

Release integrity, all measured this day on the v1.2 strings:

| | |
|---|---|
| `%` pre-flight | 0 findings across all 40 overlay scripts |
| Reproducible build | `dist` and deployed `testgame` pck both md5 `ed9bbfb0f4f01cb574845fdad474851b` |
| Handshake at 8 | all 8 peers boot `v1.5.0-8P-v1.2`, zero `VersionMismatch`, `[SEATS]` walks to 8 distinct ids, zero parse/script errors |
| Installer round-trip (clean copy) | `NOT PATCHED` → install (**4174 files, 56 mod, 94 replaced**) → `PATCHED - all 56 mod files present` + `v1.5.0-8P-v1.2` → headless boot clean → `--uninstall` → **`f5912732…`, byte-identical** |
| Zip | rebuilt per step 8: **60 entries**, extracted `mod/` `diff -rq` clean, all four root files byte-identical; md5 **`fa4fa55a560fe1f3292c7f37866bb962`** |

Tagged `v1.2`, `gh release create` (no prerelease flag) with the zip
attached; issues #6, #7, #8 closed as shipped. The Experimental caveats
came out of `CLAUDE.md`, `README.md` and `installer/README.txt`; the
version-label sites (step 6's list) all moved together.

### 2026-08-13 — Chisel: the 135° slot's player stood inside the corner barrel stack; two props now hidden at 5-8

Reported by the maintainer from an 8-player session — one player clipping
into barrel props — and pinned down by computing the geometry rather than
running anything: the character rig stands **6.74u** from the room centre
along its facing (`Visuals` at local z=−8 plus the character offset), the
four added slots face the diagonals (45°, −135°, 135°, −45°), and the
**135° slot's** character lands at (−4.77, +4.77) — **0.44u** from
`barrel_001` and **0.89u** from `barrel_002`, the barrel stacked at chest
height on it. The character capsule alone is 0.7u, so that is deep visual
interpenetration. The player root is a plain `Node3D` — no physics — so the
defect was purely visual, which is also why no trace could see it.

**A mapping trap worth keeping** (pitfall 28's family): the barrels live
under `chisel gauntlet art2/walls`, and `walls` carries a **+90° Y
rotation** — so the props' local coordinates point at the *wrong corner*.
`barrel_001` reads (−5.08, −5.10) in the file and sits at world
(−5.09, **+5.07**). Any next prop-vs-slot check must go through the parent
chain. Cross-check that validated the model: the same math puts each
cardinal desk exactly where its vanilla character faces it.

Other diagonals, measured while at it: `pallet_002` is **1.01u** from the
45° slot (borderline — **maintainer will look**, and it stays untouched
until then); `pallet_001` 1.50u from −135°; nothing near −45°.

**Fix** (maintainer's choice from the measured options): hide `barrel_001`
and `barrel_002` in `zz_mod_add_stations_rpc()` — already roster-gated > 4
and running on every peer — leaving the third barrel (1.54u clear) as
dressing; 1-4 keeps the shipped set exactly. The barrels carry their own
`StaticBody3D`, so the hide also sets `PROCESS_MODE_DISABLED` on their
collision bodies (default `disable_mode` removes them from the physics
space) — hiding the mesh alone would have left the same phantom-collider
class the entry below just removed. Trace summary is now
`cloned 10 single nodes, hid 2 props`; a miss prints `MISSING prop`.

| Check | Result |
|---|---|
| 8-player pinned run (`START=1`, 130s) | `cloned 10 single nodes, hid 2 props` ×3 rounds on host and all 7 clients; zero `MISSING` (either kind); `[SHOTGUN]` slots 0,4,2,6,1,5,3,7 ×2; zero parse/script errors; `v1.5.0-8P-v1.1` on all peers |
| 4-player parity | `player_count=4`, no found/cloned/hid lines on any peer |
| Error classes (pitfall-12 filter) | documented families only across both sizes; the classes that drift run-to-run (`data.tree` null, `ERR_UNAUTHORIZED`) drifted exactly as documented |
| Eyes | **confirmed by the maintainer, 2026-08-13: "The barrels are gone and the player looks clean now."** The pallet_002 near-miss at the 45° slot was judged by eye the same day — **"The pallet looked fine"** — so its 1.01u clearance stands as accepted; nothing else on this is open |

Public tracker: **issue #8** (shipped v1.0/v1.1 carry the bug).
`MINIGAMES.md` §10's chisel bullet carries the hide.

### 2026-08-13 — Chisel's station clone list duplicated the room's collision environment; invisible base-mesh clone dropped

Third finding from the same external audit, confirmed in full against the
scene and the code. `MOD_STATION_CONTAINERS` cloned **every** child of
`Colliders` at 45°, and that container holds **six** children, not the
commented "desk collision bodies" four: the four desk `StaticBody3D`s plus
`GeometryStaticBody` (the room's `ConcavePolygonShape3D` **and** a
`WorldBoundaryShape3D`) and a collision-enabled `CSGCylinder3D` (the centre
pillar). So every 5-8 player round also built a phantom copy of the room's
collision mesh rotated 45° — a rotation the room's 90° symmetry does not
absorb. Graded before fixing: the WorldBoundary clone is Y-rotation-invariant
(coincident) and the 12-sided pillar clone near-coincident; the concave mesh
was the real phantom, invisible by nature, never observed to affect anything
in any run or look (players stand at stations; the main exposure was effect
physics). Latent and unintended, not an observed defect.

Same function, second half: the `Geometry/environment/control panel base
mesh` clone was **invisible** — `Geometry` ships `visible = false`, nothing
in vanilla or the mod ever shows it, and no NodePath or script reaches into
that subtree — so the entry's comment ("the desk top the carve cube rests on
… without it the cube floats") described a purpose the clone never achieved.
The *visible* surfaces at the added stations come from the two `art2`
hole-mesh clones, which is consistent with every by-eye check at 8 having
passed while this clone contributed nothing.

**Fix** (`chisel_gauntlet.gd` only): the container mechanism is gone;
`MOD_STATION_NODES` now names the four desk bodies explicitly (with the
constraint in a comment) and the base-mesh entry is dropped. The `[STATIONS]`
trace accordingly reads `cloned 10 single nodes` (was `7`, plus six silent
container children).

| Check | Result |
|---|---|
| 8-player pinned run (`START=1`, 130s) | 10 `found` lines in list order + `cloned 10 single nodes` ×3 rounds on host and all 7 clients; **zero `MISSING`**; zero hits for the old clone names; `[SHOTGUN]` slots 0,4,2,6,1,5,3,7 at 45° steps ×2; zero parse/script errors |
| 4-player parity | `player_count=4`, no found/cloned lines on any peer |
| Error classes (pitfall-12 filter) | 8p: the documented three families; `comm -13` empty. One 4p-only class this run — `ERR_UNAUTHORIZED` / `recv_nodes` — is the documented despawn-churn family (2026-08-05 entry: measured at both roster sizes, deliberately unfiltered); stochastic timing, not fix-related |

No public issue: nothing user-visible was ever observed or is expected from
the removed clones. This entry is the record; `MINIGAMES.md` §10's chisel
bullet carries the constraint.

### 2026-08-13 — Chisel Gauntlet's spectate-marker clones carried a Label3D's transform; expander parse bug fixed

The second finding from the same external audit as the playlist entry below —
confirmed against the scene, the tool source and the consumption path, with two
of its impact details corrected on the way.

**The defect.** Vanilla's `DeadLobby/SpectatePositions` ships four
**transformless** markers — Godot omits the `transform` line when it is
identity — so all four vanilla spectate cameras stack at one global point,
3.4u above the DeadLobby floor. The overlay's seven clones
(`Marker3D4_MOD2`…`_MOD8`) each carried
`Transform3D(3.6222 …, −1.20x, −2.36469, −3.72135)` — the `temp controls
label` Label3D's transform, x varying in 0.001 steps. `initialize()` appends
every child of that parent in order and `spawn_players()` hands
`spectate_positions[counter]` to `set_spectate_position_rpc` (which sets
`spectate_camera.global_position`), so at 5-8 players counters 4-7 spectated
from 2.36u below and 3.72u forward of the intended point — knee height,
roughly on the screen's plane. 1-4 players never touched the clones (counters
0-3, and this path never shuffles).

**Cause: `spawn_expand.py`'s `parse()`**, which looked ahead for a transform
without stopping at the next `[node]` header and dropped transformless markers
entirely. On this scene it therefore found exactly **one** "marker" —
`Marker3D4` wearing the Label3D's transform — which is also why all seven
clones were sourced from `Marker3D4` and numbered from `_MOD2`. The bogus
nodes predate git (byte-identical in `mod_v107/`) and `chisel_gauntlet` is
not in `spawn_targets.txt`, so no current sweep regenerates them — a fossil
of an early invocation, carried forward through two updates.

**Two audit claims corrected by measurement:** the camera sat ~1.0u *above*
the DeadLobby floor (the 10×10×10 flipped-box room), not under it — 2.36u is
its offset below the *intended* point; and the 3.62× scale was inert, since
only `global_position` is ever consumed.

**Fix:** the seven bogus nodes replaced by **four transformless clones**
(`Marker3D_MOD5`…`Marker3D4_MOD8`) — indices 4-7 now exist and resolve to the
exact point vanilla stacks its own four cameras at. `parse()` now stops at
the next `[` and records a transformless marker as identity. Sweep of all 16
overlay scenes: chisel was the only one with the mis-parse signature — now
**pitfall 31**, which carries the detection rule (`_MOD` numbering starting
below 5) and the known false positives.

| Check | Result |
|---|---|
| Scene vs vanilla | diff is exactly the four transformless marker headers; `Marker3D4_MOD2` absent from the deployed pck (`grep -a`), `Marker3D_MOD5` present |
| 8-player pinned run (`START=1`, 130s) | `[STATIONS] player_count=8` + `cloned 7 single nodes` on host and all 7 clients ×3 rounds, `[SHOTGUN]` slots 0-7 at 45° steps ×2 sweeps, zero parse/script errors, `v1.5.0-8P-v1.1` on all peers |
| 4-player parity | `[STATIONS] player_count=4`, no cloning lines on any peer, zero parse/script errors |
| Error classes (pitfall-12 filter) | identical three documented families at 4 and at 8; `comm -13` empty |
| Eyes | the 5-8 spectate view itself is unwatched — low risk (the point is vanilla's own), but only a look closes it |

Public tracker: **issue #7** (the shipped v1.0/v1.1 zips carry the bug; the
fix ships with the next release). `MINIGAMES.md` §10 documents the scene's
markers; the overlay manifest row updated.

### 2026-08-13 — Playlist cap filter counted demoted spectators; a 9th connection dead-ended the session

An external audit finding, confirmed by reproduction and fixed the same day.
`generate_session_playlist()` sized its cap filter from
`connected_players.size()`, which **includes demoted debug spectators** — a
joiner past the cap re-enters through `set_as_debug_rpc` and is stored (the
backends' own comments assert it, and today's run confirmed it). At 9 entries,
`supports_player_count()` — every cap defaults to 8 — rejected every minigame
in all three playlist branches **and** in the empty-list fallback, which
re-filters with the same size. `session_minigame_list` came out empty and the
session dead-ended silently before its first minigame: the pick site's
out-of-bounds read is pitfall 23's silent-null case, so **no error line ever
prints**.

**Reachability, measured rather than assumed:** the ENet backend's
`create_server(SERVER_PORT)` sets no client cap (engine default 32), so any
9th direct-connect joiner triggers it — 8 seated + the 9th demoted to
spectator, no mixed lobby or `-trailer` needed. Steam lobbies are created at
`max_player_count` (8), so over Steam it needs `-trailer` (max 9); the audit's
mixed-lobby path (4 players + 5 demoted modded joiners = 9) is therefore
ENet-only too. A vanilla host is unaffected — the filter is mod code.

**Fix** (`game.gd`, `generate_session_playlist()` only): `lobby_size` now
counts the non-debug entries of `connected_players`, matching how the rest of
the game already treats debug peers as non-playing (they skip `client_loaded`,
send `player_ready` immediately, and never enter `player_presences`). Chosen
over clamping to `MAX_PLAYERS`, which would keep counting spectators toward
the caps and misfilter any future cap set below 8.

| Check | Result |
|---|---|
| Repro before fix (9-slot `START=1`, 8 modded + 9th demoted) | `[AUTOSTART] reached 9`, seat map full at 8; **zero** `Generating session playlist with:` lines (a normal 8-run prints 15); one state transition (`SessionStart → SessionIntro`) then nothing for 150s; zero error lines |
| After fix, same 9-slot run | **15-entry playlist at connected=9**, session cycled `MinigameStart ↔ MinigamePlaying` through three minigames on host, clients **and** the spectator peer; only documented benign error families |
| 8-slot regression | 15 entries, normal session, no new error classes |
| 4-slot parity | 15 entries, normal session, benign families only — at ≤4 no debug entries exist, so `lobby_size` is unchanged by the fix |

Public tracker: **issue #6** (the shipped v1.0/v1.1 zips carry the bug; the
fix ships with the next release). `MINIGAMES.md` §3 updated to describe the
non-debug count.


### 2026-08-09 — Vanilla-compat mode: mixed lobbies with unmodded clients, verified locally; shipped as v1.1 (Experimental)

Players who keep the mod installed can now host or join ordinary ≤4-player
lobbies containing UNMODDED v1.5.0 clients. Requested by the maintainer, built
and verified this day against a "quasi-vanilla" test peer (see Testing). The
shipped release is still v1.0; this tree carries `v1.5.0-8P-v1.1` and ships as
v1.1 only after a real-Steam mixed session confirms the Steam backend path.

**The engine fact the whole feature rests on** (verified against Godot 4.5
source, `scene_rpc_interface.cpp`): RPC wire ids are assigned from the
script chain's @rpc method names sorted alphabetically. The mod's 8 added
RPCs were named `mod_*`, which sorts before most vanilla names and silently
renumbered vanilla's RPCs relative to an unmodded build — misrouted RPCs in
any mixed lobby, at any roster size. Now pitfall 30.

**Changes** (all uncommitted until this entry lands with them):

- The 8 mod RPCs renamed with a `zz_` prefix so they sort after every vanilla
  RPC in their inheritance chains (`zz_mod_set_room_rpc`, `zz_mod_build_rooms_rpc`,
  `zz_mod_place_item_rpc`, `zz_mod_add_stations_rpc`, `zz_mod_clear_role_overlay_rpc`,
  `zz_mod_add_delivery_areas_rpc`, `zz_mod_apply_eight_seat_layout_rpc`,
  `zz_mod_raise_item_preview_rpc`). Nothing in vanilla begins with "zz"; the
  latest-sorting vanilla name in any affected chain is `update_timers_rpc`.
- Burn & Recycle's three formerly-unconditional mod RPC dispatches gated to
  roster > 4 so no mod RPC ever crosses the wire at ≤4. Two were provable
  no-ops at ≤4; the third (`zz_mod_place_item_rpc`) carries vanilla's
  incinerator spark-ramp tail for >4 rosters, so its gate branches: >4
  dispatches unchanged, ≤4 runs vanilla's original tail verbatim host-side —
  which also closes an undocumented ≤4 parity deviation (the old code ramped
  spark_ratio on every peer where vanilla ramps host-only). See §21.
- NEW overlays `modules/multiplayer/backends/steam_backend.gd` and
  `enet_backend.gd` (wire-identical @rpc sets, bodies only): self_data now
  reports `MOD_NETWORK_GAME_VERSION` ("v1.5.0", vanilla's exact string) plus a
  `mod8p` capability key vanilla provably ignores and rebroadcasts; the host
  accepts vanilla peers, refuses a differing `mod8p` (and old mod v1.0, which
  still reports the concatenated string), REFUSES a vanilla joiner that would
  push the roster past 4 (an unmodded build cannot render or spectate a 5-8
  player session), and demotes an over-cap modded joiner through vanilla's own
  debug-spectator path with the cap dropping to 4 whenever any vanilla peer is
  present.
- `network_manager.gd`: `mod_all_peers_modded()` helper (host's own self_data
  is in `connected_players` in both backends, so the scan needs no local-peer
  special case).
- `globals.gd`: the version split (`game_version` stays the display string;
  `MOD_NETWORK_GAME_VERSION` and `MOD_SUFFIX` are the wire fields — step 6 now
  covers all of them), and `CutsceneTest` RESTORED to `default_playlist` in its
  vanilla slot. The user-sanctioned cutscene removal moved to
  `generate_session_playlist()` in `game.gd`, applied only when
  `mod_all_peers_modded()` — a lobby containing a vanilla peer gets the exact
  vanilla rotation, cutscene included. The first sanctioned exception is
  rewritten accordingly. Couch mode has its own generator, so
  `scenes/local_game/script/local_game.gd` is now overlaid with the
  unconditional filter (a local session has no vanilla peers by definition).
- Test infrastructure: `tools/quasivanilla/` (a 4-file vanilla-plus-harness-
  hooks overlay, build script, and `qv.pck`; wire-identical to vanilla —
  reports "v1.5.0", no mod8p), `testgame2/` (gitignored) carrying it, and
  `tools/localtest.sh` gained `VANILLA_DIR`/`VANILLA_SLOTS` for mixed launches.
  See Testing for the mixed-run recipe and its traps.

**Verification** (all runs START=1 on the v1.1 build, md5 `3fbdbe03…`):

| Check | Result |
|---|---|
| All-modded regression baseline | 10/10 runs: BurnRecycle 8p+4p, Chisel, GreenPea, ManufactureGun 8p+4p, Forklift, DuckHunt start, full rotation 8p+4p — every documented trace on host and clients, zero new error classes, zero `zz_mod` wire errors |
| Mixed gameplay, modded host | BurnRecycle at 4 (2 modded + 2 quasi-vanilla): 2 full rounds with eliminations, no `[FILTER8] rooms` (mod RPCs off the wire), zero RPC errors |
| Mixed gameplay, vanilla host | quasi-vanilla host + 3 modded: 240s across two minigames, zero crashes |
| Vanilla joiner over cap | Controlled-order test (4 modded seated first): quasi 5th refused, `_on_join_refused with reason: 1` client-side, roster pinned at 4 |
| Modded joiner over mixed cap | Demoted silently via vanilla's spectator path — sessions ran `connected=5`, `players=4` |
| Cutscene filter, all-modded | `-original` at 8 and at 4: 15-entry playlist, CutsceneTest absent |
| Cutscene filter, mixed | `-original` mixed: 16-entry playlist, CutsceneTest present in its vanilla slot; the scene loaded and synchronized on all four peers |
| Handshake versions | quasi peers boot `v1.5.0`, modded boot `v1.5.0-8P-v1.1`, zero VersionMismatch in any accepted-join run |

**Findings, each measured rather than assumed:**

- `The rpc node checksum failed` appears once per mod-scripted node per vanilla
  peer in mixed sessions. Verified print-only in engine source
  (`scene_cache_interface.cpp`: the cache entry is stored and confirmed
  regardless), and gameplay was clean in every mixed run. Accepted as a
  documented mixed-session artifact rather than refactoring seven verified
  minigames onto RPC-hub nodes; see Testing.
- Two early "cap failed" results were a JOIN-ORDER RACE in the harness, not a
  code defect: launch order does not control handshake arrival order, so the
  quasi peer slipped in 4th (correctly admitted) and the modded last-arriver
  took the silent demotion. Cap tests need controlled ordering — idle lobby
  first, overflow joiner launched after `connected=4`; recipe in Testing.
- The wheat-field cutscene CANNOT complete unattended, by construction: its
  fallback Timer is dead code (`wait_time = 100000`, handler begins with
  `return`) and reaching `Finished` requires a player walking to the house
  (`Input.get_axis` drives movement). 3/3 unattended mixed runs stalled at
  `PlayerMarker → Play` on all peers identically; the two runs that completed
  coincided with the maintainer actively using the desktop (focused window
  catching input). Real sessions complete it by playing. Same unattended-
  harness class as Duck Hunt.
- The Minefield `curve.cpp` out-of-bounds error (24× per peer) reproduces in a
  PURE quasi-vanilla session with zero modded peers — a vanilla-under-localtest
  artifact never observable before (vanilla clients could not localtest), not a
  compat defect.
- A `Node not found: Game/Minigame/<scene>` burst on clients at each round
  load appears in mixed runs before successful and stalled rounds alike —
  same replication-churn family as the documented teardown noise.

**Open:** the Steam backend path (identical logic, kept symmetric with ENet,
reviewed — but its lobby callbacks cannot run locally). One real Steam session
with an unmodded player closes it: join both directions, the 5th-join refusal
message, and the cutscene in rotation. Until then v1.1 stays unreleased.

#### Same day: shipped as mod release v1.1, marked Experimental

At the maintainer's direction, superseding the hold-for-Steam plan one
paragraph up: v1.1 ships **now**, as a GitHub **prerelease** flagged
Experimental, with the release notes warning it may be broken and pointing at
the vanilla-compat feature. The Steam-session check (open item 3a) stays open;
it is what de-flags the release rather than what gates it.

Release integrity, re-measured this day on `testgame/` refreshed from the
clean copy:

| | |
|---|---|
| Installer round-trip | `NOT PATCHED` → install (4174 files, **56 mod, 94 replaced**) → `PATCHED - all 56 mod files present` + `v1.5.0-8P-v1.1` → `--uninstall` → **`f5912732…`, byte-identical** |
| Headless boot on the patched copy | `Running version: v1.5.0-8P-v1.1`, zero script errors |
| Zip | rebuilt per step 8: **60 entries** (57 → 60 with the three new overlay files), extracted `mod/` `diff -rq` clean against source, all four root files byte-identical. First build md5 `a5e693b2…`; rebuilt the same day with corrected user-facing text (README.md still claimed v1.0 and "every player needs the mod" — caught by the maintainer; `installer/README.txt` and `install.py`'s post-install message carried the same claim into the zip), final md5 **`fdd679cedce61306a2ac209ee98d927b`**, Release asset replaced to match |
| Non-interactive installs | `install.py --force` exists and works — supersedes the `echo y \|` workaround noted on 2026-08-08 |

Tagged `v1.1`, `gh release create --prerelease` with the zip attached. The
patched `.pck` never leaves this machine; the zip is the only asset.

### 2026-08-08 — GitHub release prep: root-installable restructure, personal-info scrub, repo staged but not published

Prepared the project for a public GitHub release. **No gameplay code changed**
— the overlay's 53 files are byte-identical to the morning's; only packaging,
paths and docs moved.

**Restructure.** `install.py` / `install.sh` / `install.bat` moved from
`installer/` to the project root, and `installer/` (with its `installer/mod`
duplicate, `diff -rq`-verified byte-identical first) deleted — `install.py`
resolves the overlay as `HERE/mod`, so the root `mod/` now serves directly and
the step-8 re-sync step is gone. Both wrapper scripts were already
self-locating; no edits needed. A git clone or GitHub source download is now
installable as-is. `tools/localtest.sh`'s default game-dir no longer hardcodes
this machine's home path (derived from the script's own location instead; same
value at runtime here).

**Round-trip re-verified after the move**, on `testgame/` refreshed from the
clean copy: `NOT PATCHED` → install (4177 files, 53 mod, 88 replaced) →
`PATCHED` + `v1.5.0-8P-v1.0` → `--uninstall` → **`f5912732…`, 635,333,716
bytes, byte-identical**. One operational note: `install.py`'s `Proceed? [y/N]`
prompt has no non-interactive flag, so scripted runs need `echo y |`.

**`README.txt` was badly stale and is rewritten.** The shipped zip's copy still
said "Built for v1.0.7", showed `v1.0.7-8P` as the verify string, and claimed
Firearm Factory, The Filter and Forklift Certified are skipped above 4 players
— all three uncapped days ago. It now matches `README.md`'s facts (all fifteen
at 8, current rough edges, Arcade caveat, Inside Job's ≥6-player threshold per
§17). The version label therefore lives in **three** places, not two:
`globals.gd`, `install.py --verify`, and `README.txt` — step 6 updated.

**Zip rebuilt** from the five root items (57 entries; extracted `mod/`
`diff -rq` clean against source, all four root files byte-identical, same file
names as the previous zip). Exact build command now in step 8 — there is no
`zip` binary on this machine; it is built with Python's `zipfile`.

**Personal-info scrub of everything that will ship**, after a full sweep (no
emails, Steam IDs, secrets or third-party names existed anywhere): `/home/adam`
→ `~` throughout the docs, the maintainer's name removed, the screenshot
anecdote generalized (rule and rationale intact), and the layout-viewer URL
moved to `NOTES-LOCAL.md` (untracked). Pre-edit docs snapshotted to
`docs_old_2026-08-08-prerelease/`.

**New release files:** `.gitignore` (blocks all decompiles, game copies,
`dist/`, `*.pck`, `userdata_backup/`, `tools/bin/`, local notes), `NOTICE.md`
(provenance: game code © the developer, published with permission —
**placeholders unfilled**), `LICENSE-MIT` (mod-original files only),
`DEV-PERMISSION-DRAFT.md` (untracked draft message to the developer).

**Pushed to a PRIVATE GitHub repo the same day:**
`https://github.com/Binary1936/machine-party-8p`, commit `e6e03d0` on `main`,
73 files / 47M. Commit identity is the GitHub noreply address
(`56046426+Binary1936@users.noreply.github.com`) so the personal email never
enters commit history; the maintainer approved keeping the Claude co-author
line. A remote-side tree audit confirmed zero game-content or personal files
made it up. **One gate before the repo goes public, the maintainer's call per
this session's explicit decision:** the developer's written OK to publish
modified *decompiled sources* — a bigger ask than modding
(`DEV-PERMISSION-DRAFT.md`, untracked, is the ask). The zip is already
attached to Release `v1.0` (asset md5 `94f53df456eb11d0b587f257066b3b39`,
verified by re-download; the zip never goes in git, and the patched `.pck`
never leaves this machine), so when the OK lands only two steps remain: fill
`NOTICE.md`'s two placeholders and flip the repo public — the Release goes
public with it.

#### Same day, after the push: installer moved into `installer/` (no mod copy)

Requested by the maintainer to clean up the repo root: `install.py`,
`install.sh`, `install.bat` and `README.txt` moved from the root into
`installer/`, and `install.py` gained a three-line fallback — if no `mod/`
sits beside it, it uses `../mod`, so a repo clone installs via
`installer/install.py` against the root overlay with **no duplicate copy of
`mod/` anywhere**. The zip build (step 8) now pulls the four files out of
`installer/` but still places them at the **zip root**, so the shipped
bundle's structure is unchanged and the fallback is inert there. Verified by
full installer round-trips from **both** layouts — the repo clone (fallback
path) and a freshly extracted zip (primary path) — each reading
`NOT PATCHED` → 4177/53/88 → `PATCHED v1.5.0-8P-v1.0` → uninstall
byte-identical (`f5912732…`). Rebuilt zip: same 57 entry names, md5
`0776a4c2ca7988d0948ec4f6a30f4ec8`. **The v1.0 Release asset was deliberately
left as released** — it differs from the rebuilt zip only by the inert
fallback lines in `install.py` and behaves identically; the next release
picks up the new copy.

#### Same day: the process docs caught up with version control

Being in git invalidated assumptions written when there was none. Changed, at
the maintainer's request: documentation-policy rule 4 is now **commit** before
restructuring (the `*_old` idiom survives only for untracked material); rule 3
records that git history is a backstop while the archive stays the reading
surface; the "only copy" claims in the archive header and the "Older entries"
intro corrected; a new **"Version control"** section (commit discipline,
subagents-never-commit, game-content-never-committed, public-facing-docs
scrub rule, noreply identity, `git show <tag>:mod/<file>` replacing future
`mod_vXXX/` snapshots, and the commit→tag→Release flow now referenced from
step 8); `CLAUDE.md` carries a three-rule entry-point copy. The two
orchestrator prompts in `~/Documents/Claude` and the project memory gained
matching lines. **Explicitly unchanged:** update-procedure steps 1-5 — the
decompiles and extractions are untracked, so the `filecmp` sweep and the
`mv project project_old` mechanics stand exactly as written.

Two conditions added the same day at the maintainer's request, now in the
Version-control rules and every entry-point copy: **no commit before the
change is verified to achieve its purpose** (where only eyes can verify, that
means after the maintainer has looked), and **no push without a human
check-in** — present the commits and their evidence, wait for the OK, batch
the ask at a natural stopping point.

#### Same day: NOTICE rewritten and the repo made public

At the maintainer's direction, superseding the earlier hold-for-approval
plan: `NOTICE.md` rewritten to full credit (Mike Klubnika and GDeavid,
published by Oro Interactive), the "small modifications to seat eight
players" framing, and an **unconditional takedown promise** — on any request
from the developers, the repository and every file in it comes down. It
deliberately makes no claim of granted permission. The repo was then flipped
**public** (Release v1.0 and its zip became publicly downloadable with it).
The permission ask to the developers (`DEV-PERMISSION-DRAFT.md`, untracked)
remains worth sending; the takedown promise is the standing safety net either
way.

#### 2026-08-09: issue tracker seeded

Per the new issue convention, the documented public-worthy known issues became
GitHub issues: **#2** the spawn-pair shove (the open `OFFSET` decision under
open item 0 — that item remains the engineering record), **#3** Smoke Break's
accepted seat clipping (§14), **#4** Arcade never run (testers wanted), **#5**
the Steam lobby's 8 previews never seen live (testers wanted — open item 3).
The maintainer had already filed **#1** (first-load parse cost of shipping
plain `.gd`, backburner). Chisel Gauntlet was also re-playtested at 8 this day
on the freshly patched throwaway — three rounds, all traces at documented
values, no new error classes; a re-confirmation, not a change.

### 2026-08-08 — v1 release audit: docs reconciled, release integrity re-verified, `OFFSET` analysis prepared

A documentation and release-readiness pass. **No mod code changed in it** — the
artifacts in `dist/` were re-proved, not rebuilt.

**Docs.** Three read-only docs-vs-code reviews swept the whole set; the fixes
landed in `UPDATING.md`, `MINIGAMES.md` and `CLAUDE.md`. Stale 50-file overlay
counts → **53**. `MINIGAMES.md`'s capped-minigames table rewritten as a
historical record of every entry it ever held, since nothing in the rotation is
capped any more. A wrong citation in the briefing-screen section (**pitfall 13 →
23** — an out-of-bounds *method call* is 23's SIGSEGV case, not 13's spawn-loop
abort). The `CutsceneTest` vanilla-vs-modded contradiction in "Current status".
§19 given the `debug_skip_brief` reveal-skip summary the overlay manifest had
been pointing at with nothing there. "Validation recipe" renamed **"Testing —
the validation recipe"**, so the many *see Testing* references resolve to a real
heading. `green_pea_chairs.py` marked **legacy** — re-running it would rewrite
the shipped chair transforms and break 1-4 parity. Dated playlist-count
snapshots marked as snapshots and superseded. The 2026-08-05 Duck Hunt entry
moved **verbatim** to `SESSION-LOG-ARCHIVE.md`: the first post-2026-08-03 move,
and the one that sets the stub convention — heading stays here, body names the
section that now owns the material. `README.md` rewritten to the release
standard, **506 → 217 lines**; `UPDATING.md` and `MINIGAMES.md` remain
authoritative. Pre-restructure copies in `docs_old_2026-08-08/`.

**Release integrity, all re-measured this day:**

| | |
|---|---|
| Reproducible build | `tools/build.py` output **byte-identical** to the shipped `dist` pck (`156f99e3…`) |
| Installer round-trip | `NOT PATCHED` → 4177 files (53 mod, 88 replaced) → `PATCHED` + `v1.5.0-8P` → uninstall **byte-identical** (`f5912732…`) |
| Patched pck carries the source | `MOD_WALL_DESK_PUSH` and `zz_mod_raise_item_preview_rpc` grep out of it |
| Headless boot | `v1.5.0-8P`, zero script errors |

**Harness spot-checks on the freshly built pck.** Firearm Factory at 8 matched
the documented traces exactly — spawns, desks, ingredients and the preview raise
on all eight peers — and at 4 was fully vanilla (no `[GUN8] expand` line at all,
`per_marker=1 total=26`). Tunnel Hazard at 8 read `markers=8 nooks=8 spawned=8`
on every peer, with **one new observation**: 8 of 192 audit lines read
`DISPLACED`, all of them `TrainRacePlayer5` on `Marker3D3_MOD7` — one of the two
`inward` clones — at 2.31-3.50u, at the **middle snapshot only**, back to `OK` by
the third, with the spawn-time snapshot clean on all peers. Consistent with the
train shoving the player nearest its centreline mid-run, not with a spawn
regression. Recorded because it bears on the `OFFSET` decision.

**Playlist re-measured at 8.** Both branches — the default debug lobby and
`ARGS="-original"` — now generate the **identical 15-entry list**, `CutsceneTest`
absent, so the branch difference no longer shows up in the entry count and the
`[ORIGINAL]` line is the only confirmation of which ran. Duck Hunt sits **5th**,
not 4th; every claim that depended on that is corrected in place.

**Error classes: the documented families, plus one that was not documented.**
`Parameter "node" is null`, paired with a filtered `Node not found` from
`scene_cache_interface.cpp`, at teardown. Measured at **both** roster sizes — 3
lines at 4 players, 7-21 at 8 — so per pitfall 12 it is not player-count-related.
No filter entry added.

**Prepared, not decided:** the `OFFSET` analysis under open item 0, including two
clone sites that *compute* as sitting inside geometry at the current 1.2. It is
static geometry throughout, unconfirmed by eye, and waiting on the user.

**Still open:** the `OFFSET` / `inward` decision, and open items 1 and 3 — both
structural.

#### Shipped as mod release v1.0 (same day, after the above)

The mod now carries its **own** release label as well as the game's:
`game_version` is `"v1.5.0-8P-v1.0"` (`mod/autoloads/globals.gd`), and
`installer/install.py`'s `--verify` message was updated to match — it hardcodes
the display string, so it is the **second place the label lives** and the one
that goes stale silently. See step 6.

That relabel changed a shipped file, so everything above it was re-proved:

| | |
|---|---|
| Reproducible build | `dist/Machine Party.pck` rebuilt, md5 **`05a89df515752f78eeabc9afc1f66b4c`**, byte-identical across three builds. **This supersedes the `156f99e3…` quoted above** — that was the pre-relabel artifact; two md5s in one entry is the version string changing, not a contradiction |
| Installer round-trip | re-run end to end on the clean copy: 4177 files (53 mod, 88 replaced), `PATCHED` naming **`v1.5.0-8P-v1.0`**, uninstall **byte-identical** (`f5912732…`) |
| Zip | re-synced from `mod/`, carries the new string |
| Handshake | 8-client run: all 8 peers booted `v1.5.0-8P-v1.0`, seats distinct, **no `VersionMismatch`** |

**Not done, and left with the user:** deleting `project_v106/`,
`extracted_v106/` and `mod_v106_ref/` was approved this day, but this
environment's sandbox refused the bulk delete again (the same refusal recorded
during the v1.5.0 rebuild). The command was handed over instead, so Layout's
"safe to delete" note stands until it is actually run.

### 2026-08-08 — Firearm Factory's wall desks pushed to the wall

Closes the last item left open when Firearm Factory was uncapped: the two turned
mid-edge desks sat 2.80u (`MOD5`) and 2.71u (`MOD7`) short of the wall behind them,
each inheriting a slightly different yaw from its nearest shipped marker.
`MOD_WALL_DESK_PUSH`
(2.05u) now pushes them out along the wall normal after the turn and the slide, to
0.75u (`MOD5`) and 0.66u (`MOD7`) — matched to the 0.73u the shipped `Marker3D2`
desk leaves against the −X wall, so they sit as close as vanilla ever puts a desk.
Full measurement in **`MINIGAMES.md` §22**.

**The binding constraint was not the wall.** It is a rotated crate collider on the
+Z side, and it is only passable because it is *rotated*: its AABB (x[−9.96,
−3.68] z[9.65, 15.77]) appears to overlap `MOD7`'s x span and forbid the push,
while its true inner edge crosses into the room only at x < −4.15, clear of the
desk's nearest corner at x = −4.00. **An AABB test says "impossible" here.** A
proper rotated-rectangle (SAT) test against every collider and wall prop is what
produced the number, and it also set it: at 2.40 the crate gap falls to 0.49u.

Two other things came out of the measurement, both recorded in §22:

- **The wall position cannot be found by a vertex scan.** The ±Z wall inner faces
  are at |z| = 11.99, but the walls are a few large triangles, so vertices exist
  at only four x positions and every bin between them reads as empty floor. Filter
  triangles by Z-dominated normal instead.
- **The workstation is reachable from all four sides.** The player's interact area
  is a radius-1.0 cylinder projected 1.0u ahead of them, and the desk's interact
  box is inset from its own solid collider, so the overlap always comes from that
  projection and fires from any face with margin. This **qualifies** pitfall 29:
  the approach axis decides how a desk reads and how much floor a player has, not
  whether the interaction works. The turn is still right; the mechanism sentence
  in §22 described authored intent, not a hard constraint.

**Verified**, `START=1 MINIGAME=ManufactureGun`, 8 clients then 4:

| Check | Result |
|---|---|
| Boot | `Running version: v1.5.0-8P`, no parse errors |
| `%` pre-flight | 0 bad specifiers across all 37 overlay scripts |
| Desks at 8 | `spawns=8 (+4) desks=8 (+4) closest_spawn_pair=5.23`, and `added=` prints `MOD5@(5.48,-9.93)/86deg … MOD7@(-2.02,10.00)/-86deg` — landing within 0.01u of the predicted positions |
| Reached `Play` at 8 | yes, two full rounds (`Countdown → Play → Finish → Countdown → Play`) |
| Ingredients at 8 | `markers=26 per_marker=2 total=52` |
| **4-player parity** | **no `[GUN8] expand` line at all** — the roster gate returns before any marker is touched — and `per_marker=1 total=26`, the vanilla count |
| Error classes | the documented families only; nothing new |

**The 4-vs-8 error diff shows three classes at 8 and not at 4, and that is *not* a
finding.** `ERR_UNAUTHORIZED` (68 lines over 8 peers and 2 rounds), the node-cache
miss and `data.tree is null` are all documented, and the 2026-08-05 entry below
records this exact class being wrongly called player-count-specific off exactly
this evidence — a single pinned-minigame `START=1` pair at each size. A matched
`FLOW=1` pair showed it at both sizes. Not re-litigated here; not filtered either.

**What is still not verified is the part only eyes can do**, and it is the same
list the wall gap was on until today: whether the turned desks' working faces
point the intended way, and whether the doubled ingredients overhang their
surfaces. `MOD_WALL_DESK_PUSH` itself also wants a look — the trace proves the
desks are where the constant asks, which is precisely what the trace could prove
about the *old* placement too.

#### Then the user looked, and it held — plus two more defects a trace cannot see

**"The new desk positions look good."** The same look turned up the two remaining
problems, and **both had been sitting in the open-items list as unverifiable by
trace, which is exactly where they were found.** Neither is a regression; both are
original 2026-08-07 uncapping defects.

**1. The doubled ingredients were interpenetrating.** `MOD_ITEM_SPREAD` was 0.45u
and the five item variations are **0.629 to 1.614u wide** — measured off
`manufacture_gun_item.tscn` — so every doubled pair was inside itself whichever two
variations were drawn. Raised to **1.10**, which is `(w1 + w2) / 2` for the average
pair. Checked against the surface under each of the 26 markers rather than guessed:
11 are on the floor, 2 on the +Z trolley, 13 on desks, and ten of those 13 have
≥ 1.10u of desk left in the offset direction. The three that do not include
`part_011`, where the **shipped** single item already overhangs its desk edge by
0.42u. Two flat discs is still the worst case and still touches; closing that needs
1.61 and overhangs four markers.

Also settled while measuring it: **the nudge must stay in world space.** 25 of the
26 item markers are rotated and `part_001` is laid on its side (its basis Y column
is world −Z), so the `spawn_expand.py` local-X approach would bury a copy under the
table — pitfall 17, in a scene nobody had checked for it. `spawn_items()` discards
marker rotation anyway.

**2. `MOD8`'s desk was covering the ingredient projection.** The five-slot recipe
hologram is **one node in the level**, not a per-player HUD, and the added
bottom-centre desk overlaps it on all three axes — burying the middle three slots,
with the item holograms showing through the desk. The user ruled out moving the desk
(it would change the arena's balance) and asked to try raising the projection by its
own height.

Done, and the height is **measured at runtime, not baked**: 1.8741u, which agrees
with the static computation off the `.tscn` to 0.0013u. Two traps in it, both
already in the pitfalls list:

- the measurement uses `mesh.get_aabb()` through each node's `global_transform`,
  **not** `get_transformed_aabb()` — pitfall 18, which returns null in the release
  template and aborts the calling function with no error line;
- the node that moves is the **parent** of the exported one, because each of the
  five `recipe item parentN` children has an AnimationPlayer driving its own
  `.:position` and `.:rotation`, so anything at or below `Visual` would be fought
  over every frame.

**Verified** (re-run at 8, then 4):

| Check | Result |
|---|---|
| Preview raise at 8 | `raised by 1.8741 … now y=2.495..4.369` on **all 8 peers**, exactly one `is_server=true` |
| Clear of the desk | desk top is y 2.14; hologram underside now 2.495 |
| Items at 8 | `per_marker=2 total=52`, unchanged count — only the offset grew |
| **Raise at 4 players** | **does not run at all** — no `[GUN8] preview` line on any peer |
| Items at 4 | `per_marker=1 total=26`, the vanilla count |
| Parse / script errors | none at either roster |

**Confirmed by the user the same day: "Both fixes worked. It looks good to go."**
The raise was proposed as an experiment and it survived the look, so it stays as
written — raise by exactly the measured height, no added clearance. The 0.026u gap
to a workstation's gun-assembly height (`MINIGAMES.md` §22) was not a problem in
practice; it is recorded because it is thin enough that a change to either number
could make it one.

**And the facing question closed with it: "the desks are facing the right way."**
`MOD_WALL_DESK_TURN_DEG`'s sign is correct, which was the last thing on this
minigame no trace could settle — open since the 2026-08-07 uncapping.

#### The Filter verified by eye the same day

The user also confirmed **The Filter (`BurnRecycle`)** at 8 on 2026-08-08, with
nothing reported wrong. That closes the "measured but never observed" category
outright: **all fifteen rotation minigames have now been both measured at 8 and
watched at 8 by a person.** Its two-room layout, per-room elimination and global
scoring were already measured per peer on 2026-08-07 — see that entry's table — so
this adds the one kind of evidence those numbers could not supply, and it needed no
code change.

**It does not touch open item 1.** Watched is not played; the harness still runs
unattended instances everywhere, so scoring and win conditions at 8 still rest on
idle behaviour. That gap is structural and needs bots or input injection.

#### Shipped

Step 8 of the update procedure, on the same day rather than left for the next
session, since the overlay is what the installer carries:

| | |
|---|---|
| `installer/mod` | re-synced from `mod/`; `diff -rq` clean, 53 files |
| `ADDED_FILES` | unchanged — still exactly `mod_player_name_list.gd`, the only file the mod adds |
| `dist/machine-party-8p-mod.zip` | rebuilt, 127 entries, 53 mod files, carries today's `manufacture_gun.gd` |
| Round-trip on the clean v1.5.0 copy | `NOT PATCHED` → 4177 files (53 mod, **88** originals replaced) → `PATCHED` + `v1.5.0-8P` → `--uninstall` → **`f5912732…`, 635,333,716 bytes, byte-identical** |
| Today's changes present in the installed pck | `MOD_WALL_DESK_PUSH`, `zz_mod_raise_item_preview_rpc` and `MOD_ITEM_SPREAD: float = 1.10` all grep out of the patched `.pck` — the mod ships plain `.gd`, so this is a direct check that the artifact carries the source, not just that the installer ran |

**88 originals replaced, where the 2026-08-05 entry recorded 82.** That is not a
regression: the overlay grew 50 → 53 files when The Filter and Firearm Factory were
uncapped, and each added `.gd` displaces its `.remap` and `.gdc` siblings. Expect
this number to track the overlay size, and re-derive it rather than treating the
older figure as the expected value.

**This project is not under version control**, so "pushed" means exactly the table
above: the overlay, the installer bundle and the zip in `dist/` are the artifacts,
and `SESSION-LOG-ARCHIVE.md` plus this file are the only history. Nothing else to
push.

### 2026-08-07 — Firearm Factory uncapped: NOTHING is capped any more

Full write-up in **`MINIGAMES.md` §22**. The last capped minigame, and the last
entry in `modded_minigame_player_cap` that pointed at anything in the rotation -
only `ScavangerChairs` remains, which is in neither playlist.

**Four blockers, three of them silent, one of them a crash.** `$SpawnPositions`
and `$WorkstationSpawns` each ship 4 markers, and the null read past index 3
aborts the host's spawn loop - at 8 players the minigame never reached `Round`.
Behind that sat `empty_desk_array[i].queue_free()`, a **method call** past the end
of a 4-element array, which is the pitfall-23 case that **SIGSEGVs** rather than
failing quietly; it had never been seen because the spawn abort happened first.
Expanded in place rather than split into rooms - the arena has 15.1u between
workstations, and it is a PvP arena where splitting would halve the opponent pool.

**A rule that looked principled and was exactly backwards.** Two added desks land
against a wall facing into it. Which two is decided by the interact box -
`BoxShape3D(2, 5, 3.6)`, approach along the 3.6-deep local Z - not by which wall
is nearest. The first attempt tested wall proximity, and selected the **exact
complement**: it turned the two desks that were already correct and left the two
broken ones alone. Every measurement passed either way.

**And a lesson about talking about geometry at all.** The camera is not
axis-aligned - it sits at `(-17.9, 11.9, 0)` looking along `+X` with its right
axis on world `+Z`, so on screen **right = +Z, up = +X**. Desks turned in world
±X appear at top- and bottom-centre. Two rounds were lost to "the left one"
meaning different things to each of us. **State the screen/world mapping before
discussing any position**; a top-down diagram settled in one pass what prose had
not in two.

**Ingredients now scale with the roster** - `spawn_items()` spawned a fixed 26
whatever the player count, halving everyone's share of the gun components at 8.
Now 1 per marker at 1-4 and 2 at 5-8. Copy 0 is exactly where vanilla puts it, so
1-4 is unchanged, and extras are nudged sideways rather than stacked because a
`ManufactureGunItem` is a plain Node3D with no physics.

**Verified** at 4 and 8: reaches `Play` at both, `spawns=8 (+4) desks=8 (+4)
closest_spawn_pair=5.23`, `items ... per_marker=2 total=52` at 8 and
`per_marker=1 total=26` at 4, and the same single error class at both - so
nothing new appears at 8. **Not verified by eye:** how close the turned desks sit
to the wall (the user asked for closer and it is deliberately left), the working
face direction, and whether the nudged ingredients overhang. See "Open items".

### 2026-08-07 — The Filter uncapped to 8, as two rooms

Full write-up in **`MINIGAMES.md` §21**; this entry is the evidence and the
process lessons.

**Uncapped by splitting, not by cramming.** The first attempt cloned the four
stations 45 degrees round the same ring. Every measurement passed —
`belts=8 presses=8 indicators=8` on all eight peers, zero errors — and a
screenshot showed the consoles interpenetrating. Two rooms of four keeps the
shipped 90-degree spacing, so nothing clips **and** the four authored camera
clips stay exact; the 45-degree version needed seven relative directions mapped
onto four clips, which is unfixable without authoring animations the mod cannot
ship. It costs no new replication surface: still one script, one StateMachine,
one MinigameOverlay, one MultiplayerSpawner.

**Verified** (host and all clients, every roster):

| Check | Result |
|---|---|
| Elimination at 8 | `victims=2` × 3 rounds → `[r0=1, r1=1]`, 6 dead, 2 survivors |
| Elimination at 5 (3+2) | `victims=2` then `victims=1` — the lone-room case cannot win by default |
| Elimination at 7 (4+3) | `victims=2, 2, 1` |
| Elimination at 4 | room B never built, `victims=1` × 3 — **vanilla** |
| Scores | `[1,1,3,3,5,5,8,8]` at 8, `[1,1,2,5,5]` at 5, `[0,1,2,4]` at 4 (vanilla) |
| Errors | only the three documented families |

**Three silent bugs, none of which a log would have shown**, all in
`MINIGAMES.md` §21: duplicating `player spawn parent` (which holds four
instances of the *player scene*) put four ghost rigs in room B and cost 256
errors a run; `zz_mod_set_room_rpc` declared `@rpc("authority")` was rejected
quietly, leaving all eight players stacked two-per-station; and `launch_rpc`
never sets position, so room B's tossed pictures spawned in room A.

**The process lesson, which is the durable part.** The ghost-rig errors were
first written off as pre-existing teardown churn, on arithmetic that fitted
(`8 peers × 8 players × 2 IK nodes = 128`) and a grep for `type="Skeleton3D"`
that returned zero. Both were wrong — **the grep cannot see inside instanced
sub-scenes** — and the wrong conclusion survived because no control was run.
What settled it was three matched controls (DiscoDodge@8, ExplodingCollarRace@8,
BurnRecycle@4, all 0/0) against BurnRecycle@8 at 128/128. **A plausible cause
that fits the numbers is not a diagnosis; run the control.**

**Point economy, surveyed while tuning this** (max raw per session at 8 players,
×85 for session points). The minigames are **not** balanced against each other,
and never were: Smoke Break can pay at most 4 raw and Stable Footing 24 — a 6×
spread. It comes from multiplying two unreconciled things, a per-match ceiling
set by each minigame's design and a match count set in `default_playlist`. Two
scoring families exist: *placement* (score = finishing position, max
`player_count`) and *accumulation* (`+= 1` per event, 0 for poor performers).
Duck Hunt is the only one whose ceiling rises with roster — 22 at eight, from
the rotating hunter — and Wrong Way is the only one feeding both score channels.

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

### 2026-08-05 — full 13-minigame playtest at 8 players on v1.5.0

Every minigame in the rotation exercised at 8 players against the v1.5.0 build on
the real 4.5.2 binary, with a positive count trace on the host **and all seven
clients** in each. **Zero parse errors, zero script errors, zero `DISPLACED`,
zero `FELL_THROUGH`, zero `OFF_DECK` across the whole set.**

| Minigame | Evidence at 8 |
|---|---|
| Minefield | 3 full rounds, clean |
| Chisel Gauntlet | 8 slots, 8 **distinct** facings 45° apart, 8 distinct peers |
| Wrong Way | `players=8 lanes=8 screens=8`, lanes −11.19 … +11.17 |
| Duck Hunt | `ducks=7 hunters=1 expected_ducks=7`, 7 markers (4 runtime), magazine 18 |
| Stable Footing | `roster=8 markers=8 spawned=8`, all 8 nodes named |
| Table Manners | `markers=8 chairs=8`, camera fov 50 |
| Tunnel Hazard | `markers=8 nooks=8 spawned=8`, 192/192 OK — **and confirmed by eye** after the `inward` fix |
| Inside Job | `markers=8 spawned=8`; `searchables=36 base=52 target=34 clamped=true` |
| Smoke Break | `seats=[8 entries] decal_array=4 players=8` |
| Debris Platforms | 8 slots assigned, camera facing split 4/4, **no `OFF_DECK`** |
| Spine Breaker | `markers=8 spawned=8 device=true` |
| Lethal Rebound | `markers=8 spawned=8 roombas=1 max_roombas=10` |
| Forklift Certified | `zones=8 added=4 rebound=20/20 plates=4/4`, `players=8 zones=8 owned=8` with 8 distinct owner ids |

**Method.** A single `START=1` rotation run covered only **4 of 13 minigames**,
and the remaining eight were done by pinning each with `MINIGAME=` for ~140s
(~20 minutes total). Tunnel Hazard was run separately and confirmed by eye.

**Why the rotation stopped at four — corrected 2026-08-05.** This entry first
recorded that as *pacing* (~150s per round × 3 rounds × 13 ≈ 98 minutes). **That
was wrong.** The rotation stopped because **Duck Hunt is 4th and `START=1` hangs
it permanently** — the skipped `RoleReveal` state is the only online caller of
`set_can_aim_rpc`, so the hunter can never fire, no duck ever dies, and
`check_game_end()` can never fire with no turn timer to save it. Measured: 240s
in `Play` with zero further transitions. A `START=1` rotation **cannot** complete,
at any duration. Full detail under "`START=1` HANGS Duck Hunt permanently".

So the operative rule is: **pin for coverage, and use `FLOW=1` for the rotation.**
Reading "the rotation only reached N minigames" as slowness is exactly the mistake
made here.

The error classes are unchanged from the documented families — teardown churn
(`tree_exited` on `BloodMist`/`BloodSplat`/`HatGib`, "multiplayer instance isn't
currently active", node-cache misses) scaling with deaths and peers, plus the
pre-existing vanilla `update_playlist_state_rpc` arity bug.

### 2026-08-05 — Tunnel Hazard spawn sides fixed (`inward` mode)

Follow-up to the v1.5.0 rebuild below, and a direct result of the user looking at
the game rather than at a log.

`spawn_expand.py` generates both `+offset` and `-offset` candidates, but ranks
them by `(times-source-used, step)` only — which **ties the two signs**, and
Python's stable sort then always hands it to `+`. So every clone in every scene
is displaced the same way in world space regardless of what is over there. In
Tunnel Hazard the two left clones happened to move into the corridor and the two
right clones moved into the wall, at x=4.62 and x=5.31 against shipped extremes
of 3.42 and 4.11.

New opt-in third field in `spawn_targets.txt` — `path::container::inward` — adds
the direction as a tiebreak, preferring the candidate nearer the centroid of the
shipped markers. Applied to `train_race` only; the other fourteen scenes are
byte-identical, which is deliberate, since flipping a clone's side moves players
in a level that is currently verified.

| | before | after |
|---|---|---|
| near-right clone | x=+4.619 | **x=+2.219** |
| far-right clone | x=+5.311 | **x=+2.911** |
| left clones | x=−2.750 / −2.770 | unchanged |
| worst physics push-out | 0.49u | **0.20u** |

`markers=8 nooks=8 spawned=8` and 192/192 `OK` on the host and all seven clients,
before *and* after — which is the whole point: **the trace could not see this bug
and cannot confirm the fix.** Only a screenshot can.

Also measured on the way past, and left open: markers are placed 1.2u apart but
each pair settles **~1.58-1.60u** apart once physics resolves frame 1, so a
character is ~1.6u wide and `OFFSET` is too small in **every** expanded scene.
See Open items 0.

### 2026-08-05 — rebuilt against game v1.5.0 (Arcade mode, Godot 4.5.2)

Full run of the update procedure. The measurement and the file-by-file table are
in "The last update, and how it was verified" in `UPDATING.md`; this entry is the evidence.

**7 of 50 overlay files re-derived, 42 proved byte-identical upstream.** Five of
the six re-derived scripts came out with a byte-identical mod delta. The two that
did not are the two that matter:

- **`game.gd`** — upstream wrapped the custom-playlist loop in an
  `if GameManager.arcade_game: ... else:`, so the mod's `supports_player_count()`
  filter had to be re-placed by hand. `patch` had put it in the Arcade branch
  with fuzz, which was a Parse Error.
- **`train_race.tscn`** — regenerated from the new scene with `spawn_expand.py`
  rather than carried forward, so it keeps the new `SafetyKillbox` node **and**
  the four `_MOD` markers (transforms identical to v1.0.7's).

**Arcade mode needed a mod change, and it is the only deliberate new behaviour
in this rebuild.** Vanilla's Arcade branch draws its ten minigames straight from
`Globals.CustomMinigamesWhitelist`, which is the one playlist path that never
consulted the caps — so an 8-player Arcade session could roll `ManufactureGun` or
`BurnRecycle`, both capped at 4. The branch now filters by
`supports_player_count()` like the other two, and clamps the shipped literal `10`
to the filtered list size, because indexing past the end of that array returns
**null silently** in the release template (pitfall 23) rather than erroring. At
1-4 players every cap is 4, so nothing is filtered and Arcade stays vanilla
there, per rule 3. Signed off by the user before it was written.

**Verified** (`START=1`, then `FLOW=1`, on the host *and* all seven clients):

| Check | Result |
|---|---|
| `-validate-scenes` | `failures=0` across all 50 overlay resources |
| Boot | `Running version: v1.5.0-8P`, no parse errors |

**Every row below and above was re-run on the real Godot 4.5.2 binary.** The
first pass was not: `testgame/` still held the 4.5.1 executable from v1.0.7,
because `MP_DEPLOY` deploys only the `.pck`. See **pitfall 25** — it is the
single most costly thing found this session, and it silently produced one wrong
finding before it was caught.
| Playlist at 8, `ARGS="-original"` | 13 entries; `ManufactureGun`/`BurnRecycle` filtered out; `CutsceneTest` still absent |
| `[TRAIN8]` at 8 | `markers=8 nooks=8 spawned=8` on all 8 peers |
| `[TRAIN8]` at 4 | `spawned=4`, all `OK`, worst 0.48u |
| `[BRIEF8]` / `[SCORE8]` at 8 | `rows=8 expanded=true`, host and clients |
| `FLOW=1` auto-ready | 8 peers, exactly one `is_server=true` |
| Installer round-trip on clean v1.5.0 | `NOT PATCHED` → 4180 files (50 mod, 82 replaced) → `PATCHED` → uninstall restores `f5912732…` **byte-identically** |

**Two findings that are not regressions of the mod but are new since v1.0.7**,
both 8-player-only and neither blocking — see "Open items":

1. **Tunnel Hazard spawns players clipped into the wall and into each other at
   8 — seen by the user, invisible to the trace.** The screenshot shows four
   *pairs* standing shoulder to shoulder, and the top-right player is inside the
   right-hand wall geometry.

   `[TRAIN8]` calls this **192/192 `OK`, worst 0.49u** — and it is not lying.
   The audit measures each player's distance to its *nearest marker*, and every
   player is sitting on its marker exactly as intended. The defect is in **where
   the markers are**: `spawn_expand.py` places each clone 1.2u outboard along the
   shipped marker's local X, which in a corridor this narrow puts it in the wall
   and half inside its neighbour. Another instance of the pattern in "An
   `@export` node reference survives `duplicate()`" — the measurable thing was
   correct and the visible thing was wrong. **A landing audit validates the spawn
   mechanism, not the level design.** No trace phrased this way can catch it.

   Noted, not fixed — the user flagged it explicitly as a note rather than a
   task. The fix, when it is wanted, is a Tunnel Hazard-specific offset (or the
   runtime-marker pattern from §19/§20, which would let the spacing be chosen per
   level instead of a global 1.2u).

   *Earlier in this same session this entry claimed a `2.99u DISPLACED` reading
   here. That was an artifact of pitfall 25 — the run was on the stale 4.5.1
   binary. On 4.5.2 the audit is clean. The wall-clipping above is the real
   finding and it was never something the audit could have reported.*
2. An error class not in the documented baseline:
   `Condition "!pinfo.recv_nodes.has(net_id)" is true. Returning: ERR_UNAUTHORIZED`,
   from `on_despawn_receive` — despawn packets arriving for nodes a peer has
   already released. **It is not player-count-specific**: measured on 4.5.2 at
   95 lines across 8 peers and 43 across 4 peers in matched `FLOW=1` sessions,
   i.e. ~12 per peer either way. It also appears on **4.5.1**, so it is not new
   4.5.2 wording. It arrives in contiguous bursts at despawn events (~39
   back-to-back on one peer), not per frame.

   **It therefore needs no pitfall-12 filter entry** — appearing at both roster
   sizes, it cancels in the `comm -13` comparison by itself, and every pattern
   added to that filter costs sensitivity permanently. Left out deliberately.

   This entry initially read "8-only, zero at 4". That was wrong, and the way it
   was wrong is worth keeping: the pair that produced it was a `START=1`
   `MINIGAME=TrainRace` run at each size, which is one minigame in one mode.
   A matched `FLOW=1` pair at both sizes showed the class at both. **A single
   pinned-minigame pair is not enough to call a class player-count-specific.**

### 2026-08-04 — Forklift Certified uncapped to 8 players

**The second cap in a row that rested on a wrong premise.** `globals.gd` said
the four DropAreas "between them tile the whole 32x32 yard ... There is no room
to add four more zones". Measured off the scene: the floor is **53.6 x 58.6**
(the inverted `CSGBox3D main collider` is the *only* static collider in the
level, so all of it is drivable - the shelves and pipes are visual-only) and the
four zones cover **24%** of it, leaving a 16.7-wide channel between the zone
columns and an 18.3-deep band between the rows. Four more zones fit at the
mid-edges. Full detail in **`MINIGAMES.md` §20**.

**A worse blocker than the documented one, found by measurement not by play.**
`crate_manager.spawn_crates()` loops `while points.size() < target_size` over
PoissonDiscSampling with **no bound**, asking for `roster * 2` points in a fixed
12x12 box at a 4.0 separation (`spawn_radius` is 4.0 - the *scene* overrides the
6.0 in the script). Reimplementing the shipped sampler and running it 100,000
times per case: 8 points (4 players) succeeds 49% of the time, 10 (5 players)
0.6%, and **12 or more never - 0 successes, max ever seen 11**. So at six
players and up vanilla spins in that loop forever. It has never been seen
because `spawn_players()` aborts first, and it would have presented as a host
freeze with no error line rather than a black screen.

Fixed by giving the sampler the free centre cell of the expanded ring (derived
at runtime from the zone colliders, inset by a rotated crate's half-diagonal)
and clamping the target to the **10-crate ceiling the shipped loop already
enforced** - a 16-crate request was never going to produce more than 10 anyway.
Ten crates in the widened cell lands in 1-8 sampler calls. A 200-attempt bound
means no future geometry change can hang the host again.

**A third bug, vanilla, that only a 5th elimination can reach.** `spawn_blood_rpc`
takes a decal out of a **four-node pool** permanently. Four players produce at
most three eliminations so vanilla never empties it; eight produce seven, and
the fifth ran `get_child(0)` on an empty node. That returned null and aborted
the caller *mid-loop*, so `remove_zero_scoring_players()` never finished and
`round_finished()` never reached `check_game_end()` - **the round hung on every
peer** with one engine ERROR and nothing else, and one client segfaulted. The
pool now refills from a decal already on the floor.

**A fourth blocker, caught by eye and not by any trace.** The zone script
reaches its border mesh, counter label, spotlight and speaker through `@export`
**object references**, which `duplicate()` copies as pointers — so every cloned
zone was driving the corner zone it came from, and its own border stayed at the
shipped `Color(0, 0, 0, 1)`, i.e. invisible. Every measurement was clean while
this was true. See its own heading, "An `@export` node reference survives
`duplicate()` pointing at the ORIGINAL"; the trace now prints `rebound=20/20`.

**And then a run of art-fitting defects, every one of them invisible to the
logs.** The zone plates are positioned for a bay **recessed into the floor art**
and the mid-edges have no bay, so the plates were buried below the drivable
plane; the side zones' plates reached into the far row's readouts; the full-size
red read as an oversized slab without the bay art covering most of it; and the
grey grid plate is painted into the yard mesh rather than being a node. Fixed by
lifting the plates to the floor, shifting the side zones clear, a 10% shrink
(visual only - the crate-detecting Area3D is untouched), a faked plate sampling
the sub-rect of the shipped atlas that holds the original art, and moving the
side readouts into the margin against the side walls. Section 20 has the table
and the workarounds that were rejected on the way. **None of this was findable
from a log** - the recess is art only, the sole collider in the level being a
flat box, so every measurement stayed clean throughout.

**Verified at 8:** `zones=8 added=4 rebound=20/20` and `players=8 zones=8
owned=8` with eight distinct owner ids, on the host **and all seven clients**,
across three complete plays; `crates requested=16 target=10 attempts=1-8 region=centre_cell`; zero
`[FORK8]` warnings. **At 4:** `added=0 (vanilla)`, `region=vanilla`,
`target=8`, `zones=4 markers=4 owned=4` on all four peers - bit-identical.

**The 4-vs-8 error diff needed a real control to read correctly.** Two classes
showed at 8 and not at 4 (`Attempt to disconnect a nonexistent connection ...
tree_exited` and `The multiplayer instance isn't currently active`). They fire
at the score-screen transition and name global autoloads plus the shared
`MineExplosion`/`BloodMist` effect pool - one BloodMist per elimination - so
they scale with *deaths*, not with Forklift. Two controls were useless because
their idle players never die (Stable Footing) or never reached a score screen in
the window (Spine Breaker). **Minefield at 8, already signed off, produces more
of both (82/112) than Forklift (41/112).** Pre-existing teardown churn.

**Two design questions closed at the end of the session, one of them by
correcting me.** Crossing another player's zone with a crate on the forks was
raised throughout as the cost of the eight-zone layout — it is **not a thing at
all**: a forked crate is teleported 50 units below the world and stripped of the
collision layer the zones watch, so only a crate actually set down can count. I
had asserted the opposite several times, including while the user was choosing
between the two layouts; the code is in `MINIGAMES.md` §20. And whether 10 crates split
eight ways plays well is **tabled as untestable here** — seven idle instances
cannot contend for crates, so it needs an organic group of eight.

### 2026-08-03 — Duck Hunt duck-node count measured

Closed the last open Duck Hunt item. `[DUCK8] spawned` reports, per peer, the
duck nodes that actually exist plus the hunter, named, with an `expected_ducks`
cross-check that warns on mismatch. Measured `ducks=7 hunters=1` on the host and
all seven clients at eight players; `ducks=3 hunters=1` on all four at four.

Until now Duck Hunt's duck count rested on a visual check plus absence-of-errors
— the same weak proxy that let Stable Footing carry a wrong `spawn_limit`
attribution for a month. Every 8-verified minigame now has a positive count.

### 2026-08-03 — Duck Hunt round pacing verified, and two more fixes it needed

The `5-8: 1` keys added earlier were **not sufficient on their own**. Verifying
them turned up two problems:

- **Two sites resolve `total_rounds`**, and the one that actually gates the
  replay (`minigame_playing_state.gd`, via `more_rounds`) was not in the
  overlay. Changing only `game.gd` would have left Duck Hunt still replaying.
- **Vanilla gates the lookup on `not GameManager.custom_game`**, so a custom
  lobby never got the roster-scaled count. Both sites now use
  `not GameManager.custom_game or player_count > 4` — the second half preserving
  rule 3, so a 1-4 custom lobby keeps its host-configured count.

Measured via the new `[ROUNDS8]` trace: **8 players = 1 round** (8 hunter turns,
not 16) in both Original and custom modes; **4 players = 2 rounds** in both,
unchanged from vanilla.

**A `START=1` trap, the second of its kind:** the intermission picker's
`debug_skip_intermission` branch loads the first minigame with a literal `3`,
bypassing both resolution sites — so a round count read under `START=1` is that
constant, not the real value. `START=1` does not only skip presentation states,
it sometimes substitutes values on the way past. See Testing.

---

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


### ARCHIVED 2026-08-14 — the v1.0.7 → v1.5.0 "last update" worked example, moved verbatim from UPDATING.md when the v2.1.2 rebuild replaced it (that section always describes the MOST RECENT update)

## The last update, and how it was verified (v1.0.7 → v1.5.0, 2026-08-05)

**This is a worked example, not a changelog entry — and the sweep at the bottom
of it is a tool you should run, not a note about something that already
happened.** If you are here to rebuild against a new version, this section plus
step 4 of the update procedure is the whole method; the 2,000 lines in between
are reference for when something breaks.

The mod targets **v1.5.0** as of this writing. This was a **much larger patch
than v1.0.7** — a new game mode, an engine bump and two gameplay fixes — and it
is the update that proves why the sweep is not a formality. Measured by diffing
the two extractions:

| Changed in v1.5.0 | | In the overlay? |
|---|---|---|
| `autoloads/globals.gd` | `game_version` `"v1.0.7"` -> `"v1.5.0"`, one line | **yes** |
| `scripts/scenes/game/game.gd` | new **Arcade** branch in `generate_session_playlist()` | **yes** |
| `scenes/bootstrap/scripts/bootstrap.gd` | `GameManager.arcade_game = false` | **yes** |
| `scenes/lobby/scripts/lobby_scene.gd` | hides the playlist button in Arcade | **yes** |
| `minigames/intermission_new/components/intermission_briefing_screen.gd` | `anim_env.play("set env to intermission screen instant")` — **the "flashbang" fix** | **yes** |
| `minigames/train_race/scripts/train_race.gd` + `train_race.tscn` | `SafetyKillbox` Area3D — **the Tunnel Hazard clip-out fix** | **yes** |
| `autoloads/game_manager.gd` | `var arcade_game: bool` | no |
| `modules/.../lobby_handler.gd` | hides the playlist button in Arcade | no |
| `minigames/knife_at_the_office/.../knife_at_the_office_player.gd` | `min(delayed_blend, 1.0)` — the blend-tree "uncanny visuals" fix | no |
| `intermission_new.tscn`, `knife_at_the_office_player.tscn`, `manufacture_gun_player.tscn`, `nook.tscn`, `main_menu.tscn` | scenes for the above | no |
| 20 localization files | `.translation` x17, the `.csv`, `.csv.import`, one `.md5` | no |
| `.godot/uid_cache.bin`, `filesystem_cache10` | engine caches | no |
| `Machine Party.x86_64` | **CHANGED** — Godot 4.5.1 → 4.5.2 | n/a |

368 `.gd` and 140 `.tscn` before and after, **no files added or removed** — the
Arcade mode ships entirely inside existing files, so the "watch for new
minigames" check in step 5 came up empty. The `.pck` grew only 2,448 bytes.

The sweep put **7 of the 50 overlay files** in the re-derive column, 42 as
byte-identical upstream, and 1 (`mod_player_name_list.gd`) as mod-added. **Two
of those seven carried an upstream bug fix** — the flashbang fix and the Tunnel
Hazard killbox — so carrying the overlay forward wholesale would have silently
reverted both, in exactly the way step 5 warns about. That is the argument for
the sweep in one sentence: it is not a shortcut, it is what tells you *which*
files you cannot afford to skip.

**Verify that claim yourself before trusting it on the next update** - do not
assume a small patch. The check is cheap:

```bash
python3 - <<'EOF'
import os, filecmp
for root, _, files in os.walk("mod"):
    for f in files:
        rel = os.path.relpath(os.path.join(root, f), "mod")
        a, b = os.path.join("project_old", rel), os.path.join("project", rel)
        if not os.path.exists(a):
            print("added   ", rel)
        elif not filecmp.cmp(a, b, shallow=False):
            print("CHANGED ", rel, "<- re-derive this one")
EOF
```

| | |
|---|---|
| v1.0.7 pck | `01e9d9140a01745dc4236c50c9837bcd`, 635,331,268 bytes |
| v1.5.0 pck | `f5912732bfa2cc5cba4340270fd76147`, 635,333,716 bytes |

A clean unmodified v1.5.0 copy is kept at `testgame_new/`; the v1.0.7 decompile
is at `project_old/` / `extracted_old/`, and the v1.0.7 overlay at `mod_v107/`.

**One thing to know about the re-derivation itself.** Applying the old mod delta
to the new source with `patch` works for most files — five of the six scripts
came out with a **byte-identical mod delta** — but `game.gd` applied its filter
hunk **with fuzz 3** and silently landed it in the *wrong branch*, inside the new
Arcade block, producing a bare `continue` outside any loop. That is a Parse
Error, i.e. pitfall 16: invisible at boot, and a black screen with the music
still looping when the minigame loads. **`patch` reporting "succeeded with fuzz"
is a request to go and read the result, not a pass.** The check that catches it
cheaply is to diff the deltas against each other:

```bash
diff <(diff project_old/$f mod_v107/$f) <(diff project/$f mod/$f)
```

Empty means the mod change carried over exactly; anything else is either an
upstream restructure you must account for, or a misapplied hunk.

---
