#!/usr/bin/env python3
"""Fail closed if Vette's Amiga input compatibility surface drifts."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def require(path: str, fragments: list[str]) -> None:
    text = (ROOT / path).read_text()
    missing = [fragment for fragment in fragments if fragment not in text]
    if missing:
        details = ", ".join(repr(fragment) for fragment in missing)
        raise SystemExit(f"{path}: missing control invariant(s): {details}")
    print(f"control audit: {path}: {len(fragments)} invariants")


def main() -> None:
    require("src/mac/MacLoader.cpp", [
        "case 0x45: key = {0x35, 0x1b, 0x1b}; return true;",
        "case 0x4c: key = {0x7e, 0, 0}; return true;",
        "case 0x4d: key = {0x7d, 0, 0}; return true;",
        "case 0x4e: key = {0x7c, 0, 0}; return true;",
        "case 0x4f: key = {0x7b, 0, 0}; return true;",
        "case 0x4c: // cursor up -> I and keypad 8 (accelerate)",
        "setDrivingKeyState(0x22, down);",
        "setDrivingKeyState(0x5b, down);",
        "case 0x4d: // cursor down -> M and keypad 2 (brake)",
        "setDrivingKeyState(0x2e, down);",
        "setDrivingKeyState(0x54, down);",
        "case 0x4e: // cursor right -> L and keypad 6",
        "setDrivingKeyState(0x25, down);",
        "setDrivingKeyState(0x58, down);",
        "case 0x4f: // cursor left -> J and keypad 4",
        "setDrivingKeyState(0x26, down);",
        "setDrivingKeyState(0x56, down);",
        "write16(vette_code_1 + 0x2bcc, 0x302d);",
        "write16(vette_code_6 + 0x6d24, 0x4a2d);",
        "s_currentA5[kShadowMBState] = buttonDown ? 0x00 : 0x80;",
    ])
    require("src/platform/amiga/MacInput.cpp", [
        "vetteMacRawKeyChanged(raw, down);",
        "s_events[s_head].rawAndUp",
        "s_keyDown[raw] = down ? 1 : 0;",
        "AddICRVector(s_ciaaBase, CIAICRB_SP, &s_keyboardInterrupt)",
    ])
    launcher_invariants = [
        "--amiga_model=\"$MODEL\"",
        "--chip_memory=2048 --fast_memory=8192",
        "--joystick_port_0=mouse --joystick_port_1=nothing",
        "--full_keyboard=1",
        "--keyboard_key_up=action_key_cursor_up --keyboard_key_down=action_key_cursor_down",
        "--keyboard_key_left=action_key_cursor_left --keyboard_key_right=action_key_cursor_right",
    ]
    for launcher in ("amiga/run.sh", "amiga/debug.sh", "amiga/diag_run.sh"):
        require(launcher, launcher_invariants)
    for trace in (
        "amiga/driving_gear1_dispatch.gdb",
        "amiga/driving_accelerator_dispatch.gdb",
        "amiga/driving_drivetrain.gdb",
        "amiga/driving_mouse_control.gdb",
        "amiga/driving_mouse_button.gdb",
        "amiga/driving_p_key_dispatch.gdb",
        "amiga/driving_escape_transition.gdb",
        "amiga/menu_options_capture.gdb",
    ):
        if not (ROOT / trace).is_file():
            raise SystemExit(f"missing dynamic control trace: {trace}")
    print("control audit: dynamic original-handler trace set: 8 scripts")
    print("control audit: PASS")


if __name__ == "__main__":
    main()
