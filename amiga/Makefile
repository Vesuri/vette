# Vette! — Amiga cross-build (m68k-amiga-elf-gcc)
#
# Usage (from amiga/ with the toolchain on PATH via `. env.sh`):
#   make                 build out/Vette.exe
#   make clean           remove obj/ and out/
#   make PROBES=1        + the timing probes (diag_run.sh needs this)
#   make FPSCOUNT=1      the HONEST framerate build: one counter, no probe instrumentation
#   make SKIP_INTRO=1    report one synthetic first mouse press to skip the proven intro
#   make GARAGE_CLICK=1  script the garage and vehicle selectors through real mouse events
#   make GARAGE_CLICK=1 GARAGE_COURSE=2  select Course Two through its real UI before ACCEPT
#   make GARAGE_CLICK=1 FREEWAY_ROUTE=1  steer by normal KeyMap input toward the Course Two freeway
#   make GARAGE_CLICK=1 FOLLOW_ROAD=1    turn right at the Course One start, then follow the road
#   make GARAGE_CLICK=1 FINISH_CHECKPOINT=1  enter the selected course's source-defined finish rectangle(s)
#   make GARAGE_CLICK=1 DAMAGE_REPAIR_CHECKPOINT=1  exercise Pro damage and gas-station repair
#   make GARAGE_CLICK=1 TERMINAL_DAMAGE_CHECKPOINT=1 exercise the beyond-repair tow lifecycle
#   make GARAGE_CLICK=1 POLICE_TICKET_CHECKPOINT=1 exercise all ordinary police penalties
#   make GARAGE_CLICK=1 FREEWAY_ROUTE=1 FREEWAY_START=11  fast-start at freeway cell (11,36)
#   add FREEWAY_START_U=n FREEWAY_START_V=n to choose a source-derived local point in that cell
#   add MAIN_START=n to hand off at Main Map cell (n,39) after a real freeway-exit response
#   make QUIT_PROBE=1    request the Control+LMB exit at the first safe event-pump trap
#   make FILLWATCH=1     rolling audit of the planar back buffer against the chunky Mac surface
#   ./run.sh             boot in FS-UAE (CTRL + left mouse button quits)
#   ./debug.sh           source-level debug via the FS-UAE GDB stub
#   ./diag_run.sh [secs] headless probe run (needs PROBES=1)
#
# Scope: Stage A display takeover plus the completed Stage B resident-code loader and loud
# Line-A stop (docs/stage-b.md).  The source lists remain wildcarded for the Stage C trap layer.
#
# ⚠⚠ `make clean` BEFORE any PROBES=1 build and AFTER editing a widely-included header.
# This Makefile tracks neither the flag nor header deps, so a partial rebuild links stale
# objects into a WORKING-BUT-WRONG binary with silent runtime breakage.  On both prior ports
# that trap cost multiple debugging sessions: treat any unexplained regression right after a
# header edit or a PROBES toggle as a stale build FIRST.  (docs/headless-fsuae.md)
#
# Structure: explicit/wildcarded source lists mapped to objects in a flat obj/ (keyed by
# basename — KEEP BASENAMES UNIQUE across the source trees), sources located via vpath.

OUT      = out/Vette
CC       = m68k-amiga-elf-gcc
AS       = m68k-amiga-elf-as
VASM     = vasmm68k_mot
OBJDUMP  = m68k-amiga-elf-objdump
SDKDIR   = $(abspath $(dir $(shell which $(CC)))../m68k-amiga-elf/sys-include)
SUPPORT  = $(abspath $(dir $(shell which $(CC)))../../support)

# Repository root (parent of amiga/) and the Amiga source tree.  This directory holds only
# build infrastructure (this Makefile, env.sh, run.sh, the diag scripts, assets/).
REPO      = ..
AMIGA_SRC = $(REPO)/src/platform/amiga

$(shell mkdir -p obj out)

# ---------------------------------------------------------------------------
# Sources
# ---------------------------------------------------------------------------
# C++: the vendored dA JoRMaS hardware framework, then this port's Amiga backend, the shared
# platform layer, and main().  The framework list is explicit because it is fixed and vendored;
# everything else is wildcarded until the files exist.
FRAMEWORK_CXX_SRCS := \
    $(AMIGA_SRC)/framework/AmigaHardware.cpp \
    $(AMIGA_SRC)/framework/Bitmap.cpp \
    $(AMIGA_SRC)/framework/CopperList.cpp \
    $(AMIGA_SRC)/framework/Palette.cpp \
    $(AMIGA_SRC)/framework/Sprite.cpp \
    $(AMIGA_SRC)/framework/Util.cpp

CXX_SRCS := $(FRAMEWORK_CXX_SRCS) \
    $(AMIGA_SRC)/GCCRuntime.cpp \
    $(wildcard $(AMIGA_SRC)/*.cpp) \
    $(wildcard $(REPO)/src/platform/*.cpp) \
    $(wildcard $(REPO)/src/mac/*.cpp) \
    $(wildcard $(REPO)/src/main.cpp)
# GCCRuntime.cpp is named explicitly AND matched by the wildcard above; de-duplicate.
CXX_SRCS := $(sort $(CXX_SRCS))

# C: the port's plain-C translation units (the trap layer may well be C).
CORE_C_SRCS := \
    $(wildcard $(REPO)/src/mac/*.c) \
    $(wildcard $(REPO)/src/platform/*.c)

# Support runtime (freestanding CRT: program entry, memset…) + any incbin'd assets.
SUPPORT_C_SRCS := $(SUPPORT)/gcc8_c_support.c
ASM_SRCS       := $(SUPPORT)/gcc8_a_support.s $(wildcard $(AMIGA_SRC)/*.s)

# Framework hand-written m68k asm (Motorola syntax, assembled by vasm -> ELF).  The matching
# GCC register-marshalling bridges live under `#if defined(ASSEMBLER) && !defined(__SASC)` in
# the corresponding framework .cpp.
FRAMEWORK_ASM_SRCS := \
    $(AMIGA_SRC)/framework/UtilAssembler.s \
    $(AMIGA_SRC)/framework/AmigaHardwareAssembler.s \
    $(AMIGA_SRC)/framework/BitmapAssembler.s \
    $(AMIGA_SRC)/framework/CopperListAssembler.s

# ---------------------------------------------------------------------------
# Build flags / feature toggles
# ---------------------------------------------------------------------------
# ⭐ THE ASM-TWIN SEAM TEMPLATE.  Every hand-asm twin gets one of these as it is written:
#
#   ifndef <NAME>_C
#   FRAMEWORK_ASM_SRCS += $(AMIGA_SRC)/<Name>Assembler.s
#   EXTRA_DEFINES += -DVETTE_<NAME>_ASM
#   ifdef VERIFY
#   EXTRA_DEFINES += -DVETTE_<NAME>_VERIFY
#   obj/<Name>Assembler.o : VASMFLAGS += -DVETTE_<NAME>_VERIFY
#   endif
#   endif
#
# `make <NAME>_C=1` falls back to the clean-C oracle; `make VERIFY=1 PROBES=1` runs the asm and
# the C oracle back-to-back on identical state EVERY CALL and compares, read via
# amiga/<name>_verify.gdb.  ⭐ That in-process differential is the ONLY valid way to price an asm
# twin — a cross-run comparison changes the workload and measures a different thing.
# See docs/perf-method.md Rule 2.

# Palette-remapped packed-pixel copy.  The C implementation remains the oracle;
# the default 68000 twin keeps the 256-byte lookup table in an address register.
# `make MAPPED_COPY_C=1` selects the oracle, while `make VERIFY=1 PROBES=1`
# executes both implementations on every eligible CopyBits and compares bytes.
ifneq ($(MAPPED_COPY_C),1)
EXTRA_DEFINES += -DVETTE_MAPPED_COPY_ASM
ifdef VERIFY
EXTRA_DEFINES += -DVETTE_MAPPED_COPY_VERIFY
endif
endif

# Chunky-to-planar rectangle kernel. The C table implementation remains the oracle;
# the default assembly twin consumes the game's packed nibbles directly and,
# extending Kalms' OCS/ECS wide-write strategy, writes 32-pixel longword
# batches plus an exact 16-pixel word tail.
# `make C2P_C=1` selects the oracle. `VERIFY=1 PROBES=1` runs both on identical
# rectangles, times them back-to-back, and byte-compares every four-plane row.
ifneq ($(C2P_C),1)
EXTRA_DEFINES += -DVETTE_C2P_ASM
ifdef VERIFY
EXTRA_DEFINES += -DVETTE_C2P_VERIFY
endif
endif

# Exact 260-byte GWorld to 256-byte logical-screen driving publication copy.
ifneq ($(DRIVING_COPY_C),1)
EXTRA_DEFINES += -DVETTE_DRIVING_COPY_ASM
ifdef VERIFY
EXTRA_DEFINES += -DVETTE_DRIVING_COPY_VERIFY
endif
endif

# Diagnostic only: run each normalized C2P rectangle once to the real chip-RAM
# back buffer and once to an equivalent fast-RAM buffer, timing both destinations.
# Use with PROBES=1; ordinary builds do not allocate the comparison buffer.
ifeq ($(C2P_SPLIT),1)
ifndef PROBES
$(error C2P_SPLIT=1 requires PROBES=1)
endif
EXTRA_DEFINES += -DVETTE_C2P_SPLIT
endif

# `make PROBES=1` — the sub-frame timing accumulators, read via the gdb stub (amiga/diag_run.sh).
# OFF by default: the probes read chip registers several times per iteration, which is exactly
# what a framerate build must not do.  ⚠ NEVER quote a framerate from a PROBES build.
ifdef PROBES
EXTRA_DEFINES += -DVETTE_PROBE
endif

# Differential fixture only: replace the application QuickDraw randSeed at
# the first Random trap.  Ordinary builds retain Vette's clock-seeded value.
ifdef FIDELITY_RANDOM_SEED
EXTRA_DEFINES += -DVETTE_FIDELITY_RANDOM_SEED=$(FIDELITY_RANDOM_SEED)
endif

# Diagnostic only: report one Amiga raw key as held without consuming or
# fabricating an EventRecord.  Normal and playable builds leave this undefined.
ifdef INPUT_PROBE_RAW_KEY
EXTRA_DEFINES += -DVETTE_INPUT_PROBE_RAW_KEY=$(INPUT_PROBE_RAW_KEY)
endif

# Diagnostic only: inject one physical-style down/up edge around the first
# driving iteration, through the same state and queue used by the CIA handler.
# Unlike INPUT_PROBE_RAW_KEY this deliberately produces EventRecords after the
# key's direct KeyMap action has returned execution to the event loop.
ifdef INPUT_PROBE_EVENT_RAW_KEY
EXTRA_DEFINES += -DVETTE_INPUT_PROBE_EVENT_RAW_KEY=$(INPUT_PROBE_EVENT_RAW_KEY)
endif

# Diagnostic only: select helicopter view through a physical F4 edge, then
# return to the forward view through F2, to cover context-0 audio replacement.
ifeq ($(VIEW_AUDIO_PROBE),1)
EXTRA_DEFINES += -DVETTE_VIEW_AUDIO_PROBE
endif

# Diagnostic only: preserve a finite context-0 Load's source arguments but
# shorten its Paula expiry to two ticks so the lifecycle can be bounded.
ifeq ($(FINITE_AUDIO_PROBE),1)
EXTRA_DEFINES += -DVETTE_FINITE_CONTEXT0_AUDIO_PROBE
endif

# Diagnostic only: pulse the documented Z horn control for one driving KeyMap
# scan after the countdown and initial acceleration, then release it through
# the next ordinary scan.
ifdef HORN_PROBE
EXTRA_DEFINES += -DVETTE_HORN_PROBE
endif

# `make FPSCOUNT=1` — the honest framerate build: one increment per painted frame and the
# headless auto-run, no instrumentation.  docs/perf-method.md Rule 1.
ifdef FPSCOUNT
EXTRA_DEFINES += -DVETTE_FPSCOUNT
endif

# Development convenience only.  Button() reports pressed on its first poll,
# then permanently returns to the real CIA mouse state.  The default build
# retains the complete intro path and its acceptance behavior.
ifeq ($(SKIP_INTRO),1)
EXTRA_DEFINES += -DVETTE_SKIP_INTRO
endif

# Diagnostic only: take the original protection routine's two-wrong-answers
# result without constructing its deliberately unsupported modal dialog. The
# ordinary build still patches the protection to the verified success state.
ifeq ($(FAIL_PROTECTION),1)
EXTRA_DEFINES += -DVETTE_FAIL_COPY_PROTECTION
endif

# Diagnostic only: after live racing begins, age the original race-start tick
# to its source-defined two-minute failed-protection police threshold. This
# accelerates the wait but leaves Traffic to spawn and sound the police itself.
ifeq ($(POLICE_PROBE),1)
EXTRA_DEFINES += -DVETTE_POLICE_PROBE
endif

# Diagnostic only: bypass the decoded distance/eligibility predicates for the
# original Main `kill` trigger and Traffic `joel` response.  Their state
# transitions and Bogas calls remain original code.
ifeq ($(REMAINING_AUDIO_PROBE),1)
EXTRA_DEFINES += -DVETTE_REMAINING_AUDIO_PROBE
endif

# Deterministic Stage-C stepping only.  GetNextEvent traverses the garage,
# vehicle and course selectors with normal mouse events; Button skips the plate
# animation through its shipped input branch.  After driving setup returns,
# one top-row + down/up pair shifts from neutral to Gear 1, then keypad 8 is held as the
# acceleration control.  Production builds always use live Amiga input and
# never define this.
ifeq ($(GARAGE_CLICK),1)
EXTRA_DEFINES += -DVETTE_GARAGE_CLICK
endif

ifdef GARAGE_COURSE
EXTRA_DEFINES += -DVETTE_GARAGE_COURSE=$(GARAGE_COURSE)
endif

ifeq ($(FREEWAY_ROUTE),1)
EXTRA_DEFINES += -DVETTE_FREEWAY_ROUTE
endif

ifeq ($(MOTION_CAPTURE),1)
EXTRA_DEFINES += -DVETTE_MOTION_CAPTURE
endif

ifdef VIEW_CAPTURE_RAW_KEY
EXTRA_DEFINES += -DVETTE_VIEW_CAPTURE_RAW_KEY=$(VIEW_CAPTURE_RAW_KEY)
endif

ifeq ($(FOLLOW_ROAD),1)
EXTRA_DEFINES += -DVETTE_FOLLOW_ROAD
endif

# Diagnostic only: after Course One reaches live race state, move the complete
# player position history to the measured finish rectangle shared with Course
# Two's genuine start. The original collision response decides and performs
# the finish; no result, score, or lifecycle state is patched.
ifeq ($(FINISH_CHECKPOINT),1)
EXTRA_DEFINES += -DVETTE_FINISH_CHECKPOINT
endif

# Diagnostic adverse-outcome checkpoints. Both retain the naturally reached
# collision and the original Traffic decisions. The repair arm relocates the
# complete car history only after damage exists; the terminal arm supplies the
# documented cumulative threshold before that same collision routine runs.
ifeq ($(DAMAGE_REPAIR_CHECKPOINT),1)
EXTRA_DEFINES += -DVETTE_DAMAGE_REPAIR_CHECKPOINT
endif
ifeq ($(TERMINAL_DAMAGE_CHECKPOINT),1)
EXTRA_DEFINES += -DVETTE_TERMINAL_DAMAGE_CHECKPOINT
endif
ifeq ($(POLICE_TICKET_CHECKPOINT),1)
EXTRA_DEFINES += -DVETTE_POLICE_TICKET_CHECKPOINT
endif

# Diagnostic-only configurable fast start for freeway work.  Pass the desired
# freeway X cell, for example FREEWAY_START=11.  The original game still
# enters driving and executes its export-212 map/traffic transition; the host
# first places the player immediately before that gateway, then moves the
# player to the requested row-36 cell after freeway mode becomes active.
ifdef FREEWAY_START
EXTRA_DEFINES += -DVETTE_FREEWAY_START=$(FREEWAY_START)
endif
ifdef FREEWAY_START_U
EXTRA_DEFINES += -DVETTE_FREEWAY_START_U=$(FREEWAY_START_U)
endif
ifdef FREEWAY_START_V
EXTRA_DEFINES += -DVETTE_FREEWAY_START_V=$(FREEWAY_START_V)
endif
ifdef MAIN_START
EXTRA_DEFINES += -DVETTE_MAIN_START=$(MAIN_START)
endif

# Diagnostic only: select the game's shipped Mouse steering default so the
# physical Amiga mouse bridge and original callbacks can be traced directly.
ifeq ($(MOUSE_CONTROL_PROBE),1)
EXTRA_DEFINES += -DVETTE_MOUSE_CONTROL_PROBE
endif

# Diagnostic only: take the same deferred exit path as Control+left-mouse at
# its first safe trap boundary, without requiring headless hardware input.
ifeq ($(QUIT_PROBE),1)
EXTRA_DEFINES += -DVETTE_QUIT_PROBE
endif

# Diagnostic only: full 512x320 chunky-vs-planar validation after every
# successful dirty conversion. Never use this build for performance numbers.
ifeq ($(FILLWATCH),1)
EXTRA_DEFINES += -DVETTE_FILLWATCH
endif

# ⭐⭐ `make PROBEFIELDS=N PROBES=1` — BOUND THE MEASUREMENT IN EMULATED TIME, not host time.
# diag_run.sh's window is `sleep <wall seconds>`, and under warp the host's throughput depends on
# what else the machine is doing, so two arms of one A/B can cover very different amounts of GAME
# time.  With this set, the accumulators freeze after N display FIELDS, so every arm describes the
# same emulated window frame for frame — and the freeze must PRINT the proof that it fired.
# ⚠⚠ THE PARTIAL-FREEZE TRAP: the freeze stops the accumulators, not the program, so every counter
# bumped elsewhere keeps climbing and any row mixing the two is FICTION.  Snapshot what you cannot
# stop.  docs/perf-method.md §Lessons — measurement.
ifdef PROBEFIELDS
EXTRA_DEFINES += -DVETTE_PROBE_FIELDS=$(PROBEFIELDS)
endif

# ---------------------------------------------------------------------------
# Objects / flags
# ---------------------------------------------------------------------------
CXX_OBJS       := $(addprefix obj/,$(notdir $(CXX_SRCS:.cpp=.o)))
CORE_C_OBJS    := $(addprefix obj/,$(notdir $(CORE_C_SRCS:.c=.o)))
SUPPORT_C_OBJS := $(addprefix obj/,$(notdir $(SUPPORT_C_SRCS:.c=.o)))
ASM_OBJS       := $(addprefix obj/,$(notdir $(ASM_SRCS:.s=.o)))
FRAMEWORK_ASM_OBJS := $(addprefix obj/,$(notdir $(FRAMEWORK_ASM_SRCS:.s=.o)))

OBJECTS := $(CXX_OBJS) $(CORE_C_OBJS) $(SUPPORT_C_OBJS) $(ASM_OBJS) $(FRAMEWORK_ASM_OBJS)

# Locate sources for the pattern rules.  (gcc8_c_support.c is deliberately NOT on vpath %.c —
# it has its own explicit rule so it builds with CCFLAGS, not CORE_CFLAGS.)
vpath %.cpp $(AMIGA_SRC)/framework $(AMIGA_SRC) $(REPO)/src/platform $(REPO)/src/mac $(REPO)/src
vpath %.c   $(REPO)/src/mac $(REPO)/src/platform
vpath %.s   $(AMIGA_SRC)/framework $(AMIGA_SRC)

WARN = -Wall -Wno-unused-function -Wno-unused-parameter -Wno-unused-variable

CORE_CINCLUDES = -I"$(AMIGA_SRC)/framework/compat-include" \
                 -I"$(REPO)/src" \
                 -I"$(REPO)/src/mac" \
                 -I"$(REPO)/src/platform"

# Optimisation level — overridable for debug builds:
#   make OPT='-O0'    (also drops -fomit-frame-pointer for clean backtraces)
OPT        ?= -O2 -fomit-frame-pointer
NATIVE_OPT ?= -O3 -funroll-loops

# -m68000: retain 68000-compatible code generation even though the supported package target is
# the A1200.  This costs the target nothing and keeps expanded OCS-machine experiments honest.
# -msoft-float: no FPU.
CORE_CFLAGS = -g -MP -MMD -m68000 -msoft-float $(OPT) -nostdlib \
              -fno-tree-loop-distribution -ffunction-sections -fdata-sections \
              $(WARN) -DVETTE_PLATFORM_AMIGA \
              $(CORE_CINCLUDES) $(EXTRA_DEFINES)
CCFLAGS   = -g -MP -MMD -m68000 -msoft-float $(OPT) -nostdlib \
            -fno-tree-loop-distribution -ffunction-sections -fdata-sections \
            $(WARN) $(EXTRA_DEFINES)
CPPFLAGS  = $(CCFLAGS) -fno-rtti -fno-exceptions -fno-use-cxa-atexit -std=gnu++17 \
            -fpermissive -Wno-write-strings -Wno-pointer-arith \
            -DVETTE_PLATFORM_AMIGA \
            -include "$(AMIGA_SRC)/framework/SASCCompat.h" \
            -I"$(AMIGA_SRC)/framework" \
            -I"$(AMIGA_SRC)/framework/compat-include" \
            -I"$(AMIGA_SRC)" \
            -I"$(REPO)/src" \
            -I"$(REPO)/src/mac" \
            -I"$(REPO)/src/platform" \
            -I"$(CURDIR)"
ASFLAGS   = -mcpu=68000 -g --register-prefix-optional -I"$(SDKDIR)" -I"$(CURDIR)"
# The supported package target is an A1200.  Only the measured C2P hot loop
# uses 68020 scaled indexing; resident Macintosh code and all other port
# assembly retain the broader 68000 setting.
obj/C2P.o: ASFLAGS := $(filter-out -mcpu=68000,$(ASFLAGS)) -mcpu=68020
# vasm (Motorola syntax) for the framework *Assembler.s.  -m68010: the only >68000 instruction in
# the vendored framework is `movec vbr,d0` in getVBR, which is behaviour-neutral on the A500.
# ⚠ -no-opt is LOAD-BEARING (it keeps hand-written encodings exactly as written), which means
# in-range hot branches must be hand-marked `.s` or they assemble as long branches.
VASMFLAGS = -m68010 -Felf -quiet -x -no-opt -nowarn=62 $(EXTRA_VASMDEFS)

# ⚠⚠ PROBE SYMBOLS — every global a committed .gdb script reads MUST be listed here.
# --gc-sections drops any section nothing in the current configuration references, and a dropped
# probe counter is WORSE than a missing one: gdb resolves the name into .text and prints
# INSTRUCTION BYTES as a value (measured on the Revs port: `painted=1223110688`).
# `--undefined=<sym>` makes the symbol a gc ROOT, at zero runtime cost.
# `__attribute__((used, retain))` does NOT work here — `retain` is ignored on this target.
# Add a symbol here the moment you add a counter; `make probe-audit` enforces it on every link.
#
# ⚠ Keep a symbol in the CONFIGURATION its script is run against: a counter that only EXISTS
# under PROBES must be added under `ifdef PROBES`, or `--undefined=` is unsatisfiable and a plain
# `make` fails at probe-audit — which is the audit working, not a bug in it.
# Stage A's acceptance globals (src/platform/amiga/PlatformAmiga.cpp).  These are read by
# amiga/stage_a.gdb in a PLAIN build -- the display path is not probe instrumentation, so
# they are unconditional rather than under `ifdef PROBES`.
PROBE_SYMS = g_vbiCount g_planeChecksum g_screenReady g_laceFields g_longFields g_lofSamples \
             g_stageBState g_trapWord g_trapSelector g_trapSegment g_trapOffset \
             g_trapPC g_trapRegisters g_trapUserStack g_resourceCount g_jumpEntryCount \
             g_blockMoveCount g_trapManager g_trapRoutine
PROBE_SYMS += g_stageCDepth
PROBE_SYMS += g_macTicks
PROBE_SYMS += g_macDrivingIterations
PROBE_SYMS += g_macDrivingCallbacks
PROBE_SYMS += g_macFramesQueued g_macFramesPresented
PROBE_SYMS += g_beamPresentLine g_beamPresentMin g_beamPresentMax \
              g_beamPresents g_beamPresentsLate
PROBE_SYMS += g_macVBLCallbackEntry g_macVBLCallbackTask g_macVBLCallbackA5 g_macVBLCallbackReturn
PROBE_SYMS += g_introAudioState g_introAudioBytes g_introAudioPeriod
ifneq ($(MAPPED_COPY_C),1)
ifdef VERIFY
PROBE_SYMS += g_mappedCopyAsmTicks g_mappedCopyCTicks g_mappedCopyVerifyCalls \
              g_mappedCopyVerifyBytes \
              g_mappedCopyVerifyFailures
endif
endif
ifneq ($(C2P_C),1)
ifdef VERIFY
PROBE_SYMS += g_c2pAsmTicks g_c2pCTicks g_c2pVerifyCalls g_c2pVerifyBytes \
              g_c2pVerifyFailures
endif
endif
ifeq ($(C2P_SPLIT),1)
PROBE_SYMS += g_c2pSplitChipTicks g_c2pSplitFastTicks g_c2pSplitFrames \
              g_c2pSplitRects g_c2pSplitPixels
endif
ifneq ($(DRIVING_COPY_C),1)
ifdef VERIFY
PROBE_SYMS += g_drivingCopyAsmTicks g_drivingCopyCTicks g_drivingCopyVerifyCalls \
              g_drivingCopyVerifyBytes g_drivingCopyVerifyFailures
endif
endif
ifdef PROBES
PROBE_SYMS += g_probePicture140TrapPC g_probePicture140Return \
              g_probePicture140Ticks g_probePicture140Frames g_probeIntroGeometry \
              g_probeStaticCollision g_probeLakeCollision \
              g_macExitState g_macHostReturnSP \
              g_restoreSavedDmacon g_restoreActualDmacon \
              g_restoreSavedIntena g_restoreActualIntena g_restoreViewMatches \
              g_profileState g_profileGeneration g_profileStartEpoch g_profileStopEpoch \
              g_profileStartField g_profileStopField g_profileStartFrames g_profileStopFrames \
              g_profileTicks g_profileCalls
endif
ifdef FPSCOUNT
PROBE_SYMS +=
endif
ifeq ($(FILLWATCH),1)
PROBE_SYMS += g_fillWatchFrames g_fillWatchRows g_fillBadFrames g_fillBadPixels \
              g_fillBadX g_fillBadY g_fillBadExpected g_fillBadActual
endif

COMMA := ,
LDFLAGS   = -Wl,--emit-relocs,--gc-sections,-Ttext=0,-Map=$(OUT).map \
            $(addprefix -Wl$(COMMA)--undefined=,$(PROBE_SYMS))

# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------
.PHONY: all clean muldiv-audit probe-audit

all: $(OUT).exe

$(OUT).exe: $(OUT).elf
	$(info Elf2Hunk $@)
	@elf2hunk $(OUT).elf $(OUT).exe

$(OUT).elf: $(OBJECTS)
	$(info Linking $@)
	@$(CC) $(CCFLAGS) $(LDFLAGS) $(OBJECTS) -o $@
	@$(OBJDUMP) --disassemble --no-show-raw-ins -S $@ > $(OUT).s 2>/dev/null || true
	@$(MAKE) --no-print-directory muldiv-audit
	@$(MAKE) --no-print-directory probe-audit

# ⚠ MANDATORY AUDIT: the 68000 has NO 32-bit multiply or divide, so GCC lowers any 32-bit
# * / / / % into __mulsi3/__divsi3/__udivsi3/__modsi3/__umodsi3 — ~200-600 cycles each.  Use the
# 16-bit helpers in src/m68k_math.h instead.  This runs on every link so a regression is caught
# the moment it is introduced, not months later.
muldiv-audit:
	@if $(OBJDUMP) -d $(OUT).elf | grep -qE '__(u?div|u?mod|mul)si3'; then \
	  echo "*** 32-bit software mul/div linked in — see docs/m68k-optimisation.md:"; \
	  $(OBJDUMP) -d $(OUT).elf | grep -E '__(u?div|u?mod|mul)si3' | head; \
	  exit 1; \
	else echo "muldiv-audit: clean"; fi

# ⚠ MANDATORY AUDIT: every PROBE_SYMS symbol must be a real data symbol in the linked ELF.
# A gc-dropped probe counter makes gdb print instruction bytes as a measurement — see PROBE_SYMS.
probe-audit:
	@bad=""; for s in $(PROBE_SYMS); do \
	  $(OBJDUMP) -t $(OUT).elf | grep -qE "[[:space:]]O[[:space:]]+\.(bss|data)[[:space:]].*[[:space:]]$$s$$" \
	    || bad="$$bad $$s"; \
	done; \
	if [ -n "$$bad" ]; then \
	  echo "*** probe symbol(s) missing from $(OUT).elf (gc-sections ate them):$$bad"; \
	  echo "    gdb would resolve these into .text and print instruction bytes as values."; \
	  exit 1; \
	else echo "probe-audit: clean ($(words $(PROBE_SYMS)) symbols)"; fi

# C++ (framework + the Amiga backend + the shared platform layer).
obj/%.o : %.cpp
	$(info C++  $<)
	@$(CC) $(CPPFLAGS) -c -o $@ "$(abspath $<)"

# The port's plain-C translation units.
obj/%.o : %.c
	$(info C    $< [core])
	@$(CC) $(CORE_CFLAGS) -c -o $@ "$(abspath $<)"

# Support runtime: gcc8_c_support.c needs CCFLAGS (no core include paths).
obj/gcc8_c_support.o : $(SUPPORT)/gcc8_c_support.c
	$(info C    $<)
	@$(CC) $(CCFLAGS) -c -o $@ "$<"

obj/gcc8_a_support.o : $(SUPPORT)/gcc8_a_support.s
	$(info ASM  $<)
	@$(AS) $(ASFLAGS) -o $@ "$<"

# Port-authored GAS assembly (68000 exception/trampoline code).
obj/%.o : $(AMIGA_SRC)/%.s
	$(info ASM  $<)
	@$(AS) $(ASFLAGS) -o $@ "$(abspath $<)"

# ⚠ .incbin dependencies are INVISIBLE to `gcc -MMD`, so list them explicitly here as they
# appear.  Without it, regenerating an embedded blob leaves a stale copy in the binary while the
# on-disk file looks correct.  Paths are relative to this amiga/ directory.
CODE_DEPS := \
    ../tmp/seg_color/CODE_00.bin \
    ../tmp/seg_color/CODE_01_Main.bin \
    ../tmp/seg_color/CODE_02_Initialize.bin \
    ../tmp/seg_color/CODE_03_Communication.bin \
    ../tmp/seg_color/CODE_04_load.bin \
    ../tmp/seg_color/CODE_05_Score.bin \
    ../tmp/seg_color/CODE_06_Traffic.bin \
    ../tmp/seg_color/CODE_07_FRED.bin \
    ../tmp/seg_color/CODE_08_Intro.bin \
    ../tmp/seg_color/CODE_09_sound.bin \
    ../tmp/seg_color/CODE_10__A5Init.bin
APP_RSRC := ../tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_Color_VETTE!.rsrc
DATA_RSRC := ../tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc
RESOURCE_ARCHIVE := assets/vette.resources
INCBIN_DEPS := $(CODE_DEPS) $(RESOURCE_ARCHIVE)

$(RESOURCE_ARCHIVE): ../tools/rsrc_pack.py $(APP_RSRC) $(DATA_RSRC)
	$(info PACK $@)
	@python3 ../tools/rsrc_pack.py "$@" "application=$(APP_RSRC)" "data=$(DATA_RSRC)"

obj/incbin.o : $(AMIGA_SRC)/incbin.s $(INCBIN_DEPS)
	$(info ASM  $<)
	@$(AS) $(ASFLAGS) -o $@ "$(abspath $(AMIGA_SRC)/incbin.s)"

# Framework hand-written asm (vasm, Motorola syntax -> ELF).  Static pattern rule so it does not
# collide with the gas-assembled gcc8_a_support.s / incbin.s explicit rules.
$(FRAMEWORK_ASM_OBJS) : obj/%.o : %.s
	$(info VASM $<)
	@$(VASM) $(VASMFLAGS) -o $@ "$(abspath $<)"

clean:
	@$(RM) -r obj/ out/

-include $(wildcard obj/*.d)
