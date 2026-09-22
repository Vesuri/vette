# Gameplay coverage matrix

This matrix distinguishes three kinds of evidence:

- **ordinary input**: the fixture supplies only mouse/keyboard events;
- **checkpoint**: the fixture waits for live play, then places source-owned
  state at a decoded endpoint so the original decision code runs;
- **oracle**: a state-paired Macintosh/Amiga comparison.

All target commands run from `amiga/` after `. ./env.sh`; add
`EXTRA_ARGS="--warp_mode=1"` to the diagnostic invocation. A loud stop is a
failure unless the row explicitly names that optional boundary.

## Front end and presentation

| surface | evidence | reproducible target command / gate | result |
|---|---|---|---|
| complete intro, animation and five cues | oracle | repository `make fidelity-check` | 163,840 game-owned pixels exact; tram, singer, mic, logo, scroller and audio lifecycle exercised |
| intro skip | ordinary input | `make clean && make -j4 PROBES=1 SKIP_INTRO=1`; `GDBSCRIPT=stage_c.gdb ./diag_run.sh 30` | shipped first-button branch, not a code-flow bypass |
| garage and ACCEPT | ordinary input | add `GARAGE_CLICK=1` | garage, opponent, difficulty and course trackers lead to live driving |
| dynamometer | ordinary input + lifecycle | add `GARAGE_DYNO=1 FINISH_CHECKPOINT=1`; use `garage_dyno.gdb` | returns to garage, then completes a race and returns again |
| palettes | resource oracle | repository `make driving-palette-compare` | selector and driving CLUTs match shipped `pltt` resources |
| F1–F5 and mirror-off | oracle | repository `make driving-view-regression` | state-paired exterior views, dashboard and mirror path covered |

## Selection matrix and complete race lifecycles

The lifecycle observer is `driving_course_lifecycle.gdb`. Its common build is
`make clean && make -j4 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FINISH_CHECKPOINT=1`
plus the variable in the table. Every row reaches original finish handling,
Score, Main return, and the next garage handoff.

| dimension | shipped values covered | fixture | result |
|---|---|---|---|
| course | `GARAGE_COURSE=1..4` | ordinary selection + decoded finish checkpoint | three short courses and Course Four's three-leg cycle |
| player Corvette | `GARAGE_CAR=1..4` | ordinary selection + finish checkpoint | all four PERF records reach driving and garage return |
| opponent | `GARAGE_OPPONENT=1..4` | ordinary selection + finish checkpoint | Porsche, Lamborghini, Testarossa and F40 reach driving and return |
| difficulty | `GARAGE_DIFFICULTY=1..3` | ordinary selection + finish checkpoint | Trainee, Rookie and Pro survive the complete lifecycle |
| mode | single player | ordinary menu state | required release scope |
| mode | Tour Mode | `TOUR_MODE_PROBE=1`, `driving_tour_mode.gdb` | shipped destination table relocates the retained player |
| mode | Communications | no run | deliberately unsupported network play; entering it remains a named loud boundary |

The archive/manual/resource/code inventory contains no separate practice or
qualifying session. High Screen and Preferences are optional desktop UI and
remain deliberate loud boundaries; their `TIME` score data is nevertheless
implemented and persistent.

## Driving behavior

| behavior | fixture and observer | coverage |
|---|---|---|
| drivetrain, acceleration, braking, manual/automatic | ordinary KeyMap events; `driving_drivetrain.gdb`, `driving_car_motion.gdb`, A/S dispatch observers | original car fields, gear gate, speed, RPM and toggles |
| keyboard and mouse input | `driving-control-audit`; physical edge/KeyMap observers | cursor-key aliases, keypad originals, mouse points/button and FS-UAE port assignment |
| city traffic | default and `FOLLOW_ROAD=1` | active object creation, movement, retirement, collision and raster rendering |
| water recovery | straight-to-lake ordinary route; `driving_lake_static_collision.gdb` | MAPS/QUAD selector 63 → PICT 140 → acknowledgement → garage |
| damage and repair | `DAMAGE_REPAIR_CHECKPOINT=1`; `driving_damage_repair.gdb` | natural impact damage, gas-station response 214 and timed repair |
| terminal damage | `TERMINAL_DAMAGE_CHECKPOINT=1`; `driving_terminal_tow.gdb` | original terminal formula, PICT 147, acknowledgement and garage return |
| difficulty damage | `DIFFICULTY_DAMAGE_CHECKPOINT=1`; `driving_difficulty_damage.gdb` | Trainee immunity and Rookie/Pro damage arms |
| difficulty cruise | `DIFFICULTY_CRUISE_CHECKPOINT=1`; `driving_difficulty_dynamics.gdb` | source difficulty comparison and realistic cruise behavior |
| police penalties | `POLICE_TICKET_CHECKPOINT=1`; `driving_police_ticket.gdb` | all four ordinary offenses, ticket/release state machine |
| finish/result/score | `FINISH_CHECKPOINT=1`; `driving_course_lifecycle.gdb` | every endpoint and common Score return |

## Map and route diversity

| path | fixture / observer | evidence |
|---|---|---|
| city road from Course One start | `FOLLOW_ROAD=1`; `driving_follow_road.gdb` | ordinary steering and acceleration remain on road through bounded checkpoint |
| city → freeway | Course Two `FREEWAY_ROUTE=1`; `driving_freeway_activation.gdb` | ordinary input reaches response 212, mode changes, freeway traffic spawns |
| first freeway bend | same build; `driving_freeway_bend.gdb`, `driving_freeway_after_bend.gdb` | decoded connected response chain runs |
| freeway `(6,36)` | same build; `driving_freeway_straight.gdb`, `driving_freeway_x6_collision.gdb` | eastbound straight and a real player/traffic hull collision |
| far freeway → city | add `FREEWAY_START=30 MAIN_START=17`; `driving_freeway_return.gdb`, `driving_main_return.gdb` | export 230 clears freeway mode and continued Main Map execution reaches cell `(17,39)` |

The short far-end start is used only after the natural city→freeway path is
proved. It changes the starting position, not collision, map, response, or
mode decisions.

## Audio

| family | evidence |
|---|---|
| intro music, bell, metallic cue, logo music | full-intro Macintosh event oracle and target trace |
| engine pitch | moving road trace, original Bogas Pitch caller and Paula period mapping |
| horn | Course Two physical Z press after race start |
| collision/splash/recovery | straight-to-lake lifecycle and post-garage deadline check |
| traffic/bridge/helicopter/police effects | bounded source-caller observers |
| overlap/replacement | `make driving-audio-regression` proves three contexts and four Paula voices |
| volume | complete resident call scan proves used Bogas range 0..300; target maps 300 to Paula 64 |

## Session, persistence and teardown

| path | fixture / observer | result |
|---|---|---|
| pause/options and Return to Game | `SESSION_CONTROL_ITEM=6`; `driving_session_control.gdb` | retained race resumes |
| Quit to Garage then Restart Race | `SESSION_CONTROL_ITEM=5`; same observer | original enable-state transition and race restart |
| menu Quit | `SESSION_CONTROL_ITEM=8`; `driving_menu_quit.gdb` | original ExitToShell cleanup and AmigaOS restoration |
| Control+left-mouse emergency exit | `QUIT_PROBE=1`; `quit_path.gdb` | same installed cleanup plus DMA/interrupt/View restoration |
| persistent scores | `SCORE_PERSISTENCE_PROBE=1`; `score_persistence.gdb` | 1,200-byte TIME payload writes after handback and imports on next launch |

`tools/check_gameplay_coverage.py` keeps this document's named observers and
build switches tied to the tree. `amiga/regression.sh` is the executable
companion. Run an individual group (`smoke`, `courses`, `vehicles`,
`difficulties`, `recovery`, `routes`, or `session`) or repository
`make gameplay-regression` for all groups. Every case requires a specific
success record and rejects loud-stop output; a mere wall-time expiry cannot
pass. This file remains the human scope statement.
