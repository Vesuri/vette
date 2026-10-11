# Repository guidance

Vette! is a working single-player Amiga port of **Color VETTE! 1.02**.
Read [README.md](README.md) and [docs/development.md](docs/development.md) for the
current build and test workflow. Keep unresolved work in
[docs/open-work.md](docs/open-work.md), technical facts in the relevant reference
document, and completed investigations in Git history.

## Shared environment and knowledge

The toolchain, emulators, Kickstarts, WHDLoad and the Python environment come from AmigaXDev
(`make setup` there); `amiga/env.sh` sources `~/.local/share/amiga/env.sh`. Lessons that hold
for any port live in AmigaXDev's docs: add or correct them there, and keep only what is
specific to this game in `docs/`.

| AmigaXDev doc | For |
| --- | --- |
| `docs/environment.md` | the shared variables and installed files |
| `docs/playbooks/new-port-playbook.md` | the phases of a port and their gates |
| `docs/reference/amiga-hardware.md` | Chip bus, takeover, interrupts, copper, blitter, Paula, AGA, the dA JoRMaS framework |
| `docs/reference/m68k-optimisation.md` | 68000/68020 cost model and code generation |
| `docs/reference/measurement-method.md` | profiling instruments, A/B discipline, pricing a change |
| `docs/reference/validation-harness.md` | faithfulness to the original: references, differentials, sabotage |
| `docs/reference/headless-fsuae.md` | the shared launcher, FS-UAE builds, gdb stub, diag runs |
| `docs/reference/port-toolchain.md` | flags, linking, link audits, WHDLoad slaves, release archives |
| `docs/native-port-validation.md` | crash dumps as regressions, installer updates, release archive checks |

## Scope and correctness

- Preserve original game decisions. Implement their documented services; do not
  replace decisions with screen-specific guesses. Measured renderer-kernel
  replacements require original-byte guards and memory/register/CCR differential
  verification. See [performance.md](docs/performance.md) for copy-row and geometry kernels.
- Attribute code addresses as **(segment, offset)** in the Color build; offsets
  include the four-byte segment header. B&W CODE is a different program.
- Original Macintosh execution is the fidelity reference. State-pair captures;
  different CPU speeds need not display identical intermediate frames.
- Preserve every live register and condition code at binary hooks. Check original
  bytes before patching. Never map Mac Page 0 over Amiga vectors/Exec state.
- Unknown calls remain named loud stops. Do not add optional dialogs to hide an
  allocator or another subsystem failure. Communications is out of scope.
- Copy-protection bypass, native presentation/input and maximum-rate pacing are
  intentional port behavior. See [architecture](docs/amiga-arch.md).

## Build and hardware

- Source `amiga/env.sh` in the same shell as builds/runs. Clean before changing
  build flags or widely included headers; HIRES is tracked automatically.
- Preserve the software mul/div and probe-symbol link audits. Use
  `src/m68k_math.h` for suitable 16-bit arithmetic.
- `VetteScreen` owns display registers. Publish complete copper lists and
  bitplane/sprite pointers first in VBI, before input or audio work.
- Keep explicit dirty rectangles; no shadow framebuffer or tile-diff machinery.
- Do not dispatch original game callbacks from an Amiga interrupt. The VBI updates
  time/input/Paula; Mac callbacks run at safe user-mode return points.
- Every debugger-read global must be in `PROBE_SYMS`; garbage-collected symbols
  can otherwise resolve into instruction bytes.
- Check timing in emulated fields/ticks, not host wall time or screenshots.
  Warp is useful for bounded regression runs, not a real-time speed measurement
  (AmigaXDev `docs/reference/measurement-method.md`).

## Local inputs and tools

- Never commit original game files, resource forks, generated disassembly,
  screenshots, audio captures, ROMs or emulator state. `tmp/` and `ref/` are
  local-only and can contain irreplaceable inputs; inspect before cleaning.
  Build outputs and release archives are ignored.
- Never kill all FS-UAE or GDB processes. Use the scripts' PID-scoped cleanup.
  The shared helper is selected by `FSUAE_COMMON`; projects share the host
  (AmigaXDev `docs/reference/headless-fsuae.md`).
- MAME must use the documented headless command, including
  `SDL_VIDEODRIVER=dummy`, `-window`, `-cfg_directory` and `-nvram_directory`.
- Keep maintained regression scripts, reusable format tools and concise current
  docs. One-off captures and diagnostics belong in `tmp/`, not the tracked tree.
- Source/resource names and decoded fields live in `disasm/symbols.csv`,
  `ghidra_scripts/entrypoints.csv` and the format documentation. Mark inference
  explicitly rather than treating a plausible name as a measured fact.
- The Mac helpers (`python3 -m amigaxdev.mac.*`: `hfs_extract`, `resource_fork`, `macbin`,
  `gen_trap_names`, `m68k_sweep`), the release archive code (`amigaxdev.release`), the smoke
  slave and the Ghidra scripts (`MacMarkEntries`, `MacApplyNames`, `MacDumpTraps`,
  `DumpCallGraph`, `ExportListing`) are AmigaXDev's. Run Ghidra headless from the project root
  with `-scriptPath "$AMIGA_GHIDRA_SCRIPTS"`; `ghidra_scripts/` keeps only `entrypoints.csv`.

## Changes

- Commit directly to `main`, one verified cohesive change per commit.
- Preserve unrelated worktree edits. Do not add hooks, signing or coauthor lines.
  Use the existing Vesuri identity and repository-local Git configuration.
- Validate in proportion to the change: host checks for pure helpers; original
  byte checks and bounded Amiga runs for runtime changes; archive audit and
  native Installer tests for release/installation changes.
- Keep documentation current and concise. Historical experiments and removed
  development stages can be recovered from Git history.
