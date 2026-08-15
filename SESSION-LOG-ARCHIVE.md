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
