# The Macintosh reference loop — ground truth

> **Read this before trusting any claim about what the original does, and before writing the first
> line of the trap layer.** ⚑ The rule it exists to serve is inherited and non-negotiable:
> **ground truth is the original on an emulator of the original machine, NEVER the dev-host
> backend and NEVER the Amiga build.** Both prior ports paid for the alternative.
>
> ⚠⚠ **THIS FILE IS A PLAN. Nothing in it is built.** Standing it up is Phase 1 and it gates
> Phase 2 (see `docs/phases.md`).

## Why this loop matters MORE here than in either prior port

- ⚠⚠ **CORRECTED — the performance-reference argument does NOT survive the build choice.** This
  bullet used to read: *"the Mac Plus is a 7.83 MHz 68000 and the A500 is 7.09 MHz, so the same
  instructions ran ~12% faster on the original machine"*, making a large Amiga shortfall diagnosable
  — a lever neither prior port had. **That reasoning applies to the B&W build only.** The port
  follows `Color VETTE!`, which needs Color QuickDraw, which `[INFERRED]` means a **Mac II-class
  machine: a 16 MHz 68020 on a 32-bit bus**. That is a different class of machine from an A500, so
  **the Color build's framerate is not an A500 yardstick and must never be quoted as one.**
  ⭐ The lever is recoverable but costs a second machine, because the two builds share
  byte-identical data and the same 11 named segments: run **B&W on an accurate Mac Plus for timing**
  and **Color on a Mac II for pixels and traps**. ⚠ Deferred by decision — behaviour first; revisit
  only if an Amiga shortfall actually needs diagnosing (`docs/open-work.md`). Until then this
  project has **no** performance reference, which is the same position both prior ports were in.
- **The trap surface is an inventory we cannot close statically.** Revs's MOS layer was proven a
  *floor* by running it — three calls were found that way. A Mac game's surface is an order of
  magnitude larger, so "run it and watch what it asks for" is not a nice-to-have, it is how the
  inventory gets finished.
- **The display is 1-bit 512×342 and the Amiga's is planar.** Every "is this drift a bug or
  faithful?" question about a pixel needs a reference frame to diff against. Revs's `make viewdiff`
  (every circuit's race view against a real BBC, byte for byte) was the single most useful gate it
  built; the equivalent here is a framebuffer diff against the emulator.

## What the loop must be able to do

Ranked by how much each capability bought in the prior ports. **A candidate emulator should be
judged against this list, not against its accuracy reputation alone.**

1. **Run headless and scripted**, so a capture is a `make` target and not a person driving a GUI.
   (Revs: `make refloop`, `make viewdiff`, `make mode7`.)
2. **Dump the framebuffer at a named moment** — the visual ground truth. A frame *number* is not
   enough; "at this PC" is what turns a pixel diff into a cause.
3. **Breakpoints + register reads + single step.** This is what makes a trap inventory possible:
   break on the trap dispatcher, read the trap word and the register arguments, log, continue.
4. **Memory peek/poke over a scriptable interface**, for reading A5 globals and the heap.
5. **Attribute a store to the PC that made it** (a watchpoint). Revs's `make fbwrites` settled what
   several unidentified routines actually drew; it is the instrument that replaces frame-staring.
6. **Deterministic replay** of a scripted input sequence, so two captures are comparable.
7. **Cycle counts**, ideally. Nice to have; the Amiga side is where performance is measured.

⚠ **Item 3 is the one to check hardest**, because it is the capability emulators most often expose
only in a GUI. Revs's postmortem chose jsbeeb over b2 largely on this: b2's HTTP API had
peek/poke/reset/run/mount/paste but breakpoints and registers appeared GUI-only.

## ⛔ The dependency that gates every candidate: ROMs and system software

⚠⚠ **No emulator here can be evaluated end to end without them, and this repo cannot contain them.**
Every candidate needs:

1. **A ROM image for the emulated machine** — a Mac II-class ROM for the Color build (`macii`,
   `mac2fdhd`, Basilisk II) or a Quadra 800 ROM for QEMU's `q800`. ⚠ QEMU's `q800` can boot Linux
   with `-kernel` and no ROM, so *a working `q800`* is **not** evidence it will boot Mac OS.
2. **A System install** — System 6.0.x or 7.x, on a disk image the emulator can mount.
3. **A volume with the game installed and PAST the password**, because the shipped build asks once on
   first run (`readme.txt`). A throwaway image re-asks every time, which is exactly where ground
   truth needs to be cheap.

### ⭐⭐ Which ROM and which System — decided, with the MAME romset names

⚠ MAME names Mac ROM files by the **Apple ROM checksum** (the longword at offset 0), which is the
same convention the common ROM collections use — so a file called `97221136 … .ROM` is literally the
`97221136.rom` MAME asks for. ⚠ But MAME verifies the **CRC32**, which is a *different* number; the
table gives both so a wrong dump variant is caught rather than assumed.

| role | file (Apple checksum) | MAME romset / driver | CRC32 MAME requires |
|---|---|---|---|
| ⭐ **primary** | `97221136` — Mac II FDHD & IIx & IIcx, 256 KB | `mac2fdhd`, and the **same file** also serves `maciix` and `macse30` | `ce3b966f` |
| ⚠ **also required** — the Mac II has **no built-in video** | Apple Macintosh Display Card 4/8, `3410801.bin`, 32 KB | romset `nb_mdc48`, selected with **`-nb9 mdc48`** | `e283da91` |
| ⚠ **also required** — alternative to the row above, and what the **default** slot config wants | Apple Macintosh Display Card 8/24, `3410868.bin`, 32 KB | romset `nb_mdc824`, the stock `-nb9` | `57f925fa` |
| ⛔ **also required, unavoidable** — a fixed device, not a slot card | ADB modem MCU, `342s0440-b.bin`, 1 KB | romset `adbmodem`; required by **every** Mac II-class driver (`macii`, `maciix`, `macse30`, `maciici`, …) | `cffb33eb` |
| second choice, more period-pure | `9779D2C4` (800K v2) or `97851DB6` (800K v1) | `macii` / `maciihmu` | `4df6d054` / `8c8b9d03` |
| QEMU fallback | `F1ACAD13` — Quadra 610/650/800 | `q800` | — |
| deferred B&W timing ref | `4D1F8172` — MacPlus v3 | `macplus` ⚠ wants **chip-level** dumps (`342-0341-c.u6d` + `342-0342-b.u8d`, 64 KB each, byte-interleaved), so a single 128 KB file must be split into even/odd bytes. `[ASSUMED]` interleave order — verify with `-verifyroms` | `f69697e6` / `49f25913` |

### Where the ROM lives, and what is still missing

⭐ **The primary ROM is in place:** `ref/mame/roms/mac2fdhd/97221136.rom`, 262 144 B, CRC32
`ce3b966f` — MAME's requirement exactly. ⚠⚠ **`/ref/` is gitignored as a whole** (not just `*.rom`):
it is the reference loop's local-only tree — ROMs, System/game disk images, MAME `cfg`/`nvram`,
savestates, captures. Nothing under it may ever be committed. Invoke with:

```
mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 …          # + the headless flags below
mame mac2fdhd -rompath ref/mame/roms -verifyroms           # what is still missing
```

⛔ **The machine will NOT run yet**, and `-verifyroms` says why: the main ROM passes, but MAME wants
two more files, both of them *device* ROMs rather than Mac ROMs, so a Mac-ROM collection does not
contain them — they live in a MAME romset (`adbmodem.zip`, `nb_mdc48.zip` / `nb_mdc824.zip`):

| file | size | CRC32 | romset | needed because |
|---|---|---|---|---|
| `342s0440-b.bin` | 1 024 | `cffb33eb` | `adbmodem` | fixed device in every Mac II-class driver — no way to configure it away |
| `3410801.bin` | 32 768 | `e283da91` | `nb_mdc48` | the video card, with `-nb9 mdc48` (the 4bpp match) |
| `3410868.bin` | 32 768 | `57f925fa` | `nb_mdc824` | the video card, if the **default** slot config is left alone instead |

⚠ Only **one** of the two card ROMs is needed — whichever matches the `-nb9` in use. Until both the
ADB ROM and one card ROM are present, MAME ends in *"Required files are missing, the machine cannot
be run."* → `docs/open-work.md` #1.

**Why `mac2fdhd` and not the others:**
- **68020.** It is the CPU class the Color build was written for. `maciix` and `macse30` are 68030 —
  one step further from the original, and under **option A the original bytes must execute**, so CPU
  class is not a cosmetic choice.
- ⭐ **One file, three drivers.** Every Mac II-class driver here is flagged `imperfect` (only
  `macplus` is `good`), so having `maciix` and `macse30` available as fallbacks *without sourcing
  another ROM* is worth real time.
- **FDHD = SuperDrive = 1.4 MB floppy images.** The 800K-ROM `macii` caps images at 800 KB, which is
  awkward for an app plus a 577 KB data file.
- ⭐ **`mdc48` fits the evidence:** the 4/8 card does **4bpp**, which is exactly the 16 colours the
  eight `pltt` resources imply (`docs/source-inventory.md`).

### ⭐⭐ The ROM side is CLOSED — `mac2fdhd` runs headlessly and asks for a boot disk

`ref/mame/roms/` now holds all four files MAME wants, all four CRC32s matching:

| file | romset dir | size | CRC32 |
|---|---|---|---|
| `97221136.rom` | `mac2fdhd/` | 262 144 | `ce3b966f` |
| `3410801.bin` | `nb_mdc48/` | 32 768 | `e283da91` |
| `3410868.bin` | `nb_mdc824/` | 32 768 | `57f925fa` |
| `342s0440-b.bin` | `adbmodem/` | 1 024 | `cffb33eb` |

`mame mac2fdhd -rompath ref/mame/roms -verifyroms` → **"romset mac2fdhd is good"**.
⚠ `-verifyroms` rejects `-nb9` ("unknown option"), so the card choice can only be verified by
running; the stock `mdc824` is what `-verifyroms` checks.

**What a run proves so far** (`-nb9 mdc48`, 27 s emulated, ~1 050% of real time): the ROM starts,
initialises the display card at **640×480**, draws the desktop grey pattern and the arrow cursor,
and by ~25 s in shows the **blinking floppy icon** — i.e. it is hunting for a boot device and
finding none. ⭐ Everything *below* the System is therefore working; capability **0b** is down to
the System install alone.

```
timeout -k 5 180 env SDL_VIDEODRIVER=dummy \
  mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
    -video none -sound none -window -skip_gameinfo -nothrottle \
    -seconds_to_run 27 -snapshot_directory ref/mame/snap \
    -autoboot_script tools/mame_snap.lua
```

⚠ **MAME writes no screenshot when `-seconds_to_run` expires**, so a headless run that is meant to
prove something needs `tools/mame_snap.lua` (`VETTE_SNAP_FRAMES=900,1500`, frame counts in
*emulated* 60 Hz fields — reproducible across host speeds, same reasoning as FS-UAE's warp mode).
Captures land in `ref/mame/snap/<machine>/` and are gitignored with the rest of `/ref/`.

### ⭐⭐ The System side is CLOSED TOO — a 6.0.8 volume boots and carries the game

Sourced from savagetaylor.com (all under the gitignored `/ref/`, originals kept in `ref/mame/dl/`):

| what | file | where it goes | verified |
|---|---|---|---|
| bootable 6.0.8 **hard drive** (driver + partition map) | `608_2GB_drive.zip` → `ref/mame/hd/608_2GB_drive.hd` | `-hard` | ⭐ boots to the Finder, volume `6.0.8 2GB (D)` |
| bootable 6.0.8 **floppy**, 1.4 MB | `OS_608_boot.dsk.zip` → `ref/mame/flop/OS_608_boot.dsk` | `-flop1` | ⭐ boots to the Finder ⚠ Finder offers *"needs minor repairs"* on mount — cosmetic, but it is a modal dialog in the way of an unattended capture |
| ResEdit 2.1.3 | `ResEdit_2.1.3.sea.bin` | not installed yet | — |

⚠⚠ **The drive image must be renamed `.dsk` → `.hd`**; MAME's `-hard` does not accept either
extension the download ships with. Its partition map is `Apple_partition_map` (block 1),
`Apple_Driver43` (64), `Apple_HFS` (96, 3 850 144 blocks) — which is why it boots where a bare
volume does not. The volume also already carries **HD SC Setup 7.3.5 (Patched)** and Disk Copy 4.2.

⭐⭐ **MacsBug 6.2.2 is installed on that volume and VERIFIED INSTALLED, not merely present.**
`MacsBug` + `Debugger Prefs` were copied into the `System 6.0.8` folder (`dbgr/mxbg`, 97 266 B data
+ 15 954 B rsrc). The check, because "the file is in the System Folder" proves nothing about
whether the System hooked it:

| boot volume | `MacJmp` (`$0120`) read from the emulator after boot | reading |
|---|---|---|
| the hard disk, with MacsBug | **`701E9A6E`** — flag bits in the high byte, code-looking bytes at `$1E9A6E` | ⭐ a debugger is installed and hooked |
| ⭐ **the boot floppy, WITHOUT MacsBug (the control)** | **`00000000`** | no debugger |

⭐ **That is a real differential, not a single reading** — `docs/method-lessons.md`'s rule is that a
control which is not the old state measures the test rather than the change, and the MacsBug-less
floppy is exactly that control. The probe is 6 lines of Lua reading `$0120` through
`manager.machine.devices[":maincpu"].spaces["program"]`, which is also the pattern every later
memory-level ground-truth probe should use.

⚠ Not yet done: **entering** MacsBug (it needs an interrupt/programmer's-switch, so it is an input
question, not an installation one) and logging A-traps from it.

### ⭐⭐ Putting files on the volume from the HOST — `hfsutils`, no floppy shuffling

`brew install hfsutils`. ⭐ **The host can write the booted volume directly, forks and all**, and the
volume still boots afterwards (verified). This is the cheap path and it removes the transfer problem
from the reference loop entirely:

```
hmount ref/mame/hd/608_2GB_drive.hd 1     # ⚠ hfsutils counts HFS PARTITIONS, not map entries:
                                          #    the Apple_HFS partition is map entry 3 but "1" here
hmkdir "Color VETTE!" ; hcd "Color VETTE!"
hcopy -m tmp/macbin/'Color_VETTE!.bin' ":Color VETTE!"   # -m = MacBinary: keeps BOTH forks
hcopy -m tmp/macbin/'VETTE!.Data.bin'  ":VETTE!.Data"    #      and the type/creator
humount
```

⚠⚠ **`hcopy -m` takes MacBinary, and nothing on a modern macOS produces it.** `tools/macbin.py`
does: it wraps a forked host file (as `unar` unpacks one — resource fork as a named fork,
type/creator in `com.apple.FinderInfo`) into MacBinary II. It **refuses** to write a MacBinary with
an empty resource fork for an `APPL`/`dbgr`/`DATA` file, because that silent loss produces a file
that exists, looks right and cannot be launched. ⚠ `os.getxattr` is **Linux-only** — on macOS read
`<path>/..namedfork/rsrc` and shell out to `xattr -px`.

```
python3 tools/macbin.py "tmp/macsbug/MacsBug 6.2.2/MacsBug" tmp/macbin/
hcopy -m tmp/macbin/MacsBug ":MacsBug"
```

The game volume itself mounts with plain `hmount tmp/VETTE_1_02.raw` (a bare HFS volume needs no
partition argument), and `hcopy -m` out of it is how the MacBinary files above were made.
⚠ **Its folder names literally begin `"(Folder) "`** — `(Folder) Color VETTE!`, `(Folder) B&W
VETTE!` — so `hcd "Color VETTE!"` fails. Not a display artefact of `hls`.

⚠⚠ **CORRECTION to a size claimed earlier in this doc and in `docs/open-work.md`:** the application
is **1 587 389 B, ALL of it resource fork** (data fork 0), and `VETTE!.Data` is **577 498 B, also
all resource fork**. The "~86 KB" figure is the 11 `CODE` segments alone — a small fraction of the
resource fork, which also carries the `PICT`s, `pltt`s and everything else. App + data = **2.16 MB,
so they do NOT fit on one 1.4 MB floppy**; the `hfsutils` path above is not merely more convenient,
it is what makes the transfer a single step.

### ⭐ What form the System install has to arrive in

Verified from `mame mac2fdhd -listmedia` / `-listxml`: the machine has **two 35hd Superdrives**
(`flop1`/`flop2`, 1.4 MB), a **SCSI hard disk at id 0 by default** (`-hard`), and a CD-ROM at
scsi:3. Accepted extensions differ per medium and that is a real trap:

| medium | extensions MAME accepts | note |
|---|---|---|
| `flop1`/`flop2` | `.dc42`, `.img`, `.dsk`, `.ima`, `.woz`, … | ⭐ Disk Copy 4.2 (`.dc42`) is the format period images ship in |
| `hard` | `.chd`, `.hd`, `.hdv`, `.2mg`, `.hdi` | ⚠⚠ **`.img` is NOT accepted here** — a raw hard-disk image must be renamed `.hd`/`.hdv`, or converted with `chdman` (⚠ not installed on this host) |

⚠⚠ **A bootable SCSI image needs an Apple Partition Map and an HFS driver partition, not just a
bare HFS volume.** The ROM's SCSI boot walks the partition map; a bare volume (what
`tools/ndif2raw.py` produces — `tmp/VETTE_1_02.raw` is an 8 MB bare HFS volume) will not boot and
will not even mount. Building one from scratch means HD SC Setup patched for a non-Apple drive,
which is GUI work best avoided.

So, in preference order:

1. ⭐⭐ **A pre-made bootable System 6.0.8 hard-disk image**, partition-mapped, 40-160 MB. One file,
   zero setup, and it is the only option that gives a *persistent* volume — which item 3 above
   (a game install past the password) requires.
2. ⭐ **A bootable System 6.0.8 "System Tools" floppy image** (`.dc42`, 800 KB). Useful *regardless*
   of #1: it boots with no hard disk at all, which makes it the cheapest possible first proof that
   the ROM and the video card work, and it doubles as a rescue disk.
3. The full 6.0.8 **install disk set** with no pre-made HD — workable but the expensive path, because
   it means formatting a blank SCSI volume first (see the partition-map warning above).

⭐ **Getting the game onto the volume is ours to solve, not a thing to source.** `Color VETTE!`
(~86 KB) plus `VETTE!.Data` (577 KB) fit on one 1.4 MB Superdrive image, which we can build with
`hfsutils` from the already-extracted volume and hand to `flop1`.

⚠ Useful extras, if they happen to be to hand — both are just files to drop into the System Folder,
not installs: **MacsBug 6.2.x** (the A-trap log for capability 3) and **ResEdit 2.1.3**.

**System 6.0.8** — and the reason is this project's, not nostalgia:

1. ⭐⭐ **The trap inventory is only as clean as the system that patches the traps.** System 6 with
   plain Finder (MultiFinder **off**) sits close to bare ROM. System 7 always runs the Process
   Manager, patches far more of the trap table and layers 32-Bit QuickDraw over Color QuickDraw —
   all of it noise in an A-trap log, exactly where capability 3 needs signal.
2. **Period-correct.** VETTE! 1.02 is 1989; System 7 is 1991.
3. **Cheap and deterministic.** Boots fast, small RAM and disk, one application, no background
   processes competing for events or time — a reference capture must be cheap to repeat.

⚠ **Fallback: System 7.1**, if debugger tooling forces it or a 6.0.8 volume proves awkward to set up
past the password. Accept the noisier trap surface knowingly. Avoid 7.5+ (heavier again) and 6.0.x
below 6.0.4 (Mac II/FDHD support).
⚠ `[ASSUMED]`, to verify rather than trust: that **MacsBug 6.2.x** is the right build for System 6
(6.6.x expects System 7), and the `-ramsize` option's accepted values for these drivers.
⭐ Apple released System 6.0.8 and 7.5.3 free, so the System side is legitimately sourceable; the
ROMs are the user's own to supply.

⭐ The tool-level capabilities **can** be evaluated without any of this (does the driver exist, does
the Lua API expose watchpoints, does the gdb stub attach, does `screendump` work), and that is what
the evaluation below does first. ⚠ Keep the two apart in the write-up: *"MAME exposes watchpoints"*
and *"MAME boots this game"* are different claims, and only the first is cheap.

## ⭐ The evaluation — a checklist, run against both, recorded as a measurement

Decided: **install both MAME and QEMU and choose on evidence**, not on preference. Fill this in as it
is run; an empty cell is an unanswered question, not a pass.

Installed and evaluated: **MAME 0.289** and **QEMU 11.1.1** (both `brew install`). ⚠ Every row below
is a *tool-level* result — see §0b for the one thing neither can do yet.

| # | Capability | MAME 0.289 | QEMU 11.1.1 |
|---|---|---|---|
| 0a | the machine exists | ✅ **both target classes in one tool**: `macii`, `mac2fdhd`, `maciix`, `maciici`, … **and** `macplus` (plus Quadra 605-800) | ⚠ `q800` only — Quadra 800, 68040 |
| 0b | ⛔ boots a real System **and the game** | **BLOCKED — ROMs + System, see above** | **BLOCKED — same** |
| 1 | headless + scripted | ✅ verified end to end, exit 0, no window, 71 154% speed (`apexc`) — ⚠ recipe below, it is not just `-video none` | ✅ `-display none -qmp stdio -S` |
| 2 | framebuffer dump at a named moment | ✅ `machine.video:snapshot()` **called successfully**; `emu.add_machine_frame_notifier` present, so "at this PC" = snapshot from a breakpoint callback | ✅ QMP `screendump` (also `human-monitor-command`) |
| 3 | ⭐⭐ breakpoints + registers + step | ✅ `debugger:command("bpset …")` **ACCEPTED**; `cpu.state["PC"].value` **read a register**; needs `-debug`, and `-debugger none` keeps it headless | ✅ gdb stub **attached and read `pc`/`sr`/`d0`** (⚠ `a7` is spelled `sp`; gdb warns *"Architecture rejected target-supplied description"* and works anyway) |
| 4 | scriptable memory peek/poke | ✅ `cpu.spaces["program"]:read_u8()` **returned a value** | ✅ gdb `x`, plus QMP `pmemsave`/`memsave` |
| 5 | ⭐ watchpoint attributing a store to its PC | ✅ `debugger:command("wpset 0,1,w")` **ACCEPTED** | ⚠ gdb watchpoints expected but **not tested** |
| 6 | deterministic scripted input | ⚠ `machine.ioport` and save states present, **injection not tested** | ⚠ would need QMP input events, **not tested** |
| 7 | cycle counts | ⚠ available via the debugger, **not tested** | ⛔ no |

⭐⭐ **Unexpected finding, and it changes the trade-off: MAME has a gdb stub that speaks m68k.**
`-debugger gdbstub` with `-debugger_host`/`-debugger_port`, and the binary carries
`org.gnu.gdb.m68k.core` among its target descriptions. So the "QEMU gives us the `amiga/debug.sh`
idiom" argument is **not exclusive to QEMU** — MAME can offer the same gdb-driven workflow *and* the
right machine class. ⚠ `[DERIVED]` from the target-description strings and the option surface, **not
from a live 68k attach** — that needs the ROMs. Test it before depending on it.

### ⚠⚠ Running MAME headlessly — four things that cost real time here

**`-video none` is NOT enough. On macOS it still opens a FULLSCREEN window** (defaults are
`window 0`, `video auto`), which hijacks the user's screen. The verified recipe:

```
timeout -k 5 60 env SDL_VIDEODRIVER=dummy \
  mame <system> -video none -sound none -window -skip_gameinfo \
               -seconds_to_run <n> -nothrottle -autoboot_script <script.lua>
```

- **`SDL_VIDEODRIVER=dummy` is the part that actually prevents a window.** `-window` is a belt-and-braces
  fallback so that anything that does appear is not fullscreen.
- **`-skip_gameinfo`, always.** The game-info screen waits for a keypress that never comes headless,
  and the symptom is a black window and an infinite hang — indistinguishable from a wedged emulator.
- **`-seconds_to_run` cannot fire on a machine with no CPU.** `___empty` hangs forever for exactly
  this reason, which makes it the wrong vehicle for an API check. ⭐ **`apexc` is ROM-free, has a CPU
  and needs no media** — use it for tool-level checks. (`a2600` demands a cartridge; `vgmplay`,
  `alto2`, `705*prg` all need ROMs.)
- **Wrap every run in an external `timeout`**, and ⚠⚠ **kill only the pid you started** — the
  `pkill` prohibition in CLAUDE.md applies here for the same reason it applies to FS-UAE.

⭐⭐ **Check `MacsBug` inside the guest as a separate instrument, whichever emulator wins.** Its
`atb`/`atr` commands break on and *record* A-line traps by name — item 3, purpose-built for the one
inventory this project most needs, and independent of the host emulator's own debugger. If it works,
the emulator's debugger matters mainly for items 2 and 5.

## Candidates — the shortlist the evaluation runs against

⚠ Listed with what to check, so the evaluation is a measurement and not a preference. **The Color
build needs Color QuickDraw, so a Mac Plus-only emulator cannot run the ported build at all** — that
demotes Mini vMac and PCE from oracle to (potential) timing reference.

| Candidate | Machine | Why it might be the oracle | What to verify first |
|---|---|---|---|
| **MAME** (`macplus`, `macse`, …) | the real target | Full Lua-scriptable debugger with breakpoints, registers, single-step and watchpoints, and genuinely headless (`-video none`). This is the shape of instrument the capability list above describes, and Revs kept MAME "in reserve" only because its BBC accuracy was less trusted than the dedicated emulators. **For the Mac there is no comparably-accurate dedicated emulator with a scripting surface**, which inverts that reasoning. | That the Mac drivers boot a real System + the game at all; the Lua API's watchpoint and framebuffer-dump surface |
| **Mini vMac** | Mac Plus, very accurate | The closest thing to a "dedicated, trusted" emulator for this exact machine, and it has a debug/`dbglog` build | ⛔ **Cannot run the Color build** (no Color QuickDraw on a Plus). Retained only as a possible B&W timing reference, and even there: whether scripted breakpoints/registers exist outside the GUI |
| **PCE** (`macplus`) | Mac Plus, cycle-level | ⭐ A scriptable monitor **and** trustworthy timing — the best available answer to "what framerate did the original get?" | ⛔ Same: B&W build only. This is the candidate to reach for **if** the deferred timing reference is ever built |
| **Basilisk II / SheepShaver** | Mac II-class (68040) | Widely available | ⚠ Wrong CPU class and wrong speed, so it is not a performance reference at all, and a 68040 can hide 68000-only behaviour |
| **QEMU** (`q800`) | Quadra 800 | gdb stub — which would give items 3 and 4 for free, in exactly the idiom this project already uses for the Amiga | Same caveat as Basilisk: wrong machine class. But the **gdb stub** is worth a lot, and a gdb-driven loop would share tooling and habits with `amiga/debug.sh` |

## ⭐⭐ Verdict on the tool-level evidence: MAME primary, QEMU as the fallback

**MAME wins, and not on reputation — on the checklist.** It is the only candidate that puts *both*
target machines in one tool (`macii` for the Color build's Color QuickDraw, `macplus` if the deferred
timing reference is ever built), it satisfied items 1-5 under test, and its gdb stub speaks m68k, so
QEMU's one distinctive advantage — the `amiga/debug.sh` idiom — is available in MAME too.

**QEMU stays as the fallback**, and it is a strong one: the stub attached first time and QMP gives
`screendump`/`pmemsave`. ⚠ But `q800` is a 68040 Quadra — wrong machine class twice over (it can
hide 68000-only behaviour and is no performance reference), and it cannot be the Mac II the Color
build wants.

⚠⚠ **Neither is proven to boot the game**, and that is item 0b, the only one that matters for ground
truth. Until the ROM + System dependency is met, "MAME is the reference loop" is a **plan**, not a
result. ⭐ Inherited note that still applies: the prior ports ended up wanting **two** reference
tools — a scriptable oracle and an interactive accurate one — and that was the right shape rather
than indecision.

## ⭐⭐ The loop DRIVES — launching the game with no window and no human

```
timeout -k 5 300 env SDL_VIDEODRIVER=dummy mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
  -ramsize 8M -hard ref/mame/hd/608_2GB_drive.hd -video none -sound none -window \
  -skip_gameinfo -nothrottle -seconds_to_run 110 -snapshot_directory ref/mame/snap \
  -cfg_directory ref/mame/cfg -nvram_directory ref/mame/nvram \
  -autoboot_script tools/mac_launch.lua
```

⚠ **`-cfg_directory` / `-nvram_directory` are not optional hygiene.** Without them MAME writes
`cfg/` and `nvram/` into the current directory — that is where the **PRAM holding the 16-colour
screen setting** lives, so it is both repo litter *and* reference state, and it was committed by
accident once before `.gitignore` grew the entries.

| script | what it is |
|---|---|
| `tools/mame_mac_input.lua` | the library: ADB key/mouse injection, menu pull-downs, `mac.launch()`, and state readback from low memory |
| `tools/mac_launch.lua` | boot → Finder → launch `Color VETTE!` → snapshot every 5 s |
| `tools/mac_probe_display.lua`, `tools/mac_probe_fb.lua` | read the display structures / dump the framebuffer + CLUT (`docs/mac-hardware.md`) |
| `tools/mac_set_16colors.lua` | one-time Monitors setup, ending in Special ▸ Shut Down so PRAM and the volume flush |
| `tools/fb_to_png.py` | re-render a framebuffer dump and diff it against MAME's screenshot |

### ⭐ Completion is read from the Mac's own low memory, never from a screenshot

`CurApName` ($910, Str31) is the frontmost application, `RawMouse` ($82C, Point v,h) is the cursor,
`MacJmp` ($120) is non-zero when a debugger is installed. **A step that silently did nothing is
otherwise indistinguishable from a slow one**, which is the whole reason the launch waits on
`CurApName == "Color VETTE!"` rather than on a frame count.

### Three gates the game itself imposes, each found by running it

1. **32-Bit QuickDraw** — without it the game quits on launch. Installed from the game volume's own
   `System Folder Additions`.
2. **More than 2 MB** — "not enough memory" at MAME's 2 MB default. `-ramsize 8M`.
3. ⭐⭐ **A 16-colour screen** — *"Please change your Monitors setting in the Control Panel to 16
   colors."* The game stating its own 4-bitplane requirement. Set once via Monitors; it persists in
   the volume/PRAM.

### ⚠⚠ Input injection — five things that cost real time, four of them silent

- ⛔ **`natkeyboard:post` types NOTHING on this driver**, with or without `in_use = true`: `macadb`
  exposes no natural-keyboard character map, so the call returns quietly and the next step acts on
  whatever was already selected. Type through **ioport fields** instead.
- ⚠ **MAME names a key by BOTH its legends** — the `o` key is the field `"o  O"` (two spaces), `6`
  is `"6  ^"`. A bare `"o"` raises "no ioport field named o", which is at least loud; the library
  widens single characters for you.
- ⚠⚠ **The mouse axes are 0..255 and act on the CHANGE between reads**, so *holding* a value moves
  the cursor nowhere (measured: held 40/200/2000 for 60 frames → +0 px). Accumulate mod 256 every
  frame. Units are not pixels — the Mac applies acceleration, measured ~0.3 px/unit and non-linear —
  so aim **closed-loop against `RawMouse`**, never open-loop.
- ⚠⚠ **Aim for a TOLERANCE and then SETTLE.** Demanding an exact pixel makes the cursor oscillate
  and park in a corner; and the ADB consumes one more delta *after* the loop stops writing, so a
  position read the instant the tolerance is met is read before the cursor has stopped. Without the
  6-frame settle a double-click landed 17 px above the icon and the launch silently did nothing.
- ⚠ **ADB is polled**: a 1-frame press can be missed entirely. Hold ~4 frames.
- ⛔ **System 6's Finder has no type-select** (that is a System 7 feature), so navigation is by
  coordinate. ⭐ Icon positions are only stable because `Special ▸ Clean Up Window` was run once —
  `hfsutils` writes no `fdLocation`, so files copied from the host land on top of each other. After
  a clean-up the positions live in the volume's catalog and survive reboots.
- Mac menus are **press-drag-release**. Releasing back on the title chooses nothing, which is the
  safe way to probe a menu's geometry (snapshot while held).

## Traps to inherit from the prior ports' reference loops

All measured, all cost real time there:

- ⭐ **Every "not observed" probe needs a positive control in the same run** — a landmark on the path
  proving the run got as far as the thing being tested. Three Revs probes reported "zero executions,
  consistent with unreachable" for code in the engine's main loop; none had checked whether the run
  reached the surrounding code, and none had.
- ⚠⚠ **When an input harness has a name-keyed table, assert the names resolve before using it.**
  jsbeeb calls the Return key `ENTER`, so every `keyCodes.RETURN` press was `keyDown(undefined)` — a
  silent no-op, indistinguishable from the program ignoring you. Applies directly to any scripted
  Mac keyboard/mouse table.
- ⚠ **Do not press keys "just in case"** into something that buffers; speculative presses jammed a
  two-character input field and wedged a run with its own input.
- **An image built from the media does not model REGISTERS or what the OS left resident.** Here that
  generalises to: the application's heap, its A5 world and low memory are all *populated by the
  system before the game runs*, and a reconstruction that starts from the resource fork models none
  of it.
- **A reconstruction is provisional until diffed against the real thing.** Revs's Phase 2 found its
  memory image had been the wrong input all along (the engine unpacked itself first). ⚠ The Mac
  analogue is the Segment Loader: what runs is relocated, and the jump table is patched.
