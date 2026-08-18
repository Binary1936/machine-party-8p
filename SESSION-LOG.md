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

### 2026-08-18 (latest) — Windows installer bundles its own Python runtime; installer no longer dies invisibly with no terminal attached

`installer/install.bat` renamed to `WindowsInstall.bat` (`git mv`); it now
prefers a Python runtime at `python\python.exe` bundled beside it, falling
back to `py -3` with the old message — one file works from both a repo
checkout and the release zip. New `tools/fetch_embed_python.py` downloads the
Windows embeddable CPython 3.13.1 amd64 from python.org, verifies a pinned
SHA-256, and extracts it to the gitignored `installer/python/` (21 MB,
reproducible, not committed) — run before packaging a release (step 8). The
release zip now ships that runtime, so Windows users need no Python install
(zip ~21 MB → ~31 MB, 94 entries). `install.sh`, launched with no tty
(double-clicked from a file manager), now re-execs itself inside a terminal
emulator instead of the confirmation prompt reading EOF unseen, and its
"Python 3 is required" message now points at the distro package manager
instead of python.org. `install.py` gained an `ask()` helper wrapping
`input()` that reports the missing terminal instead of raising `EOFError`,
used by all four confirmation prompts. New pitfall 36.

| Check | Result |
|---|---|
| Windows path, real release zip, `WindowsInstall.bat` under Windows CPython 3.13.1 | install and `--verify` succeed; pck md5 `c697a7de9842a2c29d1604c04a8653a2`, byte-identical to a Linux-built install from the same pristine `testgame_new` pck |
| Zip integrity | extracted zip's `mod/` `diff -rq` clean against repo `mod/`; `install.sh` keeps mode 755 through the zip |
| Linux, no tty, before the fix | `install.py` raised `EOFError` at `Proceed? [y/N]` — the traceback nobody sees |
| Linux, no tty, after the fix | no terminal emulator found: prints the "no terminal" message, not a traceback; one found: re-execs into it (stub on PATH received `-e <install.sh path> --game-dir ...`); real tty: re-exec correctly skipped, install completes to the same md5 |
| `tools/checks/*.py` | all five pass |

python.org ships embeddable builds for Windows only (amd64/arm64/win32); Linux
and macOS keep using the system `python3`.

### 2026-08-17 — Arcade and Custom playlist branches measured at 8 (no code change); three stale doc claims corrected

No mod change. Runs used a local-only harness aid (not in the repo) that forces
`arcade_game` from the debug lobby plus a host-side playlist print; the raw logs
were not retained, the counts below are from the session's per-peer greps. All
`tools/localtest.sh` against `testgame`, error-free after the standard filter:

| Run | Result |
|---|---|
| Arcade, 8, `START=1`, 150 s | 10 distinct whitelist entries, rounds 1–2, `lobby_size=8`; ForkliftCertified + TrainRace played, `[TRAIN8]`=27 / `[SCORE8]`=3 on all 8 peers |
| Arcade, 4, `START=1`, 120 s | 10 entries, `lobby_size=4`, `[SPINE8] factor=1.000` (rule 3 control) |
| Arcade, 8, `FLOW=1 -kato-hunt=8`, 420 s | BurnRecycle, DvdRoomba, KnifeAtTheOffice played, 5 rounds; `[FILTER8]`/`[ROOMBA8]`/`[KATO8]` identical on all 7 clients; a `DvdRoomba:2` draw played 2 rounds |
| Arcade + `MINIGAME=DuckHunt`, 8 | the pin composes with the branch; `ducks=7 hunters=1` on all peers |
| Custom, 8 and 4, `START=1` | byte-identical 15-entry lists and rounds — roster-independent |

Corrections: §3's "13 survive at 8" → 15, filter inert since 2026-08-07;
`[FILTER8] subtrees=n/6` → `n/5`, `4/5` complete under v2.1.2; "Arcade has
never been run" → run under the harness, not by people. Not shown by these
runs: ManufactureGun (seated at 8 under Arcade, clock ran out before it
played), Duck Hunt's 5–8 round relaxation under Arcade (both draws were
1-round), hand-picked custom playlists. Issue #4 stays open.

### 2026-08-16 — Shipped as mod release v1.5: the Steam lobby's lap seats for players 5-8 (issue #14) and Chisel's head-on jumbotron HUD for 5-8 lobbies

**What ships:** the two entries below — `lobby_scene.tscn`'s hand-placed
`Player5`-`Player8` seats with the runtime spread removed from
`lobby_scene.gd` (§6), and `chisel_gauntlet.gd`'s jumbotron HUD overlay
(§10). `MOD_SUFFIX` → `8P-v1.5`, so v1.4 and v1.5 peers refuse each other
cleanly per pitfall 7; `MOD_NETWORK_GAME_VERSION` stays `v2.1.2` (no game
update); display `v2.1.2-8P-v1.5` at every step-6 site (`version_strings.py`
plus the prose: `README.md`, `UPDATING.md` "Current status", step 6 and the
boot-test line, `installer/README.txt`). Session-log entries older than the
v1.4 release archived per documentation-policy rule 3 (stub table below).

Release integrity, all measured this day on the v1.5 strings:

| | |
|---|---|
| Static checks + `%` pre-flight | all five pass |
| Reproducible build | `dist` (twice) and deployed `testgame` pck md5 `e7923799f03846168c50c4b10fb90dae`; engine `9bac4458…` unchanged |
| Boot | `Running version: v2.1.2-8P-v1.5`, zero parse/script errors |
| Handshake at 8, pinned `ChiselGauntlet` (130 s) | all 8 boot `v2.1.2-8P-v1.5`, zero `VersionMismatch`/refusals, `[SEATS]` to `connected=8`; `[STATIONS]` `cloned 10 single nodes, hid 2 props` ×3 on host and all 7 clients; `[SHOTGUN]` 0,4,2,6,1,5,3,7 |
| Installer round-trip (clean v2.1.2 copy, `f5ea2339…`, pristine pck staged first) | `NOT PATCHED` → install (**4205 files, 56 mod, 94 replaced**) → `PATCHED - all 56 mod files present` + `v2.1.2-8P-v1.5` → re-install **refused** (`already patched`), pck md5 unchanged → restored from the staged copy, `f5ea2339…`, 634,798,100 bytes; no `.vanilla` created |
| Zip | rebuilt per step 8: **60 entries**, extracted `mod/` `diff -rq` clean, four root files `cmp`-identical; md5 **`b5700fe1ffaaf001d30f4d3dd49836b5`**, 21,312,266 bytes |

Tagged `v1.5`, `gh release create` with the zip attached. Issue #14 was
already closed as fixed on `main`.

### 2026-08-16 — Chisel: seats 5-8 read the jumbotron corner-on; every player in a 5-8 lobby now gets a head-on HUD view of it during the memorise phase

**Report (playtesters via the maintainer):** the four added seats make the
minigame harder — they see the jumbotron from an angle. **Measured** from the
shipped `.tscn` and the player camera's `look at jumbotron` pose (7.51 u out,
height 4.21, pitched up 21.1°, fov 18.9): the cardinal seats see one CRT
head-on (7° obliquity, centred, ~70% of frame height); the diagonal seats see
**two** CRTs at **53.6°**, split to the frame edges, nothing head-on. Same feed
on all four screens, so it is purely a viewing-angle problem. Analysis script,
its output and a plan-view SVG are preserved machine-locally (`NOTES-LOCAL.md`,
2026-08-16 entry).

**The maintainer's first instinct — clone the four CRTs at 45° like the
stations — was costed and rejected.** Unlike the consoles, the CRTs form a
near-continuous ring: a same-radius 45° clone is buried (face 0.96 u inside
the pillar box, 0.88 u into each neighbour CRT, 0.24 u into the corner post),
so it would need pushing ≥1.2 u outward (≥1.7 u to also clear the posts) and
lowering ~0.4× that to stay framed in the zoomed camera; even then the corner
post's tip ends inside the clone, its cable dangles in mid-air, and the
lowered ring peeks into the top of the carve view. Numbers in the preserved
script output.

**Fix chosen (maintainer's decision: all eight above four, not only the
diagonal seats): a HUD overlay.** The scene already contains a head-on render:
`LocalMultiplayer/JumbotronViewport`, the couch-mode SubViewport whose Camera3D
is parked at seat 1's jumbotron pose, rendering the shared world. `chisel_gauntlet.gd`
now mirrors it full-screen — a runtime `CanvasLayer(1)` + `TextureRect`, 0.5 s
fades — for as long as the local player's camera animation is
`look at jumbotron*`, hooked via `player_spawn_node.child_entered_tree` →
each player's `camera_animation_player.animation_started` and filtered to the
local player by `player_presence.network_id` (vanilla's own test). Roster gate
is a flag latched inside the existing `zz_mod_add_stations_rpc()` — the one
call already made on every peer exactly when the roster exceeds four — so
1-4 never runs it and no RPC was added (`rpc_prefix` still 8). No scene edit.
Two things found only by looking, both silent in the logs:

- **Lighting.** Online, the room is lit solely by each player's own `lights`
  node at their seat (`chisel_gauntlet_player.gd`, local player only; the
  scene-root `Lights` ship hidden), so the seat-1 render varied by seat and
  went black off-cardinal — only the unshaded CRT face survived (maintainer's
  screenshot). Now, while the overlay is up, `LocalMultiplayer` and its four
  cardinal `Lights` (couch mode's lighting for this very viewport; the
  hidden ancestor would otherwise keep them off) are shown and the local
  seat light hidden, so every client renders the identical picture; on hide
  the viewport is frozen (`UPDATE_DISABLED` keeps its last frame) and the
  lights swapped back *before* the fade, so nothing pops.
- **Seat 1's head.** The rig's hat sits ~4.8 u up and seat 1's third-person
  model stands 0.77 u in front of that camera, so its head crossed the frame
  bottom on every client but seat 1's own. Couch mode dodges it with
  per-player cull layers; online now sets the overlay camera's `near` to 2.0
  while shown (nothing else in view is nearer than the jumbotron at ~5.7 u),
  restored on hide.

| Check | Result |
|---|---|
| Static checks | all five pass on every build; `rpc_prefix` 8 mod RPCs (none added) |
| 8-player pinned run (`START=1`, 130 s), final build md5 `a9239274…` | 0 `Parse Error`/`SCRIPT ERROR` on host and all 7 clients; `[STATIONS]` `found` ×10 per round + `cloned 10 single nodes, hid 2 props` on all 8 peers (2 rounds this run, 3 in the earlier two); `[SHOTGUN]` 0,4,2,6,1,5,3,7; full `RoundInstruction` cycle on clients |
| 4-player parity | `player_count=4`, no found/cloned/hid lines on any peer; `[SHOTGUN]` 0,2,1,3 |
| Error classes (pitfall-12 filter) | 8p vs 4p `comm -13` **empty** on the final build; run 2 showed the documented run-to-run `ERR_UNAUTHORIZED` despawn-churn line only |
| Warnings sweep | no `push_warning`/light/viewport/camera/texture lines on any peer, any run |
| Eyes | **maintainer, 2026-08-16, three looks on the tiled harness windows:** first build — overlay shows and clears but is unlit and differs per seat (screenshots); second — "the screens look good", one head poking into the frame; final build — **"Looks good."** |

Not covered by any trace by design (maintainer declined one: everyone gets
the overlay, easy to check by eye): the overlay's presence, lighting and
framing rest on the looks above. Logs of all three run pairs are preserved
machine-locally (`NOTES-LOCAL.md`). `MINIGAMES.md` §10's chisel bullet
carries the mechanism; "Current status" the one-liner.

### 2026-08-16 — Steam lobby at 5-8: the runtime preview spread stacked seats 2-4 on one chair; replaced by hand-placed lap seats for players 5-8, positioned live in the game (issue #14)

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

### Archived 2026-08-16 — every entry older than the v1.4 release (2026-08-13 … the 2026-08-15 v1.3 release)

Moved **verbatim** to `SESSION-LOG-ARCHIVE.md` at the v1.5 release, per rule 3
of the documentation policy. Their durable content lives in the sections
below; read those, not the archive copy, unless you want the reasoning:

| Entry | Now owned by |
|---|---|
| 2026-08-15 — Shipped as mod release v1.3 (issues #10, #12) | "Current status" (release paragraph), pitfall 32 |
| 2026-08-15 — Duck Hunt's silent rifle and black-screen wedge: a peer dropping DURING a load (issues #10, #12) | pitfall 32, `MINIGAMES.md` §19 and §23, Testing "Simulating a peer crash during a minigame load" |
| 2026-08-14 — first real 8P-modded Steam session on v2.1.2: black-screen incident, issues #10 and #11 | Open items (issue #11), pitfall 32 |
| 2026-08-14 — installer: backup feature removed entirely (issue #9) | Toolchain (`installer/install.py`), "Update procedure" step 8 |
| 2026-08-14 — REBUILT AGAINST GAME v2.1.2 (largest patch yet) | "The last update, and how it was verified", "Update procedure" step 4, pitfall 25 |
| 2026-08-14 — UPDATING.md split: pitfalls to `PITFALLS.md`, session log to this file | "What is where", "Documentation policy" |
| 2026-08-14 — the checks wired into the working docs, plus a pre-push hook | "Version control" (static checks, pre-push hook) |
| 2026-08-13 — CI: five static checks committed as scripts, run by GitHub Actions | "Version control", `tools/checks/` |
| 2026-08-13 — Shipped as mod release v1.2, a FULL release: open item 3a closed | "Current status" (vanilla-compat paragraph), Open item 3a |
| 2026-08-13 — Chisel: the 135° slot's player stood inside the corner barrel stack | `MINIGAMES.md` §10 (chisel bullet, `MOD_HIDE_PROPS`), issue #8 |
| 2026-08-13 — Chisel's station clone list duplicated the room's collision environment | `MINIGAMES.md` §10 (chisel bullet, `MOD_STATION_NODES`) |
| 2026-08-13 — Chisel Gauntlet's spectate-marker clones carried a Label3D's transform; expander parse bug fixed | pitfall 31, `MINIGAMES.md` §10, issue #7 |
| 2026-08-13 — Playlist cap filter counted demoted spectators; a 9th connection dead-ended the session | `MINIGAMES.md` §3, "Current status" |

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

Everything older than the v1.4 release (2026-08-15) is in
**`SESSION-LOG-ARCHIVE.md`**, verbatim (the two stub tables above name what
owns each), as is any later entry
whose conclusions have since been folded completely into the live sections —
and at each release everything older than the previous release moves there
(documentation policy, rule 3). That file is verbatim — not a summary; nothing was condensed out
of it. (Both files are in git since 2026-08-08, but the archive, not git
history, is the intended reading surface; see rule 3 of the documentation
policy.)

Its durable content is already folded into `MINIGAMES.md`'s numbered sections
and the pitfalls list, so read it only when you want the reasoning behind a
decision rather than the decision itself.
