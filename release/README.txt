VETTE! FOR AMIGA - VERSION 0.90 (23.09.2026)
==========================================

This archive contains an independently developed Amiga port. Game data is
not included and must be supplied separately.

REQUIREMENTS

  68020 or better (required by the current graphics conversion routine)
  68030 or better with AGA recommended
  Kickstart 2.04 or later (3.1 tested)
  1 MB free chip RAM and 4.5 MB additional free RAM reserved by the slave
  Additional free memory for WHDLoad, the host system and optional PRELOAD
  WHDLoad 17 or later
  Hard disk with 3 MB free for the installed game
  Amiga Installer V43 or later for installation

INSTALLATION

WHDLoad is the supported installation and launch method. Install WHDLoad
from https://www.whdload.de/ first.

The slave needs a legally obtained Kickstart 3.1 image and its matching
relocation file in Devs:Kickstarts/ (or WHDCOMMON:):

  kick40068.A1200 and kick40068.A1200.RTB
  or kick40068.A4000 and kick40068.A4000.RTB
  or kick40063.A600 and kick40063.A600.RTB

These are ROM image names, not requirements for a particular Amiga model.
The .RTB files are available in the SKick package on Aminet. Neither the
Kickstart image nor the original game data is included in this archive.

Download VETTE__1.02_and_extras.sit from the Vette! page at Macintosh Repository:
https://www.macintoshrepository.org/4948-vette-
Leave the downloaded file compressed.

Double-click Install. Choose where to install the game, a temporary drawer,
and the downloaded file. A Vette! drawer and its icons will be created.

The temporary drawer needs at least 12 MB free. The default is T:, which
normally uses RAM. Choose a hard disk drawer if there is not enough free RAM.
Extraction may take several minutes. Temporary files are removed when finished;
the downloaded file is not changed.

RUNNING

Double-click the Vette! icon in the installed drawer. WHDLoad starts the game.
F10 quits to Workbench. PRELOAD is enabled in the icon; disable that tooltype
if there is insufficient memory to cache the game files.
Use Control + left mouse button for a normal exit that saves pending scores;
F10 exits immediately without running the game's save-on-exit code.

If using an emulator, set port 0 to Mouse and port 1 to Nothing; keyboard
joystick emulation may otherwise consume the cursor keys.

DRIVING

  Up / I       accelerator
  Down / M     brake
  Left / Right steering
  1 through 6  select forward gear
  0 / R        neutral / reverse
  + / -        shift up / down
  A            automatic shift
  Z            horn
  P            pause/options
  Escape or Q  menu

Single-player only; network play is not supported.

INSTALLER HELPER

The separate installer helper is LGPL-2.1-or-later. Source and build instructions:
https://github.com/Vesuri/vette/tree/main/tools/install-data
Its archive format tables are copyright 2017-present MacPaw Way Ltd.
The helper's license follows below.
