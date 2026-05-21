#!/bin/bash
# Run a single scenario: apply -> rebuild (if needed) -> inspect -> compare ->
# probe -> diff against expected -> revert.
#
# Usage:  scenarios/_harness/run.sh <scenario-name>
#
# Per-scenario directory layout: apply.sh / revert.sh / expected.json plus a
# README.md and (for source-patch scenarios) a change.patch.
#
# Outcomes recorded:
#   ocaml_build            dune build success after apply
#   ocaml_probe            OCaml probe_baseline exit (ok|fail|skip)
#   ocaml_app_binding      e12 app_binding exit (app over Tiny binding)
#   ocaml_app_helper       e13 app_helper exit (app over tiny_helper over Tiny)
#   python_cext_probe      cext probe exit
#   python_ctypes_probe    ctypes probe exit
#   cmp_symbol_ocaml       c1 against OCaml stub .a vs native lib
#   cmp_symbol_cext        c1 against cext .so vs native lib
#   cmp_api_complete_ocaml c2 against tiny.mli vs watchlist
#   cmp_api_complete_cext  c2 against dir(tiny_cext) vs watchlist
#   cmp_api_complete_ctypes c2 against dir(tiny_ctypes) vs watchlist
#
# Revert runs unconditionally on exit.
set -uo pipefail

if [ $# -ne 1 ]; then
    echo "usage: $0 <scenario-name>" >&2
    exit 2
fi

SCENARIO="$1"
HARNESS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCENARIOS_DIR="$(cd "$HARNESS_DIR/.." && pwd)"
TINY_DIR="$(cd "$SCENARIOS_DIR/.." && pwd)"
PROJ_ROOT="$(cd "$TINY_DIR/../../.." && pwd)"
INSPECTORS_DIR="$PROJ_ROOT/canary/scripts"

cd "$TINY_DIR"

LIBPATH="$TINY_DIR/c/build"
OCAML_BUILD_DIR="$PROJ_ROOT/_build/default/canary/examples/tiny/ocaml"
OCAML_PROBE="$OCAML_BUILD_DIR/examples/probe_baseline.exe"
OCAML_APP_BINDING_EXE="$OCAML_BUILD_DIR/examples/app_binding.exe"
OCAML_APP_HELPER_EXE="$OCAML_BUILD_DIR/examples/app_helper.exe"

WATCHLIST="sum,diff,offset"
TMPDIR_RUN=$(mktemp -d)

if ! python3 scenarios/scenarios.py list | grep -qx "$SCENARIO"; then
    echo "no such scenario: $SCENARIO (try: python3 scenarios/scenarios.py list)" >&2
    exit 2
fi

echo "==> scenario: $SCENARIO"

EXPECTED_JSON="$TMPDIR_RUN/expected.json"
python3 scenarios/scenarios.py expected "$SCENARIO" > "$EXPECTED_JSON"

cleanup() {
    echo "--- revert"
    python3 scenarios/scenarios.py revert "$SCENARIO" || echo "WARN: revert failed" >&2
    rm -rf "$TMPDIR_RUN"
}
trap cleanup EXIT

echo "--- apply"
python3 scenarios/scenarios.py apply "$SCENARIO"

# Locate the current native lib (apply may have renamed it).
NATIVE_LIB=$(find "$LIBPATH" -maxdepth 1 -type f -name 'libtiny.so.*.0' 2>/dev/null | head -1)
if [ -z "$NATIVE_LIB" ]; then
    NATIVE_LIB=""  # may legitimately not exist for some scenarios
    echo "    note: no libtiny.so.*.0 file found at $LIBPATH"
fi

echo "--- ocaml build (post-apply)"
if (cd ocaml && \
    LIBRARY_PATH="$LIBPATH${LIBRARY_PATH:+:$LIBRARY_PATH}" \
    LD_RUN_PATH="$LIBPATH${LD_RUN_PATH:+:$LD_RUN_PATH}" \
    dune build 2>&1); then
    OCAML_BUILD=ok
else
    OCAML_BUILD=fail
fi
echo "    -> $OCAML_BUILD"

# ----- Inspectors (collect JSONs for comparators) -----
echo "--- inspectors"

# i1 on native lib (if it exists)
if [ -n "$NATIVE_LIB" ]; then
    nm -D "$NATIVE_LIB" | python3 "$INSPECTORS_DIR/inspect_native.py" \
        --path "$NATIVE_LIB" --prefixes tiny_ --elf --emit-symbols \
        > "$TMPDIR_RUN/native.json" 2>/dev/null
    echo "    i1 native_lib  -> $TMPDIR_RUN/native.json"
fi

# i3 on OCaml stub .a (always at the same path under _build)
OCAML_STUB_A=$(find "$OCAML_BUILD_DIR" -name 'libtiny_stubs*.a' 2>/dev/null | head -1)
if [ -n "$OCAML_STUB_A" ]; then
    python3 "$INSPECTORS_DIR/inspect_binding.py" --kind stub --path "$OCAML_STUB_A" --prefix tiny_ \
        > "$TMPDIR_RUN/ocaml_stub.json" 2>/dev/null
    echo "    i3 ocaml_stubref -> $TMPDIR_RUN/ocaml_stub.json"
fi

# i1 reused on cext .so (the cext compiled binding is an ELF with undef refs).
# nm -u lists undefined symbols only; mimic the inspect_binding stub-kind shape
# so cmp_symbol can read it uniformly.
CEXT_SO=$(find python_cext/tiny_cext -name '_native.cpython-*.so' 2>/dev/null | head -1)
if [ -n "$CEXT_SO" ]; then
    nm -u "$CEXT_SO" | awk '/^[[:space:]]*U /{print $NF}' | sort -u | \
        python3 -c "
import json, sys
syms = [l.strip() for l in sys.stdin if l.strip() and l.strip().startswith('tiny_')]
json.dump({'kind': 'c_stub', 'path': '$CEXT_SO', 'counts': {'required': len(syms)}, 'requires': sorted(syms)}, sys.stdout, indent=2)
" > "$TMPDIR_RUN/cext_stub.json"
    echo "    i1' cext .so undef -> $TMPDIR_RUN/cext_stub.json"
fi

# i2 on tiny.mli (user-facing vals)
python3 "$INSPECTORS_DIR/inspect_binding.py" --kind mli --path ocaml/tiny.mli \
    > "$TMPDIR_RUN/ocaml_user.json" 2>/dev/null
echo "    i2 ocaml_user  -> $TMPDIR_RUN/ocaml_user.json"

# i5 on python user-facing packages
for pkg in tiny_cext tiny_ctypes; do
    LD_LIBRARY_PATH="$LIBPATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
        PYTHONPATH="python_$( [ "$pkg" = tiny_cext ] && echo cext || echo ctypes )" \
        python3 "$INSPECTORS_DIR/inspect_python.py" --pkg "$pkg" \
        > "$TMPDIR_RUN/python_${pkg#tiny_}_user.json" 2>/dev/null || true
    echo "    i5 python_user ($pkg) -> $TMPDIR_RUN/python_${pkg#tiny_}_user.json"
done

# ----- Comparators -----
echo "--- comparators"

run_cmp() {
    local label="$1"; shift
    "$@" > /dev/null 2>&1
    case $? in
        0) echo "pass" ;;
        2) echo "skip" ;;
        *) echo "fail" ;;
    esac
}

# c1 cmp_symbol — OCaml stub vs native lib
if [ -f "$TMPDIR_RUN/native.json" ] && [ -f "$TMPDIR_RUN/ocaml_stub.json" ]; then
    CMP_SYMBOL_OCAML=$(run_cmp c1_ocaml \
        python3 "$HARNESS_DIR/comparators/cmp_symbol.py" \
        --native "$TMPDIR_RUN/native.json" --consumer "$TMPDIR_RUN/ocaml_stub.json" --prefix tiny_)
else
    CMP_SYMBOL_OCAML=skip
fi
echo "    c1 cmp_symbol (ocaml)  -> $CMP_SYMBOL_OCAML"

# c1 cmp_symbol — cext .so vs native lib
if [ -f "$TMPDIR_RUN/native.json" ] && [ -f "$TMPDIR_RUN/cext_stub.json" ]; then
    CMP_SYMBOL_CEXT=$(run_cmp c1_cext \
        python3 "$HARNESS_DIR/comparators/cmp_symbol.py" \
        --native "$TMPDIR_RUN/native.json" --consumer "$TMPDIR_RUN/cext_stub.json" --prefix tiny_)
else
    CMP_SYMBOL_CEXT=skip
fi
echo "    c1 cmp_symbol (cext)   -> $CMP_SYMBOL_CEXT"

# c2 cmp_api_completeness — OCaml user-facing vs watchlist
CMP_API_OCAML=$(run_cmp c2_ocaml \
    python3 "$HARNESS_DIR/comparators/cmp_api_completeness.py" \
    --user "$TMPDIR_RUN/ocaml_user.json" --field vals --watchlist "$WATCHLIST")
echo "    c2 cmp_api_complete (ocaml)  -> $CMP_API_OCAML"

# c2 cmp_api_completeness — cext user-facing vs watchlist
if [ -s "$TMPDIR_RUN/python_cext_user.json" ]; then
    CMP_API_CEXT=$(run_cmp c2_cext \
        python3 "$HARNESS_DIR/comparators/cmp_api_completeness.py" \
        --user "$TMPDIR_RUN/python_cext_user.json" --field attrs --watchlist "$WATCHLIST")
else
    CMP_API_CEXT=skip
fi
echo "    c2 cmp_api_complete (cext)   -> $CMP_API_CEXT"

# c2 cmp_api_completeness — ctypes user-facing vs watchlist
if [ -s "$TMPDIR_RUN/python_ctypes_user.json" ]; then
    CMP_API_CTYPES=$(run_cmp c2_ctypes \
        python3 "$HARNESS_DIR/comparators/cmp_api_completeness.py" \
        --user "$TMPDIR_RUN/python_ctypes_user.json" --field attrs --watchlist "$WATCHLIST")
else
    CMP_API_CTYPES=skip
fi
echo "    c2 cmp_api_complete (ctypes) -> $CMP_API_CTYPES"

# ----- Probes -----
echo "--- probes"

run_ocaml_exe() {
    local exe="$1"
    if [ "$OCAML_BUILD" = "ok" ] && [ -x "$exe" ]; then
        if LD_LIBRARY_PATH="$LIBPATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
            "$exe" > /tmp/tiny_probe.out 2>&1; then
            echo ok
        else
            echo fail
        fi
        sed 's/^/    /' /tmp/tiny_probe.out >&2
    else
        echo skip
    fi
}

OCAML_PROBE_RUN=$(run_ocaml_exe "$OCAML_PROBE")
echo "    ocaml probe       -> $OCAML_PROBE_RUN"

OCAML_APP_BINDING=$(run_ocaml_exe "$OCAML_APP_BINDING_EXE")
echo "    ocaml app_binding -> $OCAML_APP_BINDING"

OCAML_APP_HELPER=$(run_ocaml_exe "$OCAML_APP_HELPER_EXE")
echo "    ocaml app_helper  -> $OCAML_APP_HELPER"

if LD_LIBRARY_PATH="$LIBPATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    PYTHONPATH=python_cext \
    python3 python_cext/examples/probe_baseline.py > /tmp/tiny_probe.out 2>&1; then
    PYTHON_CEXT_PROBE=ok
else
    PYTHON_CEXT_PROBE=fail
fi
sed 's/^/    /' /tmp/tiny_probe.out
echo "    cext probe -> $PYTHON_CEXT_PROBE"

if LD_LIBRARY_PATH="$LIBPATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    PYTHONPATH=python_ctypes \
    python3 python_ctypes/examples/probe_baseline.py > /tmp/tiny_probe.out 2>&1; then
    PYTHON_CTYPES_PROBE=ok
else
    PYTHON_CTYPES_PROBE=fail
fi
sed 's/^/    /' /tmp/tiny_probe.out
echo "    ctypes probe -> $PYTHON_CTYPES_PROBE"

echo "--- compare"
python3 "$HARNESS_DIR/check.py" \
    "$EXPECTED_JSON" \
    --ocaml-build              "$OCAML_BUILD" \
    --ocaml-probe              "$OCAML_PROBE_RUN" \
    --ocaml-app-binding        "$OCAML_APP_BINDING" \
    --ocaml-app-helper         "$OCAML_APP_HELPER" \
    --python-cext-probe        "$PYTHON_CEXT_PROBE" \
    --python-ctypes-probe      "$PYTHON_CTYPES_PROBE" \
    --cmp-symbol-ocaml         "$CMP_SYMBOL_OCAML" \
    --cmp-symbol-cext          "$CMP_SYMBOL_CEXT" \
    --cmp-api-complete-ocaml   "$CMP_API_OCAML" \
    --cmp-api-complete-cext    "$CMP_API_CEXT" \
    --cmp-api-complete-ctypes  "$CMP_API_CTYPES"
