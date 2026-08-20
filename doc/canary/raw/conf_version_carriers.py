#!/usr/bin/env python3
"""Which conf-* packages actually enforce a C-library VERSION?

Regenerates the table in surveys/conf_packages.md §G1a. A conf package's
opam version constrains the library only if its own `build:` enforces a
version, and there are exactly two ways it does:

  (i)  a pkg-config version predicate with a HARDCODED literal
       -- `pkg-config --atleast-version=1.3.8 libzstd`
  (ii) the opam `version` variable passed into a discovery script
       -- `["bash" "configure.sh" version]`

Both must be searched, and they need OPPOSITE treatment of quotes: (ii)
requires stripping quoted strings (so `"--version"` as an argument is not
mistaken for the variable), while (i) lives ENTIRELY inside a quoted
literal. The first version of this sweep stripped quotes and reported
mechanism (ii) only -- missing all 8 of (i), including conf-zstd, which
a landing then walked straight into. Hence one script that does both.

Usage:  python3 doc/canary/raw/conf_version_carriers.py [<opam-repository>]
"""
import os
import re
import sys
import glob

DEFAULT_REPO = "/home/red/code/contrib/opam-all/opam-repository"

# the literal may be joined (--atleast-version=1.3.8) or a separate quoted
# argument ("--atleast-version" "3.18") -- accept quotes and spaces between
PREDICATE = re.compile(r"--(?:atleast|exact|max)-version[=\"' ]+([0-9][0-9A-Za-z._-]*)")
VERSION_VAR = re.compile(r"(?<![\w-])version(?![\w-])")


def version_key(path):
    v = os.path.basename(path)
    v = v.split(".", 1)[1] if "." in v else ""
    return [int(x) if x.isdigit() else x for x in re.split(r"[.\-+~]", v)]


def build_section(text):
    m = re.search(r"^build:(.*?)(?=^[a-z-]+:)", text, re.S | re.M)
    return m.group(1) if m else ""


def scan(repo):
    root = os.path.join(repo, "packages")
    rows = []
    names = sorted(d for d in os.listdir(root) if d.startswith("conf-"))
    for name in names:
        versions = glob.glob(os.path.join(root, name, name + ".*"))
        if not versions:
            continue
        try:
            versions.sort(key=version_key)
        except Exception:
            versions.sort()
        newest = versions[-1]
        pkg_version = os.path.basename(newest)[len(name) + 1 :]
        try:
            build = build_section(open(os.path.join(newest, "opam")).read())
        except OSError:
            continue

        # (i) hardcoded predicate -- search the RAW text, literals are quoted
        literal = PREDICATE.search(build)
        # (ii) the version variable -- search with quoted strings REMOVED
        # the string eater must honour BACKSLASH-ESCAPED quotes: a heredoc
        # like `cat <<EOF > test.c #include \"cuda.h\"` desyncs a naive
        # [^"]* and leaks its prose into the search (conf-cuda, a false
        # positive in the first pass)
        stripped = re.sub(r'"(?:[^"\\]|\\.)*"', '""', build)
        # ... and drop opam COMMENTS, which sit inside the build section and
        # are prose ("X=12, Y=4 is the CUDA version") -- the other half of
        # the conf-cuda false positive
        stripped = re.sub(r"#.*", "", stripped)
        uses_var = bool(VERSION_VAR.search(stripped)) or "%{version}%" in build

        if literal:
            rows.append((name, pkg_version, "pkg-config-predicate", literal.group(1)))
        elif uses_var:
            rows.append((name, pkg_version, "version-variable", pkg_version))
    return rows, len(names)


def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_REPO
    rows, total = scan(repo)
    print(f"conf packages enforcing a library version: {len(rows)} / {total}\n")
    print(f"{'conf package':<26} {'opam v':<10} {'mechanism':<22} {'enforces':<10} corresponds?")
    for name, pv, mech, lit in rows:
        # mechanism (ii) enforces the package version by construction;
        # for (i) the literal and the package version agree only by convention
        same = "by construction" if mech == "version-variable" else (
            "yes" if lit == pv or lit.startswith(pv + ".") or pv in lit else "NO")
        print(f"{name:<26} {pv:<10} {mech:<22} {lit:<10} {same}")
    print("\nEverything not listed runs a bare presence check, so a version bound")
    print("declared by a BINDING over it constrains opam packaging only.")
    print("Note: this sees neither a gate inside the binding's own build (mlmpfr)")
    print("nor a version compared inside an extra-source script.")


if __name__ == "__main__":
    main()
