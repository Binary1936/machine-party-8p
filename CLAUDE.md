# Machine Party 8-Player Mod

**Read `UPDATING.md` in this folder before doing anything.** It is the handoff
document and the entry point: current verified state, toolchain, the 8-client
local test harness, the update procedure and the failure modes already hit. It
has a paste-in prompt at the top, including a variant for "the game just
updated".

Per-minigame detail — every change the mod makes, minigame by minigame, plus the
diagnostic traces and the caps — is in **`MINIGAMES.md`**, cited as *§N*. Read it
when you are touching a specific minigame, not before. `UPDATING.md`'s overlay
manifest maps each file to its section.

Currently targets game **v1.5.0** (Godot 4.5.2). The **shipped release is v1.0**;
this tree carries **v1.1** — vanilla-compat mode (mixed lobbies with unmodded
clients), **unreleased** pending a real-Steam mixed-session check — so the
in-game version string is `v1.5.0-8P-v1.1`. Before running anything, read
**"Working environment"** in `UPDATING.md` (screenshots, missing tools, the
build pre-flight) and **"Session log"** for what changed most recently.

Five rules, each of which cost real time to learn:

1. **Never modify the Steam install directory** —
   `/mnt/secondary/SteamLibrary/steamapps/common/party project/Machine Party_Linux/`.
   Copy it out. `testgame/` is the throwaway copy for test runs.
2. **Never pass a shell-expanded path** like `$PWD/...` to
   `installer/install.py`; type literal absolute paths.
3. **1-4 player lobbies must stay pixel-identical to vanilla.** Apply layout
   changes at runtime, gated on roster size — never bake them into a `.tscn`.
4. **Verify on a client window, not the host.** `initialize()` and
   `spawn_players()` run host-only, so a local scene change affects nobody else;
   a host screenshot will happily show a fix no client has. Use the
   `-localtest` diagnostic traces instead.
5. **Never take a blind full-screen screenshot.** This is a Wayland desktop
   with no `xdotool`/`wmctrl`, so a shell capture grabs the whole screen and
   the game window is not reliably frontmost — one such capture accidentally
   caught unrelated private content from another application, and was
   discarded unused. Ask the user to screenshot; the traces are the real
   evidence anyway.

## How to work on this

Two preferences that cost a correction to learn:

- **Do not add code that wasn't asked for.** Diagnostic prints, debug flags,
  test aids and convenience helpers all count, even when they feel free. The bar
  for proposing one is whether it *replaces real manual effort*: the `[SPINE8]`
  / `[DUCK8]` / `[DISCO8]` traces earn their place because they verify
  eight-player spawns and 1-4 parity across eight separate client logs, which is
  work a human would otherwise do by hand, per window, per run. A flag that
  automates something already trivial does not. Say what it would check and what
  it saves, then ask — don't add it and mention it afterwards. Adding code as
  part of an approved plan is fine; the objection is to extras that appear
  without a decision point.
- **Default to `START=1`** for speed. Use `FLOW=1` only when the measurement
  requires it — and it sometimes does, because `START=1` doesn't merely skip
  presentation states, it can *substitute values* on the way past. See the
  documented traps in `UPDATING.md` (Testing).

## Version control

In git, pushed to GitHub — **public**; `NOTICE.md` carries the credit and
takedown terms. Three rules, entry-point copies — the authoritative home
is **"Version control" in `UPDATING.md`**:

- **Never commit game content.** `.gitignore` blocks it; a `git status`
  showing any of it means the ignore rules broke — stop, never force-add.
- **Subagents never commit or push.** The orchestrating session commits after
  its own review, one verified change per commit — and **never before the
  change is verified to do what it was meant to do**.
- **Never push without a human check-in.** Present the commits and their
  evidence, then wait for the maintainer's OK. History on origin is
  append-only: never amend, rebase, or force-push anything already pushed.
- **Tracked files are public-facing.** Personal or machine-local detail goes
  to `NOTES-LOCAL.md` (untracked), never into tracked docs.

## Documentation maintenance

The doc set has a standing policy — **"Documentation policy" in `UPDATING.md`**;
read it before editing any of these files. In short: every fact lives in exactly
one authoritative place and is referenced from everywhere else; tighten wording
but never cut rules, measurements, or the *why* behind them; superseded
session-log entries move to `SESSION-LOG-ARCHIVE.md`; commit before any
restructure (the project is in git since 2026-08-08). The rules this file
repeats from `UPDATING.md` and memory are intentional entry-point copies —
when one changes, update both.

> **Note on memory:** this project's persistent memory is namespaced to the
> parent directory `~/Documents/Claude`. Starting a session *there* rather than
> here loads the project memory and the "never write to game install dirs"
> feedback. Working directly in this folder gets you this file but not those —
> which is why the two preferences above are duplicated here.
