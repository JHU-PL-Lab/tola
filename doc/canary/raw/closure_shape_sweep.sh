#!/bin/bash
# Closure-shape sweep — the falsifier for design/closure_shape.md.
#
#   bash doc/canary/raw/closure_shape_sweep.sh
#
# For every PREPARED prebuilt under contrib/*-all/prebuilt/, compare the
# exported symbol set of each pair of shipped shared objects. Two forms of
# hazard, and they are NOT the same thing:
#
#   ALT-SPELLING  overlap covers >=80% of BOTH sides — one implementation
#                 shipped under two names (ncurses: libtinfo/libtinfow).
#                 A consumer linked in a packager that ships ONE of them
#                 can load both at once and get the library's globals
#                 twice.
#   CONTAINMENT   >=80% of the SMALLER only — a large object statically
#                 absorbed a small one (sundials: libsundials_cvode
#                 contains all of nvecserial). A consumer linking both
#                 gets that implementation twice.
#
# Direction is the whole discriminator. A bare "do these share a symbol"
# test reports 82 hits for sundials and 3 for cairo — and cairo is clean.
# It would have confirmed the proposal for the wrong reason, which is the
# bug class project/landing.md §4 is about.
#
# The 80% threshold FINDS candidates. It is not what a contract should
# read: that wants the declared fact (these names are one implementation),
# per closure_shape.md §6 step 2.
#
# Result on 2026-08-25: cairo/libffi/zlib/zstd clean on both forms;
# ncurses 4 alt-spellings + 1; sundials 82 containments + 0.

set -u
threshold=80

syms() { # exported text symbols, symbol-version suffix stripped
  nm -D --defined-only "$1" 2>/dev/null | sed 's/@@.*//' | awk '$2=="T"{print $3}' | sort -u
}

for d in /home/red/code/contrib/*-all/prebuilt/*/; do
  proj=$(echo "$d" | sed -E 's|.*/contrib/([^/]+)-all/prebuilt/([^/]+)/|\1 \2|')
  libdir="$d/lib"
  [ -d "$libdir" ] || continue
  # real files only — a symlink is the same object under another name and
  # would report a spurious 100% against its own target
  mapfile -t reals < <(find "$libdir" -maxdepth 1 -type f -name "*.so*" | sort)
  alt=0; con=0; detail=""
  n=${#reals[@]}
  for ((i = 0; i < n; i++)); do
    for ((j = i + 1; j < n; j++)); do
      a="${reals[$i]}"; b="${reals[$j]}"
      sa=$(syms "$a"); sb=$(syms "$b")
      ca=$(echo "$sa" | grep -c .); cb=$(echo "$sb" | grep -c .)
      { [ "$ca" -eq 0 ] || [ "$cb" -eq 0 ]; } && continue
      ov=$(comm -12 <(echo "$sa") <(echo "$sb") | grep -c .)
      [ "$ov" -eq 0 ] && continue
      pa=$((ov * 100 / ca)); pb=$((ov * 100 / cb))
      if [ "$pa" -ge "$threshold" ] && [ "$pb" -ge "$threshold" ]; then
        alt=$((alt + 1))
        detail="${detail}   ALT-SPELLING $(basename "$a")($ca) <-> $(basename "$b")($cb): overlap $ov = ${pa}pct / ${pb}pct
"
      elif [ "$pa" -ge "$threshold" ] || [ "$pb" -ge "$threshold" ]; then
        con=$((con + 1))
      fi
    done
  done
  printf '== %-24s alt-spelling=%-3d containment=%d\n' "$proj" "$alt" "$con"
  [ "$alt" -gt 0 ] && printf '%s' "$detail"
done
exit 0
