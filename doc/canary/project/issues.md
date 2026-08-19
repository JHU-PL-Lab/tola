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
- [ ] **New project candidates** — OpenSSL/libressl, protobuf, grpc,
  jq/oniguruma, lwt+libev, cvc5, PyTorch (plan in
  [`project_pytorch.md`](project_pytorch.md)). Queue + sequencing in
  [`index.md` §2](index.md).

