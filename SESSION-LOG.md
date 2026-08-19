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

### 2026-08-18 (latest) — Documentation audit: single source of truth, closed items and history cut, session log archived through v1.5

No code change. A concision pass over the whole doc set under documentation
policy rules 1–3 (one home per fact; tighten wording, never substance; archive,
don't delete). Word counts: `UPDATING.md` 18,498 → 13,017 (−30 %),
`PITFALLS.md` 4,267 → 4,428 (+2 entries), `MINIGAMES.md` 16,463 → 15,416,
`SESSION-LOG.md` 5,609 → 2,050 (this entry included); live doc set 45,900 → 35,300 words.

- **`UPDATING.md`**: "Current status" is one paragraph plus a per-minigame
  table that also carries the identifier map; "Open items" keeps only what is
  open (0, 1, 3, 5, 6, 8 — numbering stable, closed items dropped, their
  substance at §16/§19/§22/§23, pitfalls 32–33 and the sanctioned exceptions);
  "Spawn markers are visible to 1-4 player games too" merged into "The second
  sanctioned exception" (its two fix options → "Possible future work" under
  Open items); the `@export`-survives-`duplicate()` and hardcoded-relative-path
  sections moved to **pitfalls 37 and 38**; the Duck Hunt `START=1` saga is one
  Testing subsection; the doc-file list, "Session log" and "Pitfalls" stub
  sections, the historical pck MD5 rows and the debug-lobby snapshot table are
  gone; machine-local entries (`docs_old_2026-08-08/`, `userdata_backup/`, the
  memory-file asides) moved to `NOTES-LOCAL.md`; installer round-trip got its
  own Testing heading. Every other heading kept its exact text.
- **`MINIGAMES.md`**: stale claims fixed — §2 no longer quotes a literal
  version, §10 no longer says Firearm Factory is capped, §19 no longer lists or
  describes `duck_hunt_local_handler.gd` (left the overlay 2026-08-14); §15
  gained the Debris Platforms deck notes from "Current status"; history
  narratives in §9/§10/§16/§20/§22 and the "deliberately NOT scaled" record
  compressed; session-log pointers repointed at the archive.
- **`PITFALLS.md`**: 37 and 38 appended; 3, 11, 22, 23, 25, 33, 35 tightened;
  pitfall 24 now points at "The second sanctioned exception".
- **`SESSION-LOG.md`**: the five entries from the v1.4 release through the v1.5
  release moved verbatim to the archive (diff of the moved span: empty); the
  three stub tables merged into one "Archived entries" table.
- **`README.md`**: the 1-4 paragraph no longer says the lobby "restores" preview
  positions (the runtime spread was removed 2026-08-16).

| Check | Result |
|---|---|
| `tools/checks/*.py` | all five pass (`56 files: 40 .gd, 16 .tscn` claim intact) |
| Cross-reference sweep (fresh-context agent): every quoted section name, `pitfall N` (≤ 38), `§N` (≤ 23) and open-item number cited from the six docs, both `CLAUDE.md`s, `tools/` and `mod/**/*.gd` | resolves; 18 spot-checked facts from the old text all found at their new homes |
| Three stale pointers in code comments, fixed in a follow-up commit the same day (comment-only; rebuilt and deployed, checks pass, no behaviour change) | `mod/autoloads/globals.gd:349` → §19, `mod/minigames/knife_at_the_office/components/countdown_handler/countdown_handler.gd:34` → pitfall 23, `mod/minigames/spine_breaker/scripts/spine_breaker.gd:47` → §18 "No RPC, and none is wanted" |

### 2026-08-18 — Windows installer bundles its own Python runtime; installer no longer dies invisibly with no terminal attached; Steam auto-detection widened

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

Steam auto-detection also widened, same session. `windows_steam_dirs()` now
also checks `%ProgramFiles(x86)%`/`%ProgramFiles%` (Program Files is not
always on C:), and — only when the ordinary paths find nothing, and only on
Windows — reads three read-only registry values (Steam's `SteamPath`/
`InstallPath` under `HKCU` and two `HKLM` keys; nothing enumerated or
written) to catch a Steam client installed somewhere else entirely: reading
the registry to answer a question the plain paths already answer is more
than a normal install needs to do, so it stays a last resort. Linux gained
`~/.steam/root`, the client's own-install symlink. `steam_roots()` now
de-duplicates by `realpath` and drops paths that don't exist, since the
registry, Program Files, and `.steam/root` routinely name the same directory
and each duplicate re-globbed a whole library tree. `find_game()` is now
two-pass (`_scan_roots()` holds the old body): plain paths first, registry
retried only on Windows when that came up empty.

| Check | Result |
|---|---|
| Windows path, real release zip, `WindowsInstall.bat` under Windows CPython 3.13.1 | install and `--verify` succeed; pck md5 `c697a7de9842a2c29d1604c04a8653a2`, byte-identical to a Linux-built install from the same pristine `testgame_new` pck |
| Zip integrity | extracted zip's `mod/` `diff -rq` clean against repo `mod/`; `install.sh` keeps mode 755 through the zip |
| Linux, no tty, before the fix | `install.py` raised `EOFError` at `Proceed? [y/N]` — the traceback nobody sees |
| Linux, no tty, after the fix | no terminal emulator found: prints the "no terminal" message, not a traceback; one found: re-execs into it (stub on PATH received `-e <install.sh path> --game-dir ...`); real tty: re-exec correctly skipped, install completes to the same md5 |
| Windows, Steam client at a non-default location, game in a separate library | `steam_roots()` empty (registry untouched); `steam_roots(use_registry=True)` found both; `find_game()` located the game via the fallback. An ordinary Program Files install alongside it was found without touching the registry, so the fallback never ran. Negative control (registry value deleted, then restored) isolated it as the cause; an HKLM-only key (no HKCU) also resolved |
| Linux | roots and the detected game unchanged; a stale `libraryfolders.vdf` entry naming a since-removed path now drops out at collection instead of being globbed |
| `tools/checks/*.py` | all five pass; `--verify` on a patched copy still reports `PATCHED` |

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

### Archived entries

Everything dated 2026-08-16 or earlier is in **`SESSION-LOG-ARCHIVE.md`**,
verbatim — at each release, entries older than the previous release move
there (documentation policy, rule 3). The archive, not git history, is the
recall path for this reasoning.

| Entry | Now owned by |
|---|---|
| 2026-08-16 — Shipped as mod release v1.5 (issue #14, Chisel HUD) | "Current status" (release line), §6, §10 |
| 2026-08-16 — Chisel: jumbotron HUD overlay for 5-8 lobbies | `MINIGAMES.md` §10 (chisel bullet, jumbotron HUD) |
| 2026-08-16 — Steam lobby lap seats for players 5-8, runtime spread removed (issue #14) | `MINIGAMES.md` §6, pitfall 35, Toolchain (`lobby_expand.py`, `lobby_preview/`), Testing "Placing the lobby previews" |
| 2026-08-15 — Shipped as mod release v1.4 (issue #13) | "Current status" (release line), §23 |
| 2026-08-15 — Issue #13: all fifteen disconnect handlers audited; pre-start guard everywhere | `MINIGAMES.md` §23, pitfall 33, pitfall 34, Testing "Simulating a peer QUITTING during a minigame load" |
| 2026-08-15 — Shipped as mod release v1.3 (issues #10, #12) | "Current status" (release paragraph), pitfall 32 |
| 2026-08-15 — Duck Hunt's silent rifle and black-screen wedge: a peer dropping DURING a load (issues #10, #12) | pitfall 32, `MINIGAMES.md` §19 and §23, Testing "Simulating a peer crash during a minigame load" |
| 2026-08-14 — first real 8P-modded Steam session on v2.1.2: black-screen incident, issues #10 and #11 | Open items (issue #11), pitfall 32 |
| 2026-08-14 — installer: backup feature removed entirely (issue #9) | Toolchain (`installer/install.py`), "Update procedure" step 8 |
| 2026-08-14 — REBUILT AGAINST GAME v2.1.2 (largest patch yet) | "The last update, and how it was verified", "Update procedure" step 4, pitfall 25 |
| 2026-08-14 — UPDATING.md split: pitfalls to `PITFALLS.md`, session log to this file | "What is where", "Documentation policy" |
| 2026-08-14 — the checks wired into the working docs, plus a pre-push hook | "Version control" (static checks, pre-push hook) |
| 2026-08-13 — CI: five static checks committed as scripts, run by GitHub Actions | "Version control", `tools/checks/` |
| 2026-08-13 — Shipped as mod release v1.2, a FULL release: vanilla-compat confirmed on real Steam | "Current status" (vanilla-compat paragraph) |
| 2026-08-13 — Chisel: the 135° slot's player stood inside the corner barrel stack | `MINIGAMES.md` §10 (chisel bullet, `MOD_HIDE_PROPS`), issue #8 |
| 2026-08-13 — Chisel's station clone list duplicated the room's collision environment | `MINIGAMES.md` §10 (chisel bullet, `MOD_STATION_NODES`) |
| 2026-08-13 — Chisel Gauntlet's spectate-marker clones carried a Label3D's transform; expander parse bug fixed | pitfall 31, `MINIGAMES.md` §10, issue #7 |
| 2026-08-13 — Playlist cap filter counted demoted spectators; a 9th connection dead-ended the session | `MINIGAMES.md` §3, "Current status" |
| 2026-08-09 — Vanilla-compat mode, shipped as v1.1 | "Current status" (vanilla-compat paragraph), Testing "Mixed-lobby runs (vanilla-compat)", pitfall 30, `MINIGAMES.md` §3 |
| 2026-08-08 — GitHub release prep, restructure, scrub | "Version control", "Layout" |
| 2026-08-08 — v1 release audit, `OFFSET` analysis | Open items 0 (the `OFFSET` / `MIN_CLEARANCE` analysis), "Update procedure" step 8 |
| 2026-08-08 — Firearm Factory's wall desks | §22 |
| 2026-08-07 — Firearm Factory uncapped | §22, "Current status" |
| 2026-08-07 — The Filter uncapped, two rooms | §21 |
| 2026-08-05 — Duck Hunt `START=1` hang (already stubbed) | Testing "`START=1` HANGS Duck Hunt permanently" |
| 2026-08-05 — full 13-minigame playtest at 8 on v1.5.0 | "Current status", Testing "What the local test still is not" |
| 2026-08-05 — Tunnel Hazard spawn sides (`inward` mode) | §16, Toolchain (`spawn_expand.py`), Open items 0 |
| 2026-08-05 — rebuilt against v1.5.0 | "Update procedure" and the archived v1.5.0 worked example (already there), pitfall 25 |
| 2026-08-04 — Forklift Certified uncapped | §20 |
| 2026-08-03 — Duck Hunt duck-node count; round pacing + two fixes | §19 |
