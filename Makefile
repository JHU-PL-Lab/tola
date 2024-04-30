OUT = _out

all: pi

# For pkgm e.g. make lt.pm, make md.pm

%.pm: LANG = $(basename $@)
%.pm:
	dune exec bin/$(LANG)pm.exe -- info

# Examples

e1:
	echo I love @ac@. | dune exec bin/lt.exe

e2:
	echo @p1@. | dune exec bin/lts.exe
	echo @p2@. | dune exec bin/lts.exe

loop:
	echo @loop@. | dune exec bin/lts.exe

te:
	dune exec bin/lt_example.exe

md:
	cat test/blog.md | dune exec bin/md.exe | tee $(OUT)/blog.html

shell:
	cat test/test.sh | dune exec bin/shell.exe

# Pkgm vars

DEMO_ROOT = _pm_root
NO_DEP_TEXT = $(DEMO_ROOT)/_no_dep_lt
NO_DEP_TEXT_LOCAL = $(NO_DEP_TEXT)_local
NO_DEP_TEXT_REMOTE = $(NO_DEP_TEXT)_remote

STATIC_DEP_TEXT = $(DEMO_ROOT)/_static_dep_lt
STATIC_DEP_TEXT_LOCAL = $(STATIC_DEP_TEXT)_local
STATIC_DEP_TEXT_REMOTE = $(STATIC_DEP_TEXT)_remote

STATIC_MARKDOWN = $(DEMO_ROOT)/_static_md
STATIC_MARKDOWN_LOCAL = $(STATIC_MARKDOWN)_local
STATIC_MARKDOWN_REMOTE = $(STATIC_MARKDOWN)_remote

STATIC_SHELL = $(DEMO_ROOT)/_static_shell
STATIC_SHELL_LOCAL = $(STATIC_SHELL)_local
STATIC_SHELL_REMOTE = $(STATIC_SHELL)_remote

# Initialization
pkg_init_out:
	@mkdir -p _out

pkg_init_no_dep_text:
	@rm -rf   $(NO_DEP_TEXT_LOCAL) $(NO_DEP_TEXT_REMOTE)
	@mkdir -p $(NO_DEP_TEXT_LOCAL) $(NO_DEP_TEXT_REMOTE)
	@cp -r vendor/text/ac $(NO_DEP_TEXT_LOCAL)
	@cp -r vendor/text/zfc $(NO_DEP_TEXT_REMOTE)
	@echo 'init no_dep_text'

pkg_init_static_text:
	@rm -rf   $(STATIC_DEP_TEXT_LOCAL) $(STATIC_DEP_TEXT_REMOTE)
	@mkdir -p $(STATIC_DEP_TEXT_LOCAL) $(STATIC_DEP_TEXT_REMOTE)
	@cp -r vendor/stext/* $(STATIC_DEP_TEXT_LOCAL)
	@cp -r vendor/stext/* $(STATIC_DEP_TEXT_REMOTE)
	@echo 'init static_text'

pkg_init_md:
	@rm -rf   $(STATIC_MARKDOWN_LOCAL) $(STATIC_MARKDOWN_REMOTE)
	@mkdir -p $(STATIC_MARKDOWN_LOCAL) $(STATIC_MARKDOWN_REMOTE)
	@cp -r vendor/md/* $(STATIC_MARKDOWN_LOCAL)
	@cp -r vendor/md/* $(STATIC_MARKDOWN_LOCAL)
	@echo 'init static_markdown'

pkg_init_shell:
	@rm -rf $(STATIC_SHELL_LOCAL) $(STATIC_SHELL_REMOTE)
	@mkdir -p $(STATIC_SHELL_LOCAL) $(STATIC_SHELL_REMOTE)
	@cp -r vendor/shell/* $(STATIC_SHELL_LOCAL)
	@echo 'init static_shell'

.PHONY: pkg_init
pkg_init: pkg_init_out pkg_init_no_dep_text pkg_init_static_text pkg_init_md pkg_init_shell

# Lambda Core

d:
	dune exec ./bin/dd.exe

af:
	dune exec ./bin/arith_fix.exe

t:
	dune runtest

pyp:
	python3 vendor/python/dump_syspath.py

p:
	python3 vendor/python/run_numpy.py