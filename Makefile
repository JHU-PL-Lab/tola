all: a

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