all: bi

# For pkgm and lang text

bi:
	dune exec bin/bpm.exe -- info

ni:
	dune exec bin/npm.exe -- info

pt:
	echo I love @ac@. | dune exec bin/text.exe

te:
	dune exec bin/text_example.exe

pkg_init:
	mkdir -p _local_root_text
	rm -rf _local_root_text/*
	mkdir -p _remote_root_text
	rm -rf _remote_root_text/*
	cp -r vendor/text/ac _local_root_text
	cp -r vendor/text/zfc _remote_root_text

# OCaml IR zoo

ir:
	dune exec bin/ocaml_ir/oir.exe

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