.PHONY: tola canary

PM_ROOT = _pm
OUT = _out
TOLA = dune exec src/bin/tola.exe --

all: tola

build:
	eval $$(opam env) && dune build

demo_langs:
	@echo "Demo languages: lt, md, shell" # dd

# Run language-specific examples

%.eg: LANG = $(basename $@)
%.eg:
	dune exec src/bin/example_$(LANG).exe -- $(ARGS)

CANARY = eval $$(opam env) && dune exec src/bin/canary_main.exe --

canary:
	$(CANARY) run

# ── Post-check tests: run after every session / before commit ──
# Fast pure + shell tests — always safe, always run.
canary-test:
	@echo "=== project-test (pure) ==="
	@$(CANARY) project-test 2>&1 | tail -3
	@echo ""
	@echo "=== artifact-test (pure + shell) ==="
	@$(CANARY) artifact-test 2>&1 | tail -2
	@echo ""
	@echo "=== pm-test (shell) ==="
	@$(CANARY) pm-test 2>&1 | tail -2

# Heavy integration tests — run less frequently, verify full pipeline.
canary-sqlite:
	$(CANARY) action sqlite

canary-z3:
	$(CANARY) action z3

canary-llvm:
	$(CANARY) action llvm

canary-tiny1-bridge:
	$(CANARY) action tiny1/symbol_missing

# THE ROUND TRIP: run a real project, then read its own log back and
# require that a named agreement actually reached a decided outcome.
# Everything else in the agreement layer describes what WOULD be
# checked; this is the only thing that shows a check ran. Pointing it
# at sqlite for the first time is what revealed that the project's
# inspectors were wired into a spec the run path never used, so every
# agreement had been reporting `unavailable`.
# It DROPS the probe's verdict markers first, then runs. That is not a
# workaround for the cache — it is what the assertion is about. A warm
# step re-checks nothing and emits no agreement outcome, so a gate that
# accepted a warm run would pass on a log written weeks ago. Only the
# markers of the step that READS the evidence are removed; the build,
# the fetch and the install stay warm, so this costs one probe.
# The LANDED agreements, one name per line. A row is added here only
# after a real run decided it AND a deliberate break flipped it; the
# gate then keeps it decided. Dropping the probe markers (and the lib
# probes' own output) is what stops a warm tree from answering: the
# evidence has to be produced by THIS run, in an order where the step
# that reads it runs second.
CANARY_LANDED_AGREEMENTS = api_names_present required_symbols_exported \
                           declared_symbols_exported staged_interface_preserved \
                           soname_matches_declaration soname_matches_requirement \
                           dependencies_provided

canary-agreement-roundtrip:
	@rm -f _out/canary/projects/sqlite/probe_binding/*/*.ok
	@rm -f _out/canary/projects/sqlite/probe_lib*/*.ok _out/canary/projects/sqlite/probe_lib*/*.json
	@rm -f _out/canary/projects/sqlite/build_lib/*.ok
	$(CANARY) action sqlite --thin
	$(CANARY) checks sqlite --observed
	@for a in $(CANARY_LANDED_AGREEMENTS); do \
	  $(CANARY) checks sqlite --observed | grep -q "$$a .* \(holds\|violated\)" \
	  || { echo "ROUND-TRIP FAIL: sqlite's last run did not decide $$a." ; \
	       echo "  A decided outcome means the evidence was produced AND read," ; \
	       echo "  by steps ordered so the reader runs after the writer." ; \
	       echo "  Check 'canary emit sqlite --stage realize' for the inspect step," ; \
	       echo "  and doc/canary/design/agreement/pipeline.md for the reasons" ; \
	       echo "  an agreement reports unavailable." ; \
	       exit 1; }; \
	done
	@echo "round-trip: sqlite decided $(CANARY_LANDED_AGREEMENTS) from a real run"

# The generated per-agreement catalogue. `make agreement-catalogue`
# rewrites it; `agreements.catalogue_doc_is_generated` fails if the file
# on disk differs from what the registry would emit, so it cannot drift.
agreement-catalogue:
	@$(CANARY) checks --catalogue --md > doc/canary/design/agreement/catalogue.md
	@echo "wrote doc/canary/design/agreement/catalogue.md"

canary-post-check: canary-sqlite canary-agreement-roundtrip canary-tiny1-bridge
	@echo "post-check: sqlite + round-trip + tiny1 bridge all passed"

canary_local:
	$(CANARY) local

# make sp.eg ARGS='yaml'
# make sp.eg ARGS='z3_src'

# you can use 
#   make sp.eg to run the example for SP language
# you can even use
#   make sp.eg ARGS="foo --bar" to pass arguments to `example_$(LANG).exe`

# Universal pkgm cmd `tola`

tola:
	$(TOLA)

## use `tola` to manage packages

lt:
	echo @p1@ | $(TOLA) lt info

e1:
	echo I love @ac@. | $(TOLA) lti

e2:
	echo @p1@. | $(TOLA) lti

# case for 
# 	echo @p2@. | $(TOLA) lti

# loop:
# 	echo @loop@. | $(TOLA) lti

## use `tola` to enhance interpreters

tola-z3:
	$(TOLA) run "z3 --version"

tola-run:
	$(TOLA) run z3 --o="$(OUT)/foo.smt"

md:
	cat test/blog.md | $(TOLA) mdi | tee $(OUT)/blog.html

shell:
	cat test/test.sh | $(TOLA) shelli

# Initialization for tola package manager root

%.init: LANG = $(basename $@)
%.init:
	@if [ -d "$(PM_ROOT)/$(LANG)_local" ] || [ -d "$(PM_ROOT)/$(LANG)_remote" ]; then \
		echo "already initialized $(LANG)"; \
	else \
		echo "initializing $(LANG)"; \
		mkdir -p $(PM_ROOT); \
		cp -r vendor/$(LANG)_local $(PM_ROOT)/$(LANG)_local; \
		cp -r vendor/$(LANG)_remote $(PM_ROOT)/$(LANG)_remote; \
	fi

# Other

t:
	dune runtest

pyp:
	python3 vendor/python/dump_syspath.py

p:
	python3 vendor/python/run_numpy.py

include Makefile.misc.mk
