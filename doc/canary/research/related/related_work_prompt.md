# Brief — the practice-side related-work survey

*A prompt to hand to a research assistant (human or AI) with web access.
Written 2026-09-03. The output is a second bibliography beside
[`literature.md`](literature.md), which covers only the theory side.*

---

## What already exists, so you don't redo it

`literature.md` surveys **semantics**: verified compilation (CompCert,
CakeML), type-preserving compilation, representation discipline,
multi-language semantics, linking calculi, Java dynamic linking, ELF /
dynamic-linker semantics, FFI semantics, compositional linking, and one
section on empirical ABI tooling. Do **not** re-cover those. The gap is
everything practical.

## The claim you are testing

> No existing tool answers *"is this binding compatible with this
> library, as the user will actually obtain both?"* Each nearby tool
> answers a neighbouring question and stops.

This is currently **believed, not established.** Your job is to confirm,
qualify, or refute it — a refutation is a more valuable result than a
confirmation, so look for the tool that already does this.

## Categories to cover

For each: what it checks, what it *cannot* see, and one citable source
(paper, docs, or issue tracker).

1. **ABI / API differencing** — `libabigail` / `abidiff`, ABI Compliance
   Checker, `abi-dumper`, ABI Laboratory trackers, `dpkg-gensymbols` and
   Debian `symbols` files, `ldd -r`, `dpkg-shlibdeps`.
2. **Dependency resolution and co-installability** — opam's solver,
   pip's resolver, conda, dose3 / EDOS (`distcheck`, co-installability
   analysis), apt's problem resolver, Debian's archive-wide QA.
3. **Ecosystem rebuild-and-test infrastructure — the nearest prior art,
   treat it most carefully** — Debian archive rebuilds and `ratt`,
   `autopkgtest`, piuparts; conda-forge migrators; opam-repository bulk
   builds; `cibuildwheel`; Homebrew bottle rebuilds; Fedora
   `rpmdeplint` / `rpminspect`; openSUSE's ABI checker.
4. **Provenance and supply chain** — SBOM formats and tooling (syft,
   CycloneDX, SPDX), SLSA, reproducible-builds. These answer *where it
   came from*, which is a different question from *does it fit*.
5. **Binding generators and their testing** — SWIG, `bindgen` /
   `cbindgen`, pybind11, cffi, OCaml `ctypes`. Key question: does any of
   them validate against the library the **user** will have, or only
   against the header it was generated from?
6. **Empirical studies of ecosystem breakage** — semver compliance
   (e.g. Raemaekers et al. on Maven), Decan & Mens on cross-ecosystem
   comparison, breaking-change detection, dependency-hell studies.
   These measure that breakage happens; do any *check* for it?

## The distinction to test hardest

Category 3 is the real threat, because those systems genuinely
enumerate configurations and run them. The claimed difference is:

| | ecosystem rebuild infrastructure | this work |
| --- | --- | --- |
| what varies | packages **within one ecosystem** | **provisioning of one component across ecosystems** (apt vs opam vs pip vs source vs staged install) |
| versions | the ones the ecosystem chose | a declared pair, deliberately including mismatches |
| oracle | the build / test exit code | artifact-level checks, each naming a falsifier |
| output | this package builds, or does not | *which agreement was violated, and by whom* |

Find the counterexample if one exists: a system that varies where a
component comes from **across** ecosystems, or that checks artifacts
rather than trusting a build's exit status.

## What to deliver

For each category, 3–8 entries in the style of `literature.md`'s
existing sections: citation, one-paragraph description, then an
explicit **Inherits / Departs** pair saying what this work takes from it
and where it diverges. Close with:

- a one-paragraph verdict on the claim above — confirmed, qualified, or
  refuted, and on what evidence;
- the three entries that a reviewer is most likely to raise as "isn't
  this already done?", with the sharpest available answer to each.

Prefer primary sources and tool documentation over secondary summaries,
and say plainly when you could not verify something.
