# non pkgm-related code
# mainly for other tola stuff.

CANARY_Z3_PREFIX ?= /home/ex/code/ocaml-build-examples/vendor/z3/.helper/z3_root
CANARY_Z3_SRC ?= git+file:///home/ex/code/ocaml-build-examples/vendor/z3
CANARY_Z3_WORKTREE ?= /home/ex/code/ocaml-build-examples/vendor/z3
CANARY_Z3_BUILD_DIR ?= $(CANARY_Z3_WORKTREE)/build
CANARY_Z3_SYSTEM_LIB ?= $(shell pkg-config --variable=libdir z3 2>/dev/null)/libz3.so
CANARY_OPAM_REPO_DIR ?= _out/canary/opam-local-repo
CANARY_OPAM_REPO_NAME ?= local-z3-dev
CANARY_Z3_PKG_DIR = $(CANARY_OPAM_REPO_DIR)/packages/z3/z3.dev
CANARY_BUILD_Z3_IN_OPAM ?= cmake -G Ninja -S . -B build -DZ3_BUILD_EXECUTABLE=OFF -DZ3_LINK_TIME_OPTIMIZATION=ON -DZ3_BUILD_LIBZ3_CORE=OFF -DZ3_ROOT=\"\$$Z3_PREFIX\" -DZ3_BUILD_OCAML_BINDINGS=TRUE -DZ3_BUILD_PYTHON_BINDINGS=FALSE

.PHONY: canary.opam.repo canary.opam.install canary.opam.test canary.ci.install.cmd canary.ci.install.local canary.ci.native.link.cmd canary.ci.native.link.local canary.symcheck.cmd canary.symcheck.local

canary.opam.repo:
	mkdir -p "$(CANARY_Z3_PKG_DIR)"
	cp -f canary/templates/opam-local-repo/packages/z3/z3.dev/opam "$(CANARY_Z3_PKG_DIR)/opam.in"
	cp -f canary/templates/opam-local-repo/packages/z3/z3.dev/opam "$(CANARY_Z3_PKG_DIR)/opam"
	cp -f canary/templates/opam-local-repo/repo "$(CANARY_OPAM_REPO_DIR)/repo"
	OPAMVAR_CANARY_Z3_SRC="$(CANARY_Z3_SRC)" OPAMVAR_BUILD_Z3_IN_OPAM="$(CANARY_BUILD_Z3_IN_OPAM)" opam config subst "$(CANARY_Z3_PKG_DIR)/opam"
	@echo "local repo ready at $(CANARY_OPAM_REPO_DIR)"

canary.opam.install: canary.opam.repo
	@test -d "$(CANARY_Z3_PREFIX)/lib" || (echo "missing CANARY_Z3_PREFIX lib dir: $(CANARY_Z3_PREFIX)" && exit 1)
	eval "$$(opam env)" && \
	opam repo add "$(CANARY_OPAM_REPO_NAME)" "file://$(PWD)/$(CANARY_OPAM_REPO_DIR)" --rank=1 || \
	opam repo set-url "$(CANARY_OPAM_REPO_NAME)" "file://$(PWD)/$(CANARY_OPAM_REPO_DIR)"
	eval "$$(opam env)" && opam update "$(CANARY_OPAM_REPO_NAME)"
	eval "$$(opam env)" && Z3_PREFIX="$(CANARY_Z3_PREFIX)" opam remove -y z3.dev || true
	eval "$$(opam env)" && Z3_PREFIX="$(CANARY_Z3_PREFIX)" opam install -y z3.dev --verbose

canary.opam.test:
	eval "$$(opam env)" && ocamlfind list | grep '^z3'
	printf 'let () = ()\n' > _out/canary_z3_smoke.ml
	eval "$$(opam env)" && ocamlfind ocamlc -package z3 -linkpkg -o _out/canary_z3_smoke.byte _out/canary_z3_smoke.ml
	eval "$$(opam env)" && ocamlrun ./_out/canary_z3_smoke.byte

canary.ci.install.cmd:
	@printf '%s\n' \
	'eval $$(opam env)' \
	'OPAMVAR_CANARY_Z3_SRC="git+file://$$PWD" opam config subst contrib/canary/opam-local-repo/packages/z3/z3.dev/opam' \
	'opam repo add local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo" --rank=1 || opam repo set-url local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo"' \
	'opam update local-z3-dev' \
	'opam remove -y z3.dev || true' \
	'Z3_PREFIX="$${Z3_PREFIX:-'"$(CANARY_Z3_PREFIX)"'}" opam install -y z3.dev --verbose'

canary.ci.install.local:
	$(MAKE) sp.eg ARGS='canary'
	cd "$(CANARY_Z3_WORKTREE)" && \
	eval "$$(opam env)" && \
	OPAMVAR_CANARY_Z3_SRC="git+file://$$PWD" opam config subst contrib/canary/opam-local-repo/packages/z3/z3.dev/opam && \
	(opam repo add local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo" --rank=1 || opam repo set-url local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo") && \
	opam update local-z3-dev && \
	opam remove -y z3.dev || true && \
	Z3_PREFIX="$${Z3_PREFIX:-$(CANARY_Z3_PREFIX)}" opam install -y z3.dev --verbose

canary.ci.native.link.cmd:
	@printf '%s\n' \
	'cd "$(CANARY_Z3_WORKTREE)"' \
	'eval $$(opam env)' \
	'OPAMVAR_CANARY_Z3_SRC="git+file://$$PWD" opam config subst contrib/canary/opam-local-repo/packages/z3/z3.dev/opam' \
	'opam repo add local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo" --rank=1 || opam repo set-url local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo"' \
	'opam update local-z3-dev' \
	'Z3_PREFIX="$${Z3_PREFIX:-/usr}" Z3_LIB_DIR="$${Z3_LIB_DIR:-$$(pkg-config --variable=libdir z3)}" opam reinstall -y z3.dev --verbose' \
	'eval $$(opam env)' \
	'ocamlfind ocamlopt -o ml_example_with_pkg -package z3 -linkpkg examples/ml/ml_example.ml'

canary.ci.native.link.local:
	$(MAKE) sp.eg ARGS='canary'
	cd "$(CANARY_Z3_WORKTREE)" && \
	eval "$$(opam env)" && \
	OPAMVAR_CANARY_Z3_SRC="git+file://$$PWD" opam config subst contrib/canary/opam-local-repo/packages/z3/z3.dev/opam && \
	(opam repo add local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo" --rank=1 || opam repo set-url local-z3-dev "file://$$PWD/contrib/canary/opam-local-repo") && \
	opam update local-z3-dev && \
	Z3_PREFIX="$${Z3_PREFIX:-/usr}" Z3_LIB_DIR="$${Z3_LIB_DIR:-$$(pkg-config --variable=libdir z3)}" opam reinstall -y z3.dev --verbose && \
	eval "$$(opam env)" && \
	ocamlfind ocamlopt -o ml_example_with_pkg -package z3 -linkpkg examples/ml/ml_example.ml

canary.symcheck.cmd:
	@printf '%s\n' \
	'python3 "$(CURDIR)/canary/scripts/assert_z3_symbols.py" \' \
	'  --required-lib "$(CANARY_Z3_BUILD_DIR)/src/api/ml/dllz3ml.so" \' \
	'  --required-lib "$(CANARY_Z3_BUILD_DIR)/src/api/ml/libz3ml.a" \' \
	'  --provided-lib "$(CANARY_Z3_SYSTEM_LIB)"'

canary.symcheck.local:
	python3 "$(CURDIR)/canary/scripts/assert_z3_symbols.py" \
	  --required-lib "$(CANARY_Z3_BUILD_DIR)/src/api/ml/dllz3ml.so" \
	  --required-lib "$(CANARY_Z3_BUILD_DIR)/src/api/ml/libz3ml.a" \
	  --provided-lib "$(CANARY_Z3_SYSTEM_LIB)"

dd:
	dune exec ./src/bin/dd.exe

af:
	dune exec ./src/bin/arith_fix.exe

tf:
	dune exec ./src/bin/test_fix.exe
