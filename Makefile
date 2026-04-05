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

canary-sqlite:
	$(CANARY) action sqlite

canary-z3:
	$(CANARY) action z3

canary-llvm:
	$(CANARY) action llvm

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

include Makefile.cmake.mk
include Makefile.misc.mk
