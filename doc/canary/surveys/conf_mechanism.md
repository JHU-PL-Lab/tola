# conf-* packages — the opam-side survey

> 2026-08-16; trimmed 2026-08-17. A survey of opam's `conf-*` virtual
> packages (prompted by zarith/`conf-gmp`): how they work and the
> position that opam should drop them. Canary's OWN designs that the
> survey motivated (the fork layering, the wrapper/conf-free packages,
> the shadow preference, the Publish generalization) live in
> [`../design/wrapper_packages.md`](../design/wrapper_packages.md).
> Moved here from `project/` 2026-08-21 — it is survey material, not a
> project record. Its sibling [`conf_packages.md`](conf_packages.md)
> classifies all 333 conf-* packages; this one explains the MECHANISM
> and states the position.

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

## 2. Position: opam should drop conf-<pkg> for all

Recorded as the study direction (user, 2026-08-16). The evidence from
§1: a conf package adds nothing but (a) the presence check — which a
real package can run itself, and (b) the depext mapping — which opam
supports DIRECTLY on the package (`depexts:` on zarith's own opam
file). The conf hop therefore buys only indirection + review latency.
Open questions for the broader study: whether opam's `conf` flag
semantics (no install, just availability) have uses the direct-depext
form can't express; how the human-approval bottleneck compares
quantitatively (review latency per distro bump); whether package
maintainers prefer the conf hop because depexts were historically
weaker. Deferred — not a canary blocker.

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
