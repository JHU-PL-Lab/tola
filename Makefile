.PHONY: pm_init tola

PM_ROOT = _pm_root
OUT = _out
MAIN = dune exec bin/tola.exe --

all: pi

# For pkgm e.g. make lt.pm, make md.pm

# %.pm: LANG = $(basename $@)
# %.pm:
# 	dune exec bin/$(LANG)_pm.exe -- info

# make lt.eg, make dd.eg
%.eg: LANG = $(basename $@)
%.eg:
	dune exec bin/example_$(LANG).exe

# tola:
# 	dune exec bin/tola.exe -- info

tola-z3:
	dune exec bin/tola.exe -- run "z3 --version"

tola-run:
	dune exec bin/tola.exe -- run z3 --o="$(OUT)/foo.smt"

lt:
	echo @p1@ | $(MAIN) lt info

e1:
	echo I love @ac@. | $(MAIN) lti

e2:
	echo @p1@. | $(MAIN) lti
#	echo @p2@. | $(MAIN) lti

# loop:
# 	echo @loop@. | $(MAIN) lti

md:
	cat test/blog.md | $(MAIN) mdi | tee $(OUT)/blog.html

shell:
	cat test/test.sh | $(MAIN) shelli

# Initialization
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

t:
	dune runtest

pyp:
	python3 vendor/python/dump_syspath.py

p:
	python3 vendor/python/run_numpy.py

include Makefile.cmake.mk
include Makefile.misc.mk