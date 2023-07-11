all: a

# For pkgm and lang text

pi:
	dune exec bin/pkgm.exe -- info

pt:
	echo I love @ac@. | dune exec bin/text_interp.exe

tt:
	dune exec bin/text.exe

f:
	dune exec ./bin/ff.exe

bs:
	dune exec ./bin/enum.exe

s:
	./bin/enum.exe

d:
	dune exec ./bin/dd.exe

a:
	dune exec ./bin/arith_fix.exe

b:
	dune exec bin/dd_concrete.exe

c:
	dune exec bin/dd_abstract.exe

t:
	dune runtest