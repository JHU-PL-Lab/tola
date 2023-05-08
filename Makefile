all: a

s:
	dune exec ./bin/enum.exe

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