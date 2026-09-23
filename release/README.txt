VETTE! FOR AMIGA - VERSION 0.1.0
================================

This archive contains an independently developed Amiga port. It does not
contain the copyrighted original Vette! program or game data.

REQUIREMENTS

  Amiga 1200
  Kickstart/Workbench 3.1 or compatible
  2 MB chip RAM
  8 MB fast RAM
  hard disk (the installed original resource files total about 2.1 MB)

INSTALL THE ORIGINAL DATA

Download the original VETTE__1.02_and_extras.sit archive. Leave it compressed.
Double-click Install. Choose the parent installation drawer, a temporary drawer
(default T:), and the downloaded archive. Installer creates a Vette! drawer and
icons. The standard Amiga Installer (V43 or later) must be available.

No xadmaster, Python, Deark or Macintosh emulator is needed. Installation runs
on the Amiga itself and may take several minutes on an A1200. Allow 12 MB free
in the temporary drawer and 3 MB at the destination. T: normally uses RAM;
choose a hard disk temporary drawer when RAM is insufficient.
Temporary files are automatically removed; the original archive is unchanged.

Alternatively, create Work:Games/Vette! and an existing Work:Temp drawer,
then run from an Amiga Shell in the release directory:

  VetteInstallData "Work:Downloads/VETTE__1.02_and_extras.sit" "Work:Games/Vette!/data" "Work:Temp"

Copy Vette and Vette.info into the Vette! drawer
(rename both to Vette! and Vette!.info if desired). The helper works with the default
4096-byte stack. It verifies the exact supported 1.02 files before installing
either of them, and never overwrites existing original game files. If existing
files differ, it reports an error so that you can select another destination.

Unix users can build the same helper from installer-source (make BUILD=build)
and invoke build/VetteInstallData with the archive and destination paths.
The older Python host-tools remain available for NDIF/raw HFS inputs.

After a successful graphical install, the Vette! drawer contains:

  Vette!            Amiga executable, with Vette!.info
  data/Color VETTE! original 1.02 application resource fork
  data/VETTE!.Data  original 1.02 game-data resource fork

Do not use the empty Macintosh data forks, MacBinary or AppleDouble wrappers,
or VETTE!.img itself under those names. Full extraction details are in
docs/install-original-data.md.

The separate installer helper is LGPL-2.1-or-later. Its complete source,
build instructions and license are included in installer-source.

RUNNING ON AN AMIGA

Double-click Vette! in the installed drawer, or enter in a Shell there:

  Vette!

RUNNING IN FS-UAE

Vette.fs-uae describes the supported A1200, 2 MB chip/8 MB fast configuration.
Set your legal Kickstart 3.1 ROM in FS-UAE and open that configuration. It
mounts this directory as DH1: and starts Vette through the included DH0: boot
directory. If your FS-UAE front end overrides input ports, set port 0 to Mouse
and port 1 to Nothing; keyboard joystick emulation otherwise consumes the
cursor keys.

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

The cursor keys are Amiga aliases for the original keyboard/keypad controls.
The mouse remains usable. The Macintosh menu bar is deliberately not drawn;
its keyboard equivalents still invoke the original game commands.

NOTES

The package supports the single-player game. Macintosh desktop preference,
high-screen, and communications dialogs are intentionally not implemented;
network play is out of scope. Unknown required Macintosh calls stop loudly and
identify the failing manager, routine, selector, and original caller.
