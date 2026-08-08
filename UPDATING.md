# Machine Party 8-Player Mod — working notes & update guide

Hand this whole file to a fresh assistant session. It assumes **no memory** of
how the mod was built, and covers both *continuing development* and *rebuilding
after a game update*.

**This file is the entry point and is meant to be read end to end.** The
per-minigame detail — every change the mod makes, minigame by minigame, plus the
diagnostic traces and the caps — lives in **`MINIGAMES.md`**, because you only
need it once you are touching a specific minigame. Split out 2026-08-04, when
this file had grown past the point where one read returned all of it.

## What is where

| | |
|---|---|
| **Start here → "Paste this to start"** | including the variant for "the game just updated" |
| **"Current status"** | what works, what is unproven, and "Open items" — where to pick up |
| **"Working environment"** | screenshots, missing tools, the build pre-flight. Read before running anything |
| **"Session log"** | what changed most recently and what evidence backed it |
| **"Overlay manifest"** | every file in `mod/`, mapped to the `MINIGAMES.md` section explaining it |
| **"Update procedure"** | the eight steps for rebuilding against a new game version |
| **"Testing — the validation recipe"** | the 8-client harness and the traps in it. Cited everywhere as *Testing* |
| **"Pitfalls"** | 29 numbered failure modes. Cited from code as *pitfall N* — stable, do not renumber |
| **"A rule to preserve"** | 1-4 stays vanilla, and the two accepted breaches |
| **"Documentation policy"** | how this doc set stays lean — read before editing any of these files |
| **`MINIGAMES.md`** | sections 1-22, the per-minigame reference. Cited as *§N* |

Two numbering schemes are load-bearing because code comments cite them:
**rule N** and **pitfall N** both refer to this file. **§N** always means
`MINIGAMES.md`.

## Documentation policy

The reader of these files is a future session's context window, so every
sentence costs. Four rules, applied whenever any of them is edited (requested
by the maintainer, 2026-08-08):

1. **One authoritative home per fact.** New information goes to the one place
   it belongs; everywhere else references it (*§N*, *pitfall N*, or a section
   name). The only sanctioned duplication is an entry-point file repeating a
   safety-critical rule so no session can miss it — and such a copy must say it
   is a copy and name its source (`CLAUDE.md` is the example).
2. **Tighten wording, never substance.** Rules, measurements, and the *why*
   behind each are the load-bearing content — a rule with its rationale
   stripped reads as optional to a future session. Cut narration; keep causes.
3. **Archive, don't delete.** A session-log entry whose conclusions have been
   folded into "Current status" or "Pitfalls" moves to
   `SESSION-LOG-ARCHIVE.md`.
4. **Snapshot before restructuring.** These docs are not under version
   control; copy them aside (the `*_old` idiom) before any large
   reorganisation, then check the new text still answers every question the
   old text answered.

---

## Paste this to start

> I maintain an 8-player mod for the Steam game Machine Party, at
> `~/Documents/Claude/machine-party-8p`. Read `UPDATING.md` in that folder
> first — it documents the current state, the toolchain, every change the mod
> makes, how to test with 8 local clients, and the failure modes already hit.
> Then <describe what you want: e.g. "playtest Debris Platforms at 8 players",
> or "the game updated, rebuild the mod against the new version">.
>
> Five hard rules:
> 1. Never modify anything inside the Steam install directory — copy it out.
> 2. Never pass a shell-expanded path like `$PWD/...` to `install.py`;
>    always type literal absolute paths.
> 3. A 1-4 player lobby must stay pixel-identical to vanilla — with two
>    documented exceptions; see "A rule to preserve".
> 4. Verify with the `-localtest` traces on a **client** window, not a host
>    screenshot — see "How to verify anything".
> 5. Never take a blind full-screen screenshot — see "Working environment".

The mod currently targets **v1.5.0**. Read "Working environment" before
running anything, and "Session log" for what changed most recently.

**If the game has just updated, replace that last line with this** — it is the
one instruction that decides whether the rebuild takes an hour or a day:

> The game updated to v&lt;new&gt;. Rebuild the mod against it following "Update
> procedure" in `UPDATING.md` — but do **step 4 before touching the overlay**:
> diff the old and new decompiles, then run the `filecmp` sweep to prove which
> of the 53 overlay files have byte-identical upstream source. Re-derive only
> the files that actually changed; carrying the rest forward is **provable, not
> a shortcut**. Then run the `.tscn` audit in step 5 — that is the check that
> caught `disco_dodge`'s missing `spawn_limit`.

The two updates measured so far bracket the range, which is exactly why you
measure rather than guess:

| | overlay files needing re-derivation |
|---|---|
| v1.0.6 → v1.0.7 | **2 of 35** (one line of script plus localisation) |
| v1.0.7 → v1.5.0 | **7 of 50** (a new game mode, an engine bump, two gameplay fixes) |

Re-deriving all fifty by hand would be days of work and every hand-edit a chance
to drop a change; carrying all fifty forward blindly would have silently reverted
two upstream bug fixes that landed in files the mod owns. **Measure the patch
first. Do not assume a small update, and do not assume a big one.**

---

## The facts

| | |
|---|---|
| Game | Machine Party, Steam AppID **4108000** |
| Engine | Godot **4.5.2** (`.pck` format v3 — unchanged by the 4.5.1 → 4.5.2 bump) |
| Mod built against | game **v1.5.0** |
| Install (this machine) | `/mnt/secondary/SteamLibrary/steamapps/common/party project/Machine Party_Linux/` |
| v1.0.6 pck MD5 | `e8442750eb55abd0185c646b694b05da` (635,329,556 bytes) |
| v1.0.7 pck MD5 | `01e9d9140a01745dc4236c50c9837bcd` (635,331,268 bytes) |
| v1.5.0 pck MD5 (current target) | `f5912732bfa2cc5cba4340270fd76147` (635,333,716 bytes) |
| v1.5.0 `Machine Party.x86_64` MD5 | `9bac445821a671a8adfd782773fdbdb8` (70,179,064 bytes) — **changed** this update (engine bump); it was identical across 1.0.6→1.0.7 |
| Scope | **Online (Steam/ENet) only.** Local couch play was explicitly out of scope. |

The install folder holds `Machine Party.pck`, `Machine Party.x86_64`, and four
`.so` files. **The mod only ever changes `Machine Party.pck`.**

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

## Current status (read this first)

**Working and verified at 8 players, on host *and* clients:**

- Lobby: 8 seats, 8 character previews, text roster of Steam names.
- Minefield (`exploding_collar_race`) - full rounds played to completion.
- Table Manners (`green_pea`) - 8 seats, 8 chairs, widened camera.
- Chisel Gauntlet - 8 stations, 8 distinct facings, execution device sweeps all
  eight, consoles/desks cloned for the added slots.
- Debris Platforms (`JunkPlatform`) - full round at 8, zero errors. All eight
  land on a deck; see below.
- Stable Footing (`DiscoDodge`) - `[DISCO8] spawned=8` on host and all seven
  clients, with all eight player nodes named. `spawn_limit` raised 4 -> 8, but
  a 2026-08-02 re-measurement shows that cap had no effect either way; see
  `MINIGAMES.md` §10 for the correction.
- Smoke Break (`SmokeBreak`) - 8 seats with two added crates, gun retargeted for
  all eight, four seat-capped arrays fixed. Some player-model clipping remains on
  the left four and is accepted; see `MINIGAMES.md` §14.
- Escalator Pit / **WRONG WAY** (`EscalatorPit`) - 8 stair strips (two per
  trough), 8 CRT screens and 8 input arrows, one player each; handrails and
  divider posts hidden, floor lowered slightly. Stairs, players and arrows all sit at vanilla placement - only
  their count and lateral spacing are modded. See `MINIGAMES.md` §13.
- The intermission score screen and the pre-minigame briefing screen - both
  8 rows at 8 players, both back to 4 rows at 4.
- Tunnel Hazard (`TrainRace`) - 8 spawns, and the level already ships 8 nooks;
  no gameplay edit needed. See `MINIGAMES.md` §16. Its two right-hand added
  spawns sat inside the wall until 2026-08-05, when `spawn_expand.py` gained
  `inward` mode; the traces read 8/8 `OK` throughout, before and after, so
  **treat this one as confirmed only when someone has looked at it.**
- Inside Job (`KnifeAtTheOffice`) - 8 spawns, search target clamped to the
  containers that exist, hunt HUD grown to 8. See `MINIGAMES.md` §17.
- Spine Breaker (`SpineBreaker`) - 8 spawns; full rounds played out at 8, all
  eliminations clean. Needed no *capacity* fix, but its kill pace is now scaled
  to the roster so an 8-player round does not run 2.5x as long as a 4-player
  one; see `MINIGAMES.md` §18.
- Lethal Rebound (`DvdRoomba`) - 8 spawns; three full rounds at 8. No gameplay
  edit needed; hazard count does not scale with the roster (by design).

- Duck Hunt (`DuckHunt`) - **uncapped 2026-08-02**. 7 duck spawn markers built
  at runtime above four players, magazine curve extended to 7 ducks, round
  pacing set so 8 players run 8 hunter turns not 16. See `MINIGAMES.md` §19.
- Forklift Certified (`ForkliftCertified`) - **uncapped 2026-08-04**. Four more
  delivery zones built at runtime at the yard's mid-edges (RPC, every peer),
  four more spawn markers (host-only), the crate sampler given the free centre
  cell and a reachable target, and the four-decal blood pool made to refill.
  See `MINIGAMES.md` §20.

**Every minigame in the rotation has now been played at 8** - all fifteen, since
The Filter and Firearm Factory were uncapped on 2026-08-07. The
"playable but never actually played" list is empty.

**All fifteen have now also been watched at 8 by a person**, which is a stronger
claim than the paragraph above and was not true until 2026-08-08. The last two to
get eyes on them were the last two to be uncapped:

- **Firearm Factory**, over three looks that day, which closed everything on it a
  trace could not: the wall-desk placement, the desks' facing, the ingredient
  clipping and the covered recipe projection. **Two of those four were defects a
  clean trace had already signed off on** — the same lesson as Forklift Certified's
  blood pool and Tunnel Hazard's wall clipping.
- **The Filter (`BurnRecycle`)** — verified by the user at 8 the same day. Its
  two-room layout, per-room elimination and global scoring were already measured
  per peer (see the 2026-08-07 entry); what was missing was somebody looking at it,
  and that is now done. Nothing was reported wrong.

So "measured but never observed" is empty as a category. **What remains is open
item 1, and it is untouched by any of this:** the harness runs unattended
instances, so nobody has *played* an eight-human session anywhere, and scoring,
elimination order and win conditions at 8 rest on idle-instance behaviour in every
minigame. Being watched is not the same as being played — do not let this
paragraph be read as closing that.

**Arcade mode (new in game v1.5.0)** — a 10-minigame session with random round
counts and no intro/outro. It works under the mod, and the mod filters its
playlist by the player caps the same way the other two branches are filtered; see
`game.gd` and the 2026-08-05 session-log entry. At 1-4 players it is untouched
vanilla. **It has never been run** — no local harness can reach it, because
`-localtest` always enters through the debug lobby. Treat it as unproven.

**Removed from the rotation on purpose:** the wheat-field cutscene
(`CutsceneTest`) is no longer in `default_playlist` at any roster size - the
mod's one sanctioned break from the 1-4-stays-vanilla rule. It is still
launchable via `-debug-tools`.

**Always write the identifier next to the display name.** They overlap almost
nowhere, and `MinigameReadableNames` (globals.gd:178) is the only authoritative
map. This list previously said "Wrong Way" and "Stable Footing" were untested
while both had in fact been worked on and verified - **Wrong Way is
`EscalatorPit` and Stable Footing is `DiscoDodge`**. Full map:

| Display name | Identifier | | Display name | Identifier |
|---|---|---|---|---|
| SMOKE BREAK | `SmokeBreak` | | DUCK HUNT | `DuckHunt` |
| FIREARM FACTORY | `ManufactureGun` | | LETHAL REBOUND | `DvdRoomba` |
| WRONG WAY | `EscalatorPit` | | DEBRIS PLATFORMS | `JunkPlatform` |
| CHISEL GAUNTLET | `ChiselGauntlet` | | SPINE BREAKER | `SpineBreaker` |
| MINEFIELD | `ExplodingCollarRace` | | THE FILTER | `BurnRecycle` |
| TUNNEL HAZARD | `TrainRace` | | FORKLIFT CERTIFIED | `ForkliftCertified` |
| STABLE FOOTING | `DiscoDodge` | | TABLE MANNERS | `GreenPea` |
| INSIDE JOB | `KnifeAtTheOffice` | | | |

`ShapeCutter`, `ScavangerChairs`, `MemorizePath` and `CutsceneGame02` map to
`LOC_EMPTY` and are in neither playlist. `CutsceneTest` is in *vanilla's*
`default_playlist` but is a cutscene, not a competitive game — the mod removes it
at every roster size (see "The first sanctioned exception").

**"Verified" above means 8 players spawn correctly, the layout is right on
clients, and runs are error-free.** The instances idle - nobody plays - so
scoring, elimination order and win conditions at 8 remain unproven everywhere.

**Debris Platforms notes (verified 2026-08-01).** The four shipped markers sit
exactly on the four Platform centres, and a platform deck is a
`CylinderShape3D` of radius **6.0**. `spawn_expand.py` clones each marker 1.2u
along its local X, so the added slots share a deck with an original: the worst
measured landing was 1.56u from a centre, well inside the radius. Two players
per deck is the resulting layout - playable, and scoring is last-man-standing so
nothing assumes one player per platform. `spawn_players()` indexes
`player_spawn_position_node.get_child(i)` rather than a parallel array, and
neither `MultiplayerSpawner` in the scene sets `spawn_limit`, so pitfalls 11 and
13 both come out clean here. Camera facing is derived from `position.z < 0`,
which the clones inherit: the 8-player split is 4/4, as vanilla is 2/2.

- The Filter (`BurnRecycle`) - **uncapped 2026-08-07**, as **two rooms** rather
  than eight stations in one ring. Balanced rooms (5 -> 3+2, 7 -> 4+3), per-room
  elimination at vanilla pace, global scoring with same-round ties resolved
  upward. See `MINIGAMES.md` §21.

- Firearm Factory (`ManufactureGun`) - **uncapped 2026-08-07**. 8 spawn markers
  and 8 workstations built at runtime at the arena's mid-edges, ingredients
  scaled with the roster. The two turned wall desks were pushed out to the wall
  on **2026-08-08** (`MOD_WALL_DESK_PUSH`), closing the last item on it. See
  `MINIGAMES.md` §22.

**Capped at 4 players: NOTHING.** `modded_minigame_player_cap` now holds only
`ScavangerChairs`, which is in neither playlist and unreachable. **Every minigame
in the rotation supports 8 players.**

**All four entries that table ever held have been uncapped, and only The Filter's
recorded reason survived inspection.** Three of four stated reasons were wrong on
examination - re-derive, never trust, any cap reason written here.

**Never verified:** the Steam lobby's preview rendering (`-localtest` runs the
debug lobby, so `lobby_scene.tscn`'s extra slots are validated as loading but
never seen with 8 real players).

**Pre-existing vanilla bug, not worth fixing:**
`scripts/scenes/game/states/minigame_end_state.gd:28` calls
`update_playlist_state_rpc.rpc(owner.session_minigame_list)` with one argument
against a three-parameter function, so every minigame end logs
`Method expected 3 argument(s), but called with 1`. That file is **not** in
`mod/` - the error is identical at 4 and 8 players and predates the mod. The
`rpc_id` call in `game.gd` carries the real playlist state. Do not mistake it
for mod breakage when reading logs.

**A 1-4 player game is meant to be pixel-identical to vanilla** - see the rule
below, and re-check it after any change. There are exactly **two accepted
breaches**, both signed off by the user and both written up under that rule: the
wheat-field cutscene is gone from the playlist at every roster size, and nine
expanded scenes can seat a 1-4 player 1.2u sideways of a vanilla spawn. Neither
is a bug to fix; anything *else* that differs at 1-4 is.

### Open items, in rough priority — where to pick up

Nothing is broken. As of **2026-08-08** the mod builds clean against **v1.5.0**,
installs and uninstalls byte-identically (re-verified that day on a clean copy),
and every rotation minigame has been verified at 8 with a *positive* trace count
rather than absence-of-errors — and, since 2026-08-08, watched at 8 by a person as
well. **Firearm Factory and The Filter, the last two uncapped, are both fully
closed.** What remains:

0. **Three things came out of the v1.5.0 rebuild.** One is a real 8-player
   defect that is noted rather than fixed, one was investigated and closed the
   same day, and one is a new code path nothing can exercise locally. None
   blocks:
   - ~~**Tunnel Hazard spawns clip into the wall**~~ **Fixed 2026-08-05** with
     `spawn_expand.py`'s new `inward` mode; see the session-log entry. The two
     right-hand clones moved from x=4.62/5.31 (inside the wall) to x=2.22/2.91.
     **Still wants your eyes**, because no trace can confirm it: `[TRAIN8]` read
     8/8 `OK` before the fix and reads 8/8 `OK` after.

   - ~~**`START=1` hangs Duck Hunt permanently**~~ **Fixed 2026-08-05** (found by
     the user, after three days mis-documented as a harmless overlay artifact).
     The hunter's `can_aim` is now enabled and the role overlay cleared on all
     eight peers when `debug_skip_brief` skips `RoleReveal`.

     **Still open, and a separate cause: Duck Hunt cannot complete unattended at
     all.** A duck leaves `duck_players` only by reaching the finish corridor or
     being shot, and idle instances do neither — so the turn never ends under
     `START=1` **or** `FLOW=1`. Duck Hunt is **5th** in the 15-entry rotation
     (measured 2026-08-08; `ManufactureGun`'s uncapping moved it down one), so
     **no unattended rotation run can reach the ten minigames after it**; pinning
     with `MINIGAME=` is the only full-coverage method. Closing this needs input
     injection or bots, which is open item 1 — it is not a Duck Hunt bug.

   - **Still open: every expanded pair starts interpenetrating.** Measured in
     Tunnel Hazard 2026-08-05 — markers are placed `OFFSET`=1.2u apart, but each
     pair settles ~1.58-1.60u apart once physics resolves the first frame, on all
     three pairs measured. **So a character is ~1.6u wide and 1.2 is too small**,
     which is the "clipped into ... other player" half of the original report.
     `MIN_CLEARANCE` (1.0) is under-set for the same reason.

     This is **not** Tunnel Hazard-specific: the same 1.2 is used for all fifteen
     expanded scenes, so every one of them spawns overlapping pairs that shove
     apart on frame 1. It has never been visible in a trace, and evidently was
     not obvious on screen until someone looked at a corridor narrow enough to
     make it obvious. Raising `OFFSET` is a one-word change but it moves players
     in fourteen verified scenes, so it wants a decision and a look, not a
     drive-by — and in `inward` mode a larger offset moves clones further toward
     the middle of the level, which is safe from walls but not automatically
     right (in Tunnel Hazard it walks them toward the train's centreline).

     **This is probably the most actionable item left, and 2026-08-08 supplied a
     second instance of the exact same mistake.** Firearm Factory's
     `MOD_ITEM_SPREAD` was 0.45u while the things it separates are 0.63-1.61u
     wide, so every doubled ingredient interpenetrated — a separation constant set
     smaller than the object it separates, found by a person looking, invisible to
     every trace, and fixed by measuring the object instead of guessing. `OFFSET`
     = 1.2 against a ~1.6u character is the same bug in the same shape, still open,
     across fourteen more scenes. **The method that worked: measure the thing's
     actual footprint out of its `.tscn`, then check the candidate value against
     what is around each site before changing it.**

     **Analysed 2026-08-08, from scene colliders only — computed, NOT seen. No
     part of this has been verified by eye or in game, and the decision is the
     user's.**

     - **The authored collider is a `CapsuleShape3D` of radius 0.7 (1.4u
       across), identical in every physics-bodied player scene.** The measured
       settle is ~1.6u, ~0.2u wider, and *why* is not established — candidates
       are depenetration overshoot, `safe_margin`, and residual shove velocity.
       **Design against the measured 1.6, not the authored 1.4.**
     - **Candidate: `OFFSET` 1.7 with `MIN_CLEARANCE` 1.6.** At 1.7, **12 of the
       14 baked scenes move linearly along the same ray**, so their clones stay
       where the audits already checked them. The two that do not: `shape_cutter`
       re-ranks non-linearly and flips sides by `OFFSET` 2.0; `smoke_break`'s
       baked seats are hand-authored, coupled to `rot_by_seat_index_array` and
       the camera edge, and **must never be regenerated by the tool**.
       `escalator_pit` is immune either way — its script overwrites all eight
       marker positions at runtime.
     - **Two clone sites compute as being INSIDE solid geometry at the current
       1.2**, which is the Tunnel Hazard wall bug again and equally invisible to
       every trace — the spawn audits measure distance to the nearest *marker*
       (`MOD_DISPLACED_DIST` = 2.0), never distance to geometry:
       `knife_at_the_office`'s `Marker3D4_MOD8` (0.46u from a desk collider,
       against a 0.8u body radius) and `exploding_collar_race`'s
       `player spawn 1_MOD6` (0.53u from a pillar). **Raising `OFFSET` barely
       helps either**; running those two scenes through `inward` mode fixes both
       outright (computed clearances 1.81u and 3.28u at 1.7). Unconfirmed by eye.
     - **Green Pea is coupled to this number.** `MOD_CHAIR_NARROW` (0.6) was
       derived as 1.2/2.0, so an `OFFSET` change means re-tuning it and
       re-checking the camera constants in `green_pea.gd` — **not** re-running
       the legacy chair tool; see Toolchain.
   - ~~**A new error class at 8 only:** `ERR_UNAUTHORIZED`~~ **Closed
     2026-08-05, same day.** Measured at both roster sizes on 4.5.2 (~12 lines
     per peer at 4 and at 8) and present on 4.5.1 too, so it is neither new nor
     player-count-specific — ordinary despawn churn. No filter entry needed; see
     the session-log entry for why adding one would cost more than it saves.
   - **Arcade mode has never actually been run.** The mod's filter on it is
     verified by reading, not by playing: `GameManager.arcade_game` is set by the
     main menu's Arcade button, and `-localtest` always enters through the debug
     lobby, so no local harness reaches that branch. The filter's *inputs* are
     verified (13 minigames survive the cap filter at 8, so the clamp to 10 does
     not bind), and the file parses and loads. That 13 was measured 2026-08-05
     with two caps still in place; since 2026-08-07 nothing reachable is capped,
     so the filtered whitelist at 8 is simply the whole whitelist and the clamp
     still does not bind. Exercising the branch itself would need either a real
     Steam session or a test flag that does not exist yet.

1. **Nobody has ever *played* an 8-player session.** The harness runs eight
   unattended instances, so scoring, elimination order and win conditions at 8
   are unproven **everywhere**. This is the single largest gap and it is
   structural — closing it needs in-game bots or input injection, neither of
   which exists. A human can drive exactly one window.
2. ~~**Firearm Factory's two wall desks want moving CLOSER to the wall.**~~
   **Moved 2026-08-08** with `MOD_WALL_DESK_PUSH` (2.05u), which puts them 0.75u
   and 0.66u off the wall face - the same margin shipped `Marker3D2` leaves
   against the −X wall, and as close as vanilla ever puts a desk. `MOD5` is now
   at (5.48, −9.93) and `MOD7` at (−2.02, +10.00); the `[GUN8] expand` trace
   prints all four added desks so the placement is checkable from a log. See
   `MINIGAMES.md` §22 for the measurement and why 2.05 rather than 2.4.

   **Signed off by the user on 2026-08-08: "the new desk positions look good."**
   The two issues raised in the same look — 2a and 2b below — were fixed the same
   day and both confirmed: *"Both fixes worked. It looks good to go."*

   ~~**Unconfirmed: whether the desks' working faces point the intended way**~~
   **Closed 2026-08-08 — confirmed by eye: "the desks are facing the right way."**
   `MOD_WALL_DESK_TURN_DEG`'s sign is correct. That was the last thing on this
   minigame that no trace could settle, and it had been open since the uncapping.
   Note what closed it: a person looking, twice, at three different things. The
   traces were clean the whole time.

2a. ~~**Ingredient clipping.**~~ **Fixed 2026-08-08**, `MOD_ITEM_SPREAD` 0.45 →
   **1.10**. The item variations are 0.63-1.61u wide, so 0.45 put every doubled
   pair inside itself. 1.10 is `(w1+w2)/2` for the average pair, checked against
   the surface under each of the 26 markers. See `MINIGAMES.md` §22.

2b. ~~**`MOD8`'s desk covered the ingredient projection.**~~ **Fixed 2026-08-08.**
   The recipe hologram is one node in the level, and the added bottom-centre desk
   sat on top of its middle three slots. The user ruled out moving the desk
   (balance) and asked for the projection to be raised by its own height: it
   measures its own subtree at runtime (1.8741u) and lifts to y 2.495-4.369, clear
   of the desk's 2.14 top, by RPC on all eight peers. Confirmed by eye. The
   0.026u gap between the hologram's underside and a workstation's gun-assembly
   height (§22) was not a problem in practice, but it is recorded because it is
   thin enough that a future change to either number could make it one.

   **Firearm Factory is now fully closed.** Nothing on it is outstanding beyond
   open item 1, which applies to every minigame.

   One measurement made while doing this, worth knowing before touching the turn:
   the workstation's interact box is reachable from **all four sides**, because
   the player's own interact area is a radius-1.0 cylinder projected 1.0u ahead of
   them. So the approach axis decides how a desk reads and how much floor the
   player has - not whether interaction fires. §22 has the working.
3. **The Steam lobby's 8 previews have never been seen.** Structurally
   unverifiable locally — `lobby_scene.gd` has 12 `Steam.` call sites and its
   join path is built on Steam lobby callbacks, so the real lobby cannot run
   over ENet. Needs a real 8-player Steam session.
4. ~~**Spawn-marker *selection* at 1-4 deviates from vanilla.**~~ **Closed
   2026-08-04 — decided, not fixed.** Nine scenes (six live) can seat a 1-4
   player 1.2u sideways of a vanilla spawn, same rotation, same floor. Judged
   too minor to justify touching nine minigames. Not an open item any more; see
   "Spawn markers are visible to 1-4 player games too" for the scope table, the
   evidence that would reopen it, and the two fixes if it ever does.
5. **`Parameter "data.tree" is null`** — 1-3 benign lines at the instant a round
   ends, a vanilla coroutine resuming after its node left the tree. Only 8-only
   error class left. Deliberately not chased.
6. **Smoke Break player-model clipping** on the left four seats. Cause is seat
   facing, not spacing; blocked by pinned seats and the camera frame. Accepted.

Fully closed, with per-peer measurements: Duck Hunt (markers, magazine,
animation timing, round pacing, spawn counts), Spine Breaker (pacing), Inside
Job (search economy, hunt HUD), Stable Footing, and the score/briefing screens.

## Working environment (read before running anything)

Facts about *this machine* that are not in the code and cost time to rediscover.

**Screenshots.** The desktop is **Wayland** (`XDG_SESSION_TYPE=wayland`) with
XWayland present, so `DISPLAY=:0` is set but the X root window is **empty** -
`scrot` and ImageMagick `import` return a uniformly black image (1 unique
colour). Use KDE's tool instead:

```bash
spectacle -b -n -f -o /path/out.png     # -b background, -n no notify, -f full screen
```

`xdotool` and `wmctrl` are **not installed**, so there is no way to target or
raise a specific window from the shell.

**Because of that, do not take blind full-screen captures.** The game window is
not reliably frontmost, and a full-screen grab picks up whatever else is on the
desktop - during this project one such capture accidentally caught unrelated
private content from another application, and was discarded unused. **Ask the
user to screenshot instead.** They have done so throughout and it is the safe
loop. `-localtest` traces are the primary evidence anyway; a screenshot is for
judging *looks*, which the user is better placed to do.

**Layout viewer.** An interactive 3D layout viewer exists for Smoke Break's
seats, crates and props. Its URL and re-sync caveat are in `NOTES-LOCAL.md`
(untracked, this machine only).

**Default to the fast path.** Use `START=1` for playtests; only use `FLOW=1`
when the user asks or when the session loop itself is the thing under test.
`FLOW=1` skips nothing, so a run takes far longer. (Also stored as a user
memory, but memory is namespaced to `~/Documents/Claude` - a chat started
*inside* this folder will not load it.)

**Pre-flight before every build**, because a bad format specifier in a minigame
script is invisible until that minigame loads (see pitfall 16):

```bash
python3 - <<'EOF'
import re, glob
strlit = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
spec = re.compile(r'%[-+ 0#]*[\d*]*(?:\.[\d*]+)?([a-zA-Z%])')
ok = set("scdoxXfv%")
for f in sorted(glob.glob("mod/**/*.gd", recursive=True)):
    for n, line in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
        for s in strlit.findall(line):
            for m in spec.finditer(s):
                if m.group(1) not in ok:
                    print(f"{f}:{n}: invalid %{m.group(1)}")
EOF
```

---

## Session log

Newest first. Each entry is what changed and what evidence backed it, so a new
chat can judge how solid a claim is rather than re-deriving it.

### 2026-08-08 (latest) — GitHub release prep: root-installable restructure, personal-info scrub, repo staged but not published

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
(`DEV-PERMISSION-DRAFT.md`, untracked, is the ask). When it lands: fill
`NOTICE.md`'s two placeholders, flip visibility, and attach
`dist/machine-party-8p-mod.zip` to a GitHub Release — the zip never goes in
git.

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
| Patched pck carries the source | `MOD_WALL_DESK_PUSH` and `mod_raise_item_preview_rpc` grep out of it |
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
already in this file:

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
| Today's changes present in the installed pck | `MOD_WALL_DESK_PUSH`, `mod_raise_item_preview_rpc` and `MOD_ITEM_SPREAD: float = 1.10` all grep out of the patched `.pck` — the mod ships plain `.gd`, so this is a direct check that the artifact carries the source, not just that the installer ran |

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
errors a run; `mod_set_room_rpc` declared `@rpc("authority")` was rejected
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

Moved to **`SESSION-LOG-ARCHIVE.md`**, verbatim, because it duplicated the live
text almost sentence for sentence. The authoritative account — the mechanism, the
fix, the second cause that is *not* fixed, and the lesson — is in Testing under
**"`START=1` HANGS Duck Hunt permanently"**. Read that, not the archive copy.

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
in "The last update, and how it was verified" above; this entry is the evidence.

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

### Older entries

Everything before 2026-08-03 is in **`SESSION-LOG-ARCHIVE.md`**, verbatim, as is
any later entry whose conclusions have since been folded completely into the live
sections above — each of those leaves a stub here naming the section that owns
the material. This project is not under version control, so that file is the only
copy — it is not a summary and nothing was condensed out of it.

Its durable content is already folded into `MINIGAMES.md`'s numbered sections
and the pitfalls list, so read it only when you want the reasoning behind a
decision rather than the decision itself.

## Layout

Documentation, and which file owns what:

```
UPDATING.md   entry point: status, rules, update procedure, testing, pitfalls
MINIGAMES.md  per-minigame reference, sections 1-22, cited as §N
SESSION-LOG-ARCHIVE.md  verbatim older session-log entries, plus later ones
              moved once fully folded into the live sections, each leaving a
              stub behind (no git; only copy)
README.md     player-facing overview. NOT authoritative - the two above win
CLAUDE.md     auto-loaded pointer for sessions started inside this folder
```

```
extracted/   pristine unpack of the shipped .pck (reference; regenerate on update)
project/     full decompile via GDRE Tools — readable .gd / .tscn source
mod/         the overlay: ONLY the 53 files that differ (see the manifest)
dist/        built "Machine Party.pck" + machine-party-8p-mod.zip (release zip)
install.py, install.sh, install.bat   root-level installer scripts; the release
              zip is built directly from these plus README.txt and mod/, with
              no separate installer/ copy
testgame/    throwaway copy of the game install, for test runs
testgame_new/ clean UNMODIFIED v1.5.0 copy - installer round-trip target
project_old/ v1.0.7 decompile, kept as the diff baseline for step 4
extracted_old/ v1.0.7 raw extraction, same purpose
mod_v107/    the v1.0.7 overlay, kept for reference

  The four above are ~2.8 GB of update scaffolding. On the NEXT update they
  become stale: project_old/extracted_old must be replaced by the v1.5.0
  decompile (that is what `mv project project_old` in step 2 does) and
  mod_v107/ superseded. Delete them once that update lands.

project_v106/, extracted_v106/, mod_v106_ref/
  The PREVIOUS generation of that scaffolding (v1.0.6), now two updates stale
  and safe to delete - ~2.1 GB. They were renamed aside rather than removed
  during the v1.5.0 rebuild only because this environment's sandbox refused the
  `rm -rf`; nothing references them. Deleting them is the intended end state:

    rm -rf project_v106 extracted_v106 mod_v106_ref

  Note for step 2 generally: `mv project project_old` **nests** rather than
  replaces if `project_old/` already exists, which would put the new decompile
  at `project_old/project/` and make every step-4 diff meaningless. Clear or
  rename the previous generation first.
tools/       pck.py, gdc.py, build.py, spawn_expand.py, lobby_expand.py,
             green_pea_chairs.py, spawn_targets.txt, localtest.sh, bin/
docs_old_2026-08-08/  snapshot of all five docs taken 2026-08-08 under
             Documentation policy rule 4, before the v1 release audit's doc
             restructure. The pre-restructure text, if a question needs it.
userdata_backup/  a backup of the game's user data (saves, settings, shader
             caches), ~41 MB. Not a deliverable and nothing references it.
```

## Toolchain

- **`tools/bin/gdre_tools.x86_64`** — GDRE Tools v2.6.3. Decompiles the `.pck`
  into readable GDScript and `.tscn`.
- **`tools/pck.py`** — reads/writes Godot 4.5 PCK v3. `list` / `extract` / `pack`.
- **`tools/build.py`** — builds `dist/Machine Party.pck` from `extracted/` + `mod/`.
  `MP_DEPLOY=<dir>` also copies the result into a game folder.
- **`tools/spawn_expand.py`** — rewrites a scene's 4 player-spawn markers into 8.
- **`tools/lobby_expand.py`** — clones a lobby's 4 character preview slots into
  8 and extends the handler's exported arrays. `PARENT=...` overrides the node
  path.
- **`tools/localtest.sh`** — launches N instances locally over ENet (see
  Testing). `START=1` plays a minigame, `MINIGAME=<Identifier>` pins one,
  `FLOW=1` runs the **full normal session loop** instead of the fast path, and
  `ARGS="..."` appends arbitrary flags to every instance, for minigame-specific
  test aids (`ARGS="-kato-hunt=8"`, `ARGS="-original"`).
- **`tools/green_pea_chairs.py`** — **LEGACY, superseded by `green_pea.gd`'s
  runtime layout. Do not re-run it against the current mod.** It bakes chair
  transforms into the `.tscn`: it rewrites the four *shipped* chairs and emits
  its clones without `visible = false`, so a 1-4 dinner scene would stop being
  pixel-identical to vanilla (rule 3). After changing spawn `OFFSET`, re-tune
  **`MOD_CHAIR_NARROW`** in `green_pea.gd` instead, and re-check
  `MOD_CAMERA_PULLBACK` / `MOD_CAMERA_FOV` with it — see `MINIGAMES.md` §10,
  "scene supplies the nodes; script owns the layout".
- **`tools/gdc.py`** — pulls identifier/constant pools straight out of compiled
  `.gdc` files. Useful for grepping a shipped build *before* decompiling.
- **`install.py`** (project root) — standalone patcher for end users. Carries its own
  PCK reader/writer; depends on nothing in `tools/`. Patches the **user's own**
  pck (unlike `build.py`, which builds from our `extracted/` snapshot), so it
  only swaps the overlay files. `ADDED_FILES` exempts files the mod *adds*
  from the "nothing to displace" compatibility check — without it that warning
  fired on every install because of `mod_player_name_list.gd`, which trained
  users to ignore the one message meant to stop a bad patch. Keep it in sync
  with the overlay.

### The core trick

The mod ships **plain `.gd` and `.tscn` text**, never recompiled `.gdc`/`.scn`.
Godot's release template still contains the GDScript parser and the text scene
loader. In the shipped pck, `res://x.gd` is redirected to `res://x.gdc` by a
small text file `x.gd.remap`. Delete that remap **and** the `.gdc`, drop in a
plain `x.gd`, and the engine loads the source at runtime.

`build.py` does this automatically via its `SUPERSEDES` table. This is why the
mod needs **no Godot export templates and no editor round-trip**.

---

## Overlay manifest — every file in `mod/`, and what documents it

**53 files: 37 `.gd`, 16 `.tscn`.** Regenerate with `find mod -type f | sort`.
On a game update, every one of these must be re-derived from the *new* source —
see step 5 of the update procedure. The "§" column is the section of **`MINIGAMES.md`** that explains the change.

| File | § | Change |
|---|---|---|
| `autoloads/globals.gd` | 2 | version string, 3 suit colours + tints, player caps, `supports_player_count()`, round counts, cutscene removed from `default_playlist` |
| `modules/multiplayer/network_manager.gd` | 1 | `MAX_PLAYERS` 4→8; `-localtest` backend |
| `scripts/scenes/game/game.gd` | 3, 19 | playlist filtering + fallback, **Arcade-branch cap filter + clamp (v1.5.0)**, `-minigame` pin, round-count resolution, `[ROUNDS8] load` |
| `scripts/scenes/game/states/minigame_playing_state.gd` | 19 | the **replay gate** — second round-count site |
| `scripts/components/character customization/customization_assigner.gd` | 4 | suit tinting |
| `scenes/bootstrap/scripts/bootstrap.gd` | 8 | `-localtest`, `-fullflow` |
| `scenes/lobby/lobby_scene.tscn`, `scenes/lobby/scripts/lobby_scene.gd` | 6 | 8 seats + 8 preview slots |
| `modules/multiplayer_lobby/multiplayer_menu.gd` | 6, 8 | debug-lobby seat map, window tiling, `-original` |
| `modules/multiplayer_lobby/mod_player_name_list.gd` | 7 | **the only file the mod adds** |
| `modules/multiplayer/backends/multiplayer_backend.gd` | 8 | window titles P1-P8 |
| `minigames/intermission_new/components/intermission_score_screen.gd` | 11 | 8 rows; reverb pitch clamp |
| `minigames/intermission_new/components/intermission_briefing_screen.gd` | 12 | 8 cards; `FLOW=1` auto-ready |
| `minigames/chisel_gauntlet_multiplayer/*` (4) | 5, 10 | 8 stations, facings, shotgun order, split-screen |
| `minigames/escalator_pit/*` (3) | 13 | 8 stair strips, hidden handrails |
| `minigames/smoke_break/*` (4) | 14 | 8 seats, crates, aim angles, 4 capped arrays |
| `minigames/green_pea/*` (2) | 10 | runtime 8-seat layout by RPC |
| `minigames/knife_at_the_office/*` (3) | 17 | search-target clamp, 8 hunt icons |
| `minigames/spine_breaker/*` (2) | 16, 18 | spawn audit + roster-scaled kill pace |
| `minigames/duck_hunt/*` (3) | 19 | runtime markers, magazine curve, animation fit, splitscreen, **`debug_skip_brief` reveal-skip repair (`can_aim` + overlay)** |
| `minigames/forklift_certified/*` (2) | 20 | runtime mid-edge delivery zones + markers, crate spawn region and target, blood-decal pool refill |
| `minigames/burn_recycle/*` (2) | 21 | **two-room layout**, balanced rooms, per-room elimination, tie-corrected scoring |
| `minigames/manufacture_gun/*` (1) | 22 | **runtime mid-edge spawns + workstations**, wall-desk turn + slide + **wall push (`MOD_WALL_DESK_PUSH`)**, `empty_desk_array` bounds guard, `spawn_limit` raise by property write, roster-scaled ingredients at **`MOD_ITEM_SPREAD` 1.10**, **ingredient projection raised by its own measured height (RPC, all peers)** |
| `minigames/disco_dodge/*` (2) | 10, 16 | `spawn_limit` 4→8 (inert — see §10), `[DISCO8]` |
| `minigames/junk_platform/*` (2), `train_race/*` (2), `dvd_roomba/*` (2) | 15, 16 | markers + spawn audits |
| `minigames/exploding_collar_race/*` (2) | 10 | `blood_trail.gd` empty-`Curve3D` guard |
| `minigames/cutscene_test/*`, `cutscene_game_02/*`, `shape_cutter/*`, `memorize_path/*` (4 `.tscn`) | 9 | spawn markers only; unreachable scenes, kept defensively |

---

## Reading a property out of a shipped binary resource

GDRE decompiles scripts and scenes, but **not** `.res` resources — animations,
curves and the like stay binary. When a timing number lives in one (as the rifle
animation lengths do), it can still be read without the editor. This is how the
Duck Hunt animation lengths were obtained; the engine later confirmed the figure
to four decimal places.

Two layers:

1. **Container.** `RSRC` is a plain binary resource. `RSCC` is the same thing
   zstd-compressed: header is magic, `cmode` (2 = zstd), `block_size` (4096),
   `read_total`, then one `u32` compressed size per block, then the blocks.
   Decompress each block and concatenate — **the payload has the 4-byte magic
   stripped**, so prepend `RSRC` before parsing. `pyzstd` is installed.
2. **Body.** After the magic: `big_endian`, `use_real64`, `ver_major`,
   `ver_minor`, `ver_format` (all `u32`), the type string, `importmd_ofs`
   (`u64`), `flags` (`u32`), `uid` (`u64`), **11 reserved `u32`**, then the
   string table: a `u32` count followed by that many `u32`-length-prefixed
   strings. Note these strings are **not** padded to 4 bytes, and the table does
   not start on a 4-byte boundary — a scan that steps by 4 will miss it.

Then find the property name's index in the table and search the file for that
`u32` followed by a variant type word: `4` = 32-bit float, `4 | 0x10000` =
64-bit (pitfall 9's `ENCODE_FLAG_64` again).

Measured this way:

| Animation | Length |
|---|---|
| `rifle_pull_bolt_overwrite` | 1.2167 s |
| `rifle_reload_main_overwrite` | 4.0167 s |
| `rifle_equip_overwrite` | 1.9333 s |
| `rifle_before_equip_idle_overwrite` | 0.0167 s (single-frame pose) |

A property absent from the string table means the resource uses **Godot's
default** for it — only non-default values are written. An `Animation` with no
stored `length` is 1.0s.

Prefer reading such a value at runtime (`anim_rig.get_animation(name).length`)
over baking the measured number into the mod. The measurement is for *designing*
the change; the runtime read is what keeps it correct across updates.

## An `@export` node reference survives `duplicate()` pointing at the ORIGINAL

**Found 2026-08-04, by looking at the game — no trace caught it, and none could
have.** Applies to every runtime clone of a scripted node, so read it before
cloning anything.

`@export var border_mesh_instance: MeshInstance3D` is an **object reference**.
The scene stores a NodePath and resolves it once at load, so by the time you
`duplicate()` the node, the property holds a pointer. The copy therefore comes
out pointing at the **template's** child, not its own.

In Forklift Certified's delivery zones that meant each cloned zone drove the
corner zone it was cloned from: `set_owner_rpc` recoloured the template's border
material, `update_counter_rpc` wrote to the template's counter label, and
`set_indicator_light_rpc` played the template's speaker. Two owners writing one
counter.

**Its tell is that there is no tell.** Everything measurable was correct on
every peer — `zones=8`, `owned=8`, eight distinct owner ids, the marker/zone
pairing, zero errors and zero warnings — because `belongs_to_id` and the rest of
the script state live on the clone itself. Only the *nodes it reaches through*
were shared. The visible symptom was that the four added zones rendered as bare
floor, because the shipped border material is `albedo_color = Color(0, 0, 0, 1)`
and stays black until `set_owner_rpc` recolours it. A player noticed; a log
never would.

The fix is `_mod_rebind_zone_exports()` in `forklift_certified.gd`: for each
exported reference, ask the **template** where that node sits relative to itself
(`template.get_path_to(ref)`), then resolve the same relative path on the clone.
Learning the path instead of hardcoding it keeps it correct across a scene
reshuffle, per the rule below. Do it **before `add_child()`** — `_ready()` runs
on entering the tree and caches a material off `border_mesh_instance`. The
`[FORK8] zones` trace prints `rebound=20/20` so a missed one is visible.

Note the inverse case is fine: `duplicate()` of a node with **NodePath-typed**
exports copies the path, which then resolves relative to the clone.

## Never reach scene nodes by a hardcoded relative path

`get_node_or_null("../some/path")` returns null rather than erroring, so a wrong
path makes the whole feature a **silent no-op**. Green Pea's chair repositioning
did nothing at all for several iterations because of this - and it was extra
confusing because the camera half of the same function worked, since `camera` is
an `@export`.

Anchor to an exported node and walk **up** the tree until the target is found
(see `_mod_chairs()` in green_pea.gd), and `push_warning` when it is not. The
`[SEATS8]` / `[STATIONS]` traces print how many nodes were actually found - a
count of 0 is the tell.

## Runtime scene changes must be RPCs, not local calls

`initialize()` and `spawn_players()` on a minigame run on the **host only**.
Anything that alters the scene from there - moving chairs, cloning stations,
repositioning a camera - happens on one machine and nowhere else. Seven of eight
players see the stock level, and nothing in the logs says so.

Mark such work `@rpc("authority", "call_local", "reliable")` and invoke it with
`.rpc()`, matching how the game already does `teleport_rpc` and
`set_spectate_position_rpc`. See `mod_add_stations_rpc()` in chisel_gauntlet.gd
and `mod_apply_eight_seat_layout_rpc()` in green_pea.gd.

**This also invalidates host-only screenshots as verification.** A capture of the
host window will happily show a fix that no client has. Confirm on a client
window, or check that a client log ran the code (`is_server=false`).

## A rule to preserve: 1-4 player games must stay vanilla

Anything that repositions or rescales shipped geometry has to be conditional on
the roster size, applied from script at runtime, with the **scene left as
shipped**. Green Pea (`green_pea.gd`), the lobby previews (`lobby_scene.gd`) and
Chisel's `shotgun_check_order` all follow this pattern - grep for
`MOD_VANILLA_SEATS`, `MOD_VANILLA_SLOTS` and `MOD_CHECK_ORDER_8`.

Where the map itself needs more furniture, prefer cloning at runtime over
editing the scene. Chisel Gauntlet's consoles and desk colliders all sit at the
origin distinguished only by a Y rotation, so `_mod_add_stations()` duplicates
and rotates them 45 degrees - the `.tscn` is untouched and four players never
run the code. Green Pea's chairs work the same way.

Baking an eight-player layout into a `.tscn` is the easy mistake: it silently
changes what four players see. Verify both paths after any such change with
`START=1 MINIGAME=<X> tools/localtest.sh 4 ...` and `... 8 ...`.

### The first sanctioned exception: the wheat-field cutscene

**Requested by the user on 2026-08-02, after being told it breaks this rule.
Do not "fix" it back.**

`MinigameIdentifier.CutsceneTest` - the wheat-field cutscene - has been deleted
from `default_playlist` in `mod/autoloads/globals.gd`. It no longer appears at
**any** roster size, so a 1-4 player modded lobby differs from vanilla by that
one entry. The list is byte-identical to vanilla otherwise, and step 5 of the
update procedure re-derives it from fresh source, so on the next game update
the deletion must be **re-applied deliberately** - there is a comment at the
deletion site saying exactly what was removed and where it sat.

The alternative was `modded_minigame_player_cap: {CutsceneTest: 4}`, which
would have kept 1-4 vanilla and dropped it only at 5-8. That was offered and
declined; the user wants it gone everywhere.

Nothing else was removed. The scene, `Globals.MinigamePaths`,
`CutsceneMinigameIdentifiers`, `MinigameCutsceneTransition` and the mod's four
extra spawn markers in `cutscene_test.tscn` are all intact, so `-debug-tools`
can still launch the cutscene directly at up to eight players.

See "The debug lobby is a *custom* game" below - it is why this change is not
observable in an ordinary localtest run.

### The second sanctioned exception: mod spawn markers at 1-4

**Accepted by the user on 2026-08-04 after the scope was measured.** Nine
expanded scenes bake eight spawn markers into the `.tscn` and shuffle the whole
list, so a 1-4 player game can seat someone 1.2u sideways of a vanilla spawn -
same rotation, same floor, in frame. It is a real breach of this rule and it is
being kept, because fixing it means touching nine minigames for a deviation
nothing in gameplay depends on.

Unlike the cutscene exception this one is **not deliberate design** - it is a
side effect of baking additions into scenes, and it is exactly what the advice
two paragraphs up is meant to prevent. The clean fix, if it is ever worth doing,
is to stop baking those markers and build them at runtime behind a roster gate
the way `duck_hunt` and `forklift_certified` do, which would also remove seven
`.tscn` files from the overlay. Full detail, the scope table and the evidence
that would reopen it are under "Spawn markers are visible to 1-4 player games
too".

## Update procedure

### 1. Snapshot the new build
```bash
md5sum "/mnt/secondary/SteamLibrary/steamapps/common/party project/Machine Party_Linux/Machine Party.pck"
```
Record it. Then **copy the game folder out** — never work in place:
```bash
cp -r "/mnt/secondary/SteamLibrary/steamapps/common/party project/Machine Party_Linux" testgame_new
```

### 2. Keep the old decompile for diffing
```bash
mv project project_old
mv extracted extracted_old
```

### 3. Re-extract and re-decompile
```bash
python3 tools/pck.py extract "<path to new Machine Party.pck>" extracted
./tools/bin/gdre_tools.x86_64 --recover="<path to new Machine Party.pck>" --output=project
```
**Do not pass `--headless`** — in headless mode GDRE silently fails to export
roughly half the scenes. It needs a display; there is one on this machine.

Sanity check: `.gd` count should equal the `.gdc` count, and `.tscn` should
equal the number of `.scn` under `.godot/exported/`. That has been
**368 scripts and 140 scenes** in every version so far — v1.0.6, v1.0.7 and
v1.5.0 alike, and v1.5.0 added a whole game mode without changing either count,
so equal counts are a check on the *decompile*, not evidence the patch was small.

### 4. See what upstream actually changed
```bash
diff -rq project_old project | grep -E '\.gd |\.tscn ' | head -50
```

**Do NOT use `diff -rq ... --include="*.gd"`.** `--include` also filters
directories, so recursion never descends and it reports **zero changes even
when there are some** - on the v1.0.7 update it hid the one real script change.
That failure is silent and would send you off believing upstream changed
nothing.
Pay attention to the five files the mod patches. If the developers restructured
`generate_session_playlist()`, the spawn code, or the customization assigner,
the mod's edits need rethinking, not just re-applying.

### 5. Rebuild the overlay from the NEW source
**Do not copy the old `mod/` forward.** Those files are the *old* version's code
with mod edits layered on; reusing them would silently revert every upstream fix.

```bash
rm -rf mod
```
Then, for **each file in the overlay manifest below**: `cp project/<path>
mod/<path>` and re-apply the change described in the section named beside it.
(This used to read "for each of the five scripts", which was true when the mod
was five files and has been wrong for a long time — the manifest exists so the
count can never drift out of the instructions again.) Then re-run the spawn
expander:
```bash
grep -v '^#' tools/spawn_targets.txt | grep -v '^$' | sed 's|^|mod/|' | tr '\n' '\0' | xargs -0 python3 tools/spawn_expand.py --dry-run
```
(copy each target scene from `project/` into `mod/` first; drop `--dry-run` to apply)

`spawn_targets.txt` lines may carry an optional **third** field — currently only
`inward`, which makes the expander displace clones toward the centroid of the
shipped markers instead of letting a stable-sort tie decide the direction.
`train_race` depends on it (without it two players spawn inside a wall, and the
trace still reports 8/8 `OK`). Carry the flag forward; the sweep command above
passes it through untouched.

**Audit every mod `.tscn` for edits beyond the spawn markers**, so a
hand-made scene tweak cannot go missing the way `disco_dodge`'s `spawn_limit`
did:

```bash
python3 - <<'EOF'
import os, subprocess
for root, _, files in os.walk("mod"):
    for f in sorted(files):
        if not f.endswith(".tscn"): continue
        rel = os.path.relpath(os.path.join(root, f), "mod")
        out = subprocess.run(["diff", os.path.join("project", rel),
                              os.path.join("mod", rel)],
                             capture_output=True, text=True).stdout
        other = [l for l in out.splitlines()
                 if l.startswith(("<", ">")) and "_MOD" not in l
                 and not l.startswith("> transform = Transform3D")]
        print(("OTHER EDITS " if other else "markers only") + "  " + rel)
        for l in other[:6]: print("      " + l)
EOF
```

Re-verify the spawn container node paths — they move when levels are
re-authored, and `spawn_targets.txt` records where they were **as of v1.5.0**,
not where they are now. Treat it as a diff baseline: rescan, compare against the
file, and **write the corrected paths back into `tools/spawn_targets.txt`** so
it stays accurate for the next update. A stale entry shows up as
`!! no Marker3D children under '<path>'` from the expander. (All 14 listed paths
still resolved on the v1.5.0 rescan, so no correction was needed that update.)

Watch for new minigames too — anything added since will have four spawn
markers and needs an entry here, or it will crash at five players. Note that
v1.5.0's Arcade mode is a **session mode, not a minigame** — it added no scenes
at all — so "a new mode in the patch notes" does not by itself mean a new entry
here. Check the `.tscn` count and the rescan, not the marketing copy.

**Two minigames are excluded from that file on purpose, and the rescan will
still list them.** `duck_hunt` and `forklift_certified` build their extra
markers at **runtime**, host-only, gated on roster > 4 (`MINIGAMES.md` §19 and §20).
That is not an optimisation — it is what keeps a 1-4 game seating on the shipped
markers *only*, and it is why those two alone sidestep the deviation under
"Spawn markers are visible to 1-4 player games too". Neither is capped any more,
so the old "capped, therefore excluded" reasoning no longer explains their
absence and the entries look like oversights. They are not. Baking markers into
either scene **breaks the 1-4 path**: for Forklift, `spawn_players()` sizes
`shuffled_indicies` from the marker count, so eight baked markers make it span
0-7 while a roster <= 4 leaves `delivery_areas` holding four — any drawn index
>= 4 aborts the host's spawn loop, which is a black screen at 1-4 players 98.6%
of the time. `tools/spawn_targets.txt` carries this warning at both entries.

The general rule, for any minigame expanded from here on: **prefer runtime
markers behind a roster gate to baked ones.** It is the only approach that keeps
1-4 genuinely vanilla, and it keeps the scene out of the overlay entirely — see
the second fix option under "Spawn markers are visible to 1-4 player games too",
where seven `.tscn` files exist for nothing but their markers.

Rescan with:
```bash
python3 - <<'EOF'
import re, glob, collections
pat = re.compile(r'\[node name="([^"]+)" type="Marker3D" parent="([^"]+)"\]')
res = collections.defaultdict(collections.Counter)
for f in sorted(glob.glob("project/minigames/**/*.tscn", recursive=True)):
    for m in pat.finditer(open(f, encoding="utf-8", errors="replace").read()):
        leaf = m.group(2).split("/")[-1].lower()
        if ("spawn" in leaf or "position" in leaf) and "item" not in leaf and "part" not in leaf:
            res[f][m.group(2)] += 1
for f in sorted(res):
    for parent, n in res[f].items():
        print(f"{n}  {f}::{parent}")
EOF
```

### 6. Bump version strings

In code — these change behaviour, so they are the ones that break things:
- `mod/autoloads/globals.gd` → `game_version = "v<new>-8P-v<modrelease>"`. The
  scheme is **game version + `-8P` + the mod's own release label**; currently
  `v1.5.0-8P-v1.0`. A game update bumps only the first part — **carry the mod
  release label across unchanged** unless the mod itself is being released anew.
- `install.py` (project root) → `SUPPORTED_VERSION = "v<new>"`
- `install.py` (project root, ~line 329) → the `--verify` message **hardcodes the
  same display string**. It is the second place the label lives and it does not
  derive it, so it silently goes stale; keep the two in sync.
- `README.txt` (project root, ships inside the zip) → the "DID IT WORK?" example
  strings and the "Built for Machine Party v<old>" line. **The third place the
  label lives**, and the one that went three minigames stale before the
  2026-08-08 release prep caught it — it is player-facing prose, so nothing
  breaks when it lies.

**And in the prose, which is easy to skip and leaves the next session reading a
handoff document that lies about which version it targets.** You are updating
your own instructions here; nobody else will:
- `UPDATING.md` — "The mod currently targets **v<old>**" near the top, the
  "The last update, and how it was verified" heading and its opening line, and
  the two pck MD5/size rows in "The facts"
- `CLAUDE.md` — "Currently targets game **v<old>**"
- `README.md` — the opening line and any other version reference
- `MINIGAMES.md` — only if a section quotes a version-specific measurement
- the `machine-party-8p-mod` memory entry under
  `~/.claude/projects/-home-adam-Documents-Claude/memory/`, if this session can
  see it (it is namespaced to `~/Documents/Claude`, so a chat started *inside*
  the project folder will not load it)

Then rewrite "The last update, and how it was verified" for the patch you just
measured, and add a "Session log" entry. The old contents of that section move
into the session log; it should always describe the **most recent** update, so
the worked example a future session copies is the freshest one.

### 7. Build and validate
```bash
python3 tools/build.py
MP_DEPLOY=~/Documents/Claude/machine-party-8p/testgame python3 tools/build.py
```
Then run the validation recipe below.

### 8. Repackage the release zip
`install.py`, `install.sh`, `install.bat`, `README.txt` and `mod/` all live at
the project root now — there is no separate `installer/` copy to re-sync.
`dist/machine-party-8p-mod.zip` is built directly from those five root
files/folders; its internal structure is unchanged from before. There is no
`zip` binary on this machine, so build it with Python from the project root:

```bash
python3 - <<'EOF'
import os, zipfile
with zipfile.ZipFile("dist/machine-party-8p-mod.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for f in ("install.sh", "README.txt", "install.py", "install.bat"):
        z.write(f)
    for root, dirs, files in os.walk("mod"):
        dirs.sort()
        for f in sorted(files):
            z.write(os.path.join(root, f))
EOF
```

After building, extract to a scratch directory and `diff -rq` the extracted
`mod/` against `mod/` — it must be empty before the zip ships.

---

## Testing — the validation recipe

The strongest check: make the **real game binary** load every modified resource,
in the real release runtime, then quit. Temporarily add this to `_ready()` in
`mod/modules/multiplayer/network_manager.gd` (an autoload, so it runs early),
right after `var args = Array(OS.get_cmdline_args())`:

```gdscript
	if args.has("-validate-scenes"):
		var bad := 0
		for sp in [
		"res://minigames/disco_dodge/disco_dodge.tscn",
		# ...every modified scene and script...
		]:
			var r = ResourceLoader.load(sp)
			if r == null: bad += 1
			print("[VALIDATE] ", "OK  " if r != null else "FAIL", " ", sp)
		print("[VALIDATE] failures=", bad)
		get_tree().quit()
		return
```

Build, deploy to `testgame/`, then:
```bash
cd ~/Documents/Claude/machine-party-8p/testgame
timeout 240 stdbuf -o0 -e0 ./"Machine Party.x86_64" --headless -validate-scenes 2>&1 | grep VALIDATE
```
Expect `failures=0`. **Remove the hook afterwards** and rebuild.

**The plain boot test below does NOT cover minigame scripts.** It only reaches
the main menu, so a `.gd` that lives in a minigame scene is never parsed and a
parse error in it passes silently - then the minigame loads to a **black screen
with the music still looping** (the same symptom as pitfall 13, different
cause). A stray `%r` in a `push_warning` cost a full test cycle exactly this
way. Either run the `-validate-scenes` recipe above, or pin the minigame with
`MINIGAME=` in a localtest run, and grep the logs for `Parse Error`. A cheap
pre-flight for that specific class:

```bash
python3 - <<'EOF'
import re, glob
strlit = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
spec = re.compile(r'%[-+ 0#]*[\d*]*(?:\.[\d*]+)?([a-zA-Z%])')
ok = set("scdoxXfv%")
for f in sorted(glob.glob("mod/**/*.gd", recursive=True)):
    for n, line in enumerate(open(f, encoding="utf-8", errors="replace"), 1):
        for s in strlit.findall(line):
            for m in spec.finditer(s):
                if m.group(1) not in ok:
                    print(f"{f}:{n}: invalid %{m.group(1)}")
EOF
```

Plain boot test (should run the full timeout with no script errors):
```bash
cd ~/Documents/Claude/machine-party-8p/testgame
timeout 25 stdbuf -o0 -e0 ./"Machine Party.x86_64" --windowed --resolution 960x540 2>&1 | grep -E "Running version|SCRIPT ERROR|Parse Error"
```
Should print `Running version: v<new>-8P-v<modrelease>` — currently
`v1.5.0-8P-v1.0`.

### Eight local clients

The strongest functional test, and it needs nobody else:

```bash
tools/localtest.sh 8 ~/Documents/Claude/machine-party-8p/testgame 45
```

Slot 1 hosts over ENet on 127.0.0.1:25565, slots 2-8 join; windows tile 4x2 and
title themselves P1-P8. To confirm seats actually fill, temporarily add this to
`multiplayer_menu.gd`'s `update_player_list()` (it is already there behind the
flag as of v1.0.6):

```gdscript
	if Array(OS.get_cmdline_args()).has("-localtest"):
		print("[SEATS] ", player_order_by_seat, "  connected=",
			NetworkManager.active_backend.connected_players.size())
```

Expect the host log to walk up to all eight seats holding distinct ids, every
client to converge on the same map, and zero errors in `/tmp/mp-localtest/*.log`.

`MINIGAME=<Identifier>` pins the session to one minigame (the mod adds a
`-minigame` argument to `game.gd`'s playlist generation), so a specific one can
be playtested without reshuffling until it comes up:

```bash
START=1 MINIGAME=GreenPea tools/localtest.sh 8 <game-dir> 110
```

`-debug-tools` (a stock flag, no mod needed) sets `allow_singleplayer` so the
whole rotation can be run solo.

### Full session flow (`FLOW=1`)

`START=1` is a **shortcut**, not a normal game: `bootstrap.gd` sets
`debug_skip_brief`, `debug_skip_intermission` and `skipping_intro_cutscene`
whenever `-startgame` is present, so those runs jump straight between minigames
and never exercise the intro cutscene, the briefing screen or the intermission
picker. Easy to forget when reading a "clean" log.

```bash
FLOW=1 tools/localtest.sh 8 ~/Documents/Claude/machine-party-8p/testgame 420
```

`FLOW=1` passes `-fullflow`, which suppresses exactly those three skips, so each
instance runs the loop a real player sees: **intro cutscene -> briefing ->
minigame -> score screen -> intermission picker -> next briefing**. It implies
`START=1`, because something still has to begin the session with nobody at a
keyboard. Allow generous time - nothing is skipped, so 420s gets a handful of
minigames where `START=1` would get a dozen.

The briefing's Ready button is the **only** step in that loop that waits on
player input (session end and the picker advance on timers; the cutscene needs
no press), so `intermission_briefing_screen.gd` readies each instance after
`MOD_AUTOREADY_DELAY` (3s). It goes through `set_ready_rpc` - the same call the
button handler makes - so the ready sound, the indicator and the host's
`check_all_ready()` all behave as they do for a real press. Confirm with:

```bash
grep -h "\[FLOW\] auto-ready" /tmp/mp-localtest/p*.log | sort -u
```

Expect one line per peer, exactly one with `is_server=true`. Verified
2026-08-01 at 8 players: all 8 readied, briefing and score screens ran at
`rows=8`, and the session reached four distinct minigames with zero errors.

### `localtest.sh`'s cleanup is a GLOBAL pkill — never run two sessions

`tools/localtest.sh:22` is

```bash
cleanup() { pkill -f "Machine Party.x86_64" 2>/dev/null; }
trap cleanup EXIT INT TERM
```

That pattern is **not scoped to the PIDs this script started**. It kills every
instance on the machine, so any lingering `localtest.sh` — one whose game
processes you already killed by hand, but whose `sleep` is still running out its
duration — will execute that trap on exit and take down a *newer* session with
it. The symptom is eight instances vanishing mid-play with no error, logs simply
stopping, and the launcher still cheerfully printing `running for 600s...`.

Cost three sessions on 2026-08-04 before the cause was spotted, twice while the
user was mid-playtest. Before starting a session, check that no wrapper is
already alive:

```bash
ps -eo pid,args | grep '/bin/sh tools/localtest.sh' | grep -v grep
```

and kill any that are. Two related traps if you launch it as a background task:
the wrapper's own command line **contains the string `localtest.sh`**, so a
`pkill -f localtest.sh` cleanup kills the shell that is about to launch (exit 1
before anything starts); and a backgrounded command does not inherit the project
directory, so it needs `cd ~/Documents/Claude/machine-party-8p &&` or it
exits 127.

### The debug lobby is a *custom* game — use `-original` for the real rotation

**Found 2026-08-02, and it invalidates a class of playlist testing.**

`multiplayer_menu.gd` sets `GameManager.custom_game = true` (vanilla behaviour,
project line 38). Every `-localtest` session is therefore a **custom** game, and
`generate_session_playlist()` takes its `CustomMinigamesWhitelist` branch - a
*different* branch from the one a real Steam "Original" session uses. So until
this was noticed, **the non-custom branch that every real game actually plays
had never once run under `-localtest`.**

It is directly visible in the playlist print at 8 players — **a snapshot taken
2026-08-02**, before the cutscene removal landed and before the last two
uncappings:

| | entries | contains `CutsceneTest`? |
|---|---|---|
| default debug lobby (custom) | 11 | no - the whitelist already drops both cutscenes |
| `ARGS="-original"` (non-custom) | 12 | **yes** |

**Neither row holds any more.** Re-measured 2026-08-08 at 8 players, now that
nothing in the rotation is capped and `CutsceneTest` is removed at every roster
size: **both branches generate the same 15-entry list** — all fifteen rotation
minigames in `default_playlist` order, `ManufactureGun` and `BurnRecycle`
present, `CutsceneTest` absent. **The branch difference is no longer visible in
the entry count**, so the `[ORIGINAL] custom_game=false` marker line is the only
thing that confirms which branch ran. What the table is still evidence for is
that the *two branches are different code paths*, which is the point of this
section — and that remains true whether or not their output currently agrees.

`-original` (mod flag, gated behind `-localtest`) sets `custom_game = false` so
the default rotation is exercised:

```bash
ARGS="-original" START=1 tools/localtest.sh 8 <game-dir> 45
grep -h "Generating session playlist with" /tmp/mp-localtest/p1.log
```

**Anything that touches `default_playlist`, `supports_player_count()` or the
empty-list fallback must be verified with `-original`**, or the run will
silently exercise the whitelist branch instead and prove nothing. The
`[ORIGINAL]` line in the host log confirms which branch ran.

### `START=1` hardcodes Duck Hunt's round count — use `FLOW=1` to measure it

**Found 2026-08-03.** `intermission_game_picker.gd` has a
`if Globals.debug_skip_intermission:` branch that loads the first minigame with

```gdscript
intermission_manager.game.load_minigame(..., true, 3)
```

— a **literal 3**, bypassing both `total_rounds` resolution sites entirely. Since
`START=1` sets `debug_skip_intermission`, any round-count measured under it is
that constant, not the real value. Under `FLOW=1` the same 8-player session
reports `1`.

This is the second time a `START=1` shortcut has silently distorted a
measurement (the first being the role overlay below). The pattern to remember:
`START=1` does not just *skip* presentation states, it sometimes **substitutes
values** on the way past. If the thing being measured is decided anywhere near
the briefing, the picker or the intermission, measure it with `FLOW=1`.

### `START=1` HANGS Duck Hunt permanently — `FLOW=1` is the only way to run it

**Found 2026-08-02. Called benign, and that was WRONG — corrected 2026-08-05 by
the user, who watched a run instead of reading its log.** Under `START=1` every
Duck Hunt client sits on a full-screen black overlay reading **"YOU ARE THE
HUNTER."** and appears hung. **It is hung.** The minigame never ends, at any
roster size, and it never will.

The 2026-08-02 entry read "Nothing is wrong" because the overlay was traced to a
skipped presentation state and the analysis stopped there. It went unchallenged
for three days because **every `START=1` run was killed by `localtest.sh`'s
duration before anything needed Duck Hunt to finish** — the traces fired at scene
load, got collected, and the session died. Absence of a complaint from a run that
is always executed is not evidence.

**Why it hangs, and it is not the overlay:**

- `role_reveal_state.gd:78` is the **only** online caller of
  `hunter_player.set_can_aim_rpc.rpc(true)`, and `can_aim` defaults to `false`.
  (The other `set_can_aim_rpc(true)`, at `hunter_player.gd:600`, is inside
  `reveal_role()`, which only `reveal_local()` calls — the local-couch path this
  mod does not use.)
- `round_state.gd` short-circuits `Round -> Countdown` whenever
  `Globals.debug_skip_brief` is set, skipping `RoleReveal` entirely.
- So the hunter's `can_aim` stays false forever: mouse aim is ignored
  (`hunter_player.gd:135`) and controller input returns early (line 216). **The
  hunter cannot aim or fire.**
- `check_game_end()` returns early while `duck_players` is non-empty, ducks are
  only removed by kill/disconnect handlers, and **there is no turn timer**. No
  shot is ever fired, so no duck ever dies, so the round can never end.

Measured 2026-08-05, 8 players, 240s: state path
`Empty -> Round -> Countdown -> Play`, then **nothing** — zero further
transitions, zero `Finished`, zero `Reset`, one minigame load.

This is a **vanilla** debug-path defect — the short-circuit and the single
`set_can_aim` call site are both stock — that the mod's `-startgame` reaches.
Real players never set `debug_skip_brief`, so a normal session is unaffected.

### FIXED 2026-08-05 — and there are TWO causes here, only one of which is fixed

`_mod_apply_skipped_reveal()` in `duck_hunt.gd` now re-does what the skipped
state would have done — `set_can_aim_rpc.rpc(true)` plus an RPC that clears the
role overlay on every peer — gated on `Globals.debug_skip_brief`, and called from
the end of `spawn_players()`, which `reset_state.gd` re-runs for **every** hunter
turn rather than only the first. Verified at 8 players: `overlay_visible=false
alpha=0.00` on the host **and all seven clients**.

**But the minigame still does not end unattended, and that is a different
problem.** Ducks leave `duck_players` only via `_on_player_finished` (a duck
walks to the finish corridor) or `_on_player_died` (a duck is shot). Idle test
instances do neither — they do not move and they do not fire. `check_game_end()`
therefore still never gets past its guard, with or without the fix, and with or
without `debug_skip_brief`.

So, precisely:

| | before the fix | after the fix |
|---|---|---|
| Overlay clears | no | **yes, all 8 peers** |
| A human can aim and fire | **no** | **yes** |
| Unattended run completes a turn | no | **still no** |

**What the fix buys** is that Duck Hunt can now actually be playtested by a
person on the fast path; previously even a human sat behind a black screen with
a disabled rifle. **What it does not buy is an unattended rotation run** — this
was claimed when the fix was proposed and it is not delivered.

**Duck Hunt blocks EVERY unattended rotation run, `START=1` and `FLOW=1`
alike**, because nothing in it advances without a player. It is **5th** in the
15-entry rotation (measured 2026-08-08; `ManufactureGun`'s uncapping moved it
down one), so the ten after it are unreachable that way. **Pinning with
`MINIGAME=` is the only way to cover the full rotation unattended** — see the
2026-08-05 playtest entry, where that is exactly what happened. A "the rotation
only reached N minigames" result is this, not pacing.

The original (correct, but incomplete) presentation analysis:

- `duck_hunt.tscn` bakes that placeholder into `CanvasLayer/Control/Overlay`'s
  `RoleLabel`, and the overlay ships **visible**.
- The only code that replaces the text (with `"%s IS THE HUNTER."`) and fades the
  overlay out is `RoleReveal.reveal_online()`.
- `duck_hunt.tscn` routes the Round state onward with
  `transition_to = &"RoleReveal"`.
- But `shared/states/round_state.gd` short-circuits `Round -> Countdown` whenever
  `Globals.debug_skip_brief` is set, which is precisely what `START=1` does. The
  reveal never runs, so the placeholder never clears.

Proven roster-independent: a 4-player `START=1` run shows the identical
`Empty -> Round -> Countdown -> Play` path. Under `FLOW=1` the full path
`Empty -> Round -> RoleReveal -> PlayerMarker -> Countdown -> Play` runs and the
overlay clears.

**So `FLOW=1` is the correct harness for Duck Hunt** — not merely the tidier one.

**And the generalisable lesson, which is the opposite of what this section used
to say.** It used to end "a minigame may *look* broken under `START=1` for no
reason other than the skip — check the state path before believing a screenshot",
and that advice, applied here, produced a wrong answer for three days. The state
path *was* checked; it showed `Countdown -> Play` and was read as proof the
minigame was running fine behind a stale overlay. What nobody asked was whether a
skipped state had been doing something **load-bearing** on its way past — and
`RoleReveal` was the only thing enabling the hunter to fire.

So: when a debug flag skips a state, do not stop at "the state machine moved on".
Read what that state actually did. A presentation state that also flips one
gameplay flag is indistinguishable from a purely cosmetic one in a state trace,
and `START=1` skipping it turns a minigame into a permanent hang that every
duration-limited test run will hide from you.

This is the third time `START=1` has silently distorted a result (the round-count
constant and the role overlay being the first two), and the most severe — the
other two gave wrong numbers, this one gives a wrong *verdict*.

### What the local test still is not

Unattended instances idle, and for some minigames idling is not a neutral
observation - it decides the outcome:

| Minigame | What idling does, and what stays unproven |
|---|---|
| Tunnel Hazard | idle players never enter a nook, so the first train kills **everybody** in cycle 1. The `[TRAIN8] cycle` line therefore never prints, and the nook-contention ramp (8 nooks, `nooks_to_open` tightening by one a cycle) is unexercised at 8 |
| Inside Job | nobody searches a container, so `containers_searched` stays 0 and the hunting phase is unreachable without `-kato-hunt` |
| **Duck Hunt** | **idling never ends the minigame, at all.** A duck leaves `duck_players` only by reaching the finish corridor or being shot, and idle instances neither move nor fire — so `check_game_end()` never fires and the turn runs forever. This is why an unattended rotation run stops dead here (**5th of fifteen**, measured 2026-08-08) under **both** `START=1` and `FLOW=1`. Pin it, or drive one window by hand |
| Spine Breaker, Lethal Rebound | idle players are killed in turn, which does exercise elimination, scoring and round advance - these two get the most out of an idle run |

The pattern: a minigame where **doing nothing is fatal** tests its death path
well and its skill path not at all. Reach for a test aid (`-kato-hunt`) or a
driven window before believing a "clean run" covered the whole minigame.

**What this still is not.** The instances are unattended - nobody plays, so
they idle through each minigame. Only the focused window receives keyboard
input, so a human can drive at most one; making all eight *play* needs either
in-game bots or external input injection, neither of which exists. And the
lobby is still the developers' debug lobby: `lobby_scene.gd` has 12 `Steam.`
call sites and its join path is built on Steam lobby callbacks, so the real
lobby cannot run over ENet. That is why the Steam lobby's 8-slot preview
rendering remains unverifiable locally.

Installer round-trip, on a **copy**, with literal absolute paths:
```bash
python3 ~/Documents/Claude/machine-party-8p/install.py --game-dir ~/Documents/Claude/machine-party-8p/testgame_new --verify
```
Expect `NOT PATCHED` → install → `PATCHED` → `--uninstall` → MD5 matches the
original recorded in step 1. Verified 2026-08-08 against a clean v1.5.0 copy:
install wrote 4177 files (53 from the mod, 88 originals replaced), `--verify`
reported `PATCHED` and `v1.5.0-8P-v1.0`, and uninstall restored the pck
**byte-identically** (`f5912732…`, 635,333,716 bytes). **Both counts track the
overlay size** — each added `.gd` also displaces its `.remap` and `.gdc`
siblings — so re-derive them from the run rather than treating them as
constants; the 2026-08-08 wall-desk entry explains the 82 → 88 shift.

Note `install.py` prompts for confirmation, so a non-interactive run needs
`echo y | python3 …` — without it it dies on `EOFError` before touching anything.

---

## Pitfalls (all of these cost time the first go)

1. **`res://` prefix.** The *shipped* pck stores paths **without** it; `tools/pck.py`
   writes them **with** it. Normalise before comparing, or lookups silently miss
   and the compiled `.gdc` keeps shadowing your `.gd`. `install.py` (project
   root) has a `norm()` helper for exactly this.
2. **GDRE `--headless` silently drops scenes.** Run it with a display.
3. **`.scn` files under `.godot/` are engine caches, not content.** In v1.0.6:
   140 under `exported/` (these correspond to the authored `.tscn`) and 167 under
   `imported/` (3D model imports). Nothing to convert.
4. **stdout is block-buffered when redirected.** `timeout` SIGTERMs the game and
   you lose every `print()`. Always `stdbuf -o0 -e0`. A missing debug print is
   usually this, not a broken mod.
5. **Never pass `$PWD/...` to `install.py`.** An empty expansion once made it
   auto-detect and patch the real Steam install. It now rejects an empty
   `--game-dir` and prompts before writing to an auto-detected folder, but type
   literal absolute paths regardless.
6. **A game update reverts the mod** (and so does Steam's "Verify integrity of
   game files"). That is also the safest uninstall.
7. **Everyone in a lobby needs the identical mod.** The `-8P` version suffix
   makes a mismatch fail cleanly instead of desyncing mid-session — and since
   release v1.0 it also carries the **mod release label** (`v1.5.0-8P-v1.0`), so
   two players on the same game version but different mod releases are refused
   just as cleanly.
8. `-trailer` on the command line makes the game use `MAX_DEBUG_PLAYERS`.
9. For `gdc.py`: Godot's binary Variant int/float encoding uses the
   `ENCODE_FLAG_64` bit (`0x10000`) in the type word. Ignore it and every
   constant after the first 64-bit value decodes as garbage.
10. `.gdc` layout is `GDSC` magic, `u32` version (101 in 4.5), `u32`
    decompressed size, then a zstd stream. Identifiers inside are stored one
    `u32` per character, XOR-masked with `0xB6B6B6B6`.
11. **`MultiplayerSpawner.spawn_limit`.** Documented by Godot as a cap on
    spawns; the feared symptom is a node that never appears with no error, and
    a downstream "Node not found" for a peer's synchroniser. It was set to 4 in
    `disco_dodge.tscn` and `manufacture_gun.tscn` in v1.0.6, and **still is in
    v1.5.0** (re-checked 2026-08-05 — same two scenes, same value, no new sites).
    Re-check after an update:
    `grep -rn "spawn_limit" --include="*.tscn" project/`, and raise it
    to match the player count.

    **But do not treat it as a known-guilty party.** Re-measured 2026-08-02, a
    matched pair at 4 vs 8 on `disco_dodge` was indistinguishable - all eight
    players spawned on every client either way (`MINIGAMES.md` §10 has the numbers). The
    raise is kept as defence-in-depth, but if a minigame is missing players,
    **measure before blaming this**: add a trace that counts the spawned nodes
    on each peer, the way `[DISCO8]` does. This pitfall previously read as
    settled fact and cost a wrong entry in the status list.
12. **Diff error logs at 4 vs 8 players.** `START=1 tools/localtest.sh 4 ...`
    then `8 ...` and compare `grep -hE "^ERROR|^SCRIPT ERROR" /tmp/mp-localtest/p*.log`.
    Apply the filter before comparing. An *unfiltered* diff always shows new
    lines at 8, because `Node not found: .../SomethingPlayer5` and
    `Failed to get path from RPC: ...` are the same replication families that
    appear at 4 with indices 1-4. Compare error *classes* after filtering: as of
    2026-08-01 the filtered 8-player set is a subset of the 4-player set apart
    from one benign entry, `Parameter "data.tree" is null` (a vanilla coroutine
    resuming after its node left the tree; 1-3 lines at the instant a round
    ends). Anything else present only at 8 is player-count related. This is
    what found the `spawn_limit` bug, the `blood_trail.gd` empty-`Curve3D`
    crash (~380 errors per round at 8, zero at 4), and the score screen's
    negative reverb pitch (one line per peer at 8, none at 4 - see `MINIGAMES.md` §11).
    Note the autostart threshold is the token after `-startgame`, so a
    4-player run does start.
13. **A second per-player array indexed at spawn.** The nastiest failure mode
    found: `spawn_players()` indexes some *other* array with the same index as
    the spawn position. Expanding spawns to 8 without expanding that array is
    an out-of-bounds read that aborts the host's spawn loop - the minigame
    loads to a **black screen with audio still looping**, and nothing appears
    in the logs as a crash. Find them all with:

    ```bash
    for f in $(grep -rl "func spawn_players" --include="*.gd" project/minigames/); do
      sed -n '/func spawn_players/,/^func [a-z_]*(/p' "$f" \
        | grep -oE '[a-z_]+\[(counter|shuffled_indicies\[counter\]|i)\]'
    done
    ```

    In v1.0.6 three matched: `forklift_certified` (delivery areas - recorded then
    as "unfixable, capped at 4", which was **wrong**: uncapped 2026-08-04 by
    building four more zones at runtime, see `MINIGAMES.md` §20), `chisel_gauntlet`
    (`player_rotations`, `spectate_positions` -
    both extended to 8), and `exploding_collar_race` (safe, its array is
    derived from the spawn positions themselves).
14. **Players differentiated only by rotation.** `chisel_gauntlet.gd` teleports
    every player to the *same* point (`player_spawn_node.global_position`) and
    tells them apart purely by `player_rotations[counter]` - four facings 90
    degrees apart, one per station. Padding that array by repeating the four
    values puts two players in the same slot with their carve cubes
    intersecting: one player's cube fills the other's camera, which looks like
    a giant black slab rather than an obvious error. The array now holds eight
    distinct facings 45 degrees apart. When expanding a minigame, check whether
    spawn variety comes from *position* or from *rotation*.
15. **Hardcoded per-slot iteration orders.** Beyond arrays that are *indexed*
    by player, watch for arrays that *enumerate* the slots.
    `chisel_gauntlet.gd`'s `shotgun_check_order = [0, 2, 1, 3]` is the order the
    execution device visits stations; the four added slots were simply absent,
    so those players were never checked or shot - no error, the gun just
    ignored them. Note it is a clockwise sweep **by angle, not by index**, so
    the eight-slot version is `[0, 4, 2, 6, 1, 5, 3, 7]`. Verify with the
    `[SHOTGUN]` trace in `round_eliminate.gd` under `-localtest`.
16. **A bad `%` format specifier is a Parse Error, and the boot test does not
    catch it.** A stray `%r` (Python habit, not GDScript) in a `push_warning`
    inside a *minigame* script parsed fine at boot - the plain boot test only
    reaches the main menu, so that script is never loaded - and then the
    minigame came up as a **black screen with the music still looping**, which
    is pitfall 13's symptom from an unrelated cause. Valid specifiers are
    `s c d o x X f v %`. Run the pre-flight scan in "Working environment"
    before every build, and pin the minigame with `MINIGAME=` in a localtest
    run rather than trusting a clean boot.
17. **`spawn_expand.py` displaced clones along a marker's raw local X, which
    is not always horizontal.** Escalator Pit ships three markers with the
    basis `(0,-1,0, 1,0,0, 0,0,1)`, whose first basis column is world **+Y**.
    The clones were therefore placed 1.2 units *underneath* their neighbour at
    identical x/z instead of beside them. In-game that looked like players
    doubled up on one lane with their input prompts overlapping - no error, no
    log line. Only the one identity-basis marker produced a real sideways step,
    which is why the symptom was four correct-ish spawns and four buried ones.
    `local_x` now flattens the axis to horizontal (falling back to local Z, then
    world X). **Re-check after an update:** a scene whose markers are laid on
    their side is the tell. Scan for it with the `_MOD` delta check - a
    displacement dominated by Y is always wrong for a ground spawn. As of
    2026-08-01 escalator_pit was the only affected scene.
18. **`get_transformed_aabb()` returns null in the release template, and
    assigning null to a typed variable aborts the function with NO error.**
    `var ab: AABB = mi.get_transformed_aabb()` silently killed the rest of
    `_ready()` - the print before it appeared, the print after it did not, and
    nothing was logged. Symptom is a function that half-runs. Use
    `mesh.get_aabb()` (local space) combined with
    `global_transform.basis.get_scale()`. More generally: a typed `var` is a
    runtime assertion, so a null from any engine call aborts the caller
    quietly. Suspect it whenever output stops mid-function with a clean log.
19. **Identify a mesh by toggling it, not by its name or listed position.**
    Escalator Pit's handrails are `Plane_003` - a name suggesting a flat plane,
    at a position `(-9.6, 6.4, -11.4)` suggesting one left-hand prop. It is
    rotated 90 degrees about Z, so its 22.9-unit extent actually runs across
    all four lanes. Two confident readings of the scene put the rails inside
    `base platform` instead; one visibility toggle disproved both in a single
    run. `_mod_dump_all_meshes()` in escalator_pit.gd prints every mesh with
    world position and size under `-localtest` as the starting point, but the
    toggle is what settles it.
20. **Cloning a row/slot: instantiate the PackedScene, don't `duplicate()`.**
    `user_info.tscn` wires `label_rank` / `label_score` / `label_name` /
    `opacity_visuals` via `node_paths`. Those resolve to object references at
    instantiation, and `Node.duplicate()` copies the *reference*, not the
    clone's equivalent child - so a duplicated row writes its name and score
    into the template row's labels. The symptom is a new slot that renders
    blank while an existing slot flickers between two players' data. Instantiate
    from the `PackedScene` and re-assign the handful of outward-pointing
    exports (`score_screen`, `container_order_swapper`) by hand. Note this
    differs from `lobby_expand.py`, which clones at the *text* `.tscn` level
    where NodePaths are still paths and re-resolve correctly.
21. **Arrays sized to the roster inside the per-slot node itself.**
    `Intermission_UserContainer._ready()` builds its own `user_container_array`
    from `get_parent().get_children()`. Adding sibling slots therefore changes
    every existing slot's view of its neighbours - and it *appends* rather than
    clears, so re-running it doubles the list. Re-pin such arrays explicitly
    after cloning rather than trusting `_ready()` order.
22. **Duplicated node trees.** `multiplayer_menu.tscn` (the debug lobby)
    contains both a live tree and an `Old/` copy, and the handler that is
    actually wired up lives under `Old/Components`. Expanding the non-`Old/`
    set is a no-op. Always confirm which node owns the exported arrays:
    `awk '/^\[node /{n=$0} /^players = \[/{print NR": "n}' <scene>`.
    `scenes/lobby/lobby_scene.tscn` is clean — one handler, no `Old/` tree.
    Even after expanding the `Old/` set, the debug lobby still rendered four
    characters for reasons never isolated; it is developer-only scaffolding, so
    that was left alone rather than chased further.
23. **In the release template, indexing a typed Array out of bounds is
    completely silent.** Measured against the real `Machine Party.x86_64`, not
    assumed:

    | Expression, where `a` is a 4-element `Array[TextureRect]` and `i` is 4 | Result |
    |---|---|
    | `var v = a[i]` | `v` is **null**, **no error printed**, execution continues |
    | `a[i].visible = true` | **silent no-op**, no error, execution continues |
    | `a[i].set_visible(true)` | **process crashes** (SIGSEGV, core dumped) |

    So the whole "array too small, indexed by player" class splits in two, and
    the halves look nothing alike. A **property write** past the end - which is
    what `alive_indicator_icons[i].visible = true` is - does nothing at all,
    forever, with a clean log: the only way to find it is to read the code or
    to notice the UI is wrong. A **method call** past the end takes the whole
    instance down. Neither one prints the "Invalid access to index" message
    that a debug build would give you, so **do not conclude from a clean log
    that an array is big enough**.

    This is the same family as pitfall 18 (a null from an engine call aborting
    a function quietly) and it is why the static audits in this file - grep for
    exported arrays with exactly four `NodePath`s, grep for `arr[counter]`
    inside `spawn_players` - matter more than another test run. Reproduce with
    a temporary probe in `network_manager.gd`'s `_ready()` and
    `--headless -probe-oob`, the same way the `-validate-scenes` recipe works.
24. **`spawn_expand.py`'s extra markers are visible to 1-4 player games too.**
    See the section below; this is a live deviation from the vanilla rule, not
    a hypothetical.
25. **`MP_DEPLOY` copies only the `.pck`, so `testgame/` keeps a STALE ENGINE
    BINARY across a game update.** `build.py` ends with a single
    `shutil.copy2(OUT, stage/"Machine Party.pck")` — the executable and the four
    `.so` files are whatever was last copied there by hand. That is invisible and
    harmless *within* a version, and actively misleading *across* one.

    On the v1.5.0 rebuild every validation run — the boot test, `-validate-scenes`
    and all eight-client sessions — was run against the **Godot 4.5.1** binary
    left over from v1.0.7, while the pck under test was v1.5.0. Nothing
    complained: the pck format is v3 in both, so it simply loads, and
    `Running version:` comes from `globals.gd` **inside the pck**, so it printed
    the new version and looked like proof. An engine upgrade is precisely the
    thing that run was supposed to be testing, and it tested nothing.

    It also produced a wrong conclusion before it was caught: an error class was
    recorded as 8-player-only when the run that "found" it was on the old engine.

    **After step 1 of any update, refresh the whole test folder, not the pck:**

    ```bash
    cp "/mnt/secondary/SteamLibrary/steamapps/common/party project/Machine Party_Linux/Machine Party.x86_64" testgame/
    cp "/mnt/secondary/SteamLibrary/steamapps/common/party project/Machine Party_Linux/"*.so testgame/
    ```

    and confirm it took, because no in-game output will tell you:

    ```bash
    md5sum testgame/"Machine Party.x86_64"   # must match the new install
    ```

    Generally: `Running version: v<new>-8P-v<modrelease>` proves the **pck** is
    the mod's. It says nothing whatsoever about which engine is running it.
26. **An `@rpc("authority")` call on a PLAYER node is rejected, silently.**
    `set_player_presence()` does
    `set_multiplayer_authority(player_presence.network_id, true)`, so each player
    node's authority is **that player's own peer**. The host is therefore not the
    authority for anybody else's node, and an `"authority"` RPC sent from the
    host is refused on all seven of them:

    ```
    ERROR: RPC 'mod_set_room_rpc' is not allowed on node .../BurnRecyclePlayerN
    ```

    The effect simply never applies. In The Filter that left all eight players
    stacked two-per-station while `[FILTER8] rooms=2 subtrees=6/6` reported
    success on every peer - the rooms really had been built, the players just
    never moved into them. **Vanilla's own `setup_rpc` and `set_player_presence`
    are `"any_peer", "call_local"` for exactly this reason; match them** when
    calling a method on a player node from the host.
27. **A scene-level `grep type="X"` cannot see inside INSTANCED sub-scenes.**
    Searching `burn_recycle.tscn` for `type="Skeleton3D"` returns zero, and the
    scene contains four of them - `player spawn parent` holds four instances of
    `burn_recycle_player.tscn`, whose internals never appear in the parent
    `.tscn` at all. Duplicating that node put four full character rigs in the
    second room, each starting `SkeletonIK3D` and running an absolute-path
    manager lookup while detached: 256 errors a run.

    A zero from a `type=` grep means "no node of that type is **declared here**",
    never "this subtree does not contain one". To see through an instance, follow
    `instance=ExtResource("N")` back to its `[ext_resource]` line and read that
    scene. **This is how the 45-degree clone attempt and the ghost-rig bug both
    stayed hidden while every measurement passed.**
28. **The camera is not axis-aligned - state the screen/world mapping BEFORE
    discussing any position.** Firearm Factory's camera sits at
    `(-17.9, 11.9, 0)` looking along **+X**, with its right axis on world **+Z**.
    So on screen, **right = +Z and up = +X**: two desks moved in world ±X appear
    at *top-* and *bottom-centre*, not left and right.

    Two rounds of a fix were lost to "the left one" meaning different things at
    each end of the conversation. Read the camera chain out of the `.tscn`
    (`camera main parent` basis; Godot cameras look down local **-Z**), say the
    mapping out loud, and prefer a **top-down diagram** for anything positional -
    one settled in a single pass what prose had failed to in two.
29. **A placement rule must test the property that matters, not a proxy for it.**
    Two of Firearm Factory's added desks needed turning because their *approach
    side* pointed into a wall. The rule written first tested **which wall is
    nearest** - plausible, geometric, and about the wrong thing. What decides it
    is the interact box: `BoxShape3D(2, 5, 3.6)`, approach along the 3.6-deep
    local Z. Testing proximity instead of approach axis selected the **exact
    complement**: it turned the two desks that were already correct and left the
    two broken ones alone.

    Every trace passed either way, because nothing measurable distinguishes them.
    When writing a rule about geometry, name the property you are actually
    encoding and check that the data supports it - a rule that sounds principled
    and correlates with the right answer is not the same as one that computes it.

---

## Spawn markers are visible to 1-4 player games too

**Found 2026-08-01. Scope enumerated 2026-08-04. DECIDED 2026-08-04: left as
is, deliberately. Do not open this as a bug.**

The whole of it in four lines, for whoever hits this next:

- A 1-4 player game can seat a player on a mod-added spawn marker, which is
  **1.2u sideways from a vanilla one, same rotation, same floor, in frame**.
- It affects **nine** scenes, six of them live; the full table is below.
- Nothing in gameplay depends on it: spawn order in these minigames is
  randomised anyway, so which player gets which spot is already
  non-deterministic run to run.
- The user weighed it on 2026-08-04 and judged it too minor to be worth touching
  nine minigames. **The cost of fixing it exceeds the cost of the deviation.**

**What would reopen it.** Any of these is real evidence and worth acting on -
none has been observed:

- a player spawning **inside or on top of** geometry, half-clipped into a prop,
  or falling through the floor at 1-4 players (the audits print
  `DISPLACED` / `FELL_THROUGH` - grep those first);
- a 1-4 round that plays measurably differently from vanilla because of a start
  position - e.g. someone reliably reaching a pickup or hazard first;
- a player spawning outside the playable area, which is possible in principle
  because a clone displaces *outward* and is not clamped to the original span
  (see `MINIGAMES.md` §9);
- a bug report that only reproduces at 1-4 and mentions starting positions.

**If you are here because you found a similar-looking problem elsewhere**, the
generalisable part is this: the mod adds nodes to shipped scenes, and any
shipped code that walks *all* the children of a container will pick up the added
ones at every roster size. `shuffle()` is just the case that made it visible.
The same shape could bite any container the mod grows - and the way to avoid it
outright is to build the additions at runtime behind a roster gate, as
`duck_hunt` and `forklift_certified` do, rather than baking them into the
`.tscn`.

Most minigames start `spawn_players()` with

```gdscript
var spawn_positions = player_spawn_positions_node.get_children()
spawn_positions.shuffle()
```

and then take the first N. The expanded scenes carry **eight** markers at every
roster size, so a four-player game shuffles all eight and can seat players on
`*_MOD5`..`*_MOD8`. Measured, at four players:

```
[ROOMBA8] ... spawned=4 ... player=DvdRoombaPlayer3 marker=Marker3D3_MOD7 dist=0.20 OK
[SPINE8]  ... spawned=4 ... player=SpineBreakerPlayer marker=Marker3D3_MOD7 dist=0.00 OK
```

Those positions do not exist in vanilla, so a 1-4 player game is **not**
pixel-identical there - players stand up to ~1.2u from where they would have.
It is invisible in practice (they are still on the floor, in frame, and spawn
order is randomised anyway), which is presumably why fifteen scenes' worth of
this went unnoticed, but it does contradict the rule at the top of this file.

### Exact scope, enumerated 2026-08-04

It needs **both** a scene carrying baked `_MOD` markers **and** spawn code that
shuffles the marker list. Fifteen scenes carry the markers; twelve scripts
shuffle a spawn list; the intersection is **nine**, of which six are live:

| Affected - in the rotation | Affected - debug-only |
|---|---|
| `dvd_roomba`, `spine_breaker`, `disco_dodge`, `train_race`, `knife_at_the_office`, `exploding_collar_race` | `cutscene_test`, `cutscene_game_02`, `memorize_path` |

**Not affected, and worth knowing why**, because the reasons are three different
mechanisms:

- **Take their markers in order, never shuffle:** `junk_platform` (uses
  `get_child(i)`), `escalator_pit`, `smoke_break`, `chisel_gauntlet`,
  `green_pea`, `shape_cutter`.
- **Sidestep it by construction** - markers built at runtime, host-only, gated on
  roster > 4, so at 1-4 the shipped markers are the only ones that exist:
  `duck_hunt`, `forklift_certified`. This is the newer pattern and the reason
  those two never had the problem.
- **Shuffles but has no `_MOD` markers:** `manufacture_gun` and `burn_recycle`.
  **Corrected 2026-08-08** — this used to read "`manufacture_gun`, still capped at
  4, so the mod adds no files for it", which was true until 2026-08-07. Both are
  uncapped now, and neither acquired baked markers when it was: `manufacture_gun`
  builds its four extra spawns at runtime behind the roster gate, so it belongs with
  `duck_hunt` and `forklift_certified` in the category above — **sidestepped by
  construction, not by being unreachable.** The conclusion is unchanged; the reason
  it used to give is gone.

The magnitude is exactly one `OFFSET` - **1.2u sideways along that marker's own
local X, with the same rotation** (see `MINIGAMES.md` §9). A 1-4 player game therefore
stands a player 1.2u from a vanilla position, facing the vanilla way, on the same
floor, in frame.

### Two ways to fix it, and the cheaper one is not the obvious one

1. **Filter the shuffle** - drop names containing `_MOD` when
   `PlayerManager.player_presences.size() <= 4`. Small per site, but it is nine
   scripts, several not in the overlay today, so it *adds* overlay files that
   must then be re-derived on every game update. **Deliberately left alone
   rather than half-done** - a fix in four of nine is worse than a documented
   deviation.
2. **Build the markers at runtime instead**, the Duck Hunt / Forklift pattern.
   This removes the deviation *by construction* rather than by an `if`, and it
   **shrinks** the overlay instead of growing it: diffing each expanded scene
   against vanilla shows that **seven of the nine `.tscn` files exist only to
   carry the four extra markers** (`dvd_roomba`, `spine_breaker`, `train_race`,
   `knife_at_the_office`, `cutscene_test`, `cutscene_game_02`, `memorize_path`
   - every other differing line is whitespace). Convert those and they leave the
   overlay entirely: 16 scenes drop to 9, and the manifest falls from 53 files
   to 46. Only `disco_dodge` (`spawn_limit`, itself documented as inert) and
   `exploding_collar_race` (an exported spawn array) carry a second change and
   would have to stay.

Option 2 is the better trade on every axis except the size of the change, and it
attacks the real cost of this mod - the number of files re-derived per game
update. It has not been done because nothing is broken and it touches nine
minigames at once; it wants a deliberate decision, not a drive-by.

## How to verify anything (learned the hard way)

Three times a change was reported as working when it was not. Each time the
evidence was real but measured the wrong thing:

1. A screenshot of geometry that was still **baked into the .tscn**, which was
   then replaced by runtime code that silently did nothing.
2. A screenshot of the **host window** showing a fix no client had.
3. A "clean" 4-player error log from a run that **never left the lobby**,
   because the autostart threshold was `MAX_PLAYERS`.

So:

- **Make the code say what it did.** `chairs=8, is_server=false` from a *client*
  log is unambiguous; a screenshot is not. Add a `-localtest` trace before
  reaching for a capture.
- **Check a client window (P2..P8), never P1 alone.**
- **Re-verify after refactoring**, not just after writing. Moving the chair
  layout from the scene into script silently broke it, and the earlier
  screenshot was still treated as proof.
- **Diff 4 vs 8** with the same test to separate mod bugs from vanilla noise.

## Handy commands

```bash
# build + deploy to the throwaway copy
MP_DEPLOY=~/Documents/Claude/machine-party-8p/testgame python3 tools/build.py

# 8 clients, straight into one minigame, 7 minutes to inspect
START=1 MINIGAME=GreenPea tools/localtest.sh 8 \
  ~/Documents/Claude/machine-party-8p/testgame 420

# full normal session loop at 8 - briefing/intermission NOT skipped
FLOW=1 tools/localtest.sh 8 \
  ~/Documents/Claude/machine-party-8p/testgame 420

# same at 4, to confirm vanilla behaviour is untouched
START=1 MINIGAME=GreenPea tools/localtest.sh 4 \
  ~/Documents/Claude/machine-party-8p/testgame 200

# what the traces said
grep -h "\[SEATS8\]\|\[STATIONS\]\|\[SHOTGUN\]\|\[PLATFORM\]\|\[SCORE8\]" /tmp/mp-localtest/p*.log

# did anyone spawn off a platform in Debris Platforms?
grep -h "OFF_DECK" /tmp/mp-localtest/p*.log || echo "all on deck"

# score + briefing sizing, host and clients (rows=8 at 8, rows=4 at 4)
grep -h "\[SCORE8\] is_server\|\[BRIEF8\] is_server" /tmp/mp-localtest/p*.log | sort -u

# did any player spawn inside geometry, in any of the four newest minigames?
grep -h "DISPLACED\|FELL_THROUGH" /tmp/mp-localtest/p*.log | sort -u || echo "all on their markers"

# Inside Job: is the search target reachable? (clamped=true is the fix working)
grep -h "\[KATO8\] search" /tmp/mp-localtest/p*.log

# what the REAL (non-custom) rotation is - the default debug lobby does NOT
# exercise this branch, so -original is mandatory for anything playlist-related
ARGS="-original" START=1 tools/localtest.sh 8 \
  ~/Documents/Claude/machine-party-8p/testgame 45
grep -h "\[ORIGINAL\]" /tmp/mp-localtest/p1.log        # confirms the branch
grep -h "Generating session playlist with" /tmp/mp-localtest/p1.log

# 4-vs-8 error CLASSES (pitfall 12) - run at 4, save, run at 8, compare
grep -hE "^ERROR|^SCRIPT ERROR" /tmp/mp-localtest/p*.log \
  | grep -viE "NO GRAB|Invalid packet|Node not found|Failed to get path" \
  | sed -E "s/#[0-9]+/#N/g; s/'[A-Za-z_]+[0-9]*:/'X:/g; s/[0-9]+/N/g" | sort -u > /tmp/err8.txt
comm -13 /tmp/err4.txt /tmp/err8.txt   # anything here is player-count related

# errors, minus the usual replication churn
grep -hE "^ERROR|^SCRIPT ERROR" /tmp/mp-localtest/p*.log \
  | grep -viE "NO GRAB|Invalid packet|Node not found|Failed to get path" \
  | sort | uniq -c | sort -rn
```

Minigame identifiers for `MINIGAME=`: `ChiselGauntlet`, `ExplodingCollarRace`,
`EscalatorPit`, `SmokeBreak`, `DiscoDodge`, `KnifeAtTheOffice`, `TrainRace`,
`GreenPea`, `DvdRoomba`, `JunkPlatform`, `SpineBreaker`, `DuckHunt`,
`ForkliftCertified`, `ManufactureGun`, `BurnRecycle` — **all fifteen, and every one
of them pinnable at 8.**

*This list used to end "plus the two still capped, `ManufactureGun` and
`BurnRecycle`, which only appear at <=4 players". That was true until 2026-08-07
and stale after it — and it is the worst place in this file for a stale line,
because it would tell a new session it cannot pin the two minigames most likely to
need work. Re-check it against `modded_minigame_player_cap` in
`mod/autoloads/globals.gd`, which now holds only `ScavangerChairs`.*

The localtest session ends because `localtest.sh` kills every instance when its
duration expires - that is not a crash. Pass a larger number to stay in-game.
