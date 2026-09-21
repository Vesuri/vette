# Vette! — host build + repo-level targets.
#
# ⚠ THE HOST BUILD IS AN OPEN DECISION (PROJECT.md §Open decisions #6).  RoF had an SDL backend
# and its approximation cost real time on bugs that existed only in the approximation; Revs
# deliberately had NO renderer and used the host purely for differentials.  This port's
# differentials are different again — there is no transliteration oracle to compare against — so
# the question is genuinely open, and this Makefile does not pre-answer it by growing a backend.
#
# The Amiga build is in amiga/ and is the real target: `cd amiga && . ./env.sh && make`.

.PHONY: all todo driving-sequence-compare help

all: help

help:
	@echo "Vette! — Macintosh 68000 -> Amiga port"
	@echo
	@echo "  make todo     what is open (docs/open-work.md + a live marker sweep)"
	@echo "  make driving-sequence-compare  compare saved MAME/Amiga driving frames"
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

# The captures are local evidence under ignored ref/ and tmp/ trees.  This target deliberately
# reports differences by default: after the exact named first frame, the first useful output is
# the earliest divergence to investigate.  Pass REQUIRE_EXACT=1 to turn it into a regression gate.
driving-sequence-compare:
	@python3 tools/compare_driving_sequence.py \
		ref/mame/driving-copy-source tmp/driving-copy-source \
		$(if $(REQUIRE_EXACT),--require-exact,)
