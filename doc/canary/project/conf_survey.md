# conf-* packages — mechanics, the fork layering, and the conf-free direction

> 2026-08-16. Survey of opam's `conf-*` virtual packages (prompted by
> zarith/`conf-gmp`), the git layering for a fix-fork vs a conf-bypass,
> and the position that opam should drop `conf-<pkg>` for all.

## 1. How conf-* works (the live `conf-gmp.5`)

From the installed opam-repository package
(`~/.opam/repo/default/packages/conf-gmp/conf-gmp.5/opam`):

- **The check** — the `build:` field runs a PRESENCE test, nothing else:
  `pkg-config --print-errors --exists gmp || cc -c $CFLAGS -I/usr/local/include test.c`
  (a tiny C file including `gmp.h`, fetched from opam-source-archives
  with a checksum). Windows gets a mingw variant.
- **The mapping** — the `depexts:` field maps the virtual package to the
  per-distro system package (`libgmp-dev` on debian/ubuntu, `gmp` on
  homebrew/macports, `gmp`+`gmp-devel` on centos/fedora/suse, …).
- **The marker** — `flags: conf` makes it a config-only virtual package
  (installs nothing; no version pinning of GMP itself — ANY gmp.h that
  compiles passes).
- **The dependency** — a real package (zarith) declares `"conf-gmp"` in
  `depends:`; opam resolves the virtual package against the OS.

Two structural facts follow:
1. **No GMP version constraint anywhere** — the conf package checks
   presence only. The version regime (strict vs flexible) is entirely
   implicit; zarith is the fully-flexible case, resting on GMP's ABI
   discipline (libgmp.so.10 since 6.0).
2. **Human-approval bottleneck** — the depext mapping is
   maintainer-maintained opam-repository data: adding a distro or
   bumping the check is a reviewed PR. That is the friction the user
   compares unfavorably with npm's mechanical resolution.

## 2. The fork layering — a functional fix vs a conf-bypass

The user's question: we have a forked zarith (`zarith-my-fork`) carrying
a functional fix; should the conf-bypass be a separate branch or a
separate commit in the fork? **Neither — it belongs in a different
layer entirely.**

- **The functional fix lives in the FORK** (a branch off upstream,
  PR-ready, no packaging noise). Canary already describes this: the
  repo record (`label = Some "my-fork"`, `official = false`, `ref_`,
  remote), one entry in the `Repo_axes` family.
- **The conf-bypass is PACKAGING, not source** — an opam-file-level
  change ("build this tree without consulting `conf-gmp`"). It is
  version-agnostic: the SAME bypass applies to stable, master, and the
  fork alike. Putting it in the fork (branch or commit) would (a)
  duplicate it per ref, (b) pollute the upstream-reportable fix branch
  with workflow concerns that upstream would never merge (the bypass is
  OUR opam-ecosystem stance, not a zarith bug fix).
- **Canary's description of the bypass**: it is exactly what the
  `pr_wrapper_pkgs` field + the local opam repo
  (`canary/templates/opam-local-repo/`) already are — a dev-mode
  wrapper package (`z3.dev`, `llvm.dev-shared`) that overrides the dep
  graph. `zarith-no-conf` is the same shape: a local package whose
  `build:` runs `./configure && make` over the scenario's checkout and
  whose `depends:` omits `conf-gmp` (declaring the GMP provision
  itself). The fork record and the wrapper declaration stay separate
  spec fields, so canary can enumerate "fork source × conf-free
  packaging" freely — the dev-mode combinatorial freedom the user wants.

## 3. The store-mutation consequence (the reinstall)

opam's store is global and findlib-keyed: `zarith` and `zarith-no-conf`
both install the findlib package `zarith`, so only one can own the
namespace at a time — installing one clobbers the other. Options:

- **Distinct findlib name** (e.g. `zarith-no-conf` installs findlib
  `zarith_no_conf`) — both coexist, but the probe compiles against a
  DIFFERENT name than the real-world consumer uses (weakens the
  realism of the check).
- **Same findlib name, pin-switched scenarios** — the scenario that
  needs the fork installs `zarith-no-conf` (or a pinned fork version),
  the stable scenario re-pins `zarith.1.14`; each step's `pin_check_post`
  verifies the store provably holds the right package before probing.
  This is EXACTLY the z3 stable/dev dance (opam pin 4.16.0 ↔ publish
  z3.dev), and the machinery exists: pin-checked fetch, world
  assertions, "order is a performance contract, not a correctness
  one" (algorithm_explainer.md §10).

The same-name variant is the right default — realism beats coexistence,
and the store-mutation machinery already makes it sound.

## 4. Position: opam should drop conf-<pkg> for all

Recorded as the study direction (user, 2026-08-16). The evidence from
§1: a conf package adds nothing but (a) the presence check — which a
real package can run itself, and (b) the depext mapping — which opam
supports DIRECTLY on the package (`depexts:` on zarith's own opam
file). The conf hop therefore buys only indirection + review latency.
The conf-free package (`zarith-no-conf`) is the prototype for the
alternate world: the package declares its own system-dep handling and
the checker (canary) supplies the version reality. Open questions for
the broader study: whether opam's `conf` flag semantics (no install,
just availability) have uses the direct-depext form can't express;
how the human-approval bottleneck compares quantitatively (review
latency per distro bump); whether package maintainers prefer the conf
hop because depexts were historically weaker. Deferred — not a canary
blocker.

**Refinement (user, 2026-08-16)**: "no conf-gmp" does NOT mean no
system mapping at all. Most conf packages are merely a SYSTEM-PACKAGE
DISPATCH across package managers (apt name vs brew name vs dnf name) —
almost GLOBAL knowledge, not per-conf-package registration. The
proposed shape: keep that dispatch as a GLOBAL mapping file (today
canary-local; in the future a public URL), while anything needing
special handling (checks beyond presence) becomes a PACKAGE-SIDE
script or an opam-installation script. Canary's current seam: the
per-project `linux_pkg`/`macos_pkg` pair on `system_package_spec` is
exactly that dispatch data, declared per project — the global file is
the same data lifted to one table keyed by the library name.

## 5. What this means for the pattern work

`Canary_pattern_a` is THE ocaml/opam binding pattern: an opam binding
over a system C lib via a conf virtual package. The reframe (to-do):
the pattern becomes FUNCTIONS over the general types (de-pattern-a),
parameterized by the conf dependency — `conf-gmp` today, `None` for
the conf-free variant — so the same helpers describe both worlds, and
the wrapper-package declaration (`pr_wrapper_pkgs` + the local repo
template) is the pattern's conf-bypass leg. After ocaml/opam, pip
follows the same idea.

## 6. The zarith matrix and the shadow preference (2026-08-17)

The combination space for the case study: GMP has no system dev
package (`libgmp-dev` ships only 6.3.0) and no nightly — the dev GMP
comes from the OFFICIAL repo (gmplib.org: release tarballs + the hg
repository), which the repo model already covers (`Tar`/`Hg` remotes).
Since conf-gmp constrains nothing, a future GMP release flows into the
system path automatically — the matrix is

```
                 gmp 6.3.0 (system)   gmp master (official repo)
zarith 1.14      current cell          old-binding × new-lib (deploy)
zarith master    new-binding × old-lib (forward)   new × new
```

gmp master can be a fetched archive (vendored download from the
official remote) or built from the latest source.

**The shadow preference** (user's design): ALWAYS probe the latest
prebuilt lib first — if it works, skip the source; only if it FAILS do
we on-demand fetch the source, build, re-probe, and blame. Declared at
PROJECT-SPEC level (not meta): the spec declares BOTH the vendored lib
and the source repo, and the LIB SHADOWS THE SOURCE — the internet
search is spec authoring, done once, working for all projects. Canary
shape: the lib row declares both provisions for the same
(channel, version); a resolution pass keeps the prebuilt placement and
marks the Built placement as a FALLBACK; the runner escalates to the
fallback on the preferred scenario's failure (fetch source + build +
re-probe). This differs from z3's current shape, where the two
provisions enumerate as two SEPARATE scenarios (Fetched@Stable vs
Built@Dev are different cells) — the shadow applies when both
provisions would materialize the SAME cell.
