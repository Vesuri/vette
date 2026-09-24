# Vette! — repository-level tools and release gates.
# The game has no host renderer: host code installs/inspects original data and runs fidelity
# comparisons. The Amiga build is the product: `cd amiga && . ./env.sh && make`.

VETTE_APP_RSRC ?= tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_Color_VETTE!.rsrc
VETTE_DATA_RSRC ?= tmp/rsrc_VETTE!_VETTE!_Folder_Folder_Color_VETTE!_VETTE!.Data.rsrc

.PHONY: all todo static-map-check coverage-check gameplay-regression-smoke gameplay-regression install-original-data release release-check fidelity-check course-text-regression driving-sequence-capture driving-sequence-compare driving-motion-reference driving-view-reference driving-view-capture driving-view-compare driving-view-regression driving-f1-reference driving-f1-capture driving-f1-compare driving-audio-reference driving-audio-capture driving-audio-compare driving-audio-countdown-regression driving-audio-regression driving-motion-capture driving-motion-compare driving-motion-viewport-compare driving-cadence-compare driving-control-audit driving-palette-compare driving-profile help

all: help

.PHONY: frame-pacing-test
frame-pacing-test:
	@mkdir -p build/tests
	@$(CXX) -std=c++11 tools/test_frame_pacing.cpp -o build/tests/frame-pacing
	@build/tests/frame-pacing

help:
	@echo "Vette! — Macintosh 68000 -> Amiga port"
	@echo
	@echo "  make todo     what is open (docs/open-work.md + a live marker sweep)"
	@echo "  make static-map-check  gate CODE structure, traps, low memory, symbols and coverage"
	@echo "  make coverage-check    gate gameplay matrix observer and build-switch references"
	@echo "  make gameplay-regression-smoke  clean production + driving smoke runs"
	@echo "  make gameplay-regression        all bounded gameplay/release scenario groups"
	@echo "  make install-original-data IMAGE=/path/VETTE!.img DEST=/path/Vette"
	@echo "  make install-data-helper       standalone Unix installer for the original .sit"
	@echo "  make install-data-helper-amiga standalone Amiga installer (no dependencies)"
	@echo "  make install-data-test         original archive and corruption regression tests"
	@echo "  make dist                     clean production build + Vette-0.90.lha"
	@echo "  make release-check            static/coverage/smoke, deterministic build, LHA audit"
	@echo "  make fidelity-check  gate the completed local fidelity evidence set"
	@echo "  make driving-sequence-compare  compare saved MAME/Amiga driving frames"
	@echo "  make driving-sequence-capture  capture Amiga frames at saved Macintosh game states"
	@echo "  make driving-motion-compare    compare saved moving-driving frames by game state"
	@echo "  make driving-motion-viewport-compare  gate a pixel-exact moving exterior view"
	@echo "  make driving-cadence-compare  gate A1200 completed-frame cadence against the Mac"
	@echo "  make driving-control-audit  gate the input bridge and FS-UAE configuration"
	@echo "  make driving-palette-compare  gate selector and road CLUTs from shipped resources"
	@echo "  make course-text-regression   gate PICT relative text placement in the course panel"
	@echo "  make driving-motion-reference  capture distinct moving frames on the Macintosh oracle"
	@echo "  make driving-f1-reference      capture moving F1-view frames on the Macintosh oracle"
	@echo "  make driving-f1-capture        capture matching moving F1-view Amiga frames"
	@echo "  make driving-f1-compare        gate a pixel-exact state-paired F1 view"
	@echo "  make driving-view-compare VIEW=F3 RAW_KEY=0x52  gate another moving view"
	@echo "  make driving-view-regression   recapture and gate F1-F5 plus mirror-off"
	@echo "  make driving-audio-reference   capture/report Macintosh intro and moving-driving audio"
	@echo "  make driving-audio-capture     capture target Bogas/Paula events for the same road workload"
	@echo "  make driving-audio-compare     compare reference/target audio events by source progression"
	@echo "  make driving-audio-regression  gate event fidelity, overlap, replacement and Paula volume"
	@echo "  make driving-audio-countdown-regression  gate reliable ready-set-GO Paula restarts"
	@echo "  make driving-motion-capture    capture distinct completed moving Amiga frames"
	@echo "  make driving-profile  build and measure 300 PAL fields of target-A1200 driving"
	@echo
	@echo "There is deliberately no host game build; the Amiga executable is the product."
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

course-text-regression:
	@mkdir -p tmp
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 SKIP_INTRO=1 GARAGE_CLICK=1 && \
	  GDBTAIL=100 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=course_text_layout.gdb \
	  ./diag_run.sh 90
	@cp amiga/.run/gdb-out.log tmp/amiga-course-text-layout.log
	@grep -q "course-text PASS" tmp/amiga-course-text-layout.log

static-map-check:
	@python3 tools/check_static_map.py

coverage-check:
	@python3 tools/check_gameplay_coverage.py

gameplay-regression-smoke:
	@amiga/regression.sh smoke

gameplay-regression:
	@amiga/regression.sh all

install-data-helper:
	@$(MAKE) -C tools/install-data

.PHONY: install-data-helper install-data-helper-amiga install-data-test

install-data-helper-amiga:
	@. amiga/env.sh && $(MAKE) -C tools/install-data amiga

install-data-test:
	@$(MAKE) -C tools/install-data test

install-original-data:
	@test -n "$(IMAGE)" || { echo "IMAGE=/path/to/VETTE!.img is required"; exit 1; }
	@test -n "$(DEST)" || { echo "DEST=/path/to/Amiga/Vette is required"; exit 1; }
	@python3 tools/install_original_data.py '$(IMAGE)' '$(DEST)'

.PHONY: dist
release: dist

dist:
	@cd amiga && . ./env.sh && $(MAKE) clean && $(MAKE) -j4
	@$(MAKE) -C whdload
	@$(MAKE) install-data-helper-amiga
	@python3 tools/package_release.py amiga/out/Vette.exe dist
	@python3 tools/check_release.py dist/Vette-$$(cat VERSION).lha

release-check: frame-pacing-test static-map-check coverage-check gameplay-regression-smoke
	@$(MAKE) install-data-helper-amiga install-data-test
	@$(MAKE) -C whdload
	@cd amiga && . ./env.sh && \
	  $(MAKE) clean >/dev/null && $(MAKE) -j4 >/dev/null 2>&1 && \
	  first=$$(shasum -a 256 out/Vette.exe | cut -d' ' -f1) && \
	  $(MAKE) clean >/dev/null && $(MAKE) -j4 >/dev/null 2>&1 && \
	  second=$$(shasum -a 256 out/Vette.exe | cut -d' ' -f1) && \
	  test "$$first" = "$$second" && echo "PASS: deterministic production executable $$second"
	@python3 tools/package_release.py amiga/out/Vette.exe dist
	@python3 tools/check_release.py dist/Vette-$$(cat VERSION).lha

# Fast aggregate over retained local oracle artifacts. Slow recapture remains
# split into the dedicated reference/capture/regression targets below.
fidelity-check:
	@python3 tools/verify_stage_c_intro.py
	@python3 tools/verify_driving_planar.py
	@$(MAKE) driving-sequence-compare REQUIRE_EXACT=1
	@$(MAKE) driving-cadence-compare
	@$(MAKE) driving-palette-compare
	@$(MAKE) driving-control-audit
	@$(MAKE) driving-audio-compare
	@python3 tools/check_audio_overlap.py tmp/amiga-driving-audio-overlap.log

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

driving-view-reference:
	@test -n "$(VIEW)" || { echo "VIEW is required (for example F3 or MIRROROFF)"; exit 1; }
	@timeout -k 5 300 env SDL_VIDEODRIVER=dummy VETTE_DRIVING_MOTION=1 \
		VETTE_DRIVING_VIEW=$(VIEW) VETTE_DRIVING_VIEW_KEY='$(or $(MAC_KEY),$(VIEW))' \
		VETTE_FIDELITY_RANDOM_SEED=3BD90000 \
		mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
		-ramsize 8M -hard ref/mame/hd/608_2GB_drive.hd \
		-video none -sound none -window -skip_gameinfo -nothrottle \
		-seconds_to_run 150 -snapshot_directory ref/mame/snap \
		-cfg_directory ref/mame/cfg -nvram_directory ref/mame/nvram \
		-autoboot_script tools/mac_probe_model_indices.lua > tmp/mame-$(shell echo $(VIEW) | tr A-Z a-z).log 2>&1

driving-f1-reference:
	@$(MAKE) driving-view-reference VIEW=F1

driving-audio-reference:
	@mkdir -p tmp
	@timeout -k 5 360 env SDL_VIDEODRIVER=dummy VETTE_DRIVING_AUDIO=1 \
		VETTE_FOLLOW_ROAD=1 VETTE_FIDELITY_RANDOM_SEED=3BD90000 VETTE_AUDIO_TRACE=1 \
		mame mac2fdhd -rompath ref/mame/roms -nb9 mdc48 \
		-ramsize 8M -hard ref/mame/hd/608_2GB_drive.hd \
		-video none -sound none -window -skip_gameinfo -nothrottle \
		-seconds_to_run 150 -samplerate 48000 \
		-wavwrite tmp/vette-reference-driving.wav \
		-snapshot_directory ref/mame/snap -cfg_directory ref/mame/cfg \
		-nvram_directory ref/mame/nvram \
		-autoboot_script tools/mac_probe_model_indices.lua > tmp/mame-driving-audio.log 2>&1
	@python3 tools/audio_reference_report.py tmp/vette-reference-driving.wav

driving-audio-capture:
	@mkdir -p tmp
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FOLLOW_ROAD=1 \
	    FIDELITY_RANDOM_SEED=0x3BD90000 && \
	  GDBTAIL=240 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_audio_events.gdb \
	  ./diag_run.sh 150
	@cp amiga/.run/gdb-out.log tmp/amiga-driving-audio.log
	@python3 tools/render_paula_audio.py '$(VETTE_DATA_RSRC)' \
		tmp/amiga-driving-audio.log tmp/amiga-driving-audio.wav
	@python3 tools/audio_reference_report.py tmp/amiga-driving-audio.wav

driving-audio-compare:
	@python3 tools/compare_audio_events.py \
		tmp/mame-driving-audio.log tmp/amiga-driving-audio.log \
		--allow-additional-target-loads

driving-audio-countdown-regression:
	@mkdir -p tmp
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FOLLOW_ROAD=1 \
	    FIDELITY_RANDOM_SEED=0x3BD90000 && \
	  GDBTAIL=120 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_audio_countdown.gdb \
	  ./diag_run.sh 90
	@cp amiga/.run/gdb-out.log tmp/amiga-driving-audio-countdown.log
	@grep -q "countdown-audio PASS" tmp/amiga-driving-audio-countdown.log

# The Macintosh trace is deliberately captured separately: it is a slow oracle
# artifact, while this gate rebuilds and reruns both bounded target workloads.
driving-audio-regression:
	@test -f tmp/mame-driving-audio.log || \
	  { echo "missing tmp/mame-driving-audio.log; run make driving-audio-reference first"; exit 1; }
	@mkdir -p tmp
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 FOLLOW_ROAD=1 \
	    FIDELITY_RANDOM_SEED=0x3BD90000 && \
	  GDBTAIL=240 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_audio_events.gdb \
	  ./diag_run.sh 150
	@cp amiga/.run/gdb-out.log tmp/amiga-driving-audio.log
	@python3 tools/compare_audio_events.py \
		tmp/mame-driving-audio.log tmp/amiga-driving-audio.log \
		--allow-additional-target-loads
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 PROBES=1 SKIP_INTRO=1 GARAGE_CLICK=1 GARAGE_COURSE=2 FREEWAY_ROUTE=1 \
	    HORN_PROBE=1 FIDELITY_RANDOM_SEED=0x3BD90000 && \
	  GDBTAIL=160 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_audio_overlap.gdb \
	  ./diag_run.sh 150
	@cp amiga/.run/gdb-out.log tmp/amiga-driving-audio-overlap.log
	@python3 tools/check_audio_overlap.py tmp/amiga-driving-audio-overlap.log

driving-motion-capture:
	@rm -f tmp/driving-motion-sequence.tsv tmp/driving-motion-source-*.raw tmp/driving-motion-globals-*.bin tmp/driving-motion-car-*.bin tmp/driving-motion-object-*.bin
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 SKIP_INTRO=1 GARAGE_CLICK=1 FIDELITY_RANDOM_SEED=0x3BD90000 \
	    MOTION_CAPTURE=1 && \
	  GDBTAIL=160 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_motion_sequence.gdb \
	  ./diag_run.sh 150

driving-view-capture:
	@test -n "$(VIEW)" || { echo "VIEW is required (for example F3 or MIRROROFF)"; exit 1; }
	@test -n "$(RAW_KEY)" || { echo "RAW_KEY is required (for example 0x52 for F3)"; exit 1; }
	@rm -f tmp/driving-motion-sequence.tsv tmp/driving-motion-source-*.raw tmp/driving-motion-globals-*.bin tmp/driving-motion-car-*.bin tmp/driving-motion-object-*.bin
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 SKIP_INTRO=1 GARAGE_CLICK=1 FIDELITY_RANDOM_SEED=0x3BD90000 \
	    VIEW_CAPTURE_RAW_KEY=$(RAW_KEY) MOTION_CAPTURE=1 && \
	  GDBTAIL=160 EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_motion_sequence.gdb \
	  ./diag_run.sh 150
	@rm -f tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-sequence.tsv \
		tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-source-*.raw \
		tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-globals-*.bin \
		tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-car-*.bin \
		tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-object-*.bin
	@cp tmp/driving-motion-sequence.tsv tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-sequence.tsv
	@for kind in source globals car object; do \
	  for path in tmp/driving-motion-$$kind-*; do \
	    test -e "$$path" || continue; \
	    cp "$$path" "$${path/driving-motion/driving-$(shell echo $(VIEW) | tr A-Z a-z)}"; \
	  done; \
	done

driving-f1-capture:
	@$(MAKE) driving-view-capture VIEW=F1 RAW_KEY=0x50

driving-view-compare:
	@test -n "$(VIEW)" || { echo "VIEW is required (for example F3 or MIRROROFF)"; exit 1; }
	@python3 tools/compare_driving_sequence.py \
		ref/mame/driving-$(shell echo $(VIEW) | tr A-Z a-z)-source tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-source \
		--reference-manifest ref/mame/driving-$(shell echo $(VIEW) | tr A-Z a-z)-sequence.tsv \
		--amiga-manifest tmp/driving-$(shell echo $(VIEW) | tr A-Z a-z)-sequence.tsv \
		--match-state --state-field physics_x --state-field physics_y \
		--left 0 --top 0 --width 512 --height $(or $(HEIGHT),255) \
		--require-any-exact

driving-f1-compare:
	@$(MAKE) driving-view-compare VIEW=F1 HEIGHT=255

# Macintosh references are slow local oracle artifacts and are captured
# separately. Rebuild and rerun every target view against those references.
driving-view-regression:
	@for spec in F1:0x50 F2:0x51 F3:0x52 F4:0x53 F5:0x54 MIRROROFF:0x06; do \
	  view=$${spec%%:*}; raw=$${spec##*:}; \
	  $(MAKE) driving-view-capture VIEW=$$view RAW_KEY=$$raw || exit $$?; \
	  $(MAKE) driving-view-compare VIEW=$$view HEIGHT=255 || exit $$?; \
	done

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

# Presentation cadence changes Traffic state between machines. This narrower
# gate pairs only identical complete player states and requires at least one
# exact exterior view; the full-roster target above remains deliberately strict.
driving-motion-viewport-compare:
	@python3 tools/compare_driving_sequence.py \
		ref/mame/driving-motion-source tmp/driving-motion-source \
		--reference-manifest ref/mame/driving-motion-sequence.tsv \
		--amiga-manifest tmp/driving-motion-sequence.tsv \
		--match-state --state-field physics_x --state-field physics_y \
		--left 0 --top 0 --width 512 --height 198 \
		--require-any-exact

# Cadence is measured in the game's 60 Hz Macintosh tick domain, not host wall
# time.  The A1200 may complete fewer frames than the reference Mac, but the
# bounded target prevents an accidental presentation regression from being
# mistaken for an arbitrary "slower CPU" difference.
driving-cadence-compare:
	@python3 tools/check_driving_cadence.py \
		ref/mame/driving-motion-sequence.tsv tmp/driving-motion-sequence.tsv

driving-control-audit:
	@python3 tools/check_control_surface.py

driving-palette-compare:
	@python3 tools/check_driving_palette.py \
		'$(VETTE_APP_RSRC)' 131 tmp/f40_screen.palette
	@python3 tools/check_driving_palette.py \
		'$(VETTE_APP_RSRC)' 131 tmp/amiga_driving.palette

# The measurement freezes in target time after 300 PAL fields; 60 seconds is
# only a host-side safety ceiling for reaching and reading that frozen window.
driving-profile:
	@cd amiga && . ./env.sh && $(MAKE) clean && \
	  $(MAKE) -j4 PROBES=1 PROBEFIELDS=300 SKIP_INTRO=1 GARAGE_CLICK=1 && \
	  EXTRA_ARGS="--warp_mode=1" GDBSCRIPT=driving_phase_profile.gdb \
	  ./diag_run.sh 60
