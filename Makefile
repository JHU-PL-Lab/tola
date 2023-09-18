all: pi

# For pkgm and lang text

pi:
	dune exec bin/pm.exe -- info

spi:
	dune exec bin/spm.exe -- info

pt:
	echo I love @ac@. | dune exec bin/text.exe

sd:
	echo @p1@. | dune exec bin/stext.exe
	echo @p2@. | dune exec bin/stext.exe

loop:
	# echo looping forever
	echo @loop@. | dune exec bin/stext.exe

te:
	dune exec bin/text_example.exe

DEMO_ROOT = _pm_root
NO_DEP_TEXT = $(DEMO_ROOT)/_no_dep_lt
NO_DEP_TEXT_LOCAL = $(NO_DEP_TEXT)_local
NO_DEP_TEXT_REMOTE = $(NO_DEP_TEXT)_remote

STATIC_DEP_TEXT = $(DEMO_ROOT)/_static_dep_lt
STATIC_TEXT_LOCAL = $(STATIC_DEP_TEXT)_local
STATIC_TEXT_REMOTE = $(STATIC_DEP_TEXT)_remote

pkg_init:
	rm -rf $(NO_DEP_TEXT_LOCAL)
	mkdir -p $(NO_DEP_TEXT_LOCAL)
	rm -rf $(NO_DEP_TEXT_REMOTE)
	mkdir -p $(NO_DEP_TEXT_REMOTE)
	cp -r vendor/text/ac $(NO_DEP_TEXT_LOCAL)
	cp -r vendor/text/zfc $(NO_DEP_TEXT_REMOTE)

	rm -rf $(STATIC_TEXT_LOCAL)
	mkdir -p $(STATIC_TEXT_LOCAL)
	rm -rf $(STATIC_TEXT_REMOTE)
	mkdir -p $(STATIC_TEXT_REMOTE)
	cp -r vendor/stext/* $(STATIC_TEXT_LOCAL)
	cp -r vendor/stext/* $(STATIC_TEXT_REMOTE)

# Enum 

en1:
	dune exec ./bin/enum1.exe

en2:
	dune exec ./bin/enum2.exe -- -l 3 -d 2

# Lambda Core

d:
	dune exec ./bin/dd.exe

# Program analysis via fix

af:
	dune exec ./bin/arith_fix.exe

t:
	dune runtest