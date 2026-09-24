# Gameplay regression coverage

The port supports all four single-player courses. Communications/network play
is deliberately unsupported. Optional High Screen and Preferences dialogs
remain loud boundaries; the original score tables are nevertheless persistent.

## Maintained suite

Source `amiga/env.sh`, then run `make gameplay-regression`, or select a group
with `amiga/regression.sh GROUP`. Each case requires a specific success record,
rejects loud stops, and cannot pass merely because its time limit expired.

| Group | Scope |
|---|---|
| smoke | Production startup, intro skip/audio teardown, garage to live driving |
| courses | `GARAGE_COURSE=1..4`: finish handling, Score and garage return, including Course Four's three legs |
| vehicles | `GARAGE_CAR=1..4` and `GARAGE_OPPONENT=1..4`: selection and race lifecycle |
| difficulties | `GARAGE_DIFFICULTY=1..3`: lifecycle, damage thresholds and cruise behavior |
| recovery | Lake collision/tow, damage/repair, terminal damage and police penalties |
| routes | city → freeway activation, freeway movement and far freeway → city return |
| session | Pause/resume, garage/restart, quit and persistent scores |

Selection fixtures use ordinary mouse events. Route fixtures use normal KeyMap
input; far-end starts shorten already-decoded routes. Finish, damage, repair
and police fixtures place source-owned state at decoded checkpoints and then
run the original decision code. They prove those paths, not uninterrupted
end-to-end driving of every possible route.

Representative observers are `gameplay_smoke.gdb`,
`driving_course_lifecycle.gdb`, `driving_lake_static_collision.gdb`,
`driving_damage_repair.gdb`, `driving_terminal_tow.gdb`,
`driving_police_ticket.gdb`, `driving_freeway_activation.gdb`,
`driving_freeway_straight.gdb`, `driving_main_return.gdb`,
`driving_session_control.gdb` and `score_persistence.gdb`.
The script supplies each observer's build flags and success conditions.

## Additional checks

- `make driving-control-audit` checks input/configuration invariants; it is
  not a substitute for testing physical input. `driving_options_steering.gdb`
  exercises the original steering-mode shortcuts.
- `driving_tour_mode.gdb` checks Tour Mode relocation of the retained player.
- `garage_dyno.gdb` exercises Test, return to garage and the race lifecycle.
- `make frame-pacing-test` and `frame_pacing.gdb` cover the maximum-rate limiter.
- `make driving-audio-regression` covers three contexts and four Paula voices,
  cue overlap/replacement and countdown ordering. Bogas's used range 0..300
  maps to Paula 0..64.
- Palette, view and motion comparison targets use state-paired Macintosh
  captures. See [reference workflow](mac-reference-loop.md); local captures
  must be regenerated before claiming a new runtime result.
- `make fidelity-check` checks the available local reference fixtures and
  retained audits. Historical full-intro pixel comparisons are not a fresh
  production pass; their old software-cursor verifier has been retired.

`tools/check_gameplay_coverage.py` checks this document's observer names and
build switches. It checks documentation consistency, not gameplay execution.
