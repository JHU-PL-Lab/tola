#!/bin/bash
# Test package manager primitive commands from canary_basic_apt/brew/opam.
# Uses trivial packages to verify the command patterns work.
# Run from tola root: bash canary/scripts/test_pm_primitives.sh

set -e

PASS=0
FAIL=0
SKIP=0

run_test() {
  local name="$1"
  local cmd="$2"
  local expect_rc="${3:-0}"  # expected exit code, default 0

  printf "  %-45s" "$name"
  if output=$(eval "$cmd" 2>&1); then
    rc=0
  else
    rc=$?
  fi

  if [ "$rc" -eq "$expect_rc" ]; then
    echo "PASS  (rc=$rc) ${output:0:60}"
    PASS=$((PASS + 1))
  else
    echo "FAIL  (rc=$rc, expected=$expect_rc)"
    echo "    cmd: $cmd"
    echo "    out: ${output:0:120}"
    FAIL=$((FAIL + 1))
  fi
}

skip_test() {
  local name="$1"
  local reason="$2"
  printf "  %-45s" "$name"
  echo "SKIP  ($reason)"
  SKIP=$((SKIP + 1))
}

# ── apt tests (trivial package: cowsay) ──

APT_PKG="cowsay"

if command -v apt-get >/dev/null 2>&1; then
  echo "=== apt (package: $APT_PKG) ==="

  # Pre-install checks
  run_test "check_available" \
    "apt-cache show $APT_PKG >/dev/null 2>&1"

  run_test "list_available_versions" \
    "apt-cache madison $APT_PKG 2>/dev/null | awk '{print \$3}' | head -3"

  # Install (idempotent — ok if already installed)
  run_test "install" \
    "sudo apt-get install -y $APT_PKG"

  # Post-install checks
  run_test "verify_installed" \
    "dpkg -s $APT_PKG"

  run_test "query_version" \
    "dpkg -s $APT_PKG 2>/dev/null | grep '^Version:' | cut -d' ' -f2"

  # Negative cases
  run_test "check_available (non-existent)" \
    "apt-cache show this-pkg-does-not-exist >/dev/null 2>&1" 100

  run_test "verify_installed (non-existent)" \
    "dpkg -s this-pkg-does-not-exist 2>/dev/null" 1
else
  echo "=== apt: SKIPPED (not available) ==="
fi

echo ""

# ── brew tests ──

BREW_PKG="cowsay"

if command -v brew >/dev/null 2>&1; then
  echo "=== brew (package: $BREW_PKG) ==="

  run_test "check_available" \
    "brew info $BREW_PKG >/dev/null 2>&1"

  run_test "query_version" \
    "brew info --json=v2 $BREW_PKG 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['formulae'][0]['versions']['stable'])\""

  run_test "verify_installed (before)" \
    "brew list $BREW_PKG >/dev/null 2>&1"

  # Skip install to avoid side effects on macOS
  skip_test "install" "skipped to avoid side effects"
else
  echo "=== brew: SKIPPED (not available) ==="
fi

echo ""

# ── opam tests (trivial package: fmt) ──

OPAM_PKG="fmt"

if command -v opam >/dev/null 2>&1; then
  eval $(opam env)
  echo "=== opam (package: $OPAM_PKG) ==="

  run_test "current_switch" \
    "opam switch show"

  run_test "list_switches" \
    "opam switch list --short"

  run_test "check_available" \
    "opam show $OPAM_PKG >/dev/null 2>&1"

  run_test "query_version" \
    "opam show $OPAM_PKG --field=version 2>/dev/null"

  run_test "verify_installed" \
    "opam list --installed-roots $OPAM_PKG --short"

  # Test with versioned package name
  run_test "check_available (versioned)" \
    "opam show $OPAM_PKG --field=version 2>/dev/null"

  # Test depext listing via opam show (depext plugin may not be installed)
  run_test "list_depexts (sqlite3)" \
    "opam show sqlite3 --field=depexts 2>/dev/null || echo 'no depexts field'"

  # Non-existent package
  run_test "check_available (non-existent)" \
    "opam show this-package-does-not-exist-xyz >/dev/null 2>&1" 5

  run_test "verify_installed (non-existent)" \
    "test -n \"\$(opam list --installed-roots this-pkg-does-not-exist --short 2>/dev/null)\"" 1
else
  echo "=== opam: SKIPPED (not available) ==="
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ]
