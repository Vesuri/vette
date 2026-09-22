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

You need VETTE!.img from your original Vette! 1.02 archive. On a computer with
Python 3, run this from the extracted release directory:

  python3 host-tools/install_original_data.py "/path/to/VETTE!.img" .

The original StuffIt archive must be expanded by a program that preserves the
Macintosh resource fork of VETTE!.img. On macOS, unar does this. The installer
also accepts an 8 MB raw HFS image previously made with ndif2raw.py.

After a successful install, these files sit beside the Amiga executable:

  Vette             the Amiga executable supplied by this archive
  Color VETTE!      original 1.02 application resource fork
  VETTE!.Data       original 1.02 game-data resource fork

Do not use the empty Macintosh data forks, MacBinary or AppleDouble wrappers,
or VETTE!.img itself under those names. Full extraction details are in
docs/install-original-data.md.

RUNNING ON AN AMIGA

Open a Shell, change to this directory, and enter:

  Vette

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
The original menus and mouse remain usable.

NOTES

The package supports the single-player game. Macintosh desktop preference,
high-screen, and communications dialogs are intentionally not implemented;
network play is out of scope. Unknown required Macintosh calls stop loudly and
identify the failing manager, routine, selector, and original caller.
