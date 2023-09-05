all: pi

# For pkgm and lang text

pm:
	dune exec bin/pm.exe -- info

pi:
	dune exec bin/pmm.exe -- info

pt:
	echo I love @ac@. | dune exec bin/text_interp.exe

tt:
	dune exec bin/text.exe

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