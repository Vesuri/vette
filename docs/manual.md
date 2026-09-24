# Playing Vette!

See the root [README](../README.md) for installation and hardware requirements.

## Getting started

Click to skip the intro, choose a Corvette in the garage, then Accept.
Choose Trainee, Rookie or Pro, an opponent and a course. The original trivia
requester is bypassed. Wait for the starting signal, select first gear or
automatic transmission, and accelerate. There is no separate ignition command.

| Action | Amiga key |
|---|---|
| Accelerate / brake | Up / Down; Space also brakes |
| Steer | Left / Right |
| Full stop / recover from skid | F / K |
| Gears / neutral / reverse | 1–6 / 0 / R |
| Shift up / down | + / - |
| Automatic / cruise control | A / C |
| Horn / pause | Z / P |
| Quit race to garage | Esc |
| Sound / engine sound | S / E |
| Buildings / damage / navigation | B / D / H |
| Left / forward / right / helicopter view | F1 / F2 / F3 / F4 |
| Raise / lower view | F7 / F8 |
| Normal exit, saving changed scores | Control + left mouse button |
| Immediate WHDLoad exit | F10 |

The original keyboard layout also works: J/L steer, I accelerates, M brakes,
U/O accelerate while turning and N/comma brake while turning. Numeric-keypad
equivalents are 4/6, 8, 2, 7/9 and 1/3. Cursor aliases feed both layouts; the
selected original steering mode consumes the relevant keys.

Mouse steering is a separate, mutually exclusive mode: movement steers and
the button accelerates. In that mode cursor aliases do not drive the car,
although other keyboard commands remain available. The original steering
shortcuts are Command-N/K/M/J for keypad/keyboard/mouse/joystick.
The mouse still operates selectors in keyboard mode.

The menu bar is hidden and no replacement menu has been implemented.
Original keyboard equivalents remain available. F10 is reserved by WHDLoad,
overriding the original viewing-angle-down command unless QuitKey changes.
Network play and optional High Screen/Preferences dialogs are unsupported.

If FS-UAE consumes cursor keys as joystick input, disable that assignment or
use this repository's launcher mappings.

## Racing

| Difficulty | Damage | Traction | Police | Cruise |
|---|---|---|---|---|
| Trainee | None | High | Inactive | Constant |
| Rookie | Reduced | Moderate | Active | Constant |
| Pro | Realistic | Realistic | Active | Realistic |

Water can end even a Trainee race. Park between a gas station's pumps and
building for repairs; irreparable damage results in a tow to the garage.
Pro cruise disengages after braking or below 25 mph.

Courses are Zoo → Vista Point, Golden Gate Bridge → Bay Bridge, Bay Bridge →
Zoo, and all three legs in sequence. Routes are not prescribed. Cross the
finish **between the poles**, beneath the checkerboard.

Esc quits the current race and returns to the garage through the original
Quit to Garage command. P suspends the session. Original Command-R resumes it; Restart Race is enabled
after Quit to Garage, not in the paused race. Tour Mode relocates the retained
player rather than starting another race.

Changed scores are saved to `data/Vette.scores` on normal exit. Immediate
WHDLoad quit cannot perform that deferred save.

## Reference

Controls and game rules come from the archive's scanned `Manual.pdf`
(printed pages 2–24 and 29–31) and `KeyChart.jpg`; these are local-only inputs.
The original manual's Macintosh hardware requirements do not describe this
port. Decoded implementation details belong in [data formats](data-formats.md)
and [gameplay coverage](gameplay-coverage.md).
