# Machine Party 8-Player Mod — working notes & update guide

Hand this whole file to a fresh assistant session. It assumes **no memory** of
how the mod was built, covers both *continuing development* and *rebuilding
after a game update*, and **is meant to be read end to end**. Three companion
files: per-minigame detail in **`MINIGAMES.md`** (cited *§N*); the numbered
failure modes in **`PITFALLS.md`** (cited *pitfall N* — **read it before
changing code or running the tools**); and **`SESSION-LOG.md`**, whose top
entries are what changed most recently and where new entries are recorded.

## What is where

| | |
|---|---|
| **Start here → "Paste this to start"** | including the variant for "the game just updated" |
| **"Current status"** | what works, what is unproven, and "Open items" — where to pick up |
| **"Working environment"** | repo-relative commands, the screenshot rule, the fast path, the build pre-flight. Read before running anything |
| **`SESSION-LOG.md`** | what changed most recently and the evidence behind it. New entries land there |
| **"Overlay manifest"** | every file in `mod/`, mapped to the `MINIGAMES.md` section explaining it |
| **"Update procedure"** | the eight steps for rebuilding against a new game version |
| **"Testing — the validation recipe"** | the 8-client harness and the traps in it. Cited everywhere as *Testing* |
| **`PITFALLS.md`** | the numbered failure modes, cited from code as *pitfall N* — numbered, stable, never renumber |
| **"A rule to preserve"** | 1-4 stays vanilla, and the two accepted breaches |
| **"Documentation policy"** | how this doc set stays lean — read before editing any of these files |
| **"Version control"** | the GitHub repo, commit discipline, and the release flow |
| **`MINIGAMES.md`** | sections 1-23, the per-minigame reference. Cited as *§N* |

Two numbering schemes are load-bearing because code comments cite them:
**rule N** refers to "Paste this to start" in this file, **pitfall N** to
`PITFALLS.md`. **§N** always means `MINIGAMES.md`.

## Documentation policy

The reader of these files is a future session's context window, so every
sentence costs. Four rules, applied whenever any of them is edited (requested
by the maintainer, 2026-08-08):

1. **One authoritative home per fact.** New information goes where it belongs;
   everywhere else references it (*§N*, *pitfall N*, or a section name). The
   only sanctioned duplication is an entry-point file repeating a
   safety-critical rule so no session can miss it — and such a copy must say it
   is a copy and name its source (`CLAUDE.md` is the example).
2. **Tighten wording, never substance.** Rules, measurements, and the *why*
   behind each are the load-bearing content — a rule with its rationale
   stripped reads as optional to a future session. Cut narration; keep causes.
3. **Archive, don't delete.** A session-log entry whose conclusions have been
   folded into "Current status" or `PITFALLS.md` moves to
   `SESSION-LOG-ARCHIVE.md`. Git history (since 2026-08-08) is a backstop, not a
   reading surface — a session can grep the archive but will never think to
   excavate a commit, so the archive is the recall path. **At each release,
   archive every entry older than the previous release** (verbatim, one stub
   table naming the owning sections — the 2026-08-15 cut is the model), so the
   log stays the short "what changed most recently" read it is meant to be; it
   had reached 1,768 lines before that rule.
4. **Commit before restructuring.** Commit before any large reorganisation, then
   check the new text still answers every question the old text answered. The
   `*_old` copy-aside idiom now applies only to untracked material — decompiles,
   extractions, game copies; everything `.gitignore` excludes.

## Version control

Since 2026-08-08 the project is a git repo on `main`, pushed to
`https://github.com/Binary1936/machine-party-8p` — **public since 2026-08-08
at the maintainer's decision**; `NOTICE.md` carries the credit and the
unconditional takedown promise to the developers. The rules, each of which
protects something specific:

- **No commit before verification.** A change is committed only once it is
  verified to achieve what it set out to achieve — measurement or trace evidence
  in hand, and where only eyes can verify (placement, facing, readability), only
  after the maintainer has looked. One verified change per commit, after the
  review and the doc updates land, with the message pointing at the session-log
  entry; the log carries the evidence tables and a commit message never replaces
  it.
- **No push without a human check-in.** Present the commits that would go up —
  what each changed and the evidence behind it — and wait for the maintainer's
  OK. Batch at natural stopping points rather than asking per commit.
- **Run the static checks before every push.** `tools/checks/*.py` are the five
  invariants CI enforces (what each guards: the archived 2026-08-13 CI session-log
  entry); a local pass guarantees a green run on origin, where history is
  append-only so a red X can only be fixed forward.
  `sh tools/checks/install_hook.sh` installs a pre-push hook that makes this
  automatic — once per clone, since `.git/hooks/` is untracked.
- **Subagents never commit or push.** The orchestrating session commits after
  its own review — a commit is a claim the change was verified, and only the
  reviewer can make it.
- **Never commit game content.** `.gitignore` blocks the decompiles, game
  copies, `dist/` and `*.pck`. A `git status` showing any of them means the
  ignore rules broke — stop and fix that; never force-add past it.
- **Tracked files are public-facing.** Personal or machine-local detail goes to
  `NOTES-LOCAL.md` (untracked), never into tracked docs. The 2026-08-08 scrub
  set the baseline; keep it clean.
- **Commit identity is the repo-local GitHub noreply address** — set so no
  personal email enters public history. Do not set a global identity for this.
- **Future game updates need no `mod_vXXX/` overlay snapshot**: the old overlay
  is `git show <tag>:mod/<file>`. (`mod_v107/` predates git and stays for the
  v1.0.7 baseline.)
- **History on origin is append-only.** Never amend, rebase, or force-push
  anything already pushed; amending a commit that never left this machine is
  fine. Expect non-Claude commits — the maintainer commits directly, locally and
  through the GitHub web editor, which is why every session starts with
  `git pull`.
- **User-visible bugs get GitHub issues.** A confirmed bug or limitation
  affecting players is tracked as a public issue (`gh issue create`): symptom,
  scope, workaround if any — written for the public, so no personal info or
  machine paths, and check `gh issue list` for duplicates first. The issue and
  the session-log entry that owns the evidence cross-link; the log remains the
  engineering record, the issue the public tracker.
- **Release flow**, after step 8's zip rebuild and diff check: commit, tag the
  mod release label, `gh release create <tag>` with the zip attached. The zip is
  a Release asset, never a tracked file. Then archive the session-log entries
  older than the previous release (documentation policy, rule 3).

---

## Paste this to start

> I maintain an 8-player mod for the Steam game Machine Party; the repo is
> `machine-party-8p`, cloned wherever you keep it. Read `UPDATING.md` in that folder
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

---

## The facts

| | |
|---|---|
| Game | Machine Party, Steam AppID **4108000** |
| Engine | Godot **4.5.2** (`.pck` format v3 — unchanged by the 4.5.1 → 4.5.2 bump) |
| Mod built against | game **v2.1.2** |
| Install | `<Steam library>/steamapps/common/party project/Machine Party_Linux/` — copy it out, never work in place (the maintainer's library root is machine-local: project-folder `CLAUDE.md` / `NOTES-LOCAL.md`) |
| v1.5.0 pck MD5 | `f5912732bfa2cc5cba4340270fd76147` (635,333,716 bytes) — the `project_old/` diff baseline |
| v2.1.2 pck MD5 (current target) | `f5ea2339e870cc507a58de63e4b78908` (634,798,100 bytes — the first update to SHRINK the pck) |
| `Machine Party.x86_64` MD5 | `9bac445821a671a8adfd782773fdbdb8` (70,179,064 bytes) — unchanged v1.5.0 → v2.1.2; changed at v1.5.0 (4.5.1 → 4.5.2) |
| Scope | **Online (Steam/ENet) only.** Local couch play was explicitly out of scope. |

The install folder holds `Machine Party.pck`, `Machine Party.x86_64`, and four
`.so` files. **The mod only ever changes `Machine Party.pck`.**

## The last update, and how it was verified (v1.5.0 → v2.1.2, 2026-08-14)

**A worked example, not a changelog entry — and the sweep below is a tool to
run, not a note about something that already happened.** This section plus step
4 of the update procedure is the whole method.

v2.1.2 was the **largest patch yet** (a couch/local-multiplayer feature wave
plus a custom-playlist shuffle option) and the first to add and remove files: 33
added, 2 removed, 101 changed at the raw-pck level, the pck *shrinking* by
~535 KB. The engine binary did **not** change (still Godot 4.5.2) — the first
update where it needed no re-check under pitfall 25, but check it every time;
that is what the md5 row in "The facts" is for. Script and scene counts moved
for the first time, 368 → **371** `.gd` and 140 → **141** `.tscn` (all
couch-mode UI, no new minigame; the marker rescan confirmed no new spawn
containers). The filecmp sweep put **25 of the 56 overlay files** in the
re-derive column, 30 as byte-identical upstream, 1 (`mod_player_name_list.gd`)
as mod-added.

**Measure the patch; never assume a small one or a big one.** The three updates
so far bracket the range: **2 of 35** overlay files needed re-derivation at
v1.0.7, **7 of 50** at v1.5.0, **25 of 56** at v2.1.2. Re-deriving everything by
hand is days of work with a chance to drop a change at each edit; carrying
everything forward blindly silently reverts upstream fixes in files the mod owns.

Most upstream changes were additive couch-mode branches
(`if GameManager.local_game:`) threaded through scripts the mod owns, and the
mod being online-only meant its deltas re-applied beside them cleanly. Three
lessons from the rest:

- **A delta can evaporate.** Upstream deleted the roster-indexed `Layouts`
  dictionary that `duck_hunt_local_handler.gd`'s delta guarded, replacing it
  with a roster-independent two-pane `setup()`; the re-derived file came out
  byte-identical to vanilla and **left the overlay**. The sweep plus a per-file
  read is what notices.
- **A restructured function must be re-derived by hand and its property
  re-verified.** `junk_platform.gd`'s `spawn_players()` was rewritten (positions
  gathered into an array, shuffled only in couch mode); the online path still
  walks markers in child order, so the 2-per-deck property was re-verified, not
  assumed. Upstream also rotated two of `junk_platform.tscn`'s shipped markers
  180° and the expander's clones inherit the flip (displacement flips with local
  X) — traced arithmetically, accepted as vanilla's change.
- **An upstream/mod collision needs a judgment call.** `burn_recycle.gd`'s new
  couch hide-tag call landed inside the block the mod's per-room
  `eliminate_players()` rewrite replaces; it was re-inserted per victim inside
  the mod's loop, matching vanilla's semantics.

Verification: delta-of-deltas per file (residue explained line by line — the
only content residues are the version constants, the junk marker rotation and
the two adaptations above), all five static checks, `-validate-scenes` in the
real release binary (**55/55 OK, failures=0**), a boot test printing
`v2.1.2-8P-v1.2`, and the localtest series in the archived 2026-08-14
session-log entry. The quasivanilla overlay needed 2 of its 4 files re-derived
and `qv.pck` rebuilt.

**Verify the sweep's claim yourself on the next update.** The check is cheap:

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

**One thing to know about the re-derivation itself.** Applying the old mod delta
to the new source with `patch` works for most files — but **`patch` reporting
"succeeded with fuzz" is a request to go and read the result, not a pass** (a
fuzzed hunk once landed in the wrong branch of `game.gd` and parsed into a black
screen; see the archived v1.5.0 worked example in `SESSION-LOG-ARCHIVE.md`). The
check that catches a misapplied hunk cheaply is to diff the deltas against each
other:

```bash
diff <(diff project_old/$f <old mod>/$f) <(diff project/$f mod/$f)
```

Empty means the mod change carried over exactly; anything else is either an
upstream restructure you must account for, or a misapplied hunk. Since the repo
is in git, `<old mod>` is just `git show <last-release-tag>:mod/$f`.

---

## Current status (read this first)

**v1.5 (2026-08-16) is the current mod release, built against game v2.1.2.**
All fifteen rotation minigames are verified at 8 players on the host *and* on
clients with **positive trace counts** (not absence-of-errors), and each has
been watched at 8 by a person. Nothing reachable is capped:
`modded_minigame_player_cap` holds only `ScavangerChairs`, which is in neither
playlist. The lobby carries 8 seats, 8 character previews and a text roster of
Steam names (§6, §7); the intermission score screen and the pre-minigame
briefing screen both show 8 rows at 8 players and 4 at 4 (§11, §12).
**"Verified" means 8 players spawn correctly, the layout is right on clients,
and runs are error-free.** The instances idle — nobody plays — so scoring,
elimination order and win conditions at 8 remain unproven **everywhere**; that
is open item 1 and nothing above closes it.

Per minigame. The **identifier** is what `MINIGAME=` takes (Testing) and what
code uses; `MinigameReadableNames` in `autoloads/globals.gd` is the only
authoritative map, and display names and identifiers overlap almost nowhere —
**always write the identifier next to the display name**. Two were once
confused in this file: **Wrong Way is `EscalatorPit`, Stable Footing is
`DiscoDodge`.**

| Display name | Identifier | 8-player change | § |
|---|---|---|---|
| MINEFIELD | `ExplodingCollarRace` | 8 spawns, full rounds played to completion; `blood_trail.gd` empty-`Curve3D` guard | 10 |
| TABLE MANNERS | `GreenPea` | runtime 8-seat layout by RPC: 8 chairs, widened camera | 10 |
| CHISEL GAUNTLET | `ChiselGauntlet` | 8 stations with 8 distinct facings, execution device sweeps all eight, consoles/desks cloned; head-on jumbotron HUD above four | 5, 10 |
| DEBRIS PLATFORMS | `JunkPlatform` | 8 markers, two players per deck, full round at 8 with zero errors | 15 |
| STABLE FOOTING | `DiscoDodge` | `spawn_limit` 4→8 (measured inert either way); `[DISCO8] spawned=8` on host and all seven clients | 10 |
| SMOKE BREAK | `SmokeBreak` | 8 hand-authored seats plus two crates, gun retargeted for all eight, four seat-capped arrays fixed; some model clipping on the left four accepted | 14 |
| WRONG WAY | `EscalatorPit` | 8 stair strips (two per trough), 8 CRT screens, 8 input arrows; handrails and divider posts hidden, floor lowered slightly — vanilla placement, only count and lateral spacing modded | 13 |
| TUNNEL HAZARD | `TrainRace` | 8 spawns (`inward` mode), level already ships 8 nooks — no gameplay edit needed | 16 |
| INSIDE JOB | `KnifeAtTheOffice` | 8 spawns, search target clamped to the containers that exist, hunt HUD grown to 8 | 17 |
| SPINE BREAKER | `SpineBreaker` | 8 spawns; needed no capacity fix, but kill pace is scaled to the roster so an 8-player round is not 2.5× as long | 18 |
| LETHAL REBOUND | `DvdRoomba` | 8 spawns; no gameplay edit — hazard count does not scale with the roster, by design | 16 |
| DUCK HUNT | `DuckHunt` | uncapped 2026-08-02: 7 runtime duck markers above four, magazine curve to 7, 8 hunter turns not 16; disconnect-during-load fix (pitfall 32) | 19 |
| FORKLIFT CERTIFIED | `ForkliftCertified` | uncapped 2026-08-04: four runtime mid-edge delivery zones (RPC, every peer) and four runtime markers (host-only), crate sampler given the free centre cell and a reachable target, blood pool refills | 20 |
| THE FILTER | `BurnRecycle` | uncapped 2026-08-07 as **two rooms** rather than eight stations: balanced (5→3+2, 7→4+3), per-room elimination at vanilla pace, global scoring with same-round ties resolved upward | 21 |
| FIREARM FACTORY | `ManufactureGun` | uncapped 2026-08-07: 8 runtime mid-edge spawns and workstations, wall desks turned and pushed out, roster-scaled ingredients, recipe projection raised | 22 |

All fifteen also carry the pre-start disconnect guard (§23). `ShapeCutter`,
`ScavangerChairs`, `MemorizePath` and `CutsceneGame02` map to `LOC_EMPTY` and
are in neither playlist.

**Vanilla-compat mode works.** A player who keeps the mod installed can host or
join an ordinary lobby containing unmodded clients on the same game version: the
mod's RPCs sort after vanilla's and are kept off the wire at ≤4 (pitfall 30). A
**mixed lobby caps at 4** — a vanilla joiner that would push it past 4 is
refused, because an unmodded build cannot render or spectate a 5-8 player
session — and **plays the exact vanilla rotation, cutscene included**. Confirmed
on real Steam 2026-08-13 in both join directions (modded host + vanilla joiner,
vanilla host + modded joiner), which is the half only real Steam lobby callbacks
could prove; the 5th-join refusal and the mixed-rotation cutscene still rest on
the 2026-08-09 local ENet evidence plus the backends' symmetry.

**Arcade mode** (a session mode new in game v1.5.0) works under the mod and is
filtered by the player caps like the other branches — see §3. It has never been
run by people: issue #4.

**The wheat-field cutscene (`CutsceneTest`) is removed from every all-modded
session's playlist at every roster size** — the mod's one deliberate break from
the 1-4-stays-vanilla rule; see "The first sanctioned exception".

**Pre-existing vanilla bug, not worth fixing:**
`scripts/scenes/game/states/minigame_end_state.gd`'s `enter()` calls
`update_playlist_state_rpc.rpc(owner.session_minigame_list)` with one argument
against a three-parameter function, so every minigame end logs
`Method expected 3 argument(s), but called with 1`. That file is **not** in
`mod/` — the error is identical at 4 and 8 players and predates the mod. The
`rpc_id` call in `game.gd` carries the real playlist state. Do not mistake it
for mod breakage when reading logs.

### Open items, in rough priority — where to pick up

Nothing is broken. **Numbering is stable; missing numbers are closed items —
the session-log archive has them.**

0. **Every expanded pair starts interpenetrating** (issue #2). Markers are
   placed `OFFSET` = 1.2u apart but each pair settles ~1.58-1.60u apart once
   physics resolves the first frame (Tunnel Hazard, 2026-08-05, all three
   pairs), **so a character is ~1.6u wide and 1.2 is too small**;
   `MIN_CLEARANCE` (1.0) is under-set for the same reason. The authored collider
   is a `CapsuleShape3D` of radius 0.7 (1.4u across) in every physics-bodied
   player scene, and *why* the settle is ~0.2u wider is not established
   (depenetration overshoot, `safe_margin`, residual shove velocity) — **design
   against the measured 1.6, not the authored 1.4**. The same 1.2 is used in all
   fifteen expanded scenes, and no trace has ever shown it. Same mistake in
   another shape: Firearm Factory's `MOD_ITEM_SPREAD` 0.45u against 0.63-1.61u
   items (fixed 2026-08-08, §22); **the method that worked: measure the
   object's footprint out of its `.tscn`, then check the candidate against what
   is around each site.**

   Analysed 2026-08-08 from scene colliders only — **computed, NOT seen**:
   - Candidate `OFFSET` **1.7**, `MIN_CLEARANCE` **1.6**. 12 of the 14 baked
     scenes then move linearly along the same ray, so their clones stay where
     the audits checked them; `shape_cutter` re-ranks non-linearly (flips sides
     by 2.0); `smoke_break` must **never** be regenerated by the tool
     (hand-authored seats, §14); `escalator_pit` is immune (its script
     overwrites all eight marker positions at runtime).
   - Two clone sites compute as **inside solid geometry at 1.2**, invisible to
     every trace because the audits measure distance to the nearest *marker*
     (`MOD_DISPLACED_DIST` = 2.0), never to geometry: `knife_at_the_office`'s
     `Marker3D4_MOD8` (0.46u from a desk collider, against a 0.8u body radius)
     and `exploding_collar_race`'s `player spawn 1_MOD6` (0.53u from a pillar).
     Raising `OFFSET` barely helps either; `inward` mode fixes both (computed
     1.81u and 3.28u at 1.7) — but a larger offset in `inward` mode walks
     clones toward the middle of the level, safe from walls but not
     automatically right (in Tunnel Hazard, toward the train's centreline).
   - **Green Pea is coupled:** `MOD_CHAIR_NARROW` (0.6) was derived as 1.2/2.0,
     so an `OFFSET` change means re-tuning it in `green_pea.gd` and re-checking
     the camera constants there — **not** re-running the legacy chair tool
     (Toolchain).

   It moves players in fourteen verified scenes, so it wants a decision and a
   look.

1. **Nobody has ever *played* an 8-player session.** The harness runs eight
   unattended instances, so scoring, elimination order and win conditions at 8
   are unproven **everywhere** — the single largest gap, and structural: closing
   it needs in-game bots or input injection, neither of which exists, and a
   human can drive exactly one window. Duck Hunt is the sharpest consequence, as
   it cannot complete unattended at all — a harness limit, not a mod defect; see
   Testing, "What the local test still is not".

3. **The Steam lobby's 8 previews have never been seen with 8 real peers.**
   Structurally unverifiable locally: `lobby_scene.gd` has 12 `Steam.` call
   sites and its join path is built on Steam lobby callbacks, so the real lobby
   cannot run over ENet. A real 5-player lobby (2026-08-16) exposed the runtime
   spread stacking seats 2-4 on one chair (issue #14, fixed the same day —
   players 5-8 now sit on 1-4's laps, placed live in the game; §6). All eight
   seats have been looked at with every slot forced visible in the
   `tools/lobby_preview/` build; the per-slot visibility path with eight real
   joiners has not. Needs a real 8-player Steam session — issue #5.

5. **`Parameter "data.tree" is null`** — 1-3 benign lines at the instant a round
   ends, a vanilla coroutine resuming after its node left the tree. The only
   8-only error class left. Deliberately not chased.

6. **Smoke Break player-model clipping** on the left four seats. Cause is seat
   facing, not spacing; blocked by pinned seats and the camera frame. Accepted —
   issue #3.

8. **A roster that shrinks between load and spawn can leave a scene on the wrong
   layout for one round.** Escalator Pit (`_enter_tree`) and Smoke Break
   (`_ready`) choose the 5-8 layout from `player_presences.size()` at scene load,
   while every other roster decision happens in `spawn_players()`. A peer that
   drops during the load of a 5-player lobby leaves those two expanded with four
   players for that round; every other roster size and minigame follows the
   shrunken roster. Unobserved, unfixed — cosmetic and rare; noted so nobody
   mistakes it for a spawn bug.

Arcade mode has never been run by people (issue #4) — see "Current status" and
§3. Issue #11 (a client hard-crash loading Duck Hunt in a 6-player lobby, single
report) is open with no known cause.

**Possible future work: build spawn markers at runtime behind a roster gate**,
the `duck_hunt` / `forklift_certified` / `manufacture_gun` pattern. It removes
the second sanctioned exception *by construction* rather than by an `if`, and
**shrinks** the overlay instead of growing it: seven of the nine expanded
`.tscn` files exist only to carry the four extra markers (`dvd_roomba`,
`spine_breaker`, `train_race`, `knife_at_the_office`, `cutscene_test`,
`cutscene_game_02`, `memorize_path` — every other differing line is whitespace),
so converting them drops all seven from the manifest; only `disco_dodge`
(`spawn_limit`, documented as inert) and `exploding_collar_race` (an exported
spawn array) carry a second change and would stay. The alternative — filtering
`_MOD` names out of the shuffle at ≤4 — was rejected because it *adds* overlay
files to re-derive on every game update, and a fix in four of nine sites is
worse than a documented deviation. Not done because nothing is broken and it
touches nine minigames at once; it wants a deliberate decision.

## Working environment (read before running anything)

Machine-local facts — Steam library root, desktop and capture tooling, the
layout-viewer URL — are deliberately not here: they live in the project folder's
local `CLAUDE.md` and the repo's untracked `NOTES-LOCAL.md`.

**Every command in this file is run from the repo root and uses repo-relative
paths** (`testgame`, `testgame_new`, `tools/...`); the tools resolve their own
location, so nothing here depends on where the repo is cloned — a clone path
with a space in it works as long as the one absolute path you ever type,
`install.py --game-dir` (pitfall 5 wants it literal and absolute), is quoted.
Unquoted, `tools/localtest.sh` would read the first word of such a path as the
game dir and the rest as the duration.

**Screenshots: never take a blind full-screen capture.** The game window cannot
be targeted or raised from the shell, so a capture grabs the whole screen with
the game not reliably frontmost — one such capture accidentally caught unrelated
private content from another application and was discarded unused. **Ask the
user to screenshot instead**; the `-localtest` traces are the primary evidence
anyway, and a screenshot is for judging *looks*. (Which capture tool works here
is machine-local: `NOTES-LOCAL.md`, which also holds the interactive 3D layout
viewer for Smoke Break's seats, crates and props, and its re-sync caveat.)

**Default to the fast path.** Use `START=1` for playtests; use `FLOW=1` only
when the user asks or when the session loop itself is under test. `FLOW=1` skips
nothing, so a run takes far longer.

**Pre-flight before every build**, because a bad format specifier in a minigame
script is invisible until that minigame loads (see pitfall 16):

```bash
python3 tools/checks/preflight_format_specifiers.py
```

---

## Layout

```
extracted/   pristine unpack of the shipped .pck (reference; regenerate on update)
project/     full decompile via GDRE Tools — readable .gd / .tscn source
mod/         the overlay: ONLY the 56 files that differ (see the manifest)
dist/        built "Machine Party.pck" + machine-party-8p-mod.zip (release zip)
installer/   install.py, install.sh, WindowsInstall.bat, README.txt - the
              installer scripts, no mod copy inside; install.py falls back to
              the repo-root mod/ when run from here. Also holds the gitignored
              python/ (Windows runtime, fetched by tools/fetch_embed_python.py
              - see Toolchain). The release zip is built from those four
              files plus mod/ plus python/ (step 8)
testgame/    throwaway copy of the game install, for test runs
testgame_new/ clean UNMODIFIED v2.1.2 copy - installer round-trip target
project_old/ v1.5.0 decompile, kept as the diff baseline for step 4
extracted_old/ v1.5.0 raw extraction, same purpose
mod_v107/    the v1.0.7 overlay, pre-git baseline (git has every later one)
tools/       pck.py, gdc.py, build.py, spawn_expand.py, lobby_expand.py,
             green_pea_chairs.py, spawn_targets.txt, localtest.sh,
             kill_slot_at_load.sh, checks/, quasivanilla/, lobby_preview/, bin/
```

The scaffolding above (~2.8 GB) goes stale on the NEXT update: `project_old/`
and `extracted_old/` must be replaced by the v2.1.2 decompile, which is what
`mv project project_old` in step 2 does — **clear or rename the previous
generation first** (step 2 carries the reason). The v1.0.7 generation was
deleted during the 2026-08-14 v2.1.2 rebuild; the v1.0.6 generation before that.

## Toolchain

- **`tools/bin/gdre_tools.x86_64`** — GDRE Tools v2.6.3. Decompiles the `.pck`
  into readable GDScript and `.tscn`.
- **`tools/pck.py`** — reads/writes Godot 4.5 PCK v3. `list` / `extract` / `pack`.
- **`tools/build.py`** — builds `dist/Machine Party.pck` from `extracted/` + `mod/`.
  `MP_DEPLOY=<dir>` also copies the result into a game folder.
- **`tools/spawn_expand.py`** — rewrites a scene's 4 player-spawn markers into 8.
- **`tools/lobby_expand.py`** — clones a lobby's 4 character preview slots into
  8 and extends the handler's exported arrays. `PARENT=...` overrides the node
  path. **Do not re-run it on `lobby_scene.tscn`**: since 2026-08-16 the scene's
  `Player5`-`Player8` carry hand-placed lap-seat transforms (§6) a run would
  overwrite, and its spread step also moves the shipped Player2-4 slots off
  their vanilla positions (rule 3). It remains the bootstrap for a fresh scene
  after an update that ships a new lobby; place the seats afterwards with
  `tools/lobby_preview/`.
- **`tools/lobby_preview/`** — `build_preview.py` builds the mod pck with a live
  seat-placement mode patched into `lobby_scene.gd` (all eight previews forced
  visible; keys to select, auto-place on the host's lap, nudge, turn, and print
  the exact `.tscn` lines). Output to `testgame/` or the folder given; never
  touches `mod/` or `dist/`. Recipe: Testing, "Placing the lobby previews".
- **`tools/kill_slot_at_load.sh`** — `SIGKILL`s one localtest joiner the instant
  the host starts loading a minigame: the crash-during-load trigger for pitfall
  32. Usage and traps under Testing, "Simulating a peer crash during a minigame
  load".
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
- **`installer/install.py`** — standalone patcher for end users, with its own
  PCK reader/writer; depends on nothing in `tools/`. Patches the **user's own**
  pck (unlike `build.py`, which builds from our `extracted/` snapshot), so it
  only swaps the overlay files. `ADDED_FILES` exempts files the mod *adds* from
  the "nothing to displace" compatibility check — without it that warning fired
  on every install because of `mod_player_name_list.gd`, training users to
  ignore the one message meant to stop a bad patch. Keep it in sync with the
  overlay. `find_game()` checks the Windows registry only when the ordinary
  paths find nothing — a deliberate choice to keep the installer's trust surface
  small (2026-08-18 session-log entry), not an accident of control flow, so
  don't collapse the two passes into one.
- **`tools/package_release.py`** — builds `dist/machine-party-8p-mod.zip` and
  refuses to produce a broken one; the only packaging command (step 8).
- **`tools/fetch_embed_python.py`** — downloads the pinned-SHA256 Windows
  embeddable CPython 3.13.1 into the gitignored `installer/python/`, bundled
  into the release zip so Windows users need no Python install.
  `package_release.py` calls it when that directory is absent, so it rarely
  needs running by hand; `--verify` checks an existing copy without downloading.

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

**56 files: 40 `.gd`, 16 `.tscn`.** Regenerate with `find mod -type f | sort`.
On a game update, every one of these must be re-derived from the *new* source —
see step 5 of the update procedure. The "§" column is the section of
**`MINIGAMES.md`** that explains the change.

| File | § | Change |
|---|---|---|
| `autoloads/globals.gd` | 2 | version strings (display + the two wire fields), 3 suit colours + tints, player caps, `supports_player_count()`, round counts. `default_playlist` is byte-identical to vanilla again since 2026-08-09 |
| `modules/multiplayer/network_manager.gd` | 1 | `MAX_PLAYERS` 4→8; `-localtest` backend; `mod_all_peers_modded()` |
| `modules/multiplayer/backends/steam_backend.gd`, `backends/enet_backend.gd` | — | **vanilla-compat handshake**: wire version + `mod8p` capability key, vanilla-peer accept, over-cap refusal and spectator demotion. See the archived 2026-08-09 session-log entry |
| `scenes/local_game/script/local_game.gd` | — | couch mode's own playlist generator — the **unconditional** cutscene filter (no vanilla peers by definition); see "The first sanctioned exception" |
| `scripts/scenes/game/game.gd` | 3, 19 | playlist filtering + fallback, **Arcade-branch cap filter + clamp (v1.5.0)**, **all-modded-only cutscene filter**, `-minigame` pin, round-count resolution, `[ROUNDS8] load`, **load-gate re-check on peer disconnect (pitfall 32, 2026-08-15)** |
| `scripts/scenes/game/states/minigame_playing_state.gd` | 19 | the **replay gate** — second round-count site |
| `scripts/components/character customization/customization_assigner.gd` | 4 | suit tinting |
| `scenes/bootstrap/scripts/bootstrap.gd` | 8 | `-localtest`, `-fullflow` |
| `scenes/lobby/lobby_scene.tscn`, `scenes/lobby/scripts/lobby_scene.gd` | 6 | 8 seats + 8 preview slots (5-8 hand-placed on 1-4's laps) |
| `modules/multiplayer_lobby/multiplayer_menu.gd` | 6, 8 | debug-lobby seat map, window tiling, `-original` |
| `modules/multiplayer_lobby/mod_player_name_list.gd` | 7 | **the only file the mod adds** |
| `modules/multiplayer/backends/multiplayer_backend.gd` | 8 | window titles P1-P8 |
| `minigames/intermission_new/components/intermission_score_screen.gd` | 11 | 8 rows; reverb pitch clamp |
| `minigames/intermission_new/components/intermission_briefing_screen.gd` | 12 | 8 cards; `FLOW=1` auto-ready |
| `minigames/chisel_gauntlet_multiplayer/*` (4) | 5, 10, 23 | 8 stations, facings, shotgun order, jumbotron HUD overlay above four, split-screen; the `.tscn` adds 4 identity spectate markers (pitfall 31) |
| `minigames/escalator_pit/*` (3) | 13, 23 | 8 stair strips, hidden handrails |
| `minigames/smoke_break/*` (4) | 14, 23 | 8 seats, crates, aim angles, 4 capped arrays |
| `minigames/green_pea/*` (2) | 10, 23 | runtime 8-seat layout by RPC |
| `minigames/knife_at_the_office/*` (3) | 17, 23 | search-target clamp, 8 hunt icons |
| `minigames/spine_breaker/*` (2) | 16, 18, 23 | spawn audit + roster-scaled kill pace |
| `minigames/duck_hunt/*` (2) | 19 | runtime markers, magazine curve, animation fit, **`debug_skip_brief` reveal-skip repair (`can_aim` + overlay)**, **pre-start disconnect guard (pitfall 32)** |
| `minigames/forklift_certified/*` (2) | 20, 23 | runtime mid-edge delivery zones + markers, crate spawn region and target, blood-decal pool refill |
| `minigames/burn_recycle/*` (2) | 21, 23 | **two-room layout**, balanced rooms, per-room elimination, tie-corrected scoring |
| `minigames/manufacture_gun/*` (1) | 22, 23 | **runtime mid-edge spawns + workstations**, wall-desk turn + slide + **wall push (`MOD_WALL_DESK_PUSH`)**, `empty_desk_array` bounds guard, `spawn_limit` raise by property write, roster-scaled ingredients at **`MOD_ITEM_SPREAD` 1.10**, **ingredient projection raised by its own measured height (RPC, all peers)** |
| `minigames/disco_dodge/*` (2) | 10, 16, 23 | `spawn_limit` 4→8 (inert — see §10), `[DISCO8]` |
| `minigames/junk_platform/*` (2), `train_race/*` (2), `dvd_roomba/*` (2) | 15, 16, 23 | markers + spawn audits |
| `minigames/exploding_collar_race/*` (3) | 10, 23 | `blood_trail.gd` empty-`Curve3D` guard; `exploding_collar_race.gd` joined the overlay 2026-08-15 for the **pre-start disconnect guard** (§23) — its only delta |
| `minigames/cutscene_test/*`, `cutscene_game_02/*`, `shape_cutter/*`, `memorize_path/*` (4 `.tscn`) | 9 | spawn markers only; unreachable scenes, kept defensively |

---

## Reading a property out of a shipped binary resource

GDRE decompiles scripts and scenes, but **not** `.res` resources — animations,
curves and the like stay binary. A timing number living in one can still be read
without the editor; this is how the Duck Hunt rifle animation lengths were
obtained, and the engine later confirmed the figure to four decimal places. Two
layers:

1. **Container.** `RSRC` is a plain binary resource. `RSCC` is the same thing
   zstd-compressed: header is magic, `cmode` (2 = zstd), `block_size` (4096),
   `read_total`, then one `u32` compressed size per block, then the blocks.
   Decompress each block and concatenate — **the payload has the 4-byte magic
   stripped**, so prepend `RSRC` before parsing. `pyzstd` is installed.
2. **Body.** After the magic: `big_endian`, `use_real64`, `ver_major`,
   `ver_minor`, `ver_format` (all `u32`), the type string, `importmd_ofs`
   (`u64`), `flags` (`u32`), `uid` (`u64`), **11 reserved `u32`**, then the
   string table: a `u32` count followed by that many `u32`-length-prefixed
   strings. These strings are **not** padded to 4 bytes, and the table does not
   start on a 4-byte boundary — a scan that steps by 4 will miss it.

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

## A rule to preserve: 1-4 player games must stay vanilla

Anything that repositions or rescales shipped geometry has to be conditional on
the roster size, applied from script at runtime, with the **scene left as
shipped**. Green Pea (`green_pea.gd`) and Chisel's `shotgun_check_order` follow
this pattern — grep for `MOD_VANILLA_SEATS` and `MOD_CHECK_ORDER_8`. The lobby
previews are the other legitimate shape: *added* nodes (`Player5`-`Player8`)
that vanilla's own handler leaves invisible at ≤4, so the shipped four are never
moved and no runtime layout code exists — the runtime spread that used to live
in `lobby_scene.gd` (`MOD_VANILLA_SLOTS`) was removed on 2026-08-16 after it
stacked seats 2-4 in a real lobby (issue #14).

Where the map itself needs more furniture, prefer cloning at runtime over
editing the scene. Chisel Gauntlet's consoles and desk colliders all sit at the
origin distinguished only by a Y rotation, so `_mod_add_stations()` duplicates
and rotates them 45 degrees — the `.tscn` is untouched and four players never
run the code. Green Pea's chairs work the same way.

Baking an eight-player layout into a `.tscn` is the easy mistake: it silently
changes what four players see. Verify both paths after any such change with
`START=1 MINIGAME=<X> tools/localtest.sh 4 ...` and `... 8 ...`.

### Runtime scene changes must be RPCs, not local calls

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

### The first sanctioned exception: the wheat-field cutscene

**Requested by the user on 2026-08-02, after being told it breaks this rule.
Do not "fix" it back.**

`MinigameIdentifier.CutsceneTest` — the wheat-field cutscene — is dropped from
the session playlist at **every** roster size, because it scored nothing and
broke the session's pace, so a 1-4 player modded lobby differs from vanilla by
that one entry.

**The removal is dynamic since 2026-08-09, not a deletion.** The entry sits in
`default_playlist` in `mod/autoloads/globals.gd` in its vanilla slot with its
vanilla round count, so that list is byte-identical to vanilla and step 5
re-derives it with nothing to re-apply. `generate_session_playlist()` in
`game.gd` erases it, gated on `NetworkManager.mod_all_peers_modded()` and
applied after all three branches (default, custom, empty-list fallback) have
filled the list, so it closes every path the old static deletion closed.
Vanilla-compat is why: **a lobby containing an unmodded peer plays the exact
vanilla rotation, cutscene included**, or the two sides disagree about the
playlist. Couch mode has its own generator, so
`scenes/local_game/script/local_game.gd` carries the **unconditional** filter —
a local session has no vanilla peers by definition.

The alternative, `modded_minigame_player_cap: {CutsceneTest: 4}`, would have
kept 1-4 vanilla and dropped it only at 5-8; it was offered and declined.
Nothing else was removed — the scene, `Globals.MinigamePaths`,
`CutsceneMinigameIdentifiers`, `MinigameCutsceneTransition` and the mod's four
extra spawn markers in `cutscene_test.tscn` are intact, so `-debug-tools` can
still launch the cutscene at up to eight players. "The debug lobby is a *custom*
game" is why this change is not observable in an ordinary localtest run.

### The second sanctioned exception: mod spawn markers at 1-4

**Found 2026-08-01, scope enumerated and accepted by the user on 2026-08-04
after it was measured. Do not open this as a bug.**

Nine expanded scenes bake eight spawn markers into the `.tscn` and shuffle the
whole list, so a 1-4 player game can seat someone **1.2u sideways of a vanilla
spawn — same rotation, same floor, in frame** (exactly one `OFFSET` along that
marker's own local X; §9). It is a real breach of this rule and it is being
kept, because fixing it means touching nine minigames for a deviation nothing in
gameplay depends on: spawn order in these minigames is randomised anyway, so
which player gets which spot is already non-deterministic run to run. Unlike the
cutscene exception this one is **not deliberate design** — it is a side effect
of baking additions into scenes.

The mechanism: most minigames start `spawn_players()` with

```gdscript
var spawn_positions = player_spawn_positions_node.get_children()
spawn_positions.shuffle()
```

and take the first N. The expanded scenes carry **eight** markers at every
roster size, so a four-player game shuffles all eight and can seat players on
`*_MOD5`..`*_MOD8` — measured at four players as
`[ROOMBA8] ... player=DvdRoombaPlayer3 marker=Marker3D3_MOD7 dist=0.20 OK` and
`[SPINE8] ... player=SpineBreakerPlayer marker=Marker3D3_MOD7 dist=0.00 OK`.

**Exact scope.** It needs **both** a scene carrying baked `_MOD` markers **and**
spawn code that shuffles the marker list. Fifteen scenes carry the markers;
twelve scripts shuffle a spawn list; the intersection is **nine**, six of them
live:

| Affected — in the rotation | Affected — debug-only |
|---|---|
| `dvd_roomba`, `spine_breaker`, `disco_dodge`, `train_race`, `knife_at_the_office`, `exploding_collar_race` | `cutscene_test`, `cutscene_game_02`, `memorize_path` |

**Not affected, and worth knowing why**, because the reasons are three different
mechanisms:

- **Take their markers in order, never shuffle:** `junk_platform` (uses
  `get_child(i)`), `escalator_pit`, `smoke_break`, `chisel_gauntlet`,
  `green_pea`, `shape_cutter`.
- **Sidestep it by construction** — markers built at runtime, host-only, gated on
  roster > 4, so at 1-4 the shipped markers are the only ones that exist:
  `duck_hunt`, `forklift_certified`, `manufacture_gun`. This is the newer pattern
  and the reason those three never had the problem.
- **Shuffles but has no `_MOD` markers:** `burn_recycle`.

**What would reopen it** (none observed): a player spawning **inside or on top
of** geometry, half-clipped into a prop, or falling through the floor at 1-4
(the audits print `DISPLACED` / `FELL_THROUGH` — grep those first); a 1-4 round
that plays measurably differently from vanilla because of a start position, e.g.
someone reliably reaching a pickup or hazard first; a player spawning outside
the playable area, possible in principle because a clone displaces *outward* and
is not clamped to the original span (§9); or a bug report that only reproduces
at 1-4 and mentions starting positions.

**The generalisable lesson:** the mod adds nodes to shipped scenes, and any
shipped code that walks *all* the children of a container will pick up the added
ones at every roster size. `shuffle()` is just the case that made it visible; the
same shape could bite any container the mod grows. The way to avoid it outright
is to build the additions at runtime behind a roster gate — the pattern to prefer
for any new expansion, and the fix option under "Open items", "Possible future
work".

## Update procedure

### 1. Snapshot the new build
```bash
md5sum "<Steam library>/steamapps/common/party project/Machine Party_Linux/Machine Party.pck"
```
Record it. Then **copy the game folder out** — never work in place:
```bash
cp -r "<Steam library>/steamapps/common/party project/Machine Party_Linux" testgame_new
```

### 2. Keep the old decompile for diffing
```bash
mv project project_old
mv extracted extracted_old
```
**`mv project project_old` NESTS rather than replaces if `project_old/` already
exists**, which would put the new decompile at `project_old/project/` and make
every step-4 diff meaningless. Clear or rename the previous generation first.

### 3. Re-extract and re-decompile
```bash
python3 tools/pck.py extract "<path to new Machine Party.pck>" extracted
./tools/bin/gdre_tools.x86_64 --recover="<path to new Machine Party.pck>" --output=project
```
**Do not pass `--headless`** — in headless mode GDRE silently fails to export
roughly half the scenes. It needs a display.

Sanity check: `.gd` count = `.gdc` count, `.tscn` = `.scn` under
`.godot/exported/` (371 and 141 at v2.1.2); equal counts check the decompile,
not the patch size.

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
Then, for **each file in the overlay manifest above**: `cp project/<path>
mod/<path>` and re-apply the change described in the section named beside it.
Then re-run the spawn expander:
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
re-authored, and `spawn_targets.txt` records where they were **as of v1.5.0**.
Treat it as a diff baseline: rescan, compare, and **write the corrected paths
back into `tools/spawn_targets.txt`**. A stale entry shows up as `!! no Marker3D
children under '<path>'` from the expander. (All paths resolved unchanged on the
v1.5.0 and v2.1.2 rescans.) The `smoke_break` entry is **commented out** — its
seats are hand-authored (§14) and the expander destroys them — leaving 13 active.

Watch for new minigames: anything added since will have four spawn markers and
needs an entry here, or it will crash at five players. But v1.5.0's Arcade mode
is a **session mode, not a minigame** and added no scenes at all, so "a new mode
in the patch notes" does not by itself mean a new entry — check the `.tscn`
count and the rescan, not the marketing copy.

**Two minigames are excluded from that file on purpose, and the rescan will
still list them.** `duck_hunt` and `forklift_certified` (and `manufacture_gun`)
build their extra markers at **runtime**, host-only, gated on roster > 4 (§19,
§20, §22). That is not an optimisation — it is what keeps a 1-4 game seating on
the shipped markers *only*, and why they sidestep "The second sanctioned
exception". Baking markers in **breaks the 1-4 path**: Forklift's
`spawn_players()` sizes `shuffled_indicies` from the marker count, so eight
baked markers make it span 0-7 while a roster ≤ 4 leaves `delivery_areas`
holding four — any drawn index ≥ 4 aborts the host's spawn loop, a black screen
at 1-4 players 98.6% of the time. `tools/spawn_targets.txt` warns at both
entries. **For any minigame expanded from here on, prefer runtime markers behind
a roster gate**: the only approach that keeps 1-4 genuinely vanilla, and it
keeps the scene out of the overlay entirely.

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
    e.g. `"v<new>"`. This goes on the wire, and the handshake compares it for
    equality against what an unmodded build reports. **A stale value silently
    refuses every vanilla peer** — the mod still works all-modded, so nothing
    else tells you. Copy it out of the *new* decompile's `globals.gd`, do not
    retype it.
  - `MOD_SUFFIX` → the mod's own release tag, `"8P-v<modrelease>"`. The backends
    put it on the wire under the `mod8p` key, so it is also what distinguishes a
    modded peer from a vanilla one and from an older mod build.
  - `game_version` → their concatenation, the display string; currently
    `v2.1.2-8P-v1.5`. A game update bumps only the game part — **carry the mod
    release label across unchanged** unless the mod itself is being released anew.
- `installer/install.py` → `SUPPORTED_VERSION = "v<new>"`
- `installer/install.py` → `verify()`'s printed message **hardcodes the same
  display string**. It is the second place the label lives and it does not derive
  it, so it silently goes stale; keep the two in sync.
- `installer/README.txt` (ships inside the zip at its root) → the "DID IT WORK?"
  example strings and the "Built for Machine Party v<old>" line. **The third
  place the label lives**, and the one that went three minigames stale before the
  2026-08-08 release prep caught it — it is player-facing prose, so nothing
  breaks when it lies.

The **display** label therefore lives in three places that must agree —
`globals.gd`'s `game_version`, `install.py --verify`, `README.txt` — and the two
**wire** constants are a separate, fourth thing only `globals.gd` holds. Getting
a display string wrong misinforms; getting `MOD_NETWORK_GAME_VERSION` wrong
breaks vanilla-compat outright. `python3 tools/checks/version_strings.py`
verifies all five sites at once — run it right after the bump; CI fails the push
if any disagree.

**And in the prose, which is easy to skip and leaves the next session reading a
handoff document that lies about which version it targets.** You are updating
your own instructions here; nobody else will:
- `UPDATING.md` — "The mod currently targets **v<old>**" near the top, the
  "The last update, and how it was verified" heading and its opening line, and
  the pck MD5/size rows in "The facts"
- `README.md` — the opening line and any other version reference
- `MINIGAMES.md` — only if a section quotes a version-specific measurement

Then rewrite "The last update, and how it was verified" for the patch you just
measured, and add an entry at the top of `SESSION-LOG.md`. The old contents of
that section move into the session log; it should always describe the **most
recent** update, so the worked example a future session copies is the freshest.

### 7. Build and validate
```bash
python3 tools/build.py
MP_DEPLOY=testgame python3 tools/build.py
```
Then the static checks — the same five CI runs, so a local pass here means a
green push later:
```bash
for s in tools/checks/*.py; do python3 "$s" || break; done
```
Then run the validation recipe below.

### 8. Repackage the release zip

```bash
python3 tools/package_release.py
```

Builds `dist/machine-party-8p-mod.zip` from the four `installer/` scripts
(`install.py`, `install.sh`, `WindowsInstall.bat`, `README.txt` — no mod copy
lives in `installer/`; `install.py` falls back to the repo-root `mod/`), plus
`mod/` and the Windows runtime, which it fetches if absent (Toolchain). The four
scripts land at the zip root, alongside `mod/` and `python/`.

Building and checking are **one command deliberately**, because the worst
failure is silent: `os.walk` over a missing `installer/python/` returns nothing
without erroring, so packaging without the runtime yields a valid ~21 MB zip —
the old release size, so it looks right — whose `WindowsInstall.bat` quietly
falls back to `py -3` and sends Windows users back to installing Python. The
script re-opens the finished zip and refuses one with no `python/`, a `mod/`
differing byte-for-byte from the overlay, or `install.sh` stripped of its exec
bit; `--verify` re-checks an existing zip. Builds are **reproducible** — member
timestamps and permissions are pinned, so the printed sha256 is checkable
against the published asset.

Then commit, tag, and attach the zip to a GitHub Release per "Version control".

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
cd testgame
timeout 240 stdbuf -o0 -e0 ./"Machine Party.x86_64" --headless -validate-scenes 2>&1 | grep VALIDATE
```
Expect `failures=0`. **Remove the hook afterwards** and rebuild.

**The plain boot test below does NOT cover minigame scripts.** It only reaches
the main menu, so a `.gd` living in a minigame scene is never parsed and a parse
error in it passes silently — then the minigame loads to a **black screen with
the music still looping** (pitfall 13's symptom, different cause; a stray `%r`
in a `push_warning` cost a full test cycle this way). Either run
`-validate-scenes` above, or pin the minigame with `MINIGAME=` and grep for
`Parse Error`. Cheap pre-flight for that class:
`python3 tools/checks/preflight_format_specifiers.py`.

Plain boot test (should run the full timeout with no script errors):
```bash
cd testgame
timeout 25 stdbuf -o0 -e0 ./"Machine Party.x86_64" --windowed --resolution 960x540 2>&1 | grep -E "Running version|SCRIPT ERROR|Parse Error"
```
Should print `Running version: v<new>-8P-v<modrelease>` — currently
`v2.1.2-8P-v1.5` (mod release v1.5, 2026-08-16).

### Eight local clients

The strongest functional test, and it needs nobody else:

```bash
tools/localtest.sh 8 testgame 45
```

Slot 1 hosts over ENet on 127.0.0.1:25565, slots 2-8 join; windows tile 4x2 and
title themselves P1-P8. The `[SEATS]` trace in `multiplayer_menu.gd` prints the
seat map and connected count, so seats filling is checkable from a log.

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
FLOW=1 tools/localtest.sh 8 testgame 420
```

`FLOW=1` passes `-fullflow`, which suppresses exactly those three skips, so each
instance runs the loop a real player sees: **intro cutscene → briefing →
minigame → score screen → intermission picker → next briefing**. It implies
`START=1`, because something still has to begin the session with nobody at a
keyboard. Allow generous time — 420s gets a handful of minigames where `START=1`
would get a dozen.

The briefing's Ready button is the **only** step in that loop that waits on
player input (session end and the picker advance on timers; the cutscene needs
no press), so `intermission_briefing_screen.gd` readies each instance after
`MOD_AUTOREADY_DELAY` (3s) through `set_ready_rpc` — the same call the button
handler makes, so the ready sound, the indicator and the host's
`check_all_ready()` all behave as for a real press. Confirm with:

```bash
grep -h "\[FLOW\] auto-ready" /tmp/mp-localtest/p*.log | sort -u
```

Expect one line per peer, exactly one with `is_server=true`. Verified
2026-08-01 at 8 players: all 8 readied, briefing and score screens ran at
`rows=8`, and the session reached four distinct minigames with zero errors.

### Mixed-lobby runs (vanilla-compat)

**The quasi-vanilla build** tests a vanilla peer without Steam or a second
machine. `tools/quasivanilla/` holds a 4-file overlay, `build_qv.py` and the
built `qv.pck`; `testgame2/` (gitignored) is the game copy carrying it. The
overlay adds **only** the harness entry points (`-localtest`, `-startgame`,
window titling) — `globals.gd` is deliberately not overlaid, so the build is
**wire-identical to the stock game**: vanilla's own version string (currently
`v2.1.2`), no `mod8p` key, every `@rpc` set exactly as shipped. Rebuild it with
`python3 tools/quasivanilla/build_qv.py` after any game update.

`VANILLA_SLOTS` (space-separated slot numbers) launches those slots from
`VANILLA_DIR` instead of the mod build:

```bash
VANILLA_DIR=testgame2 VANILLA_SLOTS="3 4" \
  START=1 MINIGAME=BurnRecycle tools/localtest.sh 4 testgame 120
```

Three constraints, each of which will otherwise waste a run:

- **`START=1` only.** `FLOW=1` hangs a mixed run at the first briefing — the
  auto-ready lives in the mod's `intermission_briefing_screen.gd`, so quasi peers
  never ready and `check_all_ready()` never passes.
- **Any vanilla peer caps the session at 4**, so use N≤4 (N=5 only to test the
  over-cap refusal).
- **`ARGS="-original"` for anything about the playlist or the cutscene** — see
  "The debug lobby is a *custom* game". A mixed `-original` run is how the
  16-entry cutscene-bearing playlist was confirmed.

**The join-order trap.** Launch order does not control handshake arrival order,
so a run that simply starts 5 instances proves nothing about *which* peer is the
5th — two early "cap failed" results were this race, not a code defect. Cap tests
need controlled ordering: bring up the idle lobby first (the default `START=0`
path), wait for `connected=4` in `/tmp/mp-localtest/p1.log`, then launch the
overflow joiner by hand from the other directory. A refused vanilla joiner logs
`_on_join_refused with reason: 1` client-side; an over-cap *modded* joiner is
demoted to vanilla's debug spectator instead, reading as `connected=5` with
`players=4`.

**Benign in mixed runs only** (measured 2026-08-09; add to the normal noise
list, do not chase):

- `The rpc node checksum failed`, once per mod-scripted node per vanilla peer.
  Godot exchanges an md5 of each node's `@rpc` name set and the mod's added
  names change it, but `scene_cache_interface.cpp` stores and confirms the cache
  entry regardless, so it is **print-only** (pitfall 30).
- Minefield's `curve.cpp` out-of-bounds burst (24× per peer) — reproduces in a
  **pure** quasi-vanilla session with no modded peers, so it is a
  vanilla-under-localtest artifact, not a compat defect.
- A `Node not found: Game/Minigame/<scene>` burst on clients at each round load,
  the same replication-churn family as the documented teardown noise.
- **The wheat-field cutscene never completes unattended**, by construction: its
  fallback Timer is dead code and reaching `Finished` needs a player to walk to
  the house. Unattended mixed runs stall at `PlayerMarker → Play` on every peer.
  Same class as Duck Hunt below — drive a window or pin past it.

### `localtest.sh`'s cleanup is a GLOBAL pkill — never run two sessions

`tools/localtest.sh:22` is

```bash
cleanup() { pkill -f "Machine Party.x86_64" 2>/dev/null; }
trap cleanup EXIT INT TERM
```

That pattern is **not scoped to the PIDs this script started**. It kills every
instance on the machine, so any lingering `localtest.sh` — one whose game
processes you already killed by hand, but whose `sleep` is still running out its
duration — executes that trap on exit and takes down a *newer* session with it.
The symptom is eight instances vanishing mid-play with no error, logs simply
stopping, and the launcher still cheerfully printing `running for 600s...`. It
cost three sessions on 2026-08-04, twice while the user was mid-playtest. Before
starting a session, check that no wrapper is already alive, and kill any that are:

```bash
ps -eo pid,args | grep '/bin/sh tools/localtest.sh' | grep -v grep
```

Two related traps if you launch it as a background task: the wrapper's own
command line **contains the string `localtest.sh`**, so a `pkill -f localtest.sh`
cleanup kills the shell that is about to launch (exit 1 before anything starts);
and a backgrounded command does not inherit the project directory, so it needs
`cd <repo root> &&` or it exits 127.

### The debug lobby is a *custom* game — use `-original` for the real rotation

**Found 2026-08-02, and it invalidates a class of playlist testing.**
`multiplayer_menu.gd` sets `GameManager.custom_game = true` in `_ready()`
(vanilla behaviour), so every `-localtest` session is a **custom** game and
`generate_session_playlist()` takes its `CustomMinigamesWhitelist` branch — a
*different* code path from the one a real Steam "Original" session uses. Until
this was noticed, the non-custom branch every real game plays had never once run
under `-localtest`. `-original` (a mod flag, gated behind `-localtest`) sets
`custom_game = false`:

```bash
ARGS="-original" START=1 tools/localtest.sh 8 <game-dir> 45
grep -h "Generating session playlist with" /tmp/mp-localtest/p1.log
```

**Both branches currently generate the same 15-entry list** (re-measured
2026-08-08, nothing in the rotation capped and `CutsceneTest` removed), so the
difference is **not** visible in the entry count and the
`[ORIGINAL] custom_game=false` line in the host log is the only thing that tells
them apart. **Anything touching `default_playlist`, `supports_player_count()` or
the empty-list fallback must be verified with `-original`**, or the run silently
exercises the whitelist branch and proves nothing.

### `START=1` hardcodes Duck Hunt's round count — use `FLOW=1` to measure it

**Found 2026-08-03.** `intermission_game_picker.gd` has a
`if Globals.debug_skip_intermission:` branch that loads the first minigame with

```gdscript
intermission_manager.game.load_minigame(..., true, 3)
```

— a **literal 3**, bypassing both `total_rounds` resolution sites entirely. Since
`START=1` sets `debug_skip_intermission`, any round-count measured under it is
that constant, not the real value. Under `FLOW=1` the same 8-player session
reports `1`. The pattern to remember: `START=1` does not just *skip* presentation
states, it sometimes **substitutes values** on the way past. If the thing being
measured is decided anywhere near the briefing, the picker or the intermission,
measure it with `FLOW=1`.

### `START=1` HANGS Duck Hunt permanently — `FLOW=1` is the only way to run it

**Found 2026-08-02, called benign, and that was WRONG — corrected 2026-08-05.**
Under `START=1` every Duck Hunt client sat on a full-screen black overlay reading
**"YOU ARE THE HUNTER."** and the minigame never ended, at any roster size. Why,
and it is not the overlay: `role_reveal_state.gd`'s `reveal_online()` is the
**only** online caller of `hunter_player.set_can_aim_rpc.rpc(true)` and
`can_aim` defaults to `false` (the other `set_can_aim_rpc(true)` is inside
`reveal_role()`, which only the local-couch `reveal_local()` calls), while
`round_state.gd` short-circuits `Round → Countdown` whenever
`Globals.debug_skip_brief` is set, skipping `RoleReveal` entirely. So `can_aim`
stayed false forever — mouse aim ignored, controller input returning early — and
`check_game_end()` returns early while `duck_players` is non-empty with **no
turn timer**: no shot, no dead duck, no round end. Measured 2026-08-05 at 8
players: `Empty → Round → Countdown → Play`, then zero further transitions. It
is a **vanilla** debug-path defect (both the short-circuit and the single call
site are stock) that the mod's `-startgame` reaches; real players never set
`debug_skip_brief`.

**Fixed 2026-08-05** by `_mod_apply_skipped_reveal()` in `duck_hunt.gd` (§19),
which re-does what the skipped state would have done — `set_can_aim_rpc.rpc(true)`
plus an RPC clearing the role overlay on every peer — gated on
`Globals.debug_skip_brief` and called from the end of `spawn_players()`, which
`reset_state.gd` re-runs for **every** hunter turn:

| | before the fix | after the fix |
|---|---|---|
| Overlay clears | no | **yes, all 8 peers** |
| A human can aim and fire | **no** | **yes** |
| Unattended run completes a turn | no | **still no** |

**It still cannot complete unattended**, under `START=1` or `FLOW=1`: ducks
leave `duck_players` only by reaching the finish corridor or being shot, and idle
instances neither move nor fire. Duck Hunt is **5th** of the 15-entry rotation
(measured 2026-08-08), so no unattended rotation run reaches the ten after it —
**pinning with `MINIGAME=` is the only full-coverage method**, and "the rotation
only reached N minigames" is this, not pacing.

**The lesson:** when a debug flag skips a state, read what that state actually
did. The state path *was* checked here and read as proof the minigame was running
fine behind a stale overlay; nobody asked whether the skipped state was doing
something load-bearing, and a presentation state that also flips one gameplay
flag is indistinguishable from a cosmetic one in a state trace. It went
unchallenged for three days because every `START=1` run was killed by
`localtest.sh`'s duration before anything needed Duck Hunt to finish — **absence
of a complaint from a run that always dies early is not evidence.**

### Simulating a peer crash during a minigame load

The trigger for pitfall 32 is to kill one client the instant the host starts
loading a minigame, so its `player_loaded` never arrives and ENet notices only
by timeout (~15 s locally), **after the others have loaded**. That is the
crash ordering; a peer that *quits* is a different, earlier ordering with its
own recipe below (pitfall 33) — **a disconnect path is not verified until both
have run.** Arm the killer **before** launching; it waits for the host's load
line:

```bash
tools/kill_slot_at_load.sh 4 DuckHunt &        # arm FIRST, in the background
START=1 MINIGAME=DuckHunt tools/localtest.sh 4 <game-dir> 900
```

`tools/kill_slot_at_load.sh <slot> [MinigameIdentifier]` (added 2026-08-15,
after the recipe was first run by hand) waits for the host's `[ROUNDS8] load
minigame=<Identifier>` line and `kill -9`s that joiner by pid. It carries the
two traps that each cost a run that day: it clears `/tmp/mp-localtest` itself
before waiting (a leftover `p1.log` already containing the load line fires the
trigger before any client exists, and the run silently becomes a no-kill
control), and it finds the pid with `pgrep -f "x86_64 -localtest [4] join"` —
a plain `pkill -f "-localtest 4 join"` also matches the shell running it and
kills the launcher instead of the client.
Kill signature: the slot's log stops at the briefing (`[BRIEF8]`), the host's
`[BRIEF8] players=` drops by one ~15 s later. Healthy signature after that:
`Game: SessionIntro → MinigameStart → MinigamePlaying` then the minigame's
`Empty → Round`; the broken one is `Empty → Reset` with no Game transition
(pitfall 32). Killing a joiner leaves 3 (or 7) live peers, so expect
roster-scaled traces to report the smaller roster. The archived 2026-08-15 session-log
entry has the measured runs.

### Simulating a peer QUITTING during a minigame load

The trigger for pitfall 33 and the §23 guards. A graceful quit (Alt-F4, the
pause menu) is noticed by the host on its next poll, not by timeout, so it
lands while slower peers are still loading — and locally every client loads
in about the same second, so the recipe manufactures a slow peer by freezing
one with `SIGSTOP` and closes another gracefully by sending its X11 window
`WM_DELETE_WINDOW` (Godot's default close request runs the normal quit, whose
ENet teardown sends the disconnect — the same thing Alt-F4 does):

```bash
tools/leave_slot_at_load.sh 4 3 DvdRoomba 5 &   # leave slot 4, freeze slot 3 for 5 s; arm FIRST
START=1 MINIGAME=DvdRoomba tools/localtest.sh 4 <game-dir> 120
```

`tools/leave_slot_at_load.sh <leave_slot> <freeze_slot> [Identifier] [freeze_secs]`
(added 2026-08-15, promoted from the session's scratch script) clears the log
dir itself, waits for the host's load line, `SIGSTOP`s the freeze slot, calls
`tools/graceful_close.py <pid> P<slot>` (python-xlib; matches the window by
`_NET_WM_PID`, falling back to the `P<n>` title) on the leave slot, sleeps,
`SIGCONT`s, and stamps wall-clock times of the host's `players=` drop and
`MinigameStart` so the ordering can be read without in-game timestamps. **Freeze
for 5 s:** longer than every affected minigame's finish timer (1–4 s, so the
pre-fix `Finished` fires before the resume), but a *frozen* peer is dropped by
the host sooner than a killed one — at ~7–8 s in 5 of 15 runs on 2026-08-15
with an 8 s freeze (`[BRIEF8] players=2` before the resume; the run then
starts with two peers via the gate re-run, which still exercises the guard but
is not the scenario). Quit signature:
the watcher prints "host saw players=3" within ~1 s of the load line (a kill
takes ~15 s) and the leaver's log ends with a normal exit (`resources still in
use at exit`), not a truncation. Healthy: `players=3`, then after the resume
`Game: SessionIntro → MinigameStart → MinigamePlaying` and the minigame's
`Empty → Round`. **The pre-fix tell was `<minigame>: Empty → Finished`
arriving before any `Game:` transition, then `Finished → Round`** — the game
starting from its finished state (pitfall 33). Runs on the fixed and unfixed
builds are tabled in the archived 2026-08-15 (issue #13) session-log entry.

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

**What this still is not.** Only the focused window receives keyboard input, so a
human can drive at most one; making all eight *play* needs in-game bots or
external input injection, neither of which exists. And the lobby is still the
developers' debug lobby — the real Steam lobby cannot run over ENet (12 `Steam.`
call sites; see open item 3), so its per-slot visibility with eight real joiners
is unverifiable locally. The *seats themselves* can be looked at alone, with the
preview build below.

### Placing the lobby previews (Steam lobby, one person)

The Steam lobby renders a preview slot only when it is occupied, so its eight
seats cannot be seen locally; and hand-deriving a seat from the text files is
where a transposed basis hides (pitfall 35 — `.tscn` basis text is by rows,
`Basis.x/.y/.z` are columns; two offline models were wrong that way before
anyone noticed). Place seats in the running game instead, and round-trip the
print before trusting it:

```bash
python3 tools/lobby_preview/build_preview.py          # -> testgame/Machine Party.pck (PREVIEW, not the mod)
cd testgame && ./"Machine Party.x86_64"                # Steam running; host a lobby, alone is enough
```

All eight previews are forced visible (`P1`-`P8`) and a help line sits top
right. **F5-F8** select the sitter (`Player5`-`Player8`); **F10** auto-places
it on its host's lap from the host's *live* bones (hips 0.45 u along the
thighs, 0.30 u up, knees turned to match); arrows move X/Z, PgUp/PgDn Y,
Home/End turn about the sitter's own hips, Ins/Del lift the nametag, Shift
for fine steps; **F11** resets the slot; **F9** prints the exact `.tscn`
lines (`Armature_001` and `player nametag` per slot) to the log — between
`[PV-EXPORT]` … `[/PV-EXPORT]` — and to the clipboard. Paste them over the
matching lines in `mod/scenes/lobby/lobby_scene.tscn` verbatim (tidy `1.0`
→ `1`, `0.89499998` → the scene's `0.895`), rebuild the preview, load it,
and **press F9 before touching anything: an untouched slot must print its
baked line byte for byte** (that round trip is what caught the transposed
printer). Then rebuild and **restore `testgame/` from `dist/`** — the preview
pck must never be mistaken for the mod build. The tool patches `mod/`'s `lobby_scene.gd` at build time on two
asserted anchors, so a future rebuild that moves them fails loudly rather
than silently producing a preview without the mode.

### Installer round-trip

On a **copy**, with literal absolute paths:
```bash
python3 installer/install.py --game-dir "<absolute path to>/machine-party-8p/testgame_new" --verify
```
Expect `NOT PATCHED` → install → `PATCHED` → a second install attempt
**refused** (already-patched guard) → restore the pck from a pristine copy and
confirm the step-1 MD5. **The installer keeps no backup since 2026-08-14**
(issue #9 — a stale backup silently downgraded the game after an update), so
`--uninstall` restores nothing: it reports the state and points at Steam's
Verify integrity, and the test restores by re-copying the pristine pck you
staged. Run at every release (the release entries in the session log and its
archive table the results); the printed file counts track the overlay size —
each added `.gd` displaces its `.remap` and `.gdc` siblings — so re-derive them
from the run rather than treating them as constants.

`install.py --force` answers every prompt yes for non-interactive runs;
without it a scripted run dies on `EOFError` before touching anything.

---

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
MP_DEPLOY=testgame python3 tools/build.py

# 8 clients, straight into one minigame, 7 minutes to inspect
START=1 MINIGAME=GreenPea tools/localtest.sh 8 \
  testgame 420

# full normal session loop at 8 - briefing/intermission NOT skipped
FLOW=1 tools/localtest.sh 8 \
  testgame 420

# same at 4, to confirm vanilla behaviour is untouched
START=1 MINIGAME=GreenPea tools/localtest.sh 4 \
  testgame 200

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
  testgame 45
grep -h "\[ORIGINAL\]" /tmp/mp-localtest/p1.log        # confirms the branch
grep -h "Generating session playlist with" /tmp/mp-localtest/p1.log

# 4-vs-8 error CLASSES (pitfall 12) - run at 4, save, run at 8, compare.
# ERR_UNAUTHORIZED is ordinary despawn churn, ~12 lines per peer at 4 AND at 8
# (measured 2026-08-05 on 4.5.1 and 4.5.2) - not player-count related, no
# filter entry needed
grep -hE "^ERROR|^SCRIPT ERROR" /tmp/mp-localtest/p*.log \
  | grep -viE "NO GRAB|Invalid packet|Node not found|Failed to get cached node|Failed to get path" \
  | sed -E "s/#[0-9]+/#N/g; s/'[A-Za-z_]+[0-9]*:/'X:/g; s/[0-9]+/N/g" | sort -u > /tmp/err8.txt
comm -13 /tmp/err4.txt /tmp/err8.txt   # anything here is player-count related

# errors, minus the usual replication churn ("Failed to get cached node" is the
# companion line of a "Node not found" at a round transition - present in
# no-disconnect controls, 2026-08-15)
grep -hE "^ERROR|^SCRIPT ERROR" /tmp/mp-localtest/p*.log \
  | grep -viE "NO GRAB|Invalid packet|Node not found|Failed to get cached node|Failed to get path" \
  | sort | uniq -c | sort -rn
```

The localtest session ends because `localtest.sh` kills every instance when its
duration expires - that is not a crash. Pass a larger number to stay in-game.
