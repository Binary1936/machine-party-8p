# Machine Party — 8 Player Mod

*Human Written Section* 

This mod was made almost entirely by Claude Code with heavy human supervision. There may be some issues or quirks that I have not caught.
The documentation has also been entirely written by Claude. I made this project with the intention of keeping it very vibe coding friendly. There are 
prompts in the Updating.md and a defined workflow you can use to continue work and modification with your own LLM agents. This mod isn't perfect,
but it's something I made to experiment with vibe coding, and so my friend group can play 8 player machine party. All credit goes to the original 
developers of the game. I plan to continue development on the mod and to continue working on the rough edges when I have some free time, but I'm considering
this V1.0 good enough to ship for now. Every minigame should be fully playable with 8 players. Please feel free to fork this project for yourself 
or submit Pull requests with changes. I'm still figuring GitHub out, so if I made any dumb mistakes, please feel free to let me know and I'll do my best to fix them. 

*End Human Section* 


Raises the online (Steam/ENet) player cap from 4 to 8 for **Machine Party
v2.1.2** (Godot 4.5.2). All fifteen minigames in the rotation seat eight
players, and the lobby, briefing screen and score screen grow to match. The mod
is an overlay of 56 files (40 `.gd`, 16 `.tscn`) applied to the shipped
`Machine Party.pck`: one file is new, the rest replace shipped ones.

This is mod release **v1.4**; in game it identifies itself as
**`v2.1.2-8P-v1.4`** — game version, mod suffix, mod release.

## Status

All fifteen rotation minigames are uncapped, verified at 8 players on host and
clients, and have each been watched at 8 by a person. Nothing reachable in
either playlist is capped at 4 any more.

**"Verified at 8" means** eight players spawn in the right places on every
client, full rounds run to completion, and per-peer diagnostic traces come back
with positive counts rather than merely an absence of errors. **It does not mean
the game has been played at 8.** The local test harness runs eight unattended
instances, so nobody presses a button — scoring, elimination order and win
conditions at 8 rest on idle-instance behaviour in every minigame. That is the
mod's largest gap; see [Known limitations](#known-limitations).

Lobbies of 1-4 play as vanilla, with two deliberate exceptions — see
[Behaviour at 1-4 players](#behaviour-at-1-4-players).

> **Since v1.1 you can play with unmodded friends**: a lobby may
> mix modded and vanilla v2.1.2 players, and the mod detects this automatically.
> A mixed lobby caps at **4** players — a vanilla client cannot handle more —
> and plays the exact vanilla rotation; a 5th join attempt is refused with the
> game's version-mismatch message rather than breaking mid-session. **Lobbies of
> 5-8 still need every player on this same mod release**, and two different mod
> releases always refuse each other (v1.0 and v1.1 are network-incompatible, so
> modded groups should update together).

## Install

The mod zip (~21 MB) is published on the project's Releases page. Extract it
and double-click `install.bat` (Windows) or `install.sh` (macOS/Linux), or run
`python3 install.py`. It auto-detects the Steam copy and patches
`Machine Party.pck` in place; the executable and the native libraries beside
it are untouched. **No backup is kept** — Steam's *Verify integrity of game
files* re-downloads the original at any time, so the installer refuses to run
on an already-patched copy rather than build the mod on top of itself (verify
the game files first, then reinstall). Older installer versions kept a
`Machine Party.pck.vanilla` backup; the current one offers to delete it, and
never restores from it — after a game update that copy holds the wrong game
version (issue #9).

A clone or source download of the repository installs the same way, with no
build step: run `python3 installer/install.py` (or the wrappers in
`installer/`). The installer contains no copy of the mod — it reads the
repo's `mod/` directly.

It requires Python 3, preinstalled on most macOS/Linux systems but not on
Windows.

The installer is preferred over handing out the built `.pck` for three reasons:
it is ~21 MB instead of ~652 MB, it distributes only the mod's changes rather
than a full copy of the game's assets, and it patches each person's own platform
build — so a Windows player is never running a `.pck` exported for Linux.

### Uninstall

Steam: *Properties → Installed Files → Verify integrity of game files*. That
restores the original download and is the uninstall — the installer keeps no
backup to restore from. (`python3 install.py --uninstall` reports whether the
mod is installed and points at those steps; it changes nothing.) A game update
silently reverts the mod the same way, so re-run the installer after one.

### Verify

`Globals.game_version` becomes `v2.1.2-8P-v1.4`, and that string is already wired to
the main menu's version label, so the corner of the menu is the fastest check.

Without launching:

```bash
python3 installer/install.py --game-dir "<game folder>" --verify
```

Reports `PATCHED` / `NOT PATCHED` / `PARTIALLY PATCHED` (exit 0 / 1 / 1) by
checking that every mod file is present *and* that the compiled originals it
supersedes are gone — a half-applied patch where a leftover `.gdc` shadows a mod
`.gd` is otherwise silent.

### How the mod is packaged

The mod ships plain `.gd` and `.tscn` source rather than recompiled `.gdc` /
`.scn`. Godot's release template still contains the GDScript parser and the text
scene loader, so dropping a compiled file along with its `.gd.remap` makes the
loader fall through to the text version. That is what lets the mod build with no
Godot export templates and no editor round-trip, and it keeps every change
reviewable as a normal diff. The build is byte-reproducible;
`python3 tools/build.py` rebuilds `dist/Machine Party.pck`.

## What changed

> This section summarises. **[UPDATING.md](UPDATING.md) and
> [MINIGAMES.md](MINIGAMES.md) are authoritative** — if they disagree with this
> file, they are right and this is stale. Counts and per-minigame status in
> particular are restated here for convenience and have drifted before.

| Area | Change |
|---|---|
| `modules/multiplayer/network_manager.gd` | `MAX_PLAYERS` 4 → 8. This alone drives the Steam lobby size, since `steam_backend.gd` passes `NetworkManager.max_player_count` straight into `Steam.createLobby`. Also `mod_all_peers_modded()`, which the playlist and capacity logic consult. |
| `modules/multiplayer/backends/steam_backend.gd` + `enet_backend.gd` | **Vanilla-compat (v1.1).** The wire reports vanilla's exact version string plus a `mod8p` tag vanilla ignores; unmodded peers are accepted, differing mod releases are refused, and the effective lobby cap drops to 4 whenever a vanilla peer is present (a vanilla joiner that would exceed it is refused outright). No `@rpc` is added — the handshake stays wire-identical to vanilla. |
| `scenes/local_game/script/local_game.gd` | Couch mode's own playlist generator gets the unconditional wheat-field-cutscene filter (a local session has no vanilla peers by definition). |
| `autoloads/globals.gd` | Three added suit colours (orange, cyan, pink); per-minigame player caps and `supports_player_count()`; `game_version` tagged `-8P` for display while the wire reports vanilla's version string (vanilla-compat); `default_playlist` byte-identical to vanilla — the wheat-field cutscene is filtered at playlist generation instead, only when every peer runs the mod. |
| `scripts/scenes/game/game.gd` | Playlist generation skips minigames that cannot seat the current lobby, with a fallback if that empties the list. Applied to **Arcade mode** too (new in v1.5.0), which vanilla builds without consulting the caps. |
| `scenes/lobby/lobby_scene.tscn` + `lobby_scene.gd` | Seat map derived from `MAX_PLAYERS` instead of four hardcoded entries, and four more character preview slots (`Player5`-`Player8`) appended to the handler's exported arrays. Without the first, players 5-8 join and are never assigned a seat; without the second, `customization_assigners[seat]` was an out-of-bounds crash rather than a layout problem. The room has four chairs, so players 5-8 sit on the laps of players 1-4 — hand-placed seats, positioned in the running game; the script moves nothing. |
| `modules/multiplayer_lobby/mod_player_name_list.gd` | **The mod's one new file.** A plain text roster of Steam names in the lobby corner. At eight players the seated characters are packed close enough that the floating nametags stop being readable. |
| `scripts/components/.../customization_assigner.gd` | Renders the three added suits. Only five suit textures exist, so the added colours reuse a shipped texture with an `albedo_color` tint and keep the original shading; swapping in real textures later just means adding the files and dropping the tint entry. |
| `minigames/intermission_new/.../intermission_score_screen.gd` | 8 rows. The board filled from a score-*sorted* list bounded by array size, so the four lowest-placed players were silently dropped — no crash. Also clamps a negative reverb pitch that only occurs once score totals are large enough. |
| `minigames/intermission_new/.../intermission_briefing_screen.gd` | 8 player cards. One array was *assigned* by index — an out-of-bounds write, not a truncation. |
| 15 minigame `.tscn` files | Spawn markers expanded 4 → 8. |
| `bootstrap.gd`, `multiplayer_menu.gd`, `multiplayer_backend.gd` | The `-localtest` harness only: opens the developers' debug lobby in a release build, tiles and titles eight windows, staggers the joins. No effect on a normal session. |

**Spawn markers.** Every minigame shipped exactly four, and the spawn code does
`spawn_positions[counter]`, so player five was an out-of-bounds crash. Each added
marker clones an existing one, displaced sideways and inheriting its full
rotation, so it lands beside a known-good spawn facing the same way. The shipped
four are never moved and keep their names and order, so existing `NodePath`
references stay valid.

**Layout changes are applied at runtime, never baked into a scene, and gated on
the roster exceeding four.** Extra chairs, stations, desks and lanes are cloned
by RPC when the eighth player is there and not otherwise. Editing the `.tscn`
instead was the earlier approach and it broke 4-player games; runtime cloning is
what keeps a 1-4 lobby on the vanilla layout.

### Minigames

Always pair the display name with the identifier — they overlap almost nowhere,
and `MinigameReadableNames` in `globals.gd` is the only authoritative map.

| Display name | Identifier | What the mod changed | Notes |
|---|---|---|---|
| MINEFIELD | `ExplodingCollarRace` | 8 spawn markers. `blood_trail.gd` guards an empty `Curve3D` — a latent vanilla bug that fired ~380 errors per round at 8. | — |
| CHISEL GAUNTLET | `ChiselGauntlet` | 8 stations cloned at runtime; `player_rotations` 4 → 8 **distinct** facings 45° apart; `shotgun_check_order` 4 → 8 slots ordered clockwise by angle, not index; split-screen layouts for 5-8; 8 spectate positions. | Both indexed arrays black-screened the game at 8 before the fix. |
| WRONG WAY | `EscalatorPit` | Each of the 4 troughs split into **two** stair strips — 8 lanes, one player each — plus 8 CRT screens and 8 input arrows. Handrails and divider posts hidden above 4. | Cannot be eight *full-width* lanes: the housings and pit floor are one baked mesh, so wider lanes would hang off the level. |
| STABLE FOOTING | `DiscoDodge` | `MultiplayerSpawner.spawn_limit` 4 → 8, kept as defence-in-depth. | Re-measurement showed the cap had no effect either way in this build; the raise is retained because matching it to the player count is correct regardless. All eight spawn and replicate to every client. |
| TABLE MANNERS | `GreenPea` | Runtime 8-seat layout — chairs repositioned and narrowed, camera pulled back and widened — applied by RPC only above 4. The scene ships 4 extra chairs `visible = false`. | — |
| SMOKE BREAK | `SmokeBreak` | 8 seats with two added crates; gun aim angles derived for all 8; four separate seat-capped arrays fixed, including a `match seat:` whose unmatched case left `anim_player.play("")` so eliminated players never fell. | Player-model clipping on the left four seats. Cause is seat *facing*, not spacing; blocked by pinned seats and the camera frame. Cosmetic, accepted. |
| DEBRIS PLATFORMS | `JunkPlatform` | 8 spawn markers. | Two players share each platform (4 decks, 8 players) — the clones sit beside an original on the same deck. Playable because scoring is last-man-standing, so nothing assumes one player per deck; you just start paired up. |
| TUNNEL HAZARD | `TrainRace` | 8 spawn markers, nothing else — the level already ships 8 nooks and `nooks_to_open` is computed, not a constant. | Nook contention at 8 is unexercised: idle instances are run over by the first train. |
| INSIDE JOB | `KnifeAtTheOffice` | Search target clamped to the 36 containers that exist — above it the syringe was unfindable and the round never ended. Hunt HUD grown from 4 to 8 icons. | Search economy in real play is untested; unattended instances never search a container. |
| SPINE BREAKER | `SpineBreaker` | 8 spawn markers, plus kill pace scaled to the roster (fuse and dead time × `3/(roster−1)`, clamped to 1.0). The mod's only gameplay *tuning* change: without it an 8-player round runs ~2.5x as long as a 4-player one, ~190s instead of ~93s. Unchanged at 1-4. | At 7-8 players the window to throw the spider onto someone else drops to ~9s from ~20s. Deliberate trade; `MOD_VANILLA_KILLS` is the knob. |
| LETHAL REBOUND | `DvdRoomba` | 8 spawn markers, nothing else. | Hazard count does not scale, by design — eight players share the same roombas in the same arena, which lengthens the round rather than breaking it. |
| DUCK HUNT | `DuckHunt` | **Uncapped 2026-08-02.** 7 duck spawn markers built at runtime above 4 players; magazine and reload curves extended from 3 ducks to 7 with the rifle animations speed-scaled to fit; splitscreen layouts extended past 4; round pacing set so 8 players run 8 hunter turns, not 16. Two pre-existing vanilla bugs fixed on the way. | Cannot complete unattended — an idle duck never walks home and an idle hunter never shoots — so it stalls automated rotation runs. A test-harness limitation, not something a player sees. |
| FORKLIFT CERTIFIED | `ForkliftCertified` | **Uncapped 2026-08-04.** `spawn_players()` indexed the spawn markers and the `DropArea` list with one counter, so at 8 it overran both and the minigame loaded to a black screen with the ambience still looping. Four more delivery zones are cloned at runtime at the yard's mid-edges (the shipped four cover only 24% of it), with matching host-only markers. Fixing that exposed two more: the crate sampler looped forever above five players, and the four-decal blood pool ran dry on the 5th elimination and hung the round. | — |
| THE FILTER | `BurnRecycle` | **Uncapped 2026-08-07 as two rooms, not eight stations in one ring.** Players were told apart by rotation alone (`90 * counter`, which wraps at eight) and belts, presses and indicators were exported arrays of exactly four. Cloning stations 45° round the same ring measured perfectly and looked wrong: the shipped art already fills the ring at four, and the four authored camera clips assume four directions. A second room offset in space keeps every station at the vanilla 90° spacing, so nothing clips and the camera work stays exact. Rooms are balanced (5 → 3+2, 7 → 4+3) so nobody is alone, elimination runs per room at vanilla pace, and scoring stays global with same-round ties resolved upward. | — |
| FIREARM FACTORY | `ManufactureGun` | **Uncapped 2026-08-07.** Four blockers: two 4-marker containers whose null read past index 3 aborted the host's spawn loop, a `queue_free()` on a 4-element array that would have crashed the process, and `spawn_limit = 4`. Eight spawns and eight desks are built at runtime at the arena's mid-edges (there was room — 15.1u between workstations), and ingredients now scale with the roster; they were a fixed 26 at any player count, halving everyone's share at 8. **Polished 2026-08-08:** the two desks against the end walls turned along the wall and pushed flush to it, the doubled ingredients spread far enough apart not to intersect, and the recipe hologram raised clear of the desk that covered it. | — |

### Not in any playlist

`ShapeCutter`, `ScavangerChairs`, `MemorizePath` and `CutsceneGame02` map to
`LOC_EMPTY` and are in neither the default rotation nor the custom whitelist, so
they are unreachable outside `-debug-tools`. Their scenes carry expanded spawn
markers defensively in case a future update enables them. `ScavangerChairs` is
also the only entry left in `modded_minigame_player_cap`, belt-and-braces: its
round logic is `4 - players.size()`, which goes negative at 5+. **These four have
never been run under the mod at any roster size.** The mod adds no code for them,
so "unchanged at 1-4" is a sound inference — but it is an inference, not a test
result.

## Behaviour at 1-4 players

**A lobby of 1-4 is pixel-identical to vanilla.** That is a design constraint of
the mod, not an accident: every layout change is applied at runtime and only
above four players, the shipped spawn markers are never moved, and the lobby
restores the shipped preview positions whenever it holds four or fewer.

There are exactly two sanctioned breaches, both signed off deliberately:

- **The wheat-field cutscene (`CutsceneTest`) is gone from the rotation when
  every player runs the mod.** It scored nothing and broke the session's pace,
  so it was removed at the maintainer's request in full knowledge that it breaks
  the rule. Since v1.1 the removal is dynamic: a lobby containing an unmodded
  player gets the exact vanilla rotation, cutscene included (vanilla-compat).
  The scene and its supporting code are intact, so `-debug-tools` can still
  launch it.
- **Spawn-marker *selection* at 1-4.** Nine expanded scenes (six in the rotation,
  three debug-only) shuffle the marker list before indexing it, so a 1-4 game
  draws from all eight markers and can seat someone 1.2u sideways of a vanilla
  spawn — same rotation, same floor, in frame, and spawn order is randomised in
  vanilla anyway. Accepted on 2026-08-04 as too minor to justify touching nine
  minigames.

## Known limitations

Ranked by how much they would actually bite.

- **Vanilla-compat mixed lobbies** are verified extensively with local test
  clients — both host directions, the 4-cap, the refusal path, the restored
  cutscene — and both join directions have been confirmed in a real Steam
  session with unmodded players. The over-cap refusal and the cutscene have
  not yet been seen over real Steam specifically. Unmodded players' logs show
  harmless `rpc node checksum failed` lines in mixed sessions (engine noise,
  verified print-only). Reports welcome.
- **Nobody has played an 8-human session.** The harness runs eight unattended
  instances, so scoring, elimination order and win conditions at 8 are unproven
  everywhere — the weakest claim in this file. It also skews coverage: a minigame
  where idling is fatal tests its death path well and its skill path not at all,
  which is why Tunnel Hazard's nook contention and Inside Job's search economy
  have never run.
- **Expanded spawn pairs start overlapping.** Added markers are placed 1.2u from
  their original, but a character footprint is ~1.6u, so in every expanded scene
  each pair begins interpenetrating and shoves apart on frame 1. Visible as a
  brief shove at spawn. Open — raising the offset moves players in fourteen
  already-verified scenes, so it wants a decision rather than a drive-by change.
- **Arcade mode has never been run.** The mod filters its playlist by the player
  caps like the other branches, but that is verified by reading the code and
  confirming it loads — no local harness can reach the branch, since `-localtest`
  always enters through the debug lobby. Treat it as unproven.
- **The Steam lobby with 8 real peers has never been seen.** A 5-player lobby
  was (it found the seating bug fixed on 2026-08-16), and all eight seats have
  been looked at in a preview build with every slot forced visible — but the
  per-slot visibility path with eight actual joiners has not. `lobby_scene.gd`'s
  join path is built on Steam lobby callbacks, so the real lobby cannot run over
  ENet; it needs a real 8-player Steam session.
- **Smoke Break player-model clipping** on the left four seats. Cosmetic,
  accepted.
- **Spawn-marker selection at 1-4** deviates from vanilla; see above.
- `Parameter "data.tree" is null` — 1-3 benign lines at the instant a round ends,
  a vanilla coroutine resuming after its node left the tree. The only 8-only error
  class left, deliberately not chased.

One pre-existing vanilla bug is worth not mistaking for mod breakage:
`minigame_end_state.gd:28` calls `update_playlist_state_rpc.rpc(...)` with one
argument against a three-parameter function, so every minigame end logs
`Method expected 3 argument(s), but called with 1`. It is identical at 4 and 8
players and that file is not in the overlay.

## Maintaining the mod

[UPDATING.md](UPDATING.md) is the handoff document: current verified state, the
toolchain, the eight-client local test harness, the update procedure for when the
game ships a new version, and the failure modes already found. It assumes no
prior context and can be handed to a fresh session as-is.
[MINIGAMES.md](MINIGAMES.md) carries the per-minigame detail.
