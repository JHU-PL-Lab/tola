#!/bin/bash
# Count reverse dependencies for each conf-* package and merge with
# classification from classify_conf.sh.
# Usage: ./conf_revdeps.sh /path/to/opam-repository/packages [classify.txt]
# Output: pipe-separated lines sorted by revdep count: count|category|package

REPO=${1:-/home/red/code/contrib/opam-repository/packages}
CLASSIFY=${2:-/tmp/conf_classify.txt}

# If no classify file, generate it
if [ ! -f "$CLASSIFY" ]; then
  echo "Running classify_conf.sh first..." >&2
  bash "$(dirname "$0")/classify_conf.sh" "$REPO" > "$CLASSIFY" 2>/dev/null
fi

# Count reverse deps (non-conf packages that depend on each conf package)
for d in "$REPO"/conf-*/; do
  pkg=$(basename "$d")
  count=$(grep -rl "\"$pkg\"" "$REPO"/*/*/opam 2>/dev/null | grep -v "conf-" | wc -l)
  category=$(grep "|$pkg$" "$CLASSIFY" 2>/dev/null | cut -d'|' -f1)
  [ -z "$category" ] && category="unclassified"
  echo "$count|$category|$pkg"
done | sort -t'|' -k1 -rn
