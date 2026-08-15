Machine Party - 8 Player Mod
============================

Raises the online player cap from 4 to 8.

Built for Machine Party v2.1.2. Works on Windows, macOS and Linux - it patches
whichever copy of the game you already own.


IMPORTANT
---------
Lobbies of 5-8 players need EVERYONE on this same mod release. Since v1.1
you can also play with unmodded friends: a lobby mixing modded
and unmodded players works automatically, caps at 4 players, and plays the
plain vanilla rotation. A 5th player trying to join a mixed lobby is refused
with the game's version-mismatch message rather than the game breaking halfway
through a session. Two different mod releases always refuse each other, so
modded friends should update together (e.g. v1.1 and v1.2 cannot connect).


INSTALL
-------
You need Python 3 installed. Most Linux and macOS systems already have it.
Windows: get it from https://python.org (tick "Add Python to PATH").

The installer sits in the same folder as this file:

  Windows      double-click install.bat
  macOS/Linux  double-click install.sh, or run:  python3 install.py

The installer finds your Steam copy automatically and patches your game files
directly. It keeps no backup of its own. If you run it again on a game that is
already patched it stops and tells you to restore the original first (see
UNINSTALL below) - that keeps it from building the mod on top of itself.

If it cannot find the game, point it at the folder yourself:

  python3 install.py --game-dir "C:\...\steamapps\common\party project\Machine Party_Windows"


DID IT WORK?
------------
Launch the game and look at the version in the corner of the main menu:

  v2.1.2-8P-v1.2    <- mod is active
  v2.1.2            <- still the original

Or check without launching:

  python3 install.py --verify

That reports PATCHED, NOT PATCHED, or PARTIALLY PATCHED.


UNINSTALL
---------
Steam: Properties -> Installed Files -> Verify integrity of game files. That
puts the original game back, and it is the uninstall - the installer keeps no
backup to restore from.

  python3 install.py --uninstall

only tells you whether the mod is currently installed and points you at those
same steps. It does not change your game files.

Note that a Steam update will also overwrite the mod - simply run the
installer again afterwards.


WHAT CHANGED
------------
- Lobbies hold up to 8 players.
- All fifteen minigames in the rotation play at 8. None of them are skipped
  for having too many people in the lobby.
- Spawn points in 15 minigames rebuilt to seat 8.
- Three extra suit colours (orange, cyan, pink) so everyone is distinguishable.
- A plain text list of player names in the lobby corner, because eight floating
  nametags get hard to read once the characters are packed together.
- The score screen and the pre-game briefing screen show all 8 players. They
  previously showed only the top 4 and silently dropped the rest.
- CHISEL GAUNTLET: four more carving stations, and split-screen extended to 8.
- WRONG WAY: each of the four troughs split into two sets of stairs - eight
  lanes, one player each - with eight screens and eight input arrows.
- TABLE MANNERS: eight chairs, with the camera pulled back and widened.
- SMOKE BREAK: eight seats, with two crates added at the ends of the bench.
- FORKLIFT CERTIFIED: four more delivery zones, so eight players fit in the
  yard instead of crowding the original four.
- THE FILTER: a second, identical room. Players are split between the two
  rooms so nobody is left on their own, and scoring is shared across both.
- FIREARM FACTORY: eight workstations instead of four, and more ingredients to
  go round - previously the same fixed amount was shared however many people
  were playing.
- MINEFIELD, DEBRIS PLATFORMS, TUNNEL HAZARD, LETHAL REBOUND, STABLE FOOTING:
  seat eight, no other changes needed.
- INSIDE JOB: fixed a bug where, at 6 or more players, the syringe could never
  be found and the round would never end. The hunt display now shows all 8.
- SPINE BREAKER: the spider kills faster in bigger lobbies, so an 8-player
  round does not run two and a half times as long as a 4-player one. Timing is
  unchanged at 1-4.
- DUCK HUNT: now plays with up to 8. One player hunts and everyone else runs,
  so the hunter faces up to 7 ducks; extra starting positions were added and
  the rifle's magazine grows to match. An 8-player session runs 8 hunting
  turns, not 16.

Removed on purpose:

- The wheat-field cutscene no longer appears. It scored nothing and broke up
  the pace. This is the only change that also affects 1-4 player games.

Apart from the cutscene, a 1-4 player game plays exactly as it did before.
That is deliberate: the extra seating and layout changes only switch on above
four players.


KNOWN ROUGH EDGES
-----------------
- SMOKE BREAK: the four players on the left of the bench can clip into each
  other. It is a cosmetic overlap caused by the angle those seats face, and it
  does not affect play.
- SPINE BREAKER at 7-8 players: you get less time to throw the spider onto
  somebody else before it kills you - roughly 9 seconds at 8 players against
  20 at 4. That is the trade for a round that does not drag.
- DEBRIS PLATFORMS: eight players share four platforms, so you start paired up
  with someone rather than alone.
- In a full lobby, players can spawn touching and visibly push apart for an
  instant at the start of a minigame. It settles immediately.
- The lobby's 8 character previews have been tested for loading but never seen
  in a real Steam lobby with 8 people in it. If they look wrong, say so.
- ARCADE mode (new in game v1.5.0) is expected to work - the mod applies the
  same player-count handling to it - but it has never actually been run with
  the mod, because it cannot be reached in local testing. Reports welcome.
- Nobody has yet played a real 8-player session with eight actual people, so
  scoring and win conditions at 8 are less proven than everything else. If a
  round ends with the wrong winner or fails to end, that is worth reporting.

If anything else looks off at 8 players, please report it.
