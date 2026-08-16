# Machine Party 8-Player Mod — session log

Newest first. Each entry is what changed and what evidence backed it, so a new
chat can judge how solid a claim is rather than re-deriving it. Split out of
`UPDATING.md` on 2026-08-14; **new entries are recorded here**, at the top.
The conventions are unchanged: one entry per session of work, the evidence
tables land with it, the commit message points at the entry — and an entry
whose conclusions are fully folded into the live sections (`UPDATING.md`,
`PITFALLS.md`, `MINIGAMES.md`) moves **verbatim** to `SESSION-LOG-ARCHIVE.md`,
leaving a stub here naming the section that now owns the material.

Section names cited bare — "Current status", "Open items", *Testing*, the
"Update procedure" steps — are sections of `UPDATING.md`; *pitfall N* is
`PITFALLS.md`, *§N* is `MINIGAMES.md`.

Newest first. Each entry is what changed and what evidence backed it, so a new
chat can judge how solid a claim is rather than re-deriving it.

### 2026-08-16 (latest) — Steam lobby at 5-8: the runtime preview spread stacked seats 2-4 on one chair; replaced by hand-placed lap seats for players 5-8, positioned live in the game (issue #14)

**Report (maintainer, real 5-player Steam lobby, screenshot):** four
characters piled on the left-hand chair, the fifth alone on the right; the
text roster (§7) fine. First observation of the Steam lobby above four —
"never seen" in "Current status" until today.

**Diagnosis (measured, not guessed).** `lobby_scene.gd`'s
`mod_layout_previews()` treated the `Player1`-`Player4` node x positions
(−6, −2, 2, 6) as a row of seats and, once a fifth player joined, resampled
all eight slots across that span. But those nodes are an authoring row with
identity bases: the seat itself — chair, depth, facing — is baked one level
down in each `Armature_001` transform, which differs wildly per slot. Moving
`PlayerN.position` is therefore a pure world translation on top of the baked
seat: seats 2-4 slid 2.3 / 4.6 / 6.9 u left onto seat 1's chair, while the
values written for slots 5-8 were identical to the `.tscn`'s baked ones (a
no-op). Projecting each nametag `Label3D` through the lobby camera (fov 28.2°,
1803×908 viewport) and comparing with the screenshot: mean residual **307 px**
if the spread had not run, **30 px** if it had — the spread ran, and that was
the whole defect. ≤4 was and is untouched (the restore branch), so rule 3
was never breached. Why the harness never saw it: `-localtest` routes to the
developers' debug lobby (`debug_lobby.tscn`, 4 preview slots, not overlaid);
`lobby_scene.gd` only runs on the Steam path.

**Fix — two files, both in the overlay already, no new code path:**

- `lobby_scene.gd`: `MOD_VANILLA_SLOTS`, `mod_preview_home`, the `_ready()`
  snapshot and `mod_layout_previews()` **deleted** (39 lines, deletions only).
  The script no longer touches a preview transform. Seat map and roster stay.
- `lobby_scene.tscn`: `Player5`-`Player8` re-authored as **lap seats** —
  each keeps its host's `PlayerN` x (−6, −2, 2, 6) and gets its own
  `Armature_001` + `player nametag` transform placing it on the lap of
  `Player1`-`Player4` respectively (5→1, 6→2, 7→3, 8→4; all four in
  `lobby_scene_pose_1`, the upright sit). Eleven lines changed vs HEAD;
  `Player1`-`Player4` byte-identical to HEAD (line-set md5 `b7a682a2…` both
  sides). At ≤4 the vanilla handler leaves slots 5-8 invisible and nothing
  moves — rule 3 holds by construction, no restore branch needed. Room note:
  only four chairs are upright *and* visible (`chair_001/002/003/007`;
  eight of the thirteen chair meshes ship `visible = false`), so laps, not
  more chairs.

**How the transforms were obtained — and the bug in the aid that nearly
shipped them turned.** Two offline models of the scene (a box-body page,
then one drawing the `.tscn`'s own 34-bone saved poses through the exact
node chain) each put the maintainer's placements somewhere else in the
game. What worked: a **preview build** — `mod/` plus a patched
`lobby_scene.gd` that forces all eight previews visible and adds a
key-driven placement mode (select a sitter, auto-place it on its host's lap
from the host's *live* bones, nudge/turn, print the exact `.tscn` lines to
the log and clipboard). Hosting a Steam lobby alone, the maintainer placed
all four in one round. But the first bake loaded with every sitter turned by
twice its yaw (P6 facing 177° from its host): the printer wrote `basis.x`
into the first three text slots, and **`Transform3D(...)` text is by rows
while `Basis.x/.y/.z` are columns** — the printed basis was the transpose,
i.e. the inverse yaw. The same transposition (reading `.tscn` bases as
columns) is why both offline models had "forward" wrong for three of four
seats — not, as first written, any mismatch between the played animation and
the saved pose: the four `lobby_scene_pose_N.res` were parsed (35 tracks
each: 34 bone rotations + the hips position, none on the `Armature_001`
node), so a baked armature transform survives autoplay. Caught by
round-trip: F9 on the freshly loaded scene printed the transpose of the
baked line; after the printer fix, an untouched slot printed its baked line
byte-identically (same-in-same-out). Promoted to **`tools/lobby_preview/`**
(recipe: Testing, "Placing the lobby previews"). Pitfall 35 records it.

**Evidence:**

| Check | Result |
|---|---|
| Maintainer's eyes, preview build, all eight visible | placement accepted ("worked amazingly"); after the printer fix a fresh load showed the same placement ("looks like how I originally placed them"), and the shipped lines are the fixed printer's output after one small adjustment |
| Print-aid round trip | untouched slot P6: F9 output on a fresh load == the baked `.tscn` line, byte for byte |
| `Player1`-`Player4` node + armature lines vs HEAD | identical (md5 `b7a682a2…`) |
| `lobby_scene.gd` diff | deletions only; `grep mod_layout_previews\|mod_preview_home\|MOD_VANILLA_SLOTS` → nothing (the same-named const in `manufacture_gun.gd` is unrelated and untouched) |
| Five static checks | all OK; overlay still 56 files |
| Clean build | `dist/Machine Party.pck` md5 `4b81a757…`, deployed to `testgame/` |
| `-validate-scenes` | **not run** (it is a hand-added hook, see Testing); the preview build loaded the same `.tscn` and a strict superset of the `.gd` in the real binary without error |

**Not claimed:** the eight-slot lobby with eight *real* peers (only forced
visibility has been seen — the vanilla per-slot visibility path is unchanged
code); how the four lap pairs read at Steam-name lengths; issue #5 stays open.

### 2026-08-15 — Shipped as mod release v1.4: the pre-start disconnect guard in all fifteen minigames (issue #13)

**What ships:** the entry below — `if not is_all_player_loaded: return` in
every minigame's `player_disconnected()`, `exploding_collar_race.gd` in the
overlay (56 files), the two `.get()` hygiene hunks — plus the promoted
quit-at-load tools. `MOD_SUFFIX` → `8P-v1.4`, so v1.3 and v1.4 peers refuse
each other cleanly per pitfall 7; `MOD_NETWORK_GAME_VERSION` stays `v2.1.2`
(no game update); display `v2.1.2-8P-v1.4` at every step-6 site
(`version_strings.py` plus the prose: `README.md`, `CLAUDE.md`, `UPDATING.md`
"Current status", step 6 and the boot-test line, `installer/README.txt`).

Release integrity, all measured this day on the v1.4 strings:

| | |
|---|---|
| Static checks + `%` pre-flight | all five pass |
| Reproducible build | `dist` (twice) and deployed `testgame` pck md5 `54f960fca5f4300d4ff0fb3e3263e4f0`; engine `9bac4458…` unchanged |
| Boot | `Running version: v2.1.2-8P-v1.4`, zero parse/script errors |
| Handshake at 8 | all 8 boot `v2.1.2-8P-v1.4`, zero `VersionMismatch`/refusals, `[SEATS]` to `connected=8`, `[SCORE8] rows=8` on host and clients |
| Regression on the release build, quit-at-load (`leave_slot_at_load.sh 4 3 DvdRoomba 5`) | P4 closed, `players=3` at +0.27 s, no `Empty → Finished`; after the 5 s resume `SessionIntro → MinigameStart → MinigamePlaying → Empty → Round → … → Play → Finished`, round 2 loaded at `players=3`; P2 same; P3 held (`players=3` throughout) |
| Regression, kill-at-load (`kill_slot_at_load.sh 4 DvdRoomba`) | `players=3` after the timeout → `MinigameStart → MinigamePlaying → Empty → Round → Play → Finished` |
| Errors across the three runs | only the leaver's normal exit-time RID-leak report and the documented families |
| Installer round-trip (clean v2.1.2 copy, `f5ea2339…`, pristine pck staged first) | `NOT PATCHED` → install (**4205 files, 56 mod, 94 replaced**) → `PATCHED - all 56 mod files present` + `v2.1.2-8P-v1.4` → re-install **refused** (`already patched`), pck md5 unchanged → restored from the staged copy, `f5ea2339…`, 634,798,100 bytes; no `.vanilla` created |
| Zip | rebuilt per step 8: **60 entries**, extracted `mod/` `diff -rq` clean, four root files `cmp`-identical; md5 **`c9d594aa4db778e38cbd4ea96bef76b7`**, 21,309,383 bytes |

Tagged `v1.4`, `gh release create` with the zip attached; issue #13 closed as
shipped, #11 (the original crash) stays open.

### 2026-08-15 — Issue #13: all fifteen disconnect handlers audited for a drop DURING the load. A crash was already safe; a QUIT during the load finished an unstarted game in eleven minigames (six then unable to end the round). Guarded everywhere

**Task:** open item 7 / issue #13 — do the other fourteen minigames break the
lobby when a player disconnects mid-load, the way Duck Hunt did (pitfall 32)?

**Static audit — every handler read pre-spawn (verbatim extraction by three
read-only subagents, every quote re-checked against the files):**

- The v1.3 gate re-run in `game.gd::_on_peer_disconnected` already makes the
  **crash ordering** safe for all fourteen: every `all_players_loaded()` sets
  `is_all_player_loaded` and emits `minigame_ready` synchronously,
  `_on_minigame_ready` calls `initialize()` in the same call stack, and in all
  fourteen `spawn_players()` runs before any `await` (checked per file) — so
  the game is spawned before `player_disconnected()` runs, the removal is a
  guarded no-op for a peer that was never spawned, and the end check 1 s later
  sees the live roster.
- **Quit ordering** (disconnect processed while a live peer is still loading):
  the handler runs against an unspawned game. Eleven reach an end check whose
  "still alive?" guard is false at zero players and go `Empty → Finished`
  with `player_scores_finalized.emit({})`, `MINIGAME_SFX` zeroed and effects
  hidden — burn_recycle, dvd_roomba, escalator_pit, exploding_collar_race,
  forklift_certified, green_pea, junk_platform, knife_at_the_office (inverted
  `size() <= 1` polarity, via `end_game()`), manufacture_gun, spine_breaker,
  train_race. Safe by accident: chisel_gauntlet (`can_submit` false until
  `RoundPlay`), disco_dodge (`size() != 1`). smoke_break has no end check.
  Six of the eleven latch `finished`/`game_end` in that path (burn_recycle,
  dvd_roomba, green_pea, junk_platform, spine_breaker, train_race), so a game
  that starts afterwards can never end its round. Full table: §23.
- **Which disconnect is which** was settled in the tagged engine source, not
  guessed: `~ENetMultiplayerPeer()` → `close()` → `peer_disconnect_now(0)` +
  `flush()` (4.5.2 `modules/enet/enet_multiplayer_peer.cpp:290-311, 487-491`)
  and no SIGTERM/SIGINT handler in `os_linuxbsd.cpp`/`main.cpp`. So Alt-F4
  (no `WM_CLOSE_REQUEST` override in the game) and the pause menu
  (`NetworkManager.cancel()` → `disconnect_player` RPC → `disconnect_peer`,
  `enet_backend.gd:50-54, 205-208`) are noticed on the host's next poll —
  during the load, before slower peers report in — while a crash or kill waits
  for the ~15 s ENet timeout, after them. Pitfall 33.
- **The two "unguarded index" handlers do not error in the shipped game.**
  `gdscript_vm.cpp`'s invalid-key and null-call reports are `#ifdef
  DEBUG_ENABLED`; in the release build `dict[missing]` yields null and
  `null.queue_free()` is a silent no-op — which is why the ManufactureGun and
  SmokeBreak kill-at-load runs below show no `SCRIPT ERROR` while exercising
  exactly those lines, and why manufacture_gun's pre-spawn path *does* reach
  its end check. Pitfall 34.

**Crash ordering, all fourteen, unfixed v1.3 build (`b3b6621…`) — 14 pinned
kill-at-load runs at 4 players, P4 `SIGKILL`ed at the load line, 180 s each
(subagent-run, every verdict re-checked against the archived host log):** every
run `[BRIEF8] players=3 → SessionIntro → MinigameStart → MinigamePlaying →
<minigame>: Empty → Round` on the host and both clients, zero `SCRIPT ERROR`,
no non-benign `ERROR` on the load path; ten reached round 2 / `[SCORE8]`, the
four idle-only ones (EscalatorPit, GreenPea, KnifeAtTheOffice,
ManufactureGun) sat in `Play` as documented. Two side notes: `[FORK8]`'s
`_ready`-time audit warns `got 0 / 4 / 0` before the late start (the pitfall-32
late-start tell, not a spawn failure), and six logs end with an ENet-teardown
burst (`Failed to get cached node`, `multiplayer instance isn't currently
active`, `Attempt to disconnect a nonexistent connection`) after `[SCORE8]`,
where the harness's timer kills the instances — checked against the no-kill
controls below.

**Quit ordering — the new recipe (Testing, "Simulating a peer QUITTING during
a minigame load"; `tools/leave_slot_at_load.sh` + `tools/graceful_close.py`,
promoted from the session's scratch tools):** at the host's load line,
`SIGSTOP` P3 for 8 s (a manufactured slow loader — 8 s turned out not to be
reliably under a *frozen* peer's timeout, see the caveat under the table; the
recipe now says 5 s) and send P4's X11 window `WM_DELETE_WINDOW`. Pre-fix on the v1.3 build, rebuilt
from git (reproducible, `b3b6621…`):

| Run (4p, unfixed) | What the host log showed |
|---|---|
| DvdRoomba | close sent +0.06 s after the load line, `players=3` at **+0.27 s**, P4 exited normally; `dvd_roomba: Empty → Finished` **before any `Game:` transition**; after the resume `SessionIntro → MinigameStart → MinigamePlaying`, `Finished → Round → Countdown → Play` — and no round end in the remaining ~140 s (the healthy kill run cycles three rounds and reaches `MinigameEnd`). Same sequence on P2 and P3 |
| KnifeAtTheOffice | `players=3` at +0.69 s; `knife_at_the_office: Empty → Finished` before `MinigameStart`; then `Finished → Round → Countdown → Play` (here the frozen P3 was itself dropped at ~6 s and the start came from the gate re-run on that second drop — see the freeze note below) |
| BurnRecycle | `players=3` at +0.21 s; `burn_recycle: Empty → Finished` before `MinigameStart`; then `Finished → Round → Countdown → Play`, one `[FILTER8] eliminate victims=1 … contested=true` and nothing after — `finished` latched, the elimination cycle never re-arms |

**Fix (the §19 precedent — every roster size; no new `@rpc`; RPC count still
8):** `if not is_all_player_loaded: return` at the top of all fourteen
`player_disconnected()` handlers, after the `is_server` check where there is
one (Duck Hunt's variant keeps its removal ahead of the guard because `_ready()`
builds `possible_hunters`; none of the fourteen populate a per-player container
before `spawn_players()` — verified — so nothing needs removing pre-spawn, and
that is also why a single generic gate in `game.gd` was rejected).
`exploding_collar_race.gd` joins the overlay (55 → 56 files, its only delta).
Two hygiene hunks: `manufacture_gun.gd` / `smoke_break.gd` `.get()` the
per-player dictionary for a peer that never spawned there — silent in release
either way (pitfall 34). §23 owns the change; manifest rows updated.

**Verification on the fixed build (`dc1cc971…`, deployed to `testgame/`):**

| Run (4p, fixed, `leave_slot_at_load.sh 4 3 <mg> 8`) | leaver closed → `players=3` | `Empty → Finished` before `MinigameStart`? | after the resume | round 2 / `[SCORE8]` in 120 s | non-benign errors |
|---|---|---|---|---|---|
| BurnRecycle | +0.21 s | **no** | `MinigameStart → MinigamePlaying → burn_recycle: Empty → Round`, host + P2 + P3 | round 2 | 0 |
| DvdRoomba | +0.27 s | **no** | same, `Empty → Round`; three rounds → `MinigameEnd` | both | 0 |
| EscalatorPit | +0.41 s | **no** | same, `Empty → Round` (idle-only, stays in `Play`) | — | 0 |
| ExplodingCollarRace (new overlay file) | +0.73 s | **no** (prints no minigame-level lines) | `MinigameStart → MinigamePlaying`, rounds cycle | both | 0 |
| ForkliftCertified | +0.33 s | **no** | `Empty → Round` | both | 0 |
| GreenPea | +0.37 s | **no** | `Empty → Round` (idle-only) | — | 0 |
| JunkPlatform | +0.52 s | **no** | `Empty → Round` | both | 0 |
| KnifeAtTheOffice | +0.68 s | **no** | `Empty → Round` (idle-only) | — | 0 |
| ManufactureGun | +0.47 s | **no** | `Empty → Round` (idle-only) | — | 0 |
| SmokeBreak | +0.26 s | **no** | `Empty → Round` | round 2 | 0 |
| SpineBreaker | +0.21 s | **no** | `Empty → Round` | round 2 | 0 |
| TrainRace | +0.42 s | **no** | `Empty → Round` | both | 0 |
| kill-at-load regression: ManufactureGun, SmokeBreak (150 s) | `SIGKILL` confirmed, `players=3` after the timeout | — | `MinigameStart → MinigamePlaying → Empty → Round` | — | 0 (the two `.get()` hunks changed nothing visible, as pitfall 34 predicts) |
| no-kill controls: DvdRoomba 4p and 8p | `players=4` / `players=8` only | — | `SessionIntro → MinigameStart → MinigamePlaying → Empty → Round`, rounds cycling, `[SCORE8]`, every peer `v2.1.2-8P-v1.3` | both | 0 |

Every leaver's log ends with a normal exit; P2 and P3 show the same Game and
minigame transitions as the host in every run where P3 survived. **The freeze
caveat, learned here:** with an 8 s freeze the host dropped the *frozen* peer
at ~7–8 s in 4 of the 12 (ExplodingCollarRace, GreenPea, KnifeAtTheOffice,
ManufactureGun — `players=2` before the resume, the game then starting with
two peers through the gate re-run). Those four still exercise the guard —
P4's disconnect landed pre-spawn with no `Empty → Finished`, and P3's did too
— but the recipe now says 5 s, and the same drop happened in the
KnifeAtTheOffice pre-fix run. The verification agent's table was re-derived
line by line from the archived host and client logs before being trusted; the
"Failed to get cached node" lines it flagged turned out to be the companion
line of the documented `Node not found` round-transition family (present in
both no-kill controls, 12 and 74 lines) and joined the benign filter; the
`Ignoring sync data from non-authority or for missing node` line it also
flagged is the 2026-08-14 entry's benign-shaped churn, present in both controls
as well.

Static: five checks + `%` pre-flight pass; boot prints `v2.1.2-8P-v1.3` (label
unchanged — no release cut this session); build reproducible (two builds,
same md5).

**What this does NOT claim:** nobody heard or watched these runs — the
verification is the state-machine order in the host and client logs. The Steam
backend's quit path rests on the host-side `disconnect_peer` call being
backend-independent plus the ENet evidence; a real Steam quit-at-load has not
been run. `MOD_SUFFIX` stays `8P-v1.3`: the fix is on `main`, unreleased.
Issue #11 (the original crash) stays open. Archived logs: scratchpad
`killload/<Identifier>/`, `leave/<Identifier>-{prefix,postfix}/`,
`killload-postfix/`, `controls/`.

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

### Archived 2026-08-15 — every entry dated 2026-08-09 and earlier

Moved **verbatim** to `SESSION-LOG-ARCHIVE.md` at the v1.4 release, per rule 3
of the documentation policy (the log had reached 1,768 lines). Their durable
content lives in the sections below; read those, not the archive copy, unless
you want the reasoning:

| Entry | Now owned by |
|---|---|
| 2026-08-09 — Vanilla-compat mode, shipped as v1.1 | "Current status" (vanilla-compat paragraph), Testing "Mixed-lobby runs (vanilla-compat)", pitfall 30, `MINIGAMES.md` §3 |
| 2026-08-08 — GitHub release prep, restructure, scrub | "Version control", "Layout" |
| 2026-08-08 — v1 release audit, `OFFSET` analysis | Open items 0 (the `OFFSET` / `MIN_CLEARANCE` analysis), "Update procedure" step 8 |
| 2026-08-08 — Firearm Factory's wall desks | §22, Open items 2/2a/2b |
| 2026-08-07 — Firearm Factory uncapped | §22, "Current status" |
| 2026-08-07 — The Filter uncapped, two rooms | §21 |
| 2026-08-05 — Duck Hunt `START=1` hang (already stubbed) | Testing "`START=1` HANGS Duck Hunt permanently" |
| 2026-08-05 — full 13-minigame playtest at 8 on v1.5.0 | "Current status", Testing "What the local test still is not" |
| 2026-08-05 — Tunnel Hazard spawn sides (`inward` mode) | §16, Toolchain (`spawn_expand.py`), Open items 0 |
| 2026-08-05 — rebuilt against v1.5.0 | "Update procedure" and the archived v1.5.0 worked example (already there), pitfall 25 |
| 2026-08-04 — Forklift Certified uncapped | §20 |
| 2026-08-03 — Duck Hunt duck-node count; round pacing + two fixes | §19 |

### Older entries

Everything dated 2026-08-09 or earlier is in **`SESSION-LOG-ARCHIVE.md`**,
verbatim (the stub table above names what owns each), as is any later entry
whose conclusions have since been folded completely into the live sections —
and at each release everything older than the previous release moves there
(documentation policy, rule 3). That file is verbatim — not a summary; nothing was condensed out
of it. (Both files are in git since 2026-08-08, but the archive, not git
history, is the intended reading surface; see rule 3 of the documentation
policy.)

Its durable content is already folded into `MINIGAMES.md`'s numbered sections
and the pitfalls list, so read it only when you want the reasoning behind a
decision rather than the decision itself.
