# Animation pacing on fast CPUs

The display already publishes planar buffers from VERTB, but a pending swap
causes `presentMacFrame` to return immediately. It does not stop the original
code from advancing multiple animation steps between fields. The port now
limits the following source-defined loops to one step per PAL field (50 Hz).

| Stream | Original Color CODE boundary | Why once per step |
| --- | --- | --- |
| Intro | Intro (8)+$0224, Button | Outer loop polls before visiting the four actor callbacks; returns through $020E after composition |
| Garage departure | Initialize (2)+$11AC, Button | After the complete car composite/copy, before the two-pixel move and branch back to $10AA |
| Garage Test | Initialize (2)+$0E86 or $0EAC, CopyBits | Mutually exclusive alternating car images; graph reveal at $0EF0 is not another frame |
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

Verified in FS-UAE with `--cpu=68040 --warp_mode=1`: intro 451 steps / 238 waits
in a 775-field snapshot; complete garage Test 1,320 steps / 1,319 waits and
departure 198 steps / 38 waits, followed by the opponent selector and driving.
A separate driving run reached 137 iterations with zero waits (rendering was
already slower than refresh). All recorded same-field violations were zero;
all runs retained running state 1, with no loud stop. The selector was exercised
for four steps per scripted traversal but was already slower than refresh, so
its waiting branch is covered by the shared limiter tests rather than claimed
as observed in that runtime fixture. The separate preview boundary is source-
verified and unit-tested, not reached by this scripted garage path.

At 50 steps/second the Test loop's 1,320 alternating car frames take at least
26.4 seconds. This follows its original roughly 22 car-image iterations per
graph increment; the graph copy itself does not incur an extra wait.
