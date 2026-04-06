#!/bin/bash
# Classify conf-* packages by build section complexity.
# Usage: ./classify_conf.sh /path/to/opam-repository/packages
# Output: pipe-separated lines: category|conf-package-name
REPO=${1:-/home/red/code/contrib/opam-all/opam-repository/packages}
for d in $REPO/conf-*/; do
  pkg=$(basename "$d")
  latest=$(ls "$d" | sort -V | tail -1)
  opam_file="$d/$latest/opam"
  [ ! -f "$opam_file" ] && continue
  build=$(sed -n '/^build:/,/^[a-z]/p' "$opam_file" | head -20)

  if echo "$build" | grep -q 'pkg-config\|pkgconf'; then
    echo "pkgconfig|$pkg"
  elif echo "$build" | grep -q 'configure\.sh\|build\.sh\|setup\.sh'; then
    echo "custom_script|$pkg"
  elif echo "$build" | grep -q 'which\|command -v'; then
    echo "which_check|$pkg"
  elif echo "$build" | grep -qE 'cc -c|gcc |c_compiler|test\.c'; then
    echo "compile_test|$pkg"
  elif echo "$build" | grep -q '\-\-version'; then
    echo "version_check|$pkg"
  elif [ -z "$build" ] || echo "$build" | grep -q 'build: \[\]'; then
    echo "no_build|$pkg"
  else
    echo "other|$pkg"
  fi
done | sort | tee /tmp/conf_classify.txt
echo "---"
cut -d'|' -f1 /tmp/conf_classify.txt | sort | uniq -c | sort -rn
