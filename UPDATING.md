# Machine Party 8-Player Mod — working notes & update guide

Hand this whole file to a fresh assistant session. It assumes **no memory** of
how the mod was built, and covers both *continuing development* and *rebuilding
after a game update*.

**This file is the entry point and is meant to be read end to end.** Three
things live in their own files because one read of this one stopped returning
all of it: the per-minigame detail is in **`MINIGAMES.md`** (split 2026-08-04
— read it when touching a specific minigame), the numbered failure modes are
in **`PITFALLS.md`** (split 2026-08-14 — **read it before changing code or
running the tools**), and the session log is in **`SESSION-LOG.md`** (split
2026-08-14 — read its top entries for what changed most recently; new entries
are recorded there).

## What is where

| | |
|---|---|
| **Start here → "Paste this to start"** | including the variant for "the game just updated" |
| **"Current status"** | what works, what is unproven, and "Open items" — where to pick up |
| **"Working environment"** | screenshots, missing tools, the build pre-flight. Read before running anything |
| **`SESSION-LOG.md`** | what changed most recently and what evidence backed it. New entries are recorded there |
| **"Overlay manifest"** | every file in `mod/`, mapped to the `MINIGAMES.md` section explaining it |
| **"Update procedure"** | the eight steps for rebuilding against a new game version |
| **"Testing — the validation recipe"** | the 8-client harness and the traps in it. Cited everywhere as *Testing* |
| **`PITFALLS.md`** | the numbered failure modes (32 so far). Cited from code as *pitfall N* — stable, do not renumber |
| **"A rule to preserve"** | 1-4 stays vanilla, and the two accepted breaches |
| **"Documentation policy"** | how this doc set stays lean — read before editing any of these files |
| **"Version control"** | the GitHub repo, commit discipline, and the release flow |
| **`MINIGAMES.md`** | sections 1-22, the per-minigame reference. Cited as *§N* |

Two numbering schemes are load-bearing because code comments cite them:
**rule N** refers to this file ("Paste this to start"); **pitfall N** means
`PITFALLS.md` (in this file before 2026-08-14). **§N** always means
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
3. **Archive, don't delete.** A session-log entry (recorded in
   `SESSION-LOG.md`) whose conclusions have been folded into "Current status"
   or `PITFALLS.md` moves to `SESSION-LOG-ARCHIVE.md`. Git history (since 2026-08-08) is a backstop, not
   a reading surface — a future session can grep the archive but will never
   think to excavate a commit, so the archive remains the recall path.
4. **Commit before restructuring.** The docs are in git since 2026-08-08:
   commit before any large reorganisation, then check the new text still
   answers every question the old text answered. The `*_old` copy-aside idiom
   now applies only to untracked material — decompiles, extractions, game
   copies; everything `.gitignore` excludes.

## Version control

Since 2026-08-08 the project is a git repo on `main`, pushed to
`https://github.com/Binary1936/machine-party-8p` — **public since 2026-08-08
at the maintainer's decision**; `NOTICE.md` carries the credit and the
unconditional takedown promise to the developers. The rules, each of which
protects something specific:

- **No commit before verification.** A change is committed only once it is
  verified to achieve what it set out to achieve — the measurement or trace
  evidence in hand, and where only eyes can verify (placement, facing,
  readability), only after the maintainer has looked. One verified change per
  commit, made after the review and the doc updates land, with the message
  pointing at the session-log entry; the log carries the evidence tables and
  a commit message never replaces it.
- **No push without a human check-in.** Pushing is never autonomous: present
  the commits that would go up — what each changed and the evidence behind it
  — and wait for the maintainer's OK. Batch at natural stopping points rather
  than asking per commit.
- **Run the static checks before every push.** `tools/checks/*.py` are the
  five invariants CI enforces (what each guards: the 2026-08-13 CI session-log
  entry); they run in seconds and a local pass guarantees a green run on
  origin — history there is append-only, so a red X can only be fixed forward.
  `sh tools/checks/install_hook.sh`, once per clone, installs a pre-push hook
  that makes the check automatic (hooks live in the untracked `.git/hooks/`,
  so every clone installs its own).
- **Subagents never commit or push.** The orchestrating session commits after
  its own review — a commit is a claim the change was verified, and only the
  reviewer can make it.
- **Never commit game content.** `.gitignore` blocks the decompiles, game
  copies, `dist/` and `*.pck`. A `git status` showing any of them means the
  ignore rules broke — stop and fix that; never force-add past it.
- **Tracked files are public-facing.** Personal or machine-local detail goes
  to `NOTES-LOCAL.md` (untracked), never into tracked docs. The 2026-08-08
  scrub set the baseline; keep it clean.
- **Commit identity is the repo-local GitHub noreply address** — set so no
  personal email enters public history. Do not set a global identity for this.
- **Future game updates need no `mod_vXXX/` overlay snapshot**: the old
  overlay is `git show <tag>:mod/<file>`. (`mod_v107/` predates git and
  stays for the v1.0.7 baseline.)
- **History on origin is append-only.** Never amend, rebase, or force-push
  anything already pushed; amending a commit that has never left this machine
  is fine. Expect non-Claude commits in the history — the maintainer commits
  directly, both locally and through the GitHub web editor, which is also why
  every session starts with `git pull`.
- **User-visible bugs get GitHub issues.** A confirmed bug or limitation that
  affects players is tracked as a public issue (`gh issue create`): symptom,
  scope, workaround if any — written for the public, so no personal info or
  machine paths, and check `gh issue list` for duplicates first. The issue and
  the session-log entry that owns the evidence cross-link each other; the
  session log remains the engineering record and the issue is the public
  tracker.
- **Release flow**, after step 8's zip rebuild and diff check: commit, tag
  the mod release label, `gh release create <tag>` with the zip attached.
  The zip is a Release asset, never a tracked file.

---

## Paste this to start

> I maintain an 8-player mod for the Steam game Machine Party, at
> `~/Documents/Claude/machine-party-8p`. Read `UPDATING.md` in that folder
> first — it documents the current state, the toolchain, every change the mod
> makes, and how to test with 8 local clients. The failure modes already hit
> are in `PITFALLS.md`; read it before changing anything.
> Then <describe what you want: e.g. "playtest Debris Platforms at 8 players",
> or "the game updated, rebuild the mod against the new version">.
>
> Five hard rules:
> 1. Never modify anything inside the Steam install directory — copy it out.
> 2. Never pass a shell-expanded path like `$PWD/...` to `installer/install.py`;
>    always type literal absolute paths.
> 3. A 1-4 player lobby must stay pixel-identical to vanilla — with two
>    documented exceptions; see "A rule to preserve".
> 4. Verify with the `-localtest` traces on a **client** window, not a host
>    screenshot — see "How to verify anything".
> 5. Never take a blind full-screen screenshot — see "Working environment".

This block is the generic entry point and ships with the repo. A maintainer
may layer their own workflow prompt on top of it (orchestration, delegation,
review habits); the rules above and the rest of this document remain the
binding minimum either way.

The mod currently targets **v2.1.2**. Read "Working environment" before
running anything, and `SESSION-LOG.md` for what changed most recently.

**If the game has just updated, replace that last line with this** — it is the
one instruction that decides whether the rebuild takes an hour or a day:

> The game updated to v&lt;new&gt;. Rebuild the mod against it following "Update
> procedure" in `UPDATING.md` — but do **step 4 before touching the overlay**:
> diff the old and new decompiles, then run the `filecmp` sweep to prove which
> of the 56 overlay files have byte-identical upstream source. Re-derive only
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
| Mod built against | game **v2.1.2** |
| Install (this machine) | `/mnt/secondary/SteamLibrary/steamapps/common/party project/Machine Party_Linux/` |
| v1.0.6 pck MD5 | `e8442750eb55abd0185c646b694b05da` (635,329,556 bytes) |
| v1.0.7 pck MD5 | `01e9d9140a01745dc4236c50c9837bcd` (635,331,268 bytes) |
| v1.5.0 pck MD5 | `f5912732bfa2cc5cba4340270fd76147` (635,333,716 bytes) |
| v2.1.2 pck MD5 (current target) | `f5ea2339e870cc507a58de63e4b78908` (634,798,100 bytes — the first update to SHRINK the pck) |
| `Machine Party.x86_64` MD5 | `9bac445821a671a8adfd782773fdbdb8` (70,179,064 bytes) — unchanged v1.5.0 → v2.1.2 (no engine bump this time); it changed at v1.5.0 (4.5.1 → 4.5.2) |
| Scope | **Online (Steam/ENet) only.** Local couch play was explicitly out of scope. |

The install folder holds `Machine Party.pck`, `Machine Party.x86_64`, and four
`.so` files. **The mod only ever changes `Machine Party.pck`.**

## The last update, and how it was verified (v1.5.0 → v2.1.2, 2026-08-14)

**This is a worked example, not a changelog entry — and the sweep at the bottom
of it is a tool you should run, not a note about something that already
happened.** If you are here to rebuild against a new version, this section plus
step 4 of the update procedure is the whole method.

The mod targets **v2.1.2** as of this writing. This was the **largest patch
yet** — a couch/local-multiplayer feature wave plus a custom-playlist shuffle
option — and the first to add and remove files (33 added, 2 removed, 101
changed at the raw-pck level; the pck *shrank* by ~535 KB). The engine binary
did **not** change (still Godot 4.5.2), the first update where it didn't need
re-checking under pitfall 25 — but check it every time; that is what the md5
row in "The facts" is for. Script and scene counts moved for the first time:
368 → **371** `.gd`, 140 → **141** `.tscn` (all three new scripts and the one
new scene are couch-mode UI — no new minigame; the marker rescan confirmed no
new spawn containers).

The filecmp sweep put **25 of the 56 overlay files** in the re-derive column,
30 as byte-identical upstream, and 1 (`mod_player_name_list.gd`) as mod-added.
What the re-derivation actually met, worth knowing next time:

- **Most upstream changes were additive couch-mode branches** (`if
  GameManager.local_game:`) threaded through scripts the mod owns. The mod is
  online-only, so its deltas re-applied beside them cleanly — but two files
  were genuinely restructured:
- **`duck_hunt_local_handler.gd`: the mod's delta became obsolete.** Upstream
  deleted the roster-indexed `Layouts` dictionary whose missing 5-8 keys the
  delta guarded against, replacing it with a roster-independent two-pane
  `setup()`. The re-derived file came out byte-identical to vanilla, so it
  **left the overlay** (56 → 55 files). A delta can evaporate; the sweep plus
  a per-file read is what notices.
- **`junk_platform.gd`'s `spawn_players()` was rewritten** (positions gathered
  into an array, shuffled only in couch mode). The online path still walks
  markers in child order — re-derived by hand and the 2-per-deck property
  re-verified, not assumed.
- **Upstream rotated two of `junk_platform.tscn`'s shipped spawn markers
  180°.** The expander clones inherit the flip (their displacement flips with
  local X); traced arithmetically and accepted as vanilla's change.
- **Two tool traps surfaced.** `lobby_expand.py` today repositions the shipped
  Player2-4 preview slots (the shipped v1.2 scene had them at vanilla
  positions — restored by hand, because `lobby_scene.gd` snapshots the baked
  positions at load as its ≤4-player home layout, so moving them breaks rule
  3). And `spawn_expand.py` must never run on `smoke_break.tscn` — its seats
  are hand-authored (§14); the entry in `spawn_targets.txt` is now commented
  out with the reason. **Run the expander only on scenes whose overlay change
  is markers-only.**
- One upstream/mod collision needed a judgment call: `burn_recycle.gd`'s new
  couch hide-tag call landed inside the block the mod's per-room
  `eliminate_players()` rewrite replaces; it was re-inserted per victim inside
  the mod's loop, matching vanilla's semantics.

Verification: delta-of-deltas per file (residue explained line by line — the
only content residues are the version constants, the junk marker rotation, and
the two adaptations above), all five static checks, `-validate-scenes` in the
real release binary (**55/55 OK, failures=0**), boot test printing
`v2.1.2-8P-v1.2`, and the localtest series in the 2026-08-14 session-log
entry. The quasivanilla overlay needed 2 of its 4 files re-derived and
`qv.pck` rebuilt.

**Verify the sweep's claim yourself before trusting it on the next update** —
do not assume a small patch, and do not assume a big one. The check is cheap:

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
| v1.5.0 pck | `f5912732bfa2cc5cba4340270fd76147`, 635,333,716 bytes |
| v2.1.2 pck | `f5ea2339e870cc507a58de63e4b78908`, 634,798,100 bytes |

A clean unmodified v2.1.2 copy is kept at `testgame_new/`; the v1.5.0
decompile is at `project_old/` / `extracted_old/`. (The v1.0.7 generation was
deleted this rebuild, as its note said to; `mod_v107/` stays as the pre-git
baseline.)

**One thing to know about the re-derivation itself.** Applying the old mod
delta to the new source with `patch` works for most files — but **`patch`
reporting "succeeded with fuzz" is a request to go and read the result, not a
pass** (a fuzzed hunk once landed in the wrong branch of `game.gd` and parsed
into a black screen; see the archived v1.5.0 worked example in
`SESSION-LOG-ARCHIVE.md`). The check that catches a misapplied hunk cheaply is
to diff the deltas against each other:

```bash
diff <(diff project_old/$f <old mod>/$f) <(diff project/$f mod/$f)
```

Empty means the mod change carried over exactly; anything else is either an
upstream restructure you must account for, or a misapplied hunk. Since the
repo is in git, `<old mod>` is just `git show <last-release-tag>:mod/$f`.

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
  **2026-08-15:** the vanilla disconnect-during-load wedge behind issues #10
  and #12 (silent rifle, black screen at the end) is fixed at every roster size
  — pitfall 32, §19, and the session-log entry. Issue #11 (the crash that
  triggered it) remains open, cause unknown.
- Forklift Certified (`ForkliftCertified`) - **uncapped 2026-08-04**. Four more
  delivery zones built at runtime at the yard's mid-edges (RPC, every peer),
  four more spawn markers (host-only), the crate sampler given the free centre
  cell and a reachable target, and the four-decal blood pool made to refill.
  See `MINIGAMES.md` §20.

**Vanilla-compat mode works and is verified locally (2026-08-09).** A player who
keeps the mod installed can host or join an ordinary lobby containing unmodded
clients on the same game version: the mod's RPCs were renamed to sort after vanilla's (pitfall 30)
and are kept off the wire at ≤4. **A mixed lobby caps at 4** — a vanilla joiner
that would push it past 4 is refused, because an unmodded build cannot render or
spectate a 5-8 player session — and **plays the exact vanilla rotation, cutscene
included**. The Steam backend's lobby callbacks cannot run locally, so v1.1 shipped as an
**Experimental prerelease** (maintainer's decision, 2026-08-09). **De-flagged
2026-08-13:** a real Steam mixed session confirmed both join directions
(modded host + vanilla joiner, vanilla host + modded joiner) — open item 3a is
closed, with the 5th-join refusal and the mixed-rotation cutscene still
resting on the local ENet evidence. **v1.2 (2026-08-13) is the current
release, a full release**, carrying the four fixes since v1.1 (issues #6, #7,
#8 and the station clone-list cleanup). Full local evidence in the 2026-08-09
session-log entry.

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
(`CutsceneTest`) is dropped from the session playlist at any roster size - the
mod's one sanctioned break from the 1-4-stays-vanilla rule. Since 2026-08-09 the
removal is **dynamic**: the entry sits in `default_playlist` in its vanilla slot
and `generate_session_playlist()` erases it only when every peer is modded, so a
mixed lobby plays it. It is still launchable via `-debug-tools`. See "The first
sanctioned exception".

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
`LOC_EMPTY` and are in neither playlist. `CutsceneTest` is in vanilla's
`default_playlist` — and, since 2026-08-09, in the mod's too — but is a cutscene,
not a competitive game, so the mod filters it out of every all-modded session's
playlist at every roster size (see "The first sanctioned exception").

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
wheat-field cutscene is filtered out of every all-modded session's playlist at
every roster size (a mixed lobby keeps it), and nine
expanded scenes can seat a 1-4 player 1.2u sideways of a vanilla spawn. Neither
is a bug to fix; anything *else* that differs at 1-4 is.

### Open items, in rough priority — where to pick up

Nothing is broken. As of **2026-08-14** the mod builds clean against **v2.1.2**
(the full rebuild is the 2026-08-14 session-log entry; the per-minigame
verification below was done at 8 players on v1.5.0 and carries forward on the
strength of the sweep — 30 of 55 overlay files byte-identical upstream, the
rest re-derived and delta-checked). On v1.5.0 it installed and uninstalled
byte-identically (re-verified 2026-08-08 on a clean copy),
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

3a. ~~**Vanilla-compat's Steam backend path is unconfirmed.**~~ **Closed
   2026-08-13 — a real Steam mixed session, reported by the maintainer.** Both
   join directions were exercised and worked: modded host + vanilla joiner and
   vanilla host + modded joiner — the half only real Steam lobby callbacks
   could prove. Two of the enumerated sub-checks were **not** exercised in that
   session and rest on the 2026-08-09 local ENet evidence plus the backends'
   symmetry: the vanilla 5th-join refusal, and the wheat-field cutscene
   appearing in the mixed rotation. On this basis the maintainer de-flagged
   Experimental; **v1.2 ships as a full release**. Item 3 (the Steam lobby's
   8 previews) is untouched by this — a mixed session caps at 4.
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
python3 tools/checks/preflight_format_specifiers.py
```

---

## Session log

Moved to **`SESSION-LOG.md`** on 2026-08-14, when this file outgrew one read.
Newest first; its top entries are what changed most recently and the evidence
behind it. **New entries are recorded there, not here.** The archive flow is
unchanged: an entry whose conclusions are fully folded into the live sections
moves verbatim to `SESSION-LOG-ARCHIVE.md`, leaving a stub.

## Layout

Documentation, and which file owns what:

```
UPDATING.md   entry point: status, rules, update procedure, testing
PITFALLS.md   the numbered failure modes, cited as pitfall N (stable)
SESSION-LOG.md  the live session log, newest first; new entries land here
MINIGAMES.md  per-minigame reference, sections 1-22, cited as §N
SESSION-LOG-ARCHIVE.md  verbatim older session-log entries, plus later ones
              moved once fully folded into the live sections, each leaving a
              stub behind
README.md     player-facing overview. NOT authoritative - the docs above win
CLAUDE.md     auto-loaded pointer for sessions started inside this folder
```

```
extracted/   pristine unpack of the shipped .pck (reference; regenerate on update)
project/     full decompile via GDRE Tools — readable .gd / .tscn source
mod/         the overlay: ONLY the 55 files that differ (see the manifest)
dist/        built "Machine Party.pck" + machine-party-8p-mod.zip (release zip)
installer/   install.py, install.sh, install.bat, README.txt - the installer
              scripts, no mod copy inside; install.py falls back to the
              repo-root mod/ when run from here. The release zip is built
              from these four files plus mod/
testgame/    throwaway copy of the game install, for test runs
testgame_new/ clean UNMODIFIED v2.1.2 copy - installer round-trip target
project_old/ v1.5.0 decompile, kept as the diff baseline for step 4
extracted_old/ v1.5.0 raw extraction, same purpose
mod_v107/    the v1.0.7 overlay, pre-git baseline (git has every later one)

  The scaffolding above (~2.8 GB) goes stale on the NEXT update:
  project_old/extracted_old must be replaced by the v2.1.2 decompile (that is
  what `mv project project_old` in step 2 does — clear or rename the previous
  generation FIRST, or the mv NESTS and every step-4 diff is meaningless).
  The v1.0.7 generation was deleted during the 2026-08-14 v2.1.2 rebuild;
  the v1.0.6 generation was deleted before that.

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
  path. **Known drift (2026-08-14): its spread step also MOVES the shipped
  Player2-4 slots**, which the shipped scene keeps at vanilla positions —
  `lobby_scene.gd` snapshots the baked positions at load as its ≤4-player home
  layout (rule 3), so after any run, restore Player2-4's origins to vanilla
  (-2, 2, 6) by hand, or fix the tool first. The v2.1.2 rebuild did the hand
  restore; see the session-log entry.
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
- **`installer/install.py`** — standalone patcher for end users. Carries its own
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

**55 files: 39 `.gd`, 16 `.tscn`** (was 56 until the v2.1.2 rebuild dropped
`duck_hunt_local_handler.gd` — upstream deleted the roster-indexed `Layouts`
its delta guarded, so the file went byte-identical to vanilla; see the
2026-08-14 session-log entry). Regenerate with `find mod -type f | sort`.
On a game update, every one of these must be re-derived from the *new* source —
see step 5 of the update procedure. The "§" column is the section of **`MINIGAMES.md`** that explains the change.

| File | § | Change |
|---|---|---|
| `autoloads/globals.gd` | 2 | version strings (display + the two wire fields), 3 suit colours + tints, player caps, `supports_player_count()`, round counts. `default_playlist` is byte-identical to vanilla again since 2026-08-09 |
| `modules/multiplayer/network_manager.gd` | 1 | `MAX_PLAYERS` 4→8; `-localtest` backend; `mod_all_peers_modded()` |
| `modules/multiplayer/backends/steam_backend.gd`, `backends/enet_backend.gd` | — | **vanilla-compat handshake**: wire version + `mod8p` capability key, vanilla-peer accept, over-cap refusal and spectator demotion. See the 2026-08-09 session-log entry |
| `scenes/local_game/script/local_game.gd` | — | couch mode's own playlist generator — the **unconditional** cutscene filter (no vanilla peers by definition); see "The first sanctioned exception" |
| `scripts/scenes/game/game.gd` | 3, 19 | playlist filtering + fallback, **Arcade-branch cap filter + clamp (v1.5.0)**, **all-modded-only cutscene filter**, `-minigame` pin, round-count resolution, `[ROUNDS8] load`, **load-gate re-check on peer disconnect (pitfall 32, 2026-08-15)** |
| `scripts/scenes/game/states/minigame_playing_state.gd` | 19 | the **replay gate** — second round-count site |
| `scripts/components/character customization/customization_assigner.gd` | 4 | suit tinting |
| `scenes/bootstrap/scripts/bootstrap.gd` | 8 | `-localtest`, `-fullflow` |
| `scenes/lobby/lobby_scene.tscn`, `scenes/lobby/scripts/lobby_scene.gd` | 6 | 8 seats + 8 preview slots |
| `modules/multiplayer_lobby/multiplayer_menu.gd` | 6, 8 | debug-lobby seat map, window tiling, `-original` |
| `modules/multiplayer_lobby/mod_player_name_list.gd` | 7 | **the only file the mod adds** |
| `modules/multiplayer/backends/multiplayer_backend.gd` | 8 | window titles P1-P8 |
| `minigames/intermission_new/components/intermission_score_screen.gd` | 11 | 8 rows; reverb pitch clamp |
| `minigames/intermission_new/components/intermission_briefing_screen.gd` | 12 | 8 cards; `FLOW=1` auto-ready |
| `minigames/chisel_gauntlet_multiplayer/*` (4) | 5, 10 | 8 stations, facings, shotgun order, split-screen; the `.tscn` adds 4 identity spectate markers (pitfall 31) |
| `minigames/escalator_pit/*` (3) | 13 | 8 stair strips, hidden handrails |
| `minigames/smoke_break/*` (4) | 14 | 8 seats, crates, aim angles, 4 capped arrays |
| `minigames/green_pea/*` (2) | 10 | runtime 8-seat layout by RPC |
| `minigames/knife_at_the_office/*` (3) | 17 | search-target clamp, 8 hunt icons |
| `minigames/spine_breaker/*` (2) | 16, 18 | spawn audit + roster-scaled kill pace |
| `minigames/duck_hunt/*` (2) | 19 | runtime markers, magazine curve, animation fit, **`debug_skip_brief` reveal-skip repair (`can_aim` + overlay)**, **pre-start disconnect guard (pitfall 32)**. The old third file (`duck_hunt_local_handler.gd`, splitscreen crash guard) went byte-identical to vanilla in v2.1.2 and left the overlay |
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
`set_spectate_position_rpc`. See `zz_mod_add_stations_rpc()` in chisel_gauntlet.gd
and `zz_mod_apply_eight_seat_layout_rpc()` in green_pea.gd.

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

`MinigameIdentifier.CutsceneTest` - the wheat-field cutscene - is dropped from
the session playlist at **every** roster size, because it scored nothing and
broke the session's pace. So a 1-4 player modded lobby differs from vanilla by
that one entry.

**The removal is dynamic since 2026-08-09, not a deletion.** The entry is back
in `default_playlist` in `mod/autoloads/globals.gd`, in its vanilla slot with
its vanilla round count, so that list is now byte-identical to vanilla and step
5 re-derives it with nothing to re-apply. The filtering moved to
`generate_session_playlist()` in `game.gd`, gated on
`NetworkManager.mod_all_peers_modded()` and applied after all three branches
(default, custom, empty-list fallback) have filled the list — so it closes every
path the old static deletion closed. Vanilla-compat is why: **a lobby containing
an unmodded peer plays the exact vanilla rotation, cutscene included**, or the
two sides disagree about the playlist. Every session the maintainer actually
plays is all-modded, so the sanctioned behaviour is unchanged for them.

Couch mode has its own generator, so `scenes/local_game/script/local_game.gd`
is overlaid with the **unconditional** filter — a local session has no vanilla
peers by definition. See the 2026-08-09 session-log entry.

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
equal the number of `.scn` under `.godot/exported/`. That was
**368 scripts and 140 scenes** from v1.0.6 through v1.5.0 (v1.5.0 added a
whole game mode without changing either count), and became **371 and 141** at
v2.1.2 — so equal counts are a check on the *decompile*, not evidence about
the patch's size in either direction.

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
`!! no Marker3D children under '<path>'` from the expander. (All listed paths
resolved unchanged on both the v1.5.0 and v2.1.2 rescans; the v2.1.2 rebuild
commented out the `smoke_break` entry — its seats are hand-authored, §14, and
the expander destroys them — so 13 entries are active.)

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
- `mod/autoloads/globals.gd` holds **three** strings since vanilla-compat
  (2026-08-09), and only one of them is cosmetic:
  - `MOD_NETWORK_GAME_VERSION` → **exactly** the new game's own version string,
    e.g. `"v<new>"`. This is what goes on the wire, and the handshake compares it
    for equality against what an unmodded build reports. **A stale value silently
    refuses every vanilla peer** — the mod still works all-modded, so nothing
    else tells you. Copy it out of the *new* decompile's `globals.gd`, do not
    retype it.
  - `MOD_SUFFIX` → the mod's own release tag, `"8P-v<modrelease>"`. The backends
    put it on the wire under the `mod8p` key, so it is also what distinguishes a
    modded peer from a vanilla one and from an older mod build.
  - `game_version` → their concatenation, the display string; currently
    `v2.1.2-8P-v1.2`. A game update bumps only the game part — **carry the mod
    release label across unchanged** unless the mod itself is being released anew.
- `installer/install.py` → `SUPPORTED_VERSION = "v<new>"`
- `installer/install.py` (~line 329) → the `--verify` message **hardcodes the
  same display string**. It is the second place the label lives and it does not
  derive it, so it silently goes stale; keep the two in sync.
- `installer/README.txt` (ships inside the zip at its root) → the "DID IT WORK?" example
  strings and the "Built for Machine Party v<old>" line. **The third place the
  label lives**, and the one that went three minigames stale before the
  2026-08-08 release prep caught it — it is player-facing prose, so nothing
  breaks when it lies.

The **display** label therefore still lives in three places that must agree —
`globals.gd`'s `game_version`, `install.py --verify`, `README.txt` — and the two
**wire** constants above are a separate, fourth thing that only `globals.gd`
holds. Getting a display string wrong misinforms; getting
`MOD_NETWORK_GAME_VERSION` wrong breaks vanilla-compat outright.
`python3 tools/checks/version_strings.py` verifies all five sites at once —
run it right after the bump; CI fails the push if any disagree.

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
measured, and add an entry at the top of `SESSION-LOG.md`. The old contents of
that section move into the session log; it should always describe the **most
recent** update, so
the worked example a future session copies is the freshest one.

### 7. Build and validate
```bash
python3 tools/build.py
MP_DEPLOY=~/Documents/Claude/machine-party-8p/testgame python3 tools/build.py
```
Then the static checks — the same five CI runs, so a local pass here means a
green push later:
```bash
for s in tools/checks/*.py; do python3 "$s" || break; done
```
Then run the validation recipe below.

### 8. Repackage the release zip
`install.py`, `install.sh`, `install.bat` and `README.txt` live in `installer/`
(no mod copy inside it — `install.py` falls back to the repo-root `mod/` when
run from there). `dist/machine-party-8p-mod.zip` is built from those four
`installer/` files plus `mod/`; the zip's internal structure is unchanged —
the four files still land at the zip root, alongside `mod/`. There is no
`zip` binary on this machine, so build it with Python from the project root:

```bash
python3 - <<'EOF'
import os, zipfile
with zipfile.ZipFile("dist/machine-party-8p-mod.zip", "w", zipfile.ZIP_DEFLATED) as z:
    for f in ("install.sh", "README.txt", "install.py", "install.bat"):
        z.write(os.path.join("installer", f), arcname=f)
    for root, dirs, files in os.walk("mod"):
        dirs.sort()
        for f in sorted(files):
            z.write(os.path.join(root, f))
EOF
```

After building, extract to a scratch directory and `diff -rq` the extracted
`mod/` against `mod/` — it must be empty before the zip ships. Then commit,
tag, and attach the zip to a GitHub Release per "Version control".

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
python3 tools/checks/preflight_format_specifiers.py
```

Plain boot test (should run the full timeout with no script errors):
```bash
cd ~/Documents/Claude/machine-party-8p/testgame
timeout 25 stdbuf -o0 -e0 ./"Machine Party.x86_64" --windowed --resolution 960x540 2>&1 | grep -E "Running version|SCRIPT ERROR|Parse Error"
```
Should print `Running version: v<new>-8P-v<modrelease>` — currently
`v2.1.2-8P-v1.2` (game v2.1.2 rebuild of mod release v1.2, 2026-08-14).

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

### Mixed-lobby runs (vanilla-compat)

**The quasi-vanilla build** is how a vanilla peer is tested without Steam or a
second machine. `tools/quasivanilla/` holds a 4-file overlay, `build_qv.py` and
the built `qv.pck`; `testgame2/` (gitignored) is the game copy carrying it. The
overlay adds **only** the harness entry points (`-localtest`, `-startgame`,
window titling) — `globals.gd` is deliberately not overlaid, so the build is
**wire-identical to the stock game**: it reports vanilla's own version string
(currently `v2.1.2`), stamps no `mod8p` key,
and every `@rpc` set is exactly as shipped. Rebuild it with
`python3 tools/quasivanilla/build_qv.py` after any game update.

`VANILLA_SLOTS` (space-separated slot numbers) launches those slots from
`VANILLA_DIR` instead of the mod build:

```bash
VANILLA_DIR=~/Documents/Claude/machine-party-8p/testgame2 VANILLA_SLOTS="3 4" \
  START=1 MINIGAME=BurnRecycle tools/localtest.sh 4 ~/Documents/Claude/machine-party-8p/testgame 120
```

Three constraints, each of which will otherwise waste a run:

- **`START=1` only.** `FLOW=1` hangs a mixed run at the first briefing — the
  auto-ready lives in the mod's `intermission_briefing_screen.gd`, so quasi peers
  never ready and `check_all_ready()` never passes.
- **Any vanilla peer caps the session at 4**, so use N≤4 (N=5 only to test the
  over-cap refusal).
- **`ARGS="-original"` for anything about the playlist or the cutscene**, for the
  usual reason — see "The debug lobby is a *custom* game" above. A mixed
  `-original` run is how the 16-entry cutscene-bearing playlist was confirmed.

**The join-order trap.** Launch order does not control handshake arrival order,
so a run that simply starts 5 instances proves nothing about *which* peer is the
5th — two early "cap failed" results were this race, not a code defect. Cap tests
need controlled ordering: bring up the idle lobby first (the default `START=0`
path), wait for `connected=4` in `/tmp/mp-localtest/p1.log`, then launch the
overflow joiner by hand from the other directory. A refused vanilla joiner logs
`_on_join_refused with reason: 1` client-side; an over-cap *modded* joiner is
demoted to vanilla's debug spectator instead, which reads as `connected=5`
with `players=4`.

**Benign in mixed runs only** (all measured 2026-08-09; add to the normal
noise list, do not chase):

- `The rpc node checksum failed`, once per mod-scripted node per vanilla peer.
  Godot exchanges an md5 of each node's `@rpc` name set, and the mod's added
  names change it — but `scene_cache_interface.cpp` stores and confirms the cache
  entry regardless, so it is **print-only** (pitfall 30).
- Minefield's `curve.cpp` out-of-bounds burst (24× per peer) — reproduces in a
  **pure** quasi-vanilla session with no modded peers at all, so it is a
  vanilla-under-localtest artifact, not a compat defect.
- A `Node not found: Game/Minigame/<scene>` burst on clients at each round load,
  the same replication-churn family as the documented teardown noise.
- **The wheat-field cutscene never completes unattended**, by construction: its
  fallback Timer is dead code and reaching `Finished` needs a player to walk to
  the house. Unattended mixed runs stall at `PlayerMarker → Play` identically on
  every peer. Same class as Duck Hunt below — drive a window or pin past it.

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

### Simulating a peer crash during a minigame load

The trigger for pitfall 32 — and the only way to exercise the disconnect
handlers on the load path — is to kill one client the instant the host starts
loading a minigame, so its `player_loaded` never arrives and ENet notices only
by timeout (~15 s locally), after the others have loaded. Arm the killer
**before** launching; it waits for the host's load line:

```bash
( until grep -q "load minigame=DuckHunt" /tmp/mp-localtest/p1.log 2>/dev/null; do sleep 0.05; done
  kill -9 $(pgrep -f "x86_64 -localtest [4] join") ) &
START=1 MINIGAME=DuckHunt tools/localtest.sh 4 <game-dir> 900
```

**Do not write `pkill -f "-localtest 4 join"`** — the pattern is also on the
command line of the shell running it, so it kills the launcher instead of the
client (cost one run on 2026-08-15); the `[4]` regex cannot match its own text.
Kill signature: the slot's log stops at the briefing (`[BRIEF8]`), the host's
`[BRIEF8] players=` drops by one ~15 s later. Healthy signature after that:
`Game: SessionIntro → MinigameStart → MinigamePlaying` then the minigame's
`Empty → Round`; the broken one is `Empty → Reset` with no Game transition
(pitfall 32). Killing a joiner leaves 3 (or 7) live peers, so expect
roster-scaled traces to report the smaller roster. The 2026-08-15 session-log
entry has the measured runs.

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
python3 ~/Documents/Claude/machine-party-8p/installer/install.py --game-dir ~/Documents/Claude/machine-party-8p/testgame_new --verify
```
Expect `NOT PATCHED` → install → `PATCHED` → a second install attempt
**refused** (already-patched guard) → restore the pck from a pristine copy and
confirm the step-1 MD5. **The installer keeps no backup since 2026-08-14**
(issue #9 — a stale backup silently downgraded the game after an update), so
`--uninstall` restores nothing: it reports the state and points at Steam's
Verify integrity, and the test restores by re-copying the pristine pck you
staged. Verified 2026-08-14 against a clean v2.1.2 copy: install wrote 4206
files (55 from the mod, 92 originals replaced), `--verify` reported `PATCHED`
and `v2.1.2-8P-v1.2`, both re-install attempts were refused with the pck MD5
unchanged, and the earlier same-day round-trip on the backup-era installer
restored **byte-identically** (`f5ea2339…`, 634,798,100 bytes). **Both counts
track the overlay size** — each added `.gd` also displaces its `.remap` and
`.gdc` siblings — so re-derive them from the run rather than treating them as
constants; the 2026-08-08 wall-desk entry explains an earlier 82 → 88 shift.

`install.py --force` answers every prompt yes for non-interactive runs;
without it a scripted run dies on `EOFError` before touching anything.

---

## Pitfalls

Moved to **`PITFALLS.md`** on 2026-08-14 — the numbered failure modes (1-32 so
far) and the rules that avoid them, every one of which cost real time the
first go. Cited from code and docs as *pitfall N*; the numbering is stable —
never renumber. **Read it before changing code or running the tools.** New
pitfalls append at the end of that file.

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
   overlay entirely: 16 scenes drop to 9, and the manifest falls by seven files
   (56 → 49 at the current count). Only `disco_dodge` (`spawn_limit`, itself
   documented as inert) and
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
# the five static checks CI enforces - run before every push (or install the
# pre-push hook once per clone: sh tools/checks/install_hook.sh)
for s in tools/checks/*.py; do python3 "$s" || break; done

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
