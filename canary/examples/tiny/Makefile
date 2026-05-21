# Build orchestration for the tiny example.
#
# Targets:
#   c             build libtiny.so.1 in c/build/
#   ocaml         build the OCaml binding   (static cstubs, depends on c)
#   python_cext   build the Python C-ext   (static, depends on c)
#   python_ctypes no-op (ctypes binding is pure .py — depends on c at runtime)
#   probe         run all three baseline probes
#   inspect       run canary inspectors on each surface
#   scenarios     run every wired scenario
#   clean         remove build trees

C_BUILD := c/build
LIB     := $(C_BUILD)/libtiny.so.1

LIBPATH := $(abspath $(C_BUILD))
RUNENV  := LD_LIBRARY_PATH=$(LIBPATH)$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}

# dune places artifacts under the project root's _build/, not the example dir's.
PROJ_ROOT   := $(abspath ../../..)
OCAML_BUILD := $(PROJ_ROOT)/_build/default/canary/examples/tiny/ocaml

SCENARIOS := $(shell python3 scenarios/scenarios.py list 2>/dev/null)

.PHONY: all c ocaml python_cext python_ctypes probe probe-ocaml probe-python-cext probe-python-ctypes inspect clean scenarios scenario-list

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

scenario-list:
	@python3 scenarios/scenarios.py list | sed 's/^/  /'

scenario-%: c ocaml python_cext
	bash scenarios/_harness/run.sh $*

scenarios: c ocaml python_cext
	@fail=0; \
	for s in $(SCENARIOS); do \
	    out=$$(bash scenarios/_harness/run.sh $$s 2>&1); \
	    if echo "$$out" | grep -q '^PASS$$'; then \
	      echo "PASS  $$s"; \
	    else \
	      echo "FAIL  $$s"; echo "$$out" | sed 's/^/    /'; fail=$$((fail+1)); \
	    fi; \
	done; \
	if [ $$fail -gt 0 ]; then echo "$$fail scenario(s) failed" >&2; exit 1; fi

clean:
	rm -rf $(C_BUILD)
	cd ocaml && dune clean
	rm -rf python_cext/build python_cext/dist python_cext/tiny_cext.egg-info
	rm -f python_cext/tiny_cext/_native*.so
	find python_cext python_ctypes -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
