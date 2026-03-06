#!/bin/bash
# opam_survey.sh — Reproducible survey of opam-repository native library patterns
#
# Usage: ./survey.sh /path/to/opam-repository /path/to/output-dir
#
# All categorization is done by grep/awk on opam file fields.
# NO LLM inference. See METHODOLOGY notes inline for each heuristic.

set -euo pipefail

REPO="${1:?Usage: $0 /path/to/opam-repository /path/to/output-dir}"
OUTDIR="${2:?Usage: $0 /path/to/opam-repository /path/to/output-dir}"
PKGDIR="$REPO/packages"

mkdir -p "$OUTDIR"

# Helper: get latest version dir for a package
latest_version() {
  ls "$PKGDIR/$1" | sort -V | tail -1
}

# Helper: get opam file path for latest version
opam_file() {
  local latest
  latest=$(latest_version "$1")
  echo "$PKGDIR/$1/$latest/opam"
}

echo "=== Survey of $PKGDIR ==="
echo "Output: $OUTDIR"
echo ""

# ---------------------------------------------------------------------
# 1. All conf-* packages: metadata extraction
# METHODOLOGY: Package name starts with "conf-". For each, check:
#   - pkg-config usage: grep for literal "pkg-config" or "pkgconf" in opam file
#   - depexts presence: grep for literal "depexts" in opam file
#   - synopsis: first line matching ^synopsis:
# ---------------------------------------------------------------------
echo "[1/9] Scanning conf-* packages..."
: > "$OUTDIR/conf_survey.tsv"
for pkg in "$PKGDIR"/conf-*; do
  pkg=$(basename "$pkg")
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  has_pkgconfig="no"; grep -q 'pkg-config\|pkgconf' "$f" && has_pkgconfig="yes"
  has_depexts="no"; grep -q 'depexts' "$f" && has_depexts="yes"
  synopsis=$(grep '^synopsis:' "$f" | head -1 | sed 's/synopsis: *"\(.*\)"/\1/')
  echo "$pkg|$latest|$has_pkgconfig|$has_depexts|$synopsis" >> "$OUTDIR/conf_survey.tsv"
done
echo "  Found $(wc -l < "$OUTDIR/conf_survey.tsv") conf-* packages"

# ---------------------------------------------------------------------
# 2. Classify conf-* into C library vs tool
# METHODOLOGY: A conf package is "C library" if its opam file body
#   (not just depexts) contains the patterns "-dev\b" or "-devel\b"
#   (matching Debian/Fedora -dev package naming) or starts with "lib"
#   in the depexts values. This is a HEURISTIC — it catches most C
#   library conf packages but may miss some (e.g., conf-blas which
#   uses different naming) or include false positives.
# KNOWN LIMITATIONS:
#   - Matches "-dev" anywhere in the file, not just in depexts values
#   - "lib" prefix match is on any line, not scoped to depexts
#   - conf-gmp uses a test.c compile check, no "-dev" in its depexts
#     on all platforms, but IS caught because Debian depext is "libgmp-dev"
# ---------------------------------------------------------------------
echo "[2/9] Classifying conf-* into C lib vs tool..."
: > "$OUTDIR/conf_clib.txt"
: > "$OUTDIR/conf_tools.txt"
for pkg in "$PKGDIR"/conf-*; do
  pkg=$(basename "$pkg")
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  if grep -q 'depexts' "$f" && grep -qE '\-dev\b|-devel\b|^lib' "$f" 2>/dev/null; then
    echo "$pkg" >> "$OUTDIR/conf_clib.txt"
  else
    echo "$pkg" >> "$OUTDIR/conf_tools.txt"
  fi
done
echo "  C library conf: $(wc -l < "$OUTDIR/conf_clib.txt")"
echo "  Tool/other conf: $(wc -l < "$OUTDIR/conf_tools.txt")"

# ---------------------------------------------------------------------
# 3. Packages depending on conf-* (any conf-* in depends: field)
# METHODOLOGY: grep for literal '"conf-' in the opam file. This matches
#   the opam depends: syntax where package names are quoted. Extracts
#   all conf-* package names referenced. Does NOT distinguish depends:
#   from depopts: — that's done separately in step 8.
# KNOWN LIMITATIONS:
#   - A "conf-" match in a comment or URL would be a false positive
#     (rare in practice since opam files have minimal comments)
# ---------------------------------------------------------------------
echo "[3/9] Finding packages depending on conf-*..."
: > "$OUTDIR/binding_packages.tsv"
for pkgdir in "$PKGDIR"/*/; do
  pkg=$(basename "$pkgdir")
  [[ "$pkg" == conf-* ]] && continue
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  conf_deps=$(grep -oE '"conf-[a-zA-Z0-9_+-]+"' "$f" 2>/dev/null | tr -d '"' | sort -u | tr '\n' ',' | sed 's/,$//' || true)
  if [ -n "$conf_deps" ]; then
    has_depexts="no"; grep -q 'depexts' "$f" && has_depexts="yes"
    synopsis=$(grep '^synopsis:' "$f" | head -1 | sed 's/synopsis: *"\(.*\)"/\1/')
    echo "$pkg|$latest|$conf_deps|$has_depexts|$synopsis" >> "$OUTDIR/binding_packages.tsv"
  fi
done
echo "  Found $(wc -l < "$OUTDIR/binding_packages.tsv") packages depending on conf-*"

# ---------------------------------------------------------------------
# 4. Packages with depexts but NO conf-* dependency
# METHODOLOGY: Has "depexts" in opam file AND zero matches for '"conf-'
# These handle their own native deps without the conf indirection layer.
# ---------------------------------------------------------------------
echo "[4/9] Finding direct-depexts packages (no conf-*)..."
: > "$OUTDIR/direct_depexts.tsv"
for pkg in "$PKGDIR"/*/; do
  pkg=$(basename "$pkg")
  [[ "$pkg" == conf-* ]] && continue
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  has_conf_dep=$(grep -c '"conf-' "$f" 2>/dev/null || true)
  has_depexts=$(grep -c 'depexts' "$f" 2>/dev/null || true)
  if [ "$has_depexts" -gt 0 ] && [ "$has_conf_dep" -eq 0 ]; then
    synopsis=$(grep '^synopsis:' "$f" | head -1 | sed 's/synopsis: *"\(.*\)"/\1/')
    depexts_sample=$(grep -A1 'depexts' "$f" | tail -1 | tr -d '[]" ' | head -c 80)
    echo "$pkg|$latest|$depexts_sample|$synopsis" >> "$OUTDIR/direct_depexts.tsv"
  fi
done
echo "  Found $(wc -l < "$OUTDIR/direct_depexts.tsv") direct-depexts packages"

# ---------------------------------------------------------------------
# 5. Packages with clib: tags but no conf-* dependency
# METHODOLOGY: grep for literal "clib:" in opam file tags, AND no
#   '"conf-' match in the file. The clib: tag is an opam convention
#   to declare C library requirements.
# ---------------------------------------------------------------------
echo "[5/9] Finding clib-tagged packages (no conf-*)..."
: > "$OUTDIR/clib_no_conf.tsv"
for pkg in "$PKGDIR"/*/; do
  pkg=$(basename "$pkg")
  [[ "$pkg" == conf-* ]] && continue
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  has_clib=$(grep -c 'clib:' "$f" 2>/dev/null || true)
  has_conf_dep=$(grep -c '"conf-' "$f" 2>/dev/null || true)
  if [ "$has_clib" -gt 0 ] && [ "$has_conf_dep" -eq 0 ]; then
    clib_tags=$(grep -oE 'clib:[a-zA-Z0-9_+-]+' "$f" | tr '\n' ',' | sed 's/,$//')
    has_depexts="no"; grep -q 'depexts' "$f" && has_depexts="yes"
    synopsis=$(grep '^synopsis:' "$f" | head -1 | sed 's/synopsis: *"\(.*\)"/\1/')
    echo "$pkg|$latest|$clib_tags|depexts=$has_depexts|$synopsis" >> "$OUTDIR/clib_no_conf.tsv"
  fi
done
echo "  Found $(wc -l < "$OUTDIR/clib_no_conf.tsv") clib-tagged packages"

# ---------------------------------------------------------------------
# 6. Packages using dune-configurator with no other C markers
# METHODOLOGY: grep for "dune-configurator" in depends, AND no conf-*,
#   AND no depexts, AND no clib: tags. dune-configurator is the standard
#   way to get C compilation flags in dune projects.
# KNOWN LIMITATIONS:
#   - dune-configurator is also used for non-C configuration (e.g.,
#     detecting OS features). Some false positives expected.
#   - This is the LEAST reliable category — these packages need manual
#     inspection to determine if they actually have C code.
# ---------------------------------------------------------------------
echo "[6/9] Finding dune-configurator-only packages..."
: > "$OUTDIR/dune_conf_no_markers.tsv"
for pkg in "$PKGDIR"/*/; do
  pkg=$(basename "$pkg")
  [[ "$pkg" == conf-* ]] && continue
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  has_conf_dep=$(grep -c '"conf-' "$f" 2>/dev/null || true)
  has_depexts=$(grep -c 'depexts' "$f" 2>/dev/null || true)
  has_clib=$(grep -c 'clib:' "$f" 2>/dev/null || true)
  has_dune_conf=$(grep -c 'dune-configurator' "$f" 2>/dev/null || true)
  if [ "$has_conf_dep" -eq 0 ] && [ "$has_depexts" -eq 0 ] && [ "$has_clib" -eq 0 ] && [ "$has_dune_conf" -gt 0 ]; then
    synopsis=$(grep '^synopsis:' "$f" | head -1 | sed 's/synopsis: *"\(.*\)"/\1/')
    echo "$pkg|$latest|$synopsis" >> "$OUTDIR/dune_conf_no_markers.tsv"
  fi
done
echo "  Found $(wc -l < "$OUTDIR/dune_conf_no_markers.tsv") dune-configurator-only packages"

# ---------------------------------------------------------------------
# 7. Self-building packages (depend on C/C++ compiler conf packages)
# METHODOLOGY: grep for conf-c++, conf-cmake, conf-gcc, or conf-g++ in
#   the opam file. These conf packages provide build TOOLS (compilers,
#   build systems), not C libraries. Packages depending on them are
#   likely compiling C/C++ code from their own source tarball.
# KNOWN LIMITATIONS:
#   - Some packages depend on conf-gcc just to compile small C stubs
#     (not "self-building" in the Z3 sense). This category conflates
#     heavy vendored builds (z3) with light C stub compilation (goblint-cil).
# ---------------------------------------------------------------------
echo "[7/9] Finding self-building packages (C/C++ build-tool conf deps)..."
: > "$OUTDIR/builds_c_from_source.tsv"
for pkg in "$PKGDIR"/*/; do
  pkg=$(basename "$pkg")
  [[ "$pkg" == conf-* ]] && continue
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  if grep -qE '"conf-c\+\+"|"conf-cmake"|"conf-gcc"|"conf-g\+\+"' "$f" 2>/dev/null; then
    conf_deps=$(grep -oE '"conf-[a-zA-Z0-9_+-]+"' "$f" 2>/dev/null | tr -d '"' | sort -u | tr '\n' ',' | sed 's/,$//' || true)
    synopsis=$(grep '^synopsis:' "$f" | head -1 | sed 's/synopsis: *"\(.*\)"/\1/')
    echo "$pkg|$latest|$conf_deps|$synopsis" >> "$OUTDIR/builds_c_from_source.tsv"
  fi
done
echo "  Found $(wc -l < "$OUTDIR/builds_c_from_source.tsv") self-building packages"

# ---------------------------------------------------------------------
# 8. Packages with conf-* in depopts (optional C library deps)
# METHODOLOGY: Extract the depopts: block (from "depopts:" to next "]")
#   using awk, then grep for '"conf-' within that block only.
# ---------------------------------------------------------------------
echo "[8/9] Finding packages with conf-* in depopts..."
: > "$OUTDIR/depopts_conf.tsv"
for pkg in "$PKGDIR"/*/; do
  pkg=$(basename "$pkg")
  [[ "$pkg" == conf-* ]] && continue
  latest=$(latest_version "$pkg")
  f="$PKGDIR/$pkg/$latest/opam"
  [ -f "$f" ] || continue
  depopt_confs=$(awk '/^depopts:/,/^\]/' "$f" | grep -oE '"conf-[a-zA-Z0-9_+-]+"' | tr -d '"' | tr '\n' ',' | sed 's/,$//' || true)
  if [ -n "$depopt_confs" ]; then
    synopsis=$(grep '^synopsis:' "$f" | head -1 | sed 's/synopsis: *"\(.*\)"/\1/')
    echo "$pkg|$latest|$depopt_confs|$synopsis" >> "$OUTDIR/depopts_conf.tsv"
  fi
done
echo "  Found $(wc -l < "$OUTDIR/depopts_conf.tsv") packages with conf-* in depopts"

# ---------------------------------------------------------------------
# 9. Reverse dependency counts for conf-* packages
# METHODOLOGY: From binding_packages.tsv, split the conf-deps column
#   on commas and count occurrences of each conf-* package name.
# ---------------------------------------------------------------------
echo "[9/9] Computing reverse dependency counts..."
awk -F'|' '{split($3,a,","); for(i in a) print a[i]}' "$OUTDIR/binding_packages.tsv" \
  | sort | uniq -c | sort -rn > "$OUTDIR/conf_revdeps.txt"
echo "  Top 5:"
head -5 "$OUTDIR/conf_revdeps.txt" | sed 's/^/    /'

# ---------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------
echo ""
echo "=== SUMMARY ==="
total_pkgs=$(ls "$PKGDIR" | wc -l | tr -d ' ')
conf_count=$(wc -l < "$OUTDIR/conf_survey.tsv" | tr -d ' ')
binding_count=$(wc -l < "$OUTDIR/binding_packages.tsv" | tr -d ' ')
direct_count=$(wc -l < "$OUTDIR/direct_depexts.tsv" | tr -d ' ')
clib_count=$(wc -l < "$OUTDIR/clib_no_conf.tsv" | tr -d ' ')
dune_count=$(wc -l < "$OUTDIR/dune_conf_no_markers.tsv" | tr -d ' ')
build_count=$(wc -l < "$OUTDIR/builds_c_from_source.tsv" | tr -d ' ')
depopts_count=$(wc -l < "$OUTDIR/depopts_conf.tsv" | tr -d ' ')
echo "Total packages:                $total_pkgs"
echo "conf-* packages:               $conf_count"
echo "  C library conf:              $(wc -l < "$OUTDIR/conf_clib.txt" | tr -d ' ')"
echo "  Tool/other conf:             $(wc -l < "$OUTDIR/conf_tools.txt" | tr -d ' ')"
echo "Depends on conf-*:             $binding_count"
echo "Direct depexts (no conf-*):    $direct_count"
echo "clib: tags (no conf-*):        $clib_count"
echo "dune-configurator only:        $dune_count"
echo "Self-building (compiler conf): $build_count"
echo "Optional conf-* (depopts):     $depopts_count"
echo ""
echo "All output in: $OUTDIR"
