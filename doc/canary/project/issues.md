# Project issues — open, per-project, pickable

> 2026-08-19. Split out of [`status_project.md`](status_project.md) §2/§3
> so a standalone agent can own this list. Everything here is OPEN and
> tied to a PARTICULAR project (or to one project's tooling); anything
> framework-level stays in `status_project.md`, and anything already
> fixed lives in [`../worklog/`](../worklog/).
>
> Conventions for whoever picks these up: the project layer's rules are
> in [`landing.md`](landing.md) and the repo CLAUDE.md — bottom-up
> increments, every increment ships a pin (`canary project-test`), and
> `make canary-test` after any edit under `src/canary/`. Live-verify with
> `canary action <project>` before calling an issue closed, and move the
> entry to the worklog rather than deleting it.

## How the entries are grouped

1. **Findings that are real and unresolved** — a run says something true
   that we have not acted on.
2. **Declaration gaps** — the spec is thinner than the project deserves;
   `canary spec-check` names most of these.
3. **Per-project chores** — small, self-contained.

---

## 1. Findings that are real and unresolved

### Found — the arbipher fork cannot serve a staged consumer, and
### `assert_staged = None` let the install claim success anyway (2026-08-19)

The fork's staged world FAILS at `probe_binding_ocaml` while its Built
twin passes. Not a migration bug — a true finding, and the first one the
Installed axis produced on its own:

- Evidence: `src/api/ml/CMakeLists.txt` has **0** `install(` rules in
  `contrib/z3-all/z3` (the fork) against **3** in the official `latest`
  checkout. The fork's tree simply predates/lacks PR #10549's OCaml
  install rules — the same defect `pre-10549` was constructed to hold.
- The staged prefix confirms it: `install/lib` holds `libz3.so{,.4.15,
  .4.15.5.0}`, `cmake/`, `pkgconfig/` — and no `lib/ocaml/z3` at all.
- **The sharper half**: `install_lib` PASSED. Its completeness check is
  `assert_staged = (if official then Some [...] else None)`, so a
  non-official repo asserts NOTHING and the install reports success
  while staging an unusable package set. The defect surfaced two steps
  later, on the consumer, as an undeclared failure. That is a concrete
  argument for the staged-parity item's *completeness* bullet: derive
  `assert_staged` from the DECLARED consumer-facing surface instead of a
  hand list gated on `official` — then the install fails where the
  defect is, for every repo, and the consumer probe stops being the
  detector of last resort.

**Open question (needs a decision — the modeling is a fork in the road):**
the xfail for the same defect is keyed on `src_id = "pre-10549"` and the
install assert on `official` — two different proxies for one fact
("does this ref's install stage the OCaml package"). Options: (a) put
that fact on `source_repo` as a declared capability and key BOTH sides on
it; (b) don't enumerate a staged world for refs that can't serve one
(needs per-ref universe overrides — the universe is per-artifact today);
(c) leave it a live finding and fix the fork upstream (it is our own
fork — cherry-picking the install rules makes the world green and the
finding actionable rather than modeled away). Until this is decided the
fork's staged world stays RED in `action z3` (the default full run) —
deliberately, since silencing it would be choosing (a) by default.


## 2. Declaration gaps

### Fixed — one world-assertion vocabulary (2026-08-20)

"Did this step run in the world its scenario names?" had FIVE
implementations, and by 2026-08-20 four of them had failed:

| was | failure |
| --- | --- |
| `ssl_world_check` / `z3_world_check` / `llvm_world_check` | three byte-identical copies, differing only in a shell variable name |
| sqlite's `asserts` + `with_world_asserts` | appended after `exit $RC` — had NEVER run (fixed 2026-08-19) |
| the opam template's `world_check` + `~log_grep` | never wired for Vendored lib worlds, so cairo/libffi pointed the loader and never checked it obeyed (found 2026-08-20) |
| z3's `assert_staged` | `None` let an install claim success (2026-08-19) |

Now one type: `Canary_world.t` in `base/`, with `Opam_pin` (checked
BEFORE the command, aborts on mismatch) and `Log_names` (checked AFTER,
greped from the step's own log). `pre_shell` / `log_substrings` route the
two kinds to their enforcement points, so a caller can no longer honour
one and silently drop the other — which is exactly the `log_grep:None`
shape that left cairo unchecked. Every assertion carries a `why`.

Pinned as `world.one_vocabulary`: the same claim renders the same shell
wherever declared, the shared builder entry point agrees with the
vocabulary, the two kinds do not leak into each other, the post-hoc form
survives a command ending in `exit $RC`, and every assertion has a
non-empty reason. Falsified two ways (drop the subshell; leak a log claim
into the pre-command shell) and verified at runtime on all three paths —
including hiding the vendored libzstd and watching the world assert turn
the run red.

**Still outside the vocabulary**: z3's `assert_staged` is a `check_post`
on the install step rather than a step-world claim, so it was left alone;
folding it in wants a `File_present` constructor and a look at whether
`check_post` and world assertions should be one thing. Not urgent — it
has a live guard now.


### Found — ninja will not relink a binding whose lib bumped SONAME
### (2026-08-20, surfaced by running the pre-10549 ref)

Running z3's `pre-10549` ref for the first time failed all three of its
Built-binding cells at `build_binding_ocaml`. Two independent causes,
found in sequence:

**1. The env_guard pointed nowhere (FIXED).** z3's Build_binding row
prepends the freshly built `<build>/src/api/ml` to `CAML_LD_LIBRARY_PATH`
so z3's POST_BUILD self-check does not load the opam switch's stale
`dllz3ml.so`. It absolutised with a `$(pwd)/` prefix — correct while
`build` was relative, wrong since the per-ref build dirs of 2026-08-19
made it absolute. The guard expanded to
`<repo>//home/red/code/contrib/…`, which cannot exist. It still SET the
variable, so nothing failed loudly and the shadowing came straight back
(`unknown C primitive 'n_solver_register_on_clause'` — the very error the
guard was written for in 2026-08-13). Fixed by absolutising
conditionally; pinned as `z3.env_guard_paths` (no `//` past the root, and
the guard must still name the build tree), falsified by restoring the
unconditional prefix.

**2. A stale relink ninja would not do (WORKED AROUND, not fixed).** With
the guard corrected the error MOVED, which is how we knew the fix
mattered:

```
Fatal error: cannot load shared library dllz3ml
Reason: libz3.so.5.0: cannot open shared object file
```

`build-pre-10549/src/api/ml/dllz3ml.so` carried `NEEDED libz3.so.5.0`
while the tree's own `libz3.so` has `SONAME libz3.so.5.1` — and no
`libz3.so.5.0` exists anywhere on this machine. Both files are dated the
same minute (2026-08-17 16:49), so the binding was linked against a libz3
that tree no longer produces. **Ninja considered `dllz3ml.so` up to
date**: its recorded inputs had not changed, and a dependency's SONAME
bump is not one of the things a build system's timestamp/hash check
looks at.

Deleting the ml link outputs (`dllz3ml.so`, `libz3ml.a`, `z3ml.{cma,cmxa,a}`)
and re-running the target relinked it against `libz3.so`, and all five
pre-10549 cells then ran.

**Why this is a canary-shaped finding, not just a chore.** It is the same
failure the framework exists to detect — a binding and the library beside
it disagreeing about a soname — arriving in canary's OWN build trees, and
invisible to the build system that produced it. The generalisable fix is
the one `artifact_cache.md` §5 already proposes: a step's fingerprint
must include the IDENTITY of its input artifacts, not only its own
command text. A libz3 whose soname changed is a different input artifact;
today nothing records that, so nothing invalidates the binding built
against the old one.

**Open**: no guard exists yet. A cheap first one, in the spirit of
sqlite's `.built-<version>` stamps: after `build_binding`, assert that
every `NEEDED` entry naming the project's lib matches the soname the
tree's lib actually exports. That turns a silent stale relink into a
failed step.


### Found — every template project is HALF a 2×2, and the template
### cannot express the other half (2026-08-20)

Reading the result matrix, rows 33–40 (cairo, libffi, zlib, zstd) show
two C-lib versions against **one** OCaml binding; ssl's rows show two
bindings against **one** lib. Both are half of the 2×2 the user set as
every project's lower bound, and the halves are complementary — nothing
outside sqlite and z3 has both axes.

The mechanical part is small: ssl declares its binding axis as
`SC.Lang_pkg { versions = Some [pins] }`, while `Canary_opam_binding`
hardcodes `versions = None`
([canary_opam_binding.ml](../../src/canary/project/canary_opam_binding.ml)),
so no template project can carry one. A field plus threading.

The part that is not small is that an opam pin is shared state. Measured
costs and the design consequences are in
[`../design/store_switching.md` §5](../design/store_switching.md); three tiers, per the
user's reading:

| tier | projects | pin cost | verdict |
| --- | --- | --- | --- |
| 1 — the package alone | zlib, cairo | 1 downgrade | **fine, could land today** — opam cannot hold two versions of a package anyway, so a swap is inherent |
| 2 — collateral rebuilds | libffi | 2 downgrades + **3 recompiles** (`llvm.19-shared`, `yaml`, `zstd`) | **both good and bad** — contamination for a clean libffi test, but each rebuild is itself a consumer/provider compatibility test we cannot enumerate. Decide what it is FOR before isolating it away (§5e) |
| 3 — the compiler | zstd | 3 removed, 37 downgraded, **157 recompiled**; `ocaml` 5.4.1 → 5.1.1 | **out** — a whole-switch compiler downgrade to run one scenario |

**Do not land a partial fix that adds the field and declares all four
pairs.** zstd's pair alone rebuilds the switch against OCaml 5.1.1.


### Open — supplying the DEV half from a prebuilt (the zstd route we
### did not need)

zstd was briefly blocked because `conf-zstd` runs
`pkg-config --atleast-version=1.3.8 libzstd` and this box had `libzstd1`
without `libzstd-dev` — no `.pc` file, no header. The user installed
`libzstd-dev` and the project landed the ordinary way (2026-08-20), so
this is no longer a blocker. What stays open is the route it pointed at:

conda-forge's `zstd` package ships `include/zstd.h` and
`lib/pkgconfig/libzstd.pc` alongside the runtime object. Pointing
`PKG_CONFIG_PATH` and the include path at a prepared prebuilt would
satisfy a conf package with **no system dev package at all** — which is
how a project would test a library version the distro does not ship in
any form, and the only way to reach a version older or newer than the
distro's on the COMPILE side rather than the load side.

Two things it needs. The prepare step currently supplies runtime only, so
a declaration would have to say which conda package half it wants (zlib
splits `libzlib` / `zlib`; zstd does not split). And it changes which
world is "stable" — the system PM is the stable point by the sourcing
rule, and a world with no system package has to say what it is instead.
Its own small arc, not a fold-in.

### Found — a vendored world can be POINTED without being CHECKED
### (2026-08-20; cairo and libffi still are)

`Canary_opam_binding.probe_names_lib` (added with the zlib landing) makes
the Vendored probe assert that the library the loader actually mapped is
inside the prebuilt's libdir. It requires the project's example to PRINT
what it resolved — zlib reads `/proc/self/maps` and prints
`zlib resolved: <path>`.

`cairo` and `libffi` declare `probe_names_lib = false`: their vendored
worlds set `LD_LIBRARY_PATH` and nothing verifies the loader obeyed.
(zlib and zstd both declare `true` — zstd's probe carries two witnesses,
the loader's mapped path AND a runtime `ZSTD_versionNumber()` call.)
cairo is the worse of the two (its two versions export identical symbol
counts, so a fallback is invisible in every verdict); libffi is the more
interesting (a `Dynamic_ffi` consumer resolves through `dlsym` at
runtime, so "which libffi answered" is the entire question).

**Fix**: teach each example to print its resolved library — the same
`/proc/self/maps` scan zlib uses, matching on `libcairo.so` /
`libffi.so` — then flip the flag. The pin
`vendored.probe_names_the_world` already covers all three projects and
will start enforcing the assert as soon as the flag turns true.


### Found — a gate can live in the BINDING's own build, and `pm_dep_gate`
### cannot express it (2026-08-20, from the conf-* survey sampling)

`mlmpfr` declares a bare `"conf-mpfr"` dependency, so by metadata alone we
would tag it `Free_with_conf`. Measured, that is wrong: its opam `build:`
compiles and RUNS an extra-source C program that reads `MPFR_VERSION_*`
from the installed header and exits nonzero when the lib is older than the
binding:

```
build: [ ["cc" "mlmpfr_compatibility_test.c" "-lmpfr" "-o" …]
         ["./mlmpfr_compatibility_test"]        ← nonzero aborts the build
         ["dune" "build" "-p" name "-j" jobs] ]
```

So mlmpfr 4.2.1 refuses to build against mpfr 4.2.0, and its opam version
tracks mpfr's (mlmpfr.4.2.1 ↔ mpfr 4.2.1). The gate is real, enforced, and
invisible to `opam show --field=depends` — the only place we look today.

**What it needs**: a `Self_check_in_build` constructor on
`Canary_binding_decl.pm_dep_gate`, whose `combination_freedom_of` is a
lower bound derived from the binding's own version. NOT added yet: no live
user until mlmpfr lands, and the codebase rule is to grow by concrete
increments.

**Why it is worth landing**: mlmpfr's forward mismatch (new binding over
old lib) is rejected by a check the upstream package already ships — a
naturally occurring xfail rather than a constructed one, which no project
in the registry has. Details and the ranked context:
[`../surveys/conf_packages.md` §G1b](../surveys/conf_packages.md).

### Open — assert that a version-bearing gate names a version-carrying conf

Measured (§G1a): 13 of 370 conf packages enforce a library version — 8 by
a pkg-config predicate (`conf-efl`, `conf-gtk3`, `conf-libblake3`,
`conf-libmd`, `conf-libuv`, `conf-openimageio`, `conf-taglib_c`,
`conf-zstd`, all floors) and 5 by feeding the opam version to a script
(`conf-llvm{,-shared,-static}`, `conf-libclang`, `conf-qt`, all
generations). Any declaration that sets `Fixed_with_conf`, or
`Bounded_with_conf { tracks_lib = true }`, over a conf package outside
that list is a declaration bug. The list is small and stable enough to
hardcode as a `project-test` invariant, and
`doc/canary/raw/conf_version_carriers.py` regenerates it; not yet wired.


### Found — spec non-uniformities (2026-08-13, `canary spec-check`)

The static checker audits the artifact table AS DECLARED. The first
report's four non-uniformities: three CLOSED by the 2026-08-13
fulfillment (pattern-A typed rows + sources, sqlite's source row +
api_source, tiny-full's `pr_api_source`); the remaining ones are
recorded here, reported as-is, NOT special-cased in checker code:

- **z3/llvm** source rows carry the STABLE repo's provider; per-channel
  (dev) source providers are the known not-yet-wired provenance
  refinement.
- **tiny-full** declares its api_source on `project_run.pr_api_source`
  (its source row is Vendored, not repo-carried) and is exempt from the
  reporting-oriented checks (in-tree witness).
- **sqlite's source row is declaration-coupled via `~follows:a_lib`**
  (the amalgamation version IS the lib's version) — source-follows-lib
  is a new axis direction, first used here.


### Open — install inspection gaps

- **`make install` template** — `cmake_install` is the only templated
  install. Autotools (`make DESTDIR=$PREFIX install`), meson, etc. need
  templates. Not yet planned in detail — to be discussed (user,
  2026-08-12).
- **Build-path leakage** — `prefix_layout_inspect_cmd` inventories the
  installed tree but doesn't check for hardcoded build-tree paths (rpath
  → `_out/`, baked `-I` in `.pc` files). A default install inspection
  should verify the installed artifact is relocatable.
- **tiny install scenarios** — tiny1 has no `Install_lib` scenario. A
  `build_install` scenario (built → installed → staged-probe chain)
  would catch install embedding build paths; a `wrong_lib_install` case
  (stale artifact or dev-lib-installed-as-stable) would test install
  identity.
- Prefix safety IS enforced: `test -n "$PREFIX"` in `cmake_install_cmd`
  refuses empty/system paths — canary never global-installs (fetch
  actions are the only intended global-store writes).

### Known — CI runs the pre-A5 shape

`ci_jobs` (`canary_run.ml`) derives steps from legacy `runner_spec`
values — one chain per project, not the enumerated scenario set. Realign
with the registry when CI grows scenario coverage.


## 3. Per-project chores

- [ ] **Spec-check warning-reconsideration pass** — zarith's
  `python_binding` ⚠ is a naming-scope artifact (the LIB is gmp, whose
  python binding is gmpy2; zarith is only the OCaml binding — an
  OCaml-focused project legitimately skips it). Revisit the warning's
  semantics when a gmp-named project (or a second zarith binding)
  lands; user confirmed leaving it for now.

- [ ] **Build-step store-hazard audit** — the z3 self-check shadowing
  class; audit other build steps' store reads (env_guard
  generalization).

**Pending (user, 2026-08-17 — AFTER active plans 3&4)**:


- [ ] **Extend tiny with the Publish** — the wrapper decl + primitive
  give tiny an opam-visible artifact when it wants one.

**Housekeeping**:


- [ ] **Upstream z3 PR** — POST_BUILD self-check env isolation
  (2-line CMake patch); per user, AFTER the 3-way repo work.

- [ ] **spec-check warns fulfillment** — the ratchet-tracked ⚠ set:
  llvm's missing Publish row (`llvm.dev-shared`); the pattern-A trio +
  ssl's wrapper/python/built-binding gaps; sqlite/tiny-full's binding
  dev-source.
- [ ] **Real-world PRs** — find a bug with canary, fix it, submit
  upstream PR, link from the results page (the z3 PR above is the first
  candidate).

