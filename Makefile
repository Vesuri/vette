# Vette! — host build + repo-level targets.
#
# ⚠ THE HOST BUILD IS AN OPEN DECISION (PROJECT.md §Open decisions #6).  RoF had an SDL backend
# and its approximation cost real time on bugs that existed only in the approximation; Revs
# deliberately had NO renderer and used the host purely for differentials.  This port's
# differentials are different again — there is no transliteration oracle to compare against — so
# the question is genuinely open, and this Makefile does not pre-answer it by growing a backend.
#
# The Amiga build is in amiga/ and is the real target: `cd amiga && . ./env.sh && make`.

.PHONY: all todo driving-sequence-capture driving-sequence-compare driving-motion-reference driving-audio-reference driving-motion-capture driving-motion-compare driving-profile help

all: help

help:
	@echo "Vette! — Macintosh 68000 -> Amiga port"
	@echo
	@echo "  make todo     what is open (docs/open-work.md + a live marker sweep)"
	@echo "  make driving-sequence-compare  compare saved MAME/Amiga driving frames"
	@echo "  make driving-sequence-capture  capture Amiga frames at saved Macintosh game states"
	@echo "  make driving-motion-compare    compare saved moving-driving frames by game state"
	@echo "  make driving-motion-reference  capture distinct moving frames on the Macintosh oracle"
	@echo "  make driving-audio-reference   capture/report Macintosh intro and moving-driving audio"
	@echo "  make driving-motion-capture    capture distinct completed moving Amiga frames"
	@echo "  make driving-profile  build and measure 300 PAL fields of target-A1200 driving"
	@echo
	@echo "There is no host build yet — see PROJECT.md 'Open decisions' #6."
	@echo "The Amiga build:  cd amiga && . ./env.sh && make"

# ⭐⭐ WHAT IS OPEN.  The queue plus a live sweep for markers in the tracked, non-vendored tree.
# Expected marker output is "none" — a printed marker is either a real work item that belongs in
# docs/open-work.md or a stale marker to delete.  (CLAUDE.md §Working conventions.)
# ⚠ The pattern is written with character classes (TOD[O] etc) so this Makefile does not match
# ITSELF and report a permanent phantom hit.
todo:
	@cat docs/open-work.md
	@echo
	@echo "=== live marker sweep (tracked, non-vendored) ==="
	@if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then \
	  hits=$$(git grep -nE '(TOD[O]|FIXM[E]|HAC[K]|XX[X])' -- \
	            ':!src/platform/amiga/framework' ':!docs' 2>/dev/null); \
	  if [ -n "$$hits" ]; then echo "$$hits"; else echo "none"; fi; \
	else echo "(not a git repo)"; fi

# The captures are local evidence under ignored ref/ and tmp/ trees. Capture by complete game state,
# not ordinal: different machine speeds need not publish the same intermediate states. The comparison
# reports one-sided coverage and the earliest shared-state divergence. REQUIRE_EXACT=1 gates pixels
# and state alignment for every paired state without pretending one-sided states are comparable.
driving-sequence-capture:
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 SKIP_INTRO=1 GARAGE_CLICK=1 INPUT_PROBE_RAW_KEY=62 && \
	  EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_state_sequence.gdb \
	  ./diag_run.sh 150

driving-sequence-compare:
	@python3 tools/compare_driving_sequence.py \
		ref/mame/driving-copy-source tmp/driving-copy-source \
		--match-state \
		$(if $(REQUIRE_EXACT),--require-exact,)

driving-motion-reference:
	@timeout -k 5 300 env SDL_VIDEODRIVER=dummy VETTE_DRIVING_MOTION=1 \
		VETTE_FIDELITY_RANDOM_SEED=3BD90000 \
		VETTE_TRAFFIC_POSITION_TRACE=$(VETTE_TRAFFIC_POSITION_TRACE) \
		VETTE_TRAFFIC_INIT_TRACE=$(VETTE_TRAFFIC_INIT_TRACE) \
		mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
		-ramsize 8M -hard ref/mame/hd/608_2GB_drive.hd \
		-video none -sound none -window -skip_gameinfo -nothrottle \
		-seconds_to_run 150 -snapshot_directory ref/mame/snap \
		-cfg_directory ref/mame/cfg -nvram_directory ref/mame/nvram \
		-autoboot_script tools/mac_probe_model_indices.lua > tmp/mame-motion.log 2>&1

driving-audio-reference:
	@mkdir -p tmp
	@timeout -k 5 360 env SDL_VIDEODRIVER=dummy VETTE_DRIVING_MOTION=1 \
		VETTE_FOLLOW_ROAD=1 VETTE_FIDELITY_RANDOM_SEED=3BD90000 \
		mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
		-ramsize 8M -hard ref/mame/hd/608_2GB_drive.hd \
		-video none -sound none -window -skip_gameinfo -nothrottle \
		-seconds_to_run 150 -samplerate 48000 \
		-wavwrite tmp/vette-reference-driving.wav \
		-snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
		-nvram_directory ref/mame/nvram \
		-autoboot_script tools/mac_probe_model_indices.lua > tmp/mame-driving-audio.log 2>&1
	@python3 tools/audio_reference_report.py tmp/vette-reference-driving.wav

driving-motion-capture:
	@rm -f tmp/driving-motion-sequence.tsv tmp/driving-motion-source-*.raw tmp/driving-motion-globals-*.bin tmp/driving-motion-car-*.bin tmp/driving-motion-object-*.bin
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 SKIP_INTRO=1 GARAGE_CLICK=1 FIDELITY_RANDOM_SEED=0x3BD90000 && \
	  GDBTAIL=160 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_motion_sequence.gdb \
	  ./diag_run.sh 150

driving-motion-compare:
	@python3 tools/compare_driving_sequence.py \
		ref/mame/driving-motion-source tmp/driving-motion-source \
		--reference-manifest ref/mame/driving-motion-sequence.tsv \
		--amiga-manifest tmp/driving-motion-sequence.tsv \
		--reference-object-prefix ref/mame/driving-motion-object \
		--amiga-object-prefix tmp/driving-motion-object \
		--match-state \
		--match-objects \
		--state-field physics_x --state-field physics_y \
		$(if $(REQUIRE_EXACT),--require-exact,)

# The measurement freezes in target time after 300 PAL fields; 60 seconds is
# only a host-side safety ceiling for reaching and reading that frozen window.
driving-profile:
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 PROBES=1 PROBEFIELDS=300 SKIP_INTRO=1 GARAGE_CLICK=1 && \
	  EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_phase_profile.gdb \
	  ./diag_run.sh 60
