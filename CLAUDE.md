# Machine Party 8-Player Mod

**Read `UPDATING.md` in this folder before doing anything.** It is the handoff
document and the entry point: current verified state and version, toolchain,
the 8-client local test harness, the update procedure, and a paste-in prompt at
the top (with a variant for "the game just updated"). The failure modes already
hit are in **`PITFALLS.md`** (cited as *pitfall N*) — read it before changing
code or running the tools. **`SESSION-LOG.md`** has what changed most recently;
**`MINIGAMES.md`** (cited as *§N*) has the per-minigame detail — read it when
touching a specific minigame, not before. Every command in the docs is
repo-relative and run from the repo root.

Five rules, each of which cost real time to learn:

1. **Never modify the Steam install directory** — wherever Steam put the game,
   copy it out. `testgame/` is the throwaway copy for test runs.
2. **Never pass a shell-expanded path** like `$PWD/...` to
   `installer/install.py`; type a literal absolute path (quoted if it has a
   space).
3. **1-4 player lobbies must stay pixel-identical to vanilla.** Apply layout
   changes at runtime, gated on roster size — never bake them into a `.tscn`.
4. **Verify on a client window, not the host.** `initialize()` and
   `spawn_players()` run host-only, so a local scene change affects nobody else;
   a host screenshot will happily show a fix no client has. Use the
   `-localtest` diagnostic traces instead.
5. **Never take a blind full-screen screenshot.** A shell capture grabs the
   whole screen and the game window is not reliably frontmost — one such
   capture caught unrelated private content from another application. Ask the
   user to screenshot; the traces are the real evidence anyway.

## How to work on this

Two preferences that cost a correction to learn:

- **Do not add code that wasn't asked for.** Diagnostic prints, debug flags,
  test aids and convenience helpers all count, even when they feel free. The bar
  for proposing one is whether it *replaces real manual effort*: the `[SPINE8]`
  / `[DUCK8]` / `[DISCO8]` traces earn their place because they verify
  eight-player spawns and 1-4 parity across eight separate client logs, which is
  work a human would otherwise do by hand, per window, per run. Say what it
  would check and what it saves, then ask — don't add it and mention it
  afterwards. Adding code as part of an approved plan is fine; the objection is
  to extras that appear without a decision point.
- **Default to `START=1`** for speed. Use `FLOW=1` only when the measurement
  requires it — `START=1` doesn't merely skip presentation states, it can
  *substitute values* on the way past. See the documented traps in
  `UPDATING.md` (Testing).

## Version control

In git, pushed to GitHub — **public**; `NOTICE.md` carries the credit and
takedown terms. Entry-point copies — the authoritative home is **"Version
control" in `UPDATING.md`**:

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
session-log entries move to `SESSION-LOG-ARCHIVE.md`. The rules this file
repeats from `UPDATING.md` are intentional entry-point copies — when one
changes, update both.

This file is the anchor for a session started *inside* the repo. The
maintainer starts sessions one level up, where a local, untracked `CLAUDE.md`
and kickoff prompt carry the machine-specific pointers.
