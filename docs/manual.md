# What the shipped documentation says

This is the port-facing digest of the scanned VETTE! manual and extras. It records facts that
would otherwise be tempting to infer from code or data. Page numbers below are the **printed manual
pages**; the PDF has six unnumbered front-matter pages before page 1.

Sources, all local-only under `tmp/unpacked/VETTE! 1.02 Folder/`:

- `scans/Manual.pdf` - 49 scanned pages, the original VETTE! manual
- `scans/KeyChart.jpg` - keyboard command chart
- `scans/Map.jpg`, `MapInfo_1.jpg`, `MapInfo_2.jpg` - street map and location guide
- `scans/Package.pdf` - the later Mindscape five-game CD package
- `web_docs/cheats.txt` - archive maintainer's cheats and version-specific patches

The package scan is not the authority for the original game's requirements: it describes the
later five-game CD bundle (System 7, 4 MB, 256-colour monitor). The original manual below describes
the VETTE! release whose binaries are in the archive.

## Supported Macintosh configurations

The manual states (pp. 5-7):

- all Macs need at least 1 MB RAM and an 800K drive;
- colour requires a Mac II-series or LC, at least 2 MB RAM, a 4-bit/16-colour video card and a hard
  drive;
- both versions require System 6.0.2 or later;
- the colour version specifically requires System 6.0.5 or later, 32-bit QuickDraw, the Monitors
  setting at 16 colours, and a hard drive;
- under MultiFinder/System 7, colour needs 1,500K RAM; 68000 Macs need MacsBug and 900K for B&W.

The Gravis MouseStick instructions name four intended display configurations: **512x342** for a
standard 9-inch screen, **512x384** for a 12-inch screen, **640x400** for a Portable, and
**640x480** for a 13-inch RGB monitor (p. 7). This independently supports the port's chosen
512x384 display while explaining the game's 512x342 and 512x320 Macintosh drawing surfaces.

## Game flow and named states

The documented single-player flow (pp. 2-10) is:

1. title/intro, dismissible with the mouse button;
2. performance-test garage: select one of four player Corvettes, optionally run the dynamometer,
   then accept;
3. choose `TRAINEE`, `ROOKIE`, or `PRO`;
4. choose one of four opponent cars;
5. choose one of four courses;
6. answer the trivia/copy-protection question;
7. wait for the bottom starting light, then race;
8. finish between the two poles and under the checkerboard, followed by a win/loss scene and
   possibly a Top Ten name entry.

The shipped session controls do **not** contain practice or qualifying modes. `MENU 444` contains
`Tour Mode`; `MENU 222` contains `Restart Race`, `Return to Game`, `Quit to Garage`, and `Quit`.
`MENU 130` selects `Single Player` or the deliberately unsupported communications transports.
This inventory is reproducible with `tools/dump_menu.py` and is the coverage authority; generic
racing-game phase terminology must not be projected onto Vette.

Tour Mode is not an alternate race started from the garage. Main clears its flag on the ordinary
new-race transitions at `$1FB4` and `$2142`. While a game is suspended, Options > Tour Mode enables
the separate `MENU 777` list of 26 San Francisco destinations; selecting one relocates the existing
player through `Main+$3456`, and Return to Game resumes that session.

Player cars (Appendix A, p. 31) are:

- 1989 Stock Corvette
- 1989 ZR1 "King of the Hill" Corvette
- Callaway "Twin Turbo" Corvette
- Callaway "Sledgehammer" Corvette

Opponent cars are Porsche 928S4, Lamborghini Countach, Ferrari Testarossa and Ferrari F40.
These names are the semantic key for the eight 110-byte `PERF` resources. The appendix's recurring
field groups are engine, drivetrain/gears, dimensions, steering/brakes, wheels/tires, acceleration
and performance; use those labels to test a decode rather than assigning fields from numerical
shape alone.

### Difficulty is a concrete four-column state

The selector defines this exact matrix (p. 8):

| level | damage | traction | police | cruise control |
|---|---|---|---|---|
| TRAINEE | none | high | inactive | constant |
| ROOKIE | reduced | moderate | active | constant |
| PRO | realistic | realistic | active | realistic |

At TRAINEE, collisions cannot damage the car; they can still slow it and cost time. Water is the
documented exception that can end a TRAINEE race (p. 4), matching the observed Lake Merced tow
sequence. Realistic cruise control disengages after braking or below 25 mph and must be re-engaged.

## Driving model vocabulary

The manual supplies names worth carrying into symbols and probes (pp. 10-14):

- manual/automatic transmission; four to six forward gears plus reverse;
- steering input, current speed, degree of turn and terrain jointly determine acceleration;
- `turn correction`, `skid traction`, `skid rate`, and `skid scrub rate` are separately adjustable;
- collision damage depends on speed, angle, object and skill level;
- damage is divided into steering, turning, engine and transmission indicators, with minor,
  moderate and severe levels;
- gas stations repair the car when parked between pumps and building; beyond-repair damage causes
  a tow back to the garage and ends the race;
- active police issue speeding, reckless-driving, hit-and-run and vehicular-manslaughter tickets;
  penalties are 5, 10, 10 and 30 seconds respectively;
- the finish must be crossed between two poles beneath the checkerboard.

The dashboard exposes race timer, cruise-control indicator, speedometer, turn signal,
automatic-shift indicator, upshift indicator, tachometer, traffic-control icons, current street and
upcoming cross street (p. 12). The navigation map shows player and opponent positions; the player's
square flashes twice and heading appears at lower right (p. 18).

## Renderer and performance controls

These are real user-facing renderer controls, not inferred optimisation ideas (pp. 14-17):

- rear-view mirror toggle;
- sound and engine-sound toggles;
- in-car versus helicopter view;
- traffic density;
- `block size`: 3x2 default for speed, 3x3 or 4x3 for more visible buildings/objects;
- buildings toggle;
- B&W-only horizon toggle and solid/wireframe toggle;
- `outline`: outlines buildings and vehicles when enabled; the manual recommends disabling it on
  68000 Macs;
- brake rate, minimum turn, maximum turn, turn correction, skid traction, skid rate, skid scrub
  rate and gravity.

The manual's prescribed speed-up order is: rear mirror off, sound off, use an inside view instead
of helicopter view, B&W horizon off, reduce traffic density, B&W wireframe, buildings off, use the
B&W executable, then restore Outline off and Block Size 3x2 if preferences changed.

This matters to the port roadmap: object density, visible-block radius and rendering style are
explicit game states. They should be located in A5 globals and named before profiling or changing
the renderer.

## Complete keyboard controls

Chapter 9 (pp. 29-30) and `KeyChart.jpg` agree:

| action | key |
|---|---|
| steer left/right | `J` / `L`, or keypad `4` / `6` |
| recover from skid | `K`, or keypad `5` |
| full stop | `F` |
| accelerate | `I`, or keypad `8` |
| brake | `M`, Space, or keypad `2` |
| accelerate left/right | `U` / `O`, or keypad `7` / `9` |
| brake left/right | `N` / `,`, or keypad `1` / `3` |
| views left/forward/right/helicopter | F1/F2/F3/F4 |
| raise/lower view | F7/F8 |
| viewing angle up/down | F9/F10 |
| gears 1-6 | top-row `1`-`6` |
| neutral/reverse | top-row `0` / `R` |
| upshift/downshift | top-row `+` / `-` |
| front dash / rear mirror | `5` / `6` (or the documented command/function equivalents) |
| automatic shift / buildings / cruise / damage | `A` / `B` / `C` / `D` |
| engine sound / gear-shift display / navigation / pause / sound | `E` / `G` / `H` / `P` / `S` |
| tour mode / menu / horn | `T` / Escape or `Q` / `Z` |
| head-to-head chat | `9` |

The B&W-only horizon and wireframe toggles are `V` and `W`.

The original game defaults to Numeric keypad steering and assigns no driving action to the
Macintosh cursor keys. The standalone Amiga port aliases each cursor key to both equivalent
layouts in the live driving KeyMap: left/right act as `J`/`L` and keypad `4`/`6`; up/down act as
`I`/`M` and keypad `8`/`2`. Only the currently selected original mode consumes one set. Their
ordinary cursor-key EventRecord identity is preserved. Thus Up is throttle, Down is brake, and
Left/Right steer without requiring a keypad or a menu change.

The supplied FS-UAE launchers explicitly attach the mouse to Amiga port 0 and leave port 1 empty.
FS-UAE otherwise enables its keyboard-joystick fallback and consumes the host cursor keys before
the emulated Amiga keyboard can report them. FS-UAE calls the empty-device value `nothing`, not
`none`. Some FS-UAE installations nevertheless reassign that port on startup, so the launchers do
not rely on the port choice: they enable full-keyboard mode and explicitly map all four host arrows
to the corresponding Amiga cursor keys. Custom input mappings override FS-UAE's keyboard-joystick
assignment. The production launcher also enables automatic input grab; Command-G or the middle
mouse button releases it.

The shipped Options -> Steering submenu contains four mutually exclusive choices: Numeric keypad,
Keyboard, Mouse, and Joystick. Mouse is a real driving mode, not the Gravis MouseStick setting:
the game reads the Macintosh `Mouse` low-memory point for steering and treats the mouse button as
the accelerator. If selected from the menu, the standalone port redirects its direct Page-0
`Mouse`, `RawMouse`, `MTemp`, and `MBState` accesses to private A5-adjacent shadows updated from the
Amiga mouse. This prevents writes into the Amiga's vector page.

The original modes remain mutually exclusive. In Mouse mode the arrow aliases do not steer,
accelerate, or brake, although ordinary keyboard commands continue to work. The physical mouse
remains available for menus while Keyboard steering is active.

## Courses and world boundaries

The four course endpoints (pp. 18-21) are:

1. San Francisco Zoo to Vista Point via the Golden Gate Bridge;
2. Golden Gate Bridge to Bay Bridge;
3. Bay Bridge to San Francisco Zoo;
4. the first three in sequence, Zoo -> Golden Gate -> Bay Bridge -> Zoo.

Routes are not fixed: the printed map shows streets but deliberately does not prescribe a route.
The city is bounded by intentionally inaccessible/construction-blocked roads. `Map.jpg` supplies
the authoritative street/landmark vocabulary; `MapInfo_1/2.jpg` describes the named landmarks,
including Lake Merced as a U-shaped reservoir southwest of the zoo.

The archive cheat documents one additional state: on Course 3, reverse from the Bay Bridge far
enough with wall left/ocean right to enter hidden streets named after the developers. This is a
useful later reference-loop target, not evidence for the normal map format.

## Communication is head-to-head play

The manual settles the `Communication` segment and `COMM` resource question (Chapter 7,
pp. 22-24). VETTE! supports two-player head-to-head racing over:

- direct modem-port cable (`Direct Connect`);
- two Hayes-compatible modems at 1200 baud or faster (`Modem Connect`), including tone/pulse,
  baud rate, auto-answer, manual AT commands, audio checksum and saved setup;
- AppleTalk (`AppleTalk Connect`) with opponent discovery/challenge.

The Options -> Communications submenu switches from Single Player to Mac to Mac. Each player may
choose a different difficulty and Corvette; the opponent selector controls the model drawn for the
remote car while its performance follows the other player's chosen Corvette. Course disagreement
is resolved randomly (or by the caller for modem play). `+` opens a chat window and pauses both
players until the message has been read.

Therefore `Communication` is not mysterious game logic. The Amiga port is deliberately
**single-player only**: direct serial, modem, AppleTalk, remote-car synchronization, multiplayer
chat, and communications-setup persistence will not be implemented. The original segment remains
resident as part of the complete CODE image, but entering its head-to-head path is unsupported and
must remain an explicit loud failure rather than acquiring a partial transport emulation.

## Copy protection notes

The manual says the player gets two attempts; a second wrong answer allows a short drive before a
police arrest and automatic quit (pp. 3, 9). `web_docs/cheats.txt` says version 1.02 asks only once
on first run and records older version-specific binary patches. Those patches are historical clues,
not a basis for this port's protection removal; the port's patch remains tied to its own disassembly.
