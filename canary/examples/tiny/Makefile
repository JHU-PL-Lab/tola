# Build orchestration for the tiny example.
#
# Targets:
#   c              build libtiny.so.1 in c/build/
#   ocaml          build the OCaml binding   (static cstubs, depends on c)
#   python_cext    build the Python C-ext    (static, depends on c)
#   python_ctypes  no-op (ctypes binding is pure .py — depends on c at runtime)
#   probe          run all three baseline probes
#   inspect        run canary inspectors on each surface
#   baseline       populate scenarios/_cache/baseline/ via `canary tiny-scenarios baseline`
#   prepare-<name> populate scenarios/_cache/<name>/ via `canary tiny-scenarios prepare`
#   prepare-all    populate every scenario cache
#   scenario-list  list scenario names
#   clean          remove build trees
#
# Running scenarios goes through canary directly:
#   dune exec src/bin/canary_main.exe -- action tiny            (all variants)
#   dune exec src/bin/canary_main.exe -- action tiny/<variant>  (one variant)
#
# The legacy Python harness (scenarios.py + _harness/run.sh + run_cached.py)
# was archived under doc/_legacy_code/tiny_python_harness/ at Phase E of the
# tiny migration (see doc/canary/design/tiny_migration.md §9); the OCaml
# path fully supersedes it.

C_BUILD := c/build
LIB     := $(C_BUILD)/libtiny.so.1

LIBPATH := $(abspath $(C_BUILD))
RUNENV  := LD_LIBRARY_PATH=$(LIBPATH)$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}

# dune places artifacts under the project root's _build/, not the example dir's.
PROJ_ROOT   := $(abspath ../../..)
OCAML_BUILD := $(PROJ_ROOT)/_build/default/canary/examples/tiny/ocaml

# Invoke canary from the tola project root.
CANARY := cd $(PROJ_ROOT) && eval $$(opam env) && dune exec src/bin/canary_main.exe --

.PHONY: all c ocaml python_cext python_ctypes probe probe-ocaml probe-python-cext probe-python-ctypes inspect clean scenario-list baseline prepare-all

all: c ocaml python_cext

c: $(LIB)

$(LIB): c/src/tiny.c c/include/tiny.h c/CMakeLists.txt
	cmake -S c -B $(C_BUILD)
	cmake --build $(C_BUILD)

ocaml: c
	cd ocaml && LIBRARY_PATH=$(LIBPATH)$${LIBRARY_PATH:+:$$LIBRARY_PATH} \
	            LD_RUN_PATH=$(LIBPATH)$${LD_RUN_PATH:+:$$LD_RUN_PATH} \
	            dune build

PY_EXT_SUFFIX := $(shell python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))')
CEXT_SO       := python_cext/tiny_cext/_native$(PY_EXT_SUFFIX)
CEXT_BUILT    := python_cext/build/lib.linux-x86_64-cpython-$(shell python3 -c 'import sys;print(f"{sys.version_info.major}{sys.version_info.minor}")')/tiny_cext/_native$(PY_EXT_SUFFIX)

python_cext: $(CEXT_SO)

# Build the CPython C extension via PEP 517 (setuptools backend from
# pyproject.toml). uv brings setuptools into a temporary build env;
# no setuptools install in the project Python required. Then copy the
# built .so back next to __init__.py for in-place imports
# (PYTHONPATH=python_cext).
$(CEXT_SO): python_cext/tiny_cext/_native.c $(LIB) c/include/tiny.h python_cext/pyproject.toml python_cext/setup.py
	cd python_cext && uv build --wheel >/dev/null
	cp $(CEXT_BUILT) $(CEXT_SO)

python_ctypes:
	@true   # pure Python; nothing to build

probe: probe-ocaml probe-python-cext probe-python-ctypes

probe-ocaml: ocaml
	$(RUNENV) $(OCAML_BUILD)/examples/probe_baseline.exe

probe-python-cext: python_cext
	$(RUNENV) PYTHONPATH=python_cext python3 python_cext/examples/probe_baseline.py

probe-python-ctypes: c
	$(RUNENV) PYTHONPATH=python_ctypes python3 python_ctypes/examples/probe_baseline.py

inspect: c ocaml python_cext
	@echo "==> native library  (Symbol + ABI surfaces of libtiny.so.1)"
	nm -D $(LIB) | python3 ../../scripts/inspect_native.py --path $(LIB) --prefixes tiny_ --elf --emit-symbols
	@echo
	@echo "==> OCaml user-facing .mli (API-completeness surface)"
	python3 ../../scripts/inspect_binding.py --kind mli --path ocaml/tiny.mli
	@echo
	@echo "==> OCaml stub-facing .mli (Type surface — externals)"
	python3 ../../scripts/inspect_binding.py --kind mli --path ocaml/tiny_raw.mli
	@echo
	@echo "==> OCaml stub .a (Symbol surface — undefined refs)"
	-@find $(PROJ_ROOT)/_build/default/canary/examples/tiny/ocaml -name 'libtiny_stubs*.a' \
	    -exec python3 ../../scripts/inspect_binding.py --kind stub --path {} --prefix tiny_ \;
	@echo
	@echo "==> OCaml .cmxa modules (s5 binding_lib modules)"
	-@find $(PROJ_ROOT)/_build/default/canary/examples/tiny/ocaml -name 'tiny.cmxa' \
	    -exec python3 ../../scripts/inspect_ocaml.py --path {} \;
	@echo
	@echo "==> cext _native.so (s5 binding_lib ELF — i1 reused on a binding artifact)"
	-@find python_cext/tiny_cext -name '_native.cpython-*.so' \
	    -exec sh -c 'nm -D "$$1" | python3 ../../scripts/inspect_native.py --path "$$1" --prefixes tiny_ --elf --emit-symbols' _ {} \;
	@echo
	@echo "==> Python ctypes binding (dir(tiny_ctypes) — API-completeness)"
	$(RUNENV) PYTHONPATH=python_ctypes python3 ../../scripts/inspect_python.py --pkg tiny_ctypes
	@echo
	@echo "==> Python cext binding   (dir(tiny_cext)   — API-completeness)"
	$(RUNENV) PYTHONPATH=python_cext python3 ../../scripts/inspect_python.py --pkg tiny_cext

# Scenario cache management — routes through canary (OCaml). See
# doc/canary/design/tiny_migration.md §9 for the migration history.
scenario-list:
	@$(CANARY) tiny-scenarios list | sed 's/^/  /'

baseline:
	$(CANARY) tiny-scenarios baseline

prepare-%:
	$(CANARY) tiny-scenarios prepare $*

prepare-all:
	$(CANARY) tiny-scenarios prepare-all

clean:
	rm -rf $(C_BUILD)
	cd ocaml && dune clean
	rm -rf python_cext/build python_cext/dist python_cext/tiny_cext.egg-info
	rm -f python_cext/tiny_cext/_native*.so
	find python_cext python_ctypes -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
