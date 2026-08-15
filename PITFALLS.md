# Machine Party 8-Player Mod — pitfalls

The numbered failure modes, every one of which cost real time the first go.
Split out of `UPDATING.md` on 2026-08-14, when that file outgrew one read —
the same reason `MINIGAMES.md` split out on 2026-08-04. **Read this file
before changing code or running the tools**; each entry carries the rule
that avoids it.

**The numbering is load-bearing and stable — never renumber, never reuse a
freed number.** Code comments and every doc cite these as *pitfall N*; new
pitfalls append at the end. The other conventions, unchanged: **rule N** is
the five hard rules in `UPDATING.md` ("Paste this to start"), ***§N*** is
`MINIGAMES.md`, ***Testing*** is `UPDATING.md`'s "Testing — the validation
recipe", and a dated *session-log entry* lives in `SESSION-LOG.md` (or
`SESSION-LOG-ARCHIVE.md` once superseded).

1. **`res://` prefix.** The *shipped* pck stores paths **without** it; `tools/pck.py`
   writes them **with** it. Normalise before comparing, or lookups silently miss
   and the compiled `.gdc` keeps shadowing your `.gd`. `installer/install.py`
   has a `norm()` helper for exactly this.
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
7. **Everyone in a lobby needs the identical mod — or none of it.** Mod releases
   must match: the wire carries `MOD_SUFFIX` under the `mod8p` key, so two
   players on the same game version but different mod releases are refused
   cleanly instead of desyncing mid-session (before v1.1 the same job was done by
   the `-8P` label inside the version string itself, which is why old v1.0 builds
   are still recognised and refused). **The one sanctioned mismatch is a peer
   with no mod at all**: since v1.1 an unmodded v1.5.0 client can share a lobby,
   which caps it at 4 — see "Current status" and the 2026-08-09 session-log
   entry.
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
    `s c d o x X f v %`. Run `tools/checks/preflight_format_specifiers.py`
    before every build ("Working environment" in `UPDATING.md`), and pin the minigame with `MINIGAME=` in a localtest
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
    See "Spawn markers are visible to 1-4 player games too" in `UPDATING.md`; this is a live deviation from the vanilla rule, not
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
    ERROR: RPC 'zz_mod_set_room_rpc' is not allowed on node .../BurnRecyclePlayerN
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
30. **Adding an `@rpc` RENUMBERS the vanilla ones. Name every mod RPC `zz_`.**
    Godot assigns RPC wire ids from the **sorted** set of `@rpc` method names in
    a node's whole script chain (`scene_rpc_interface.cpp`), and separately
    exchanges an **md5 of that name set** per node. The two failure modes are not
    equally loud:
    - **The id mismatch misroutes silently.** A mod RPC named `mod_*` sorts
      before most vanilla names, shifting every vanilla id after it by one — so a
      modded peer and an unmodded one disagree about what each id means, at any
      roster size, with no error. This is why the 8 mod RPCs are prefixed `zz_`:
      nothing in vanilla begins with "zz", so they sort **after** every vanilla
      name in their chains and vanilla's ids stay identical to an unmodded build.
      **Any new mod `@rpc` must keep that property**, and it is the whole basis of
      vanilla-compat.
    - **The checksum mismatch is print-only.** Any added `@rpc` changes the
      node's name-set md5, so a vanilla peer in a mixed session prints
      `The rpc node checksum failed` once per mod-scripted node.
      `scene_cache_interface.cpp` stores and confirms the cache entry regardless;
      verified in engine source and clean in every mixed run. **Expect it, do not
      chase it** — see the 2026-08-09 session-log entry and Testing.
31. **A transformless marker is IDENTITY, not absent — and `_MOD` numbering
    starting below 5 means the expander mis-parsed the scene.** Godot omits a
    node's `transform` line when it is identity. Before 2026-08-13,
    `spawn_expand.py`'s `parse()` scanned past the next `[node]` header looking
    for one, so an identity marker either vanished from the marker list or
    **stole the next node's transform**. In `chisel_gauntlet.tscn` that
    attributed a Label3D's transform (3.62 scale, 2.36u low) to `Marker3D4`,
    and the resulting single-source expansion put players 5-8's spectate
    cameras at the label's position — shipped that way in v1.0 and v1.1
    (issue #7). Both halves are fixed (`parse()` stops at `[`; identity is
    recorded as identity), but the detection rule outlives the fix: the
    expander names clones `_MOD<n+1>` onward from n originals, so **any `_MOD`
    node numbered below 5 means it saw fewer than four originals**. Sweep after
    any regeneration:

    ```bash
    grep -roE '_MOD[0-9]+' --include="*.tscn" mod/ | sort -u
    ```

    Known false positives: `green_pea` / `smoke_break` seat meshes named
    `*_MOD3/4` — hand-authored `MeshInstance3D`s on a per-side numbering
    scheme, not expander output (§10, §14).
32. **A peer that drops DURING a minigame load leaves vanilla's load gate
    stuck, and Duck Hunt then starts itself through the wrong door.**
    `Minigame.player_loaded()` fires `all_players_loaded()` → `initialize()`
    only when `players_loaded.size() == player_presences.size()`, and only
    when a `player_loaded` arrives; a disconnect shrinks the right-hand number
    without re-asking. Duck Hunt's `player_disconnected()` → `check_game_end()`
    then finds nothing spawned and transitions to `Reset`, whose state re-runs
    `spawn_players()`. The round plays, but `initialize()` never ran: the
    `MINIGAME_SFX` bus stays at the 0.0 the previous minigame set (no rifle,
    no duck sounds — issue #12) and the Game state machine never enters
    `MinigamePlaying`, whose `enter()` is the only listener for
    `minigame_finished`, so `Finished` never becomes `MinigameEnd` and every
    peer black-screens (issue #10). Vanilla at every roster size; fixed in the
    mod on 2026-08-15 (§19). **The tell, in any log:** the minigame's own
    `Empty → …` line arriving with no `Game: … to MinigameStart` /
    `MinigamePlaying` before it, and `Empty → Reset` as the first Duck Hunt
    transition. Under `-localtest` the `[DUCK8] spawned` audit (fixed 6 s after
    `_ready`) prints `ducks=0 hunters=0` with its mismatch warning — a late
    start, not a spawn failure. Read the **Game-level** state machine before
    trusting a minigame-level trace: every Duck Hunt trace was green in a
    session that had never left `MinigamePick`. Reproduce with the kill-at-load
    recipe in Testing.
33. **A crash and a quit are two different disconnects, and a fix verified
    against one is unverified against the other.** A killed or crashed peer is
    noticed by the host only when ENet times it out (~15 s locally: default
    `timeoutLimit` 32 → the sixth retry) — *after* every live peer has finished
    loading. That is the ordering the kill-at-load recipe produces and the one
    the v1.3 load-gate re-run in `game.gd` repairs. A peer that **quits** —
    Alt-F4 (Godot's default `WM_CLOSE_REQUEST` quit; the game installs no
    override) or the pause menu (`NetworkManager.cancel()` RPCs
    `disconnect_player` → `disconnect_peer` on the host, `enet_backend.gd`) —
    is noticed on the host's next poll, because `~ENetMultiplayerPeer()` →
    `close()` → `peer_disconnect_now(0)` + `flush()` (Godot 4.5.2
    `modules/enet/enet_multiplayer_peer.cpp:290-311, 487-491`; no SIGTERM or
    SIGINT handler in `os_linuxbsd.cpp`/`main.cpp`, so `kill -TERM` is a
    crash, not a quit). During a load that lands the disconnect **before** the
    slower peers report in, and every minigame's `player_disconnected()` then
    runs against an unspawned game: eleven of fifteen went `Empty → Finished`
    at zero players, and when the slow peer loaded afterwards six of them
    started from `Finished` with `finished`/`game_end` already latched, so the
    round could never end. Guarded in every handler on 2026-08-15 (§23). Two
    lessons: **a disconnect path needs both recipes** (the 14-minigame
    kill-at-load series was healthy end to end while the quit path was broken
    in eleven of them — Testing, "Simulating a peer quitting during a minigame
    load"); and **the tell is the same as pitfall 32's** — the minigame's own
    `Empty → …` line arriving before any `Game: … to MinigameStart`, here
    reading `Empty → Finished`.
34. **The shipped binary is a release build: GDScript's invalid-key and
    null-call errors do not exist in it.** In `gdscript_vm.cpp` (4.5.2) the
    `OPCODE_GET_KEYED*` "Invalid access to property or key" branches and the
    `OPCODE_CALL*` "Attempt to call function … on a null instance" report are
    all inside `#ifdef DEBUG_ENABLED`; in release, `dict[missing]` yields
    `null` and `null.method()` is a silent no-op, and execution **continues**.
    So code that reads as "this would error and abort" runs on with nulls, and
    the log stays clean: `manufacture_gun.gd`'s `active_players[_network_id]`
    and `smoke_break.gd`'s `player_characters[_network_id]`, indexed for a peer
    that had dropped during the load and never spawned there, produced no
    `SCRIPT ERROR` in the kill-at-load runs that exercised exactly those lines
    (2026-08-15) — the read gave null and the handler ran on. Two consequences: an absence of `SCRIPT ERROR` proves
    less than it seems for guard-shaped bugs, and a missing `has()`/`get()`
    guard is a logic bug, not a crash. Parse errors and the core `ERR_FAIL_*`
    macros (`Parameter "node" is null`, `Invalid packet received`) do print
    in release — those are C++-side, not the VM's.

---
