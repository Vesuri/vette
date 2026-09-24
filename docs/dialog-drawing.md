# Dialog drawing compatibility

`DrawDialog` draws dialog items; it is not a whole-window erase. See Apple's
[Inside Macintosh description](https://dev.os9.ca/techpubs/mac/Toolbox/Toolbox-429.html).
The compatibility handler retains item-list validation and bookkeeping but
must not clear the screen. Text/control item rendering remains incomplete;
this change does not implement the optional Macintosh dialogs.

DLOG 900 and 910 share DITL 900, containing only a null application-defined
item. DLOG/DITL 600 (About/model preview) has the same empty-item structure.
The original caller draws their content separately. No blanket no-op replaces
the trap, and no original game instructions are changed.

The water recovery previously cleared global bounds (50,23)-(462,319), while
its picture drew at local (5,5)-(407,291) in the port's screen buffer. C2P
rounded the latter's right edge to 416, exposing the cleared area at
(407,23), size 9x268. Removing the unjustified clear preserves those pixels
without changing picture placement or C2P alignment. General window-local
QuickDraw coordinate translation is not implemented by this fix.

## Original caller audit

All 21 decoded Color CODE call sites below were checked against original
`A981` bytes. Offsets include the four-byte segment header. The audit is
static; it does not claim runtime coverage of unsupported dialogs.

| Segment | DrawDialog offset → DLOG resource |
| --- | --- |
| Main (1) | $0766 → 920 (bypassed copy protection) |
| Main (1) | $09F0 → 505; $0A42 → 503; $0B32 → 504; $0C1E → 521; $0C64 → 519 |
| Main (1) | $0D0E/$0DB8 → 509; $0E62 → 506; $0EB6 → 150; $0EF6 → 159 |
| Main (1) | $0FC8 → caller-supplied D6 (recovery picture wrapper) |
| Main (1) | $1262 → 128; $167E → 999 (Teleport); $1852 → 600 |
| Initialize (2) | $1AC6 → 700 (error dialog) |
| Communication (3) | $0522 → A5-$78AC (unsupported multiplayer) |
| Load (4) | $006C → 151 |
| Score (5) | $034C → 140; $05DA → 800; $0C94 → 1111 |

None requires a whole-window erase from `DrawDialog`. Real text, controls,
or installed user-item draw procedures need their own implementation rather
than the former background-fill substitute.

## Regression

Build with `PROBES=1 HIRES=1 SKIP_INTRO=1 GARAGE_CLICK=1` and run
`GDBSCRIPT=recovery_background.gdb amiga/diag_run.sh 55` with warp enabled.
Then run `python3 tools/check_recovery_background.py amiga/.run`. Captures
remain local. The check compares the complete chunky buffer across DrawDialog
and checks every pixel outside the recovery picture after DrawPicture.
