# Animation pacing on fast CPUs

The display already publishes planar buffers from VERTB, but a pending swap
causes `presentMacFrame` to return immediately. It does not stop the original
code from advancing multiple animation steps between fields. The port now
limits the following source-defined loops to one step per PAL field (50 Hz).

| Stream | Original Color CODE boundary | Why once per step |
| --- | --- | --- |
| Intro | Intro (8)+$0224, Button | Outer loop polls before visiting the four actor callbacks; returns through $020E after composition |
| Garage departure | Initialize (2)+$11AC, Button | After the complete car composite/copy, before the two-pixel move and branch back to $10AA |
| Garage Test | Initialize (2)+$0EF0, after CopyBits | Completed curve increment, after the repeated car-image copies at $0E86/$0EAC |
| Opponent | Initialize (2)+$1A34, CopyBits | Final screen copy after one angle increment, background restoration and 3D draw; background copy at $1A0E is not paced |
| Separate model preview | Main (1)+$1AB8, Button | End of the model-preview loop, before its back edge to $19C4 |
| Driving | Main (1)+$1FD2, existing private hook | One full driving iteration, only while the original driving predicate is true |

These are trap-caller checks, not generic delays in QuickDraw or input polling.
No extra original instructions are patched. Each stream remembers the last
16-bit `g_vbiCount` it consumed. First use proceeds immediately; another step
in the same field waits for VERTB. If drawing already crossed a field boundary,
there is no added wait or attempt to catch up missed frames. Counter wrap is
handled by equality rather than ordered comparisons. The rate is per interlaced
field, not per two-field image.

Waits run at the existing Line-A boundary with interrupts enabled. They neither
use AmigaOS WaitTOF (the OS VBI chain is detached during play) nor recursively
invoke Macintosh callbacks. The hardware pointer, tick clock and Paula service
continue in interrupts. Original physics formulas, audio deadlines and actor
timers are unchanged; this is an intentional Amiga-only maximum-rate policy,
not a claim that all original machines animated at 50 steps/second. Warp mode
still accelerates emulated time, including VERTB.

`make frame-pacing-test` checks first use, fast/slow frames, counter wrap,
independent streams, all selected callers and important excluded partial draws.
`amiga/frame_pacing.gdb` reports steps/waits/same-field violations and stops early
on a loud stop. Build normally for intro; add `SKIP_INTRO=1 GARAGE_CLICK=1
GARAGE_DYNO=1 GARAGE_DEPARTURE_FULL=1` for the scripted test/departure/selector/
driving sequence. Use `PROBES=1` for both runtime diagnostic builds.

The TEST loop alternates the car image 22 times per curve increment. Waiting
on each car copy stretched its 59-increment curve reveal to over 26 seconds.
Only the completed curve copy now consumes a pacing step; the repeated car
copies remain untouched and incur no wait. Garage departure still waits at
its complete car-composite boundary.

`amiga/garage_pacing.gdb` checks the full scripted TEST/departure path with the
same diagnostic flags. In FS-UAE (`--cpu=68040 --warp_mode=1`), TEST completed
in 107 PAL fields (2.14 seconds), with 59 pacing steps, no added waits and no
same-field violations. Departure retained 198 steps, including 74 waits, and
the fixture reached four driving iterations without a loud stop. Timing is for
the diagnostic build; the limiter still caps faster execution at one completed
curve increment per field.
