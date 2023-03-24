all: a

a:
	dune exec ./bin/arith_fix.exe

b:
	dune exec bin/dd_concrete.exe

c:
	dune exec bin/dd_abstract.exe

t:
	dune runtest