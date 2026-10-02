.PHONY: tola canary view

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
# The model tests and the framework tests: fast, pure and shell, always
# run. Each suite prints its summary (its last lines when it fails) and
# keeps its full output in _out/canary/test/<suite>.out; the target fails
# when any suite does.
CANARY_TEST_SUITES = project-test artifact-test pm-test mutation-test cache-test
canary-test:
	@mkdir -p _out/canary/test; fail=0; \
	for s in $(CANARY_TEST_SUITES); do \
	  log=_out/canary/test/$$s.out; echo "=== $$s ==="; \
	  if $(CANARY) $$s > $$log 2>&1; then tail -1 $$log; \
	  else fail=1; tail -15 $$log; fi; \
	done; exit $$fail

# The agents' harness: the repository's own text against the code and its
# stated rules. Not canary's; agents run it before committing.
.PHONY: harness
harness:
	@eval $$(opam env) && dune exec harness/harness.exe

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
# markers of the steps that READ the evidence are removed, and the
# library build's; the fetch and the install stay warm.
# The LANDED agreements, one name per line. A row is added here only
# after a real run decided it AND a deliberate break flipped it; the
# gate then keeps it decided. Dropping the probe markers (and the lib
# probes' own output) is what stops a warm tree from answering: the
# evidence has to be produced by THIS run, in an order where the step
# that reads it runs second.
# EVERY WORLD, not --thin (2026-09-29): the rm clears every world's
# lib-probe output, and a world the gate did not re-run kept its logged
# verdicts with its inspections gone, which the overview page then drew
# without them. Measured: 25 s, against 22 s thin.
CANARY_LANDED_AGREEMENTS = api_names_present required_symbols_exported \
                           declared_symbols_exported staged_interface_preserved \
                           soname_matches_declaration soname_matches_requirement \
                           dependencies_provided

canary-agreement-roundtrip:
	@rm -f _out/canary/projects/sqlite/probe_binding/*/*.ok
	@rm -f _out/canary/projects/sqlite/probe_lib*/*.ok _out/canary/projects/sqlite/probe_lib*/*.json
	@rm -f _out/canary/projects/sqlite/build_lib/*.ok
	$(CANARY) action sqlite
	$(CANARY) checks sqlite --observed
	@for a in $(CANARY_LANDED_AGREEMENTS); do \
	  $(CANARY) checks sqlite --observed | grep -q "$$a .* \(holds\|violated\)" \
	  || { echo "ROUND-TRIP FAIL: sqlite's last run did not decide $$a." ; \
	       echo "  A decided outcome means the evidence was produced AND read," ; \
	       echo "  by steps ordered so the reader runs after the writer." ; \
	       echo "  Check 'canary emit sqlite --stage realize' for the inspect step," ; \
	       echo "  and doc/canary/design/agreement/README.md for the reasons" ; \
	       echo "  an agreement reports unavailable." ; \
	       exit 1; }; \
	done
	@echo "round-trip: sqlite decided $(CANARY_LANDED_AGREEMENTS) from a real run"

# REFRESH ONE PROJECT'S AGREEMENT OUTCOMES.
#   make canary-refresh PROJECT=cairo
# A warm step re-checks nothing and logs nothing, so a project's
# recorded outcomes outlive the registry that produced them: after
# applicability became a static property (2026-09-14) the old
# `not_applicable` lines stayed in the logs, and the result table marks
# those cells `stale`. This is how you clear them.
# It drops the markers of the steps that DECIDE — probes, binding
# builds, staging — and re-runs. Fetches and the library build stay
# warm on purpose: they are the expensive ones, they decide little, and
# re-running them from scratch is what `canary action <p>` without this
# is for. Verified on zarith 2026-09-15: three `stood down` claims, two
# of which went straight to `decided`.
CANARY_REFRESH_STEPS = probe_binding probe_binding_ocaml probe_binding_python \
                       probe_lib probe_lib_staged probe_lib_apt \
                       build_binding_ocaml build_binding_python install_lib

canary-refresh:
	@test -n "$(PROJECT)" || { echo "usage: make canary-refresh PROJECT=<name>"; exit 2; }
	@for s in $(CANARY_REFRESH_STEPS); do \
	  rm -f "_out/canary/projects/$(PROJECT)/$$s"/*.ok \
	        "_out/canary/projects/$(PROJECT)/$$s"/*/*.ok 2>/dev/null; \
	done; true
	$(CANARY) action $(PROJECT)
	@echo "refresh: $(PROJECT) re-decided its agreements — 'make view' to see the gap on the overview page (§1.2)"

# Print the live catalogue. The Agreement overview is the primary reference;
# no generated catalogue is maintained in the design docs.
.PHONY: agreement-catalogue
agreement-catalogue:
	@$(CANARY) checks --catalogue

# THE WEB VIEW — the overview page: the chain and its recorded runs (§1),
# the result table (§1.2) and the agreement overview (§2), which is the
# result table's template — an empty column there can be looked up in §2
# to see whether anything was ever meant to fill it. A pure READ of
# actions.log and the run manifests; it runs nothing.
#
# ONE PAGE since 2026-09-28 (user): the result page this also refreshed
# retired, and docs/canary/projects/ holds only the pointers the overview
# writes beside itself.
view:
	@$(CANARY) overview > /dev/null
	@echo "open docs/canary/overview.html  (the chain, its runs, the result table, the agreements)"

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
