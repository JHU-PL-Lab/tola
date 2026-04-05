#!/bin/bash
# Test LLVM version resolution chain:
#   system PM → llvm-config (locator) → conf-llvm (opam) → llvm (opam binding)
#
# Diagnoses version mismatch issues before attempting opam install.
# Usage:
#   bash canary/scripts/test_llvm_versions.sh          # diagnose
#   bash canary/scripts/test_llvm_versions.sh switch 19 # switch to LLVM 19
#   bash canary/scripts/test_llvm_versions.sh test-seams # test each resolution seam

set -uo pipefail
eval $(opam env)

CMD=${1:-diagnose}
TARGET_VER=${2:-}

# ── Helpers ──

all_installed_llvm_versions() {
  dpkg -l 2>/dev/null | grep -E "^ii.*llvm-[0-9]+-dev " | \
    sed 's/.*llvm-\([0-9]*\)-dev.*/\1/' | sort -n | uniq
}

locator_for_version() {
  local ver=$1
  for candidate in "llvm-config-$ver" "llvm-config${ver}" "llvm-config-${ver}.0"; do
    local path=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$path" ]; then
      local actual=$("$path" --version 2>/dev/null | cut -d. -f1)
      if [ "$actual" = "$ver" ]; then
        echo "$path"
        return 0
      fi
    fi
  done
  return 1
}

# ── Commands ──

cmd_diagnose() {
  echo "=== 1. System PM: installed LLVM versions ==="
  echo ""
  echo "  apt packages (llvm-*-dev):"
  dpkg -l 2>/dev/null | grep -E "^ii.*llvm-[0-9]+-dev " | \
    awk '{printf "    %-40s %s\n", $2, $3}'
  echo ""
  echo "  Default llvm-config:"
  local default_cfg=$(command -v llvm-config 2>/dev/null)
  if [ -n "$default_cfg" ]; then
    echo "    $default_cfg → $(llvm-config --version)"
  else
    echo "    (not found)"
  fi
  echo ""
  echo "  update-alternatives status:"
  update-alternatives --query llvm-config 2>/dev/null | grep -E "^(Value|Alternative)" | \
    sed 's/^/    /' || echo "    (not managed by alternatives)"
  echo ""

  echo "=== 2. Locator: all llvm-config binaries ==="
  echo ""
  for ver in $(all_installed_llvm_versions); do
    local cfg=$(locator_for_version "$ver")
    if [ -n "$cfg" ]; then
      printf "    ver %-4s → %-30s prefix=%s\n" "$ver" "$cfg" "$($cfg --prefix)"
    else
      printf "    ver %-4s → NOT FOUND\n" "$ver"
    fi
  done
  # Also check unversioned
  local unver=$(command -v llvm-config 2>/dev/null)
  if [ -n "$unver" ]; then
    printf "    default → %-30s version=%s\n" "$unver" "$(llvm-config --version)"
  fi
  echo ""

  echo "=== 3. Opam: installed and available ==="
  echo ""
  echo "  Current switch: $(opam switch show)"
  echo ""
  echo "  Installed:"
  opam list --installed llvm conf-llvm conf-llvm-static 2>/dev/null | \
    grep -v '^#' | sed 's/^/    /' || echo "    (none)"
  echo ""
  echo "  Available llvm bindings: $(opam show llvm --field=all-versions 2>/dev/null | tr ' ' '\n' | grep -E '^1[789]|^2[0-9]' | tr '\n' ' ')"
  echo "  Available conf-llvm-static: $(opam show conf-llvm-static --field=all-versions 2>/dev/null)"
  echo ""

  echo "=== 4. Compatibility matrix ==="
  echo ""
  printf "    %-10s %-12s %-15s %-12s %-25s\n" "Version" "System" "Locator" "Conf pkg" "opam binding"
  printf "    %-10s %-12s %-15s %-12s %-25s\n" "-------" "------" "-------" "--------" "------------"
  for ver in 17 18 19 23; do
    # System
    if dpkg -s "llvm-${ver}-dev" >/dev/null 2>&1; then
      sys="installed"
    elif apt-cache show "llvm-${ver}-dev" >/dev/null 2>&1; then
      sys="available"
    else
      sys="—"
    fi

    # Locator
    local cfg=$(locator_for_version "$ver" 2>/dev/null)
    if [ -n "$cfg" ]; then
      loc="✓ $($cfg --version 2>/dev/null)"
    else
      loc="—"
    fi

    # Conf
    if opam show "conf-llvm-static.${ver}" >/dev/null 2>&1; then
      conf="static.${ver}"
    elif opam show "conf-llvm.${ver}" >/dev/null 2>&1; then
      conf="llvm.${ver}"
    else
      conf="—"
    fi

    # Binding
    opam_ver="—"
    for suffix in "-static" "-shared"; do
      if opam show "llvm.${ver}${suffix}" >/dev/null 2>&1; then
        opam_ver="${ver}${suffix}"
        break
      fi
    done

    printf "    %-10s %-12s %-15s %-12s %-25s\n" "llvm-$ver" "$sys" "$loc" "$conf" "$opam_ver"
  done
  echo ""

  echo "=== 5. Version switch commands ==="
  echo ""
  echo "  --- apt: install a specific LLVM version ---"
  echo "  sudo apt install -y llvm-19-dev    # install LLVM 19"
  echo "  sudo apt install -y llvm-18-dev    # install LLVM 18"
  echo ""
  echo "  --- apt: switch default llvm-config via update-alternatives ---"
  for ver in $(all_installed_llvm_versions); do
    echo "  sudo update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-${ver} ${ver}0"
  done
  echo "  sudo update-alternatives --config llvm-config   # interactive picker"
  echo ""
  echo "  --- opam: install binding for a specific version ---"
  echo "  opam install llvm.19-static        # uses conf-llvm-static.19 → llvm-config-19"
  echo "  opam install llvm.18-static        # uses conf-llvm-static.18 → llvm-config-18"
  echo ""
  echo "  --- opam: force conf to find a specific llvm-config ---"
  echo "  # conf-llvm-static searches by name (llvm-config-19 etc.)"
  echo "  # No env var override — must have llvm-config-<ver> on PATH"
  echo "  # To test: install llvm-<ver>-dev, then opam install conf-llvm-static.<ver>"
  echo ""
  echo "  --- opam: switch between versions (reinstall) ---"
  echo "  opam remove llvm conf-llvm-static -y"
  echo "  opam install llvm.19-static -y     # switch to 19"
  echo ""
}

cmd_switch() {
  local ver=${TARGET_VER:?Usage: test_llvm_versions.sh switch <version>}
  echo "=== Switching to LLVM $ver ==="
  echo ""

  # Step 1: Check system package
  if ! dpkg -s "llvm-${ver}-dev" >/dev/null 2>&1; then
    echo "  [1/4] Installing llvm-${ver}-dev..."
    sudo apt-get install -y "llvm-${ver}-dev"
  else
    echo "  [1/4] llvm-${ver}-dev already installed ✓"
  fi

  # Step 2: Verify locator
  local cfg=$(locator_for_version "$ver")
  if [ -n "$cfg" ]; then
    echo "  [2/4] Locator: $cfg → $($cfg --version) ✓"
  else
    echo "  [2/4] ERROR: llvm-config-${ver} not found after install"
    return 1
  fi

  # Step 3: Remove old opam llvm if installed
  local installed=$(opam list --installed llvm --short 2>/dev/null)
  if [ -n "$installed" ]; then
    echo "  [3/4] Removing old opam llvm ($installed)..."
    opam remove llvm conf-llvm-static conf-llvm -y 2>/dev/null
  else
    echo "  [3/4] No existing opam llvm to remove ✓"
  fi

  # Step 4: Install new version
  local pkg=""
  for suffix in "-static" "-shared"; do
    if opam show "llvm.${ver}${suffix}" >/dev/null 2>&1; then
      pkg="llvm.${ver}${suffix}"
      break
    fi
  done
  if [ -z "$pkg" ]; then
    echo "  [4/4] ERROR: No opam llvm binding for version $ver"
    return 1
  fi
  echo "  [4/4] Installing $pkg..."
  opam install "$pkg" -y --assume-depexts
  echo ""
  echo "  Done. Verify: opam list --installed llvm"
}

cmd_test_seams() {
  echo "=== Testing version resolution seams ==="
  echo ""
  local PASS=0 FAIL=0

  for ver in $(all_installed_llvm_versions); do
    echo "  --- LLVM $ver ---"

    # Seam 1: System PM → Locator
    printf "    Seam 1 (system → locator): "
    local cfg=$(locator_for_version "$ver")
    if [ -n "$cfg" ]; then
      local reported=$("$cfg" --version | cut -d. -f1)
      if [ "$reported" = "$ver" ]; then
        echo "PASS — $cfg reports $($cfg --version)"
        PASS=$((PASS + 1))
      else
        echo "FAIL — $cfg reports $reported, expected $ver"
        FAIL=$((FAIL + 1))
      fi
    else
      echo "FAIL — no llvm-config found for version $ver"
      FAIL=$((FAIL + 1))
    fi

    # Seam 2: Locator → Conf package
    printf "    Seam 2 (locator → conf):   "
    local conf_pkg=""
    if opam show "conf-llvm-static.${ver}" >/dev/null 2>&1; then
      conf_pkg="conf-llvm-static.${ver}"
    elif opam show "conf-llvm.${ver}" >/dev/null 2>&1; then
      conf_pkg="conf-llvm.${ver}"
    fi
    if [ -n "$conf_pkg" ]; then
      echo "PASS — $conf_pkg available"
      PASS=$((PASS + 1))
    else
      echo "SKIP — no conf package for version $ver in opam"
      # Not a failure — opam may not have this version yet
    fi

    # Seam 3: Conf → Binding
    printf "    Seam 3 (conf → binding):   "
    local binding=""
    for suffix in "-static" "-shared"; do
      if opam show "llvm.${ver}${suffix}" >/dev/null 2>&1; then
        binding="llvm.${ver}${suffix}"
        break
      fi
    done
    if [ -n "$binding" ]; then
      echo "PASS — $binding available"
      PASS=$((PASS + 1))
    else
      echo "SKIP — no opam binding for version $ver"
    fi

    echo ""
  done
marker_of_rule 
  echo "  Summary: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}

# ── Dispatch ──

case "$CMD" in
  diagnose) cmd_diagnose ;;
  switch)   cmd_switch ;;
  test-seams) cmd_test_seams ;;
  *)
    echo "Usage: $0 [diagnose|switch <ver>|test-seams]"
    exit 1
    ;;
esac
