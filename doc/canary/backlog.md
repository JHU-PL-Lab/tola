# Canary Backlog

Lower-priority TODOs moved out of CLAUDE.md to keep it concise.
Numbers are stable (never renumbered). See CLAUDE.md for active TODOs.

5. **CI mode for opam depexts** — use `--confirm-level=unsafe-yes` to let
   opam auto-install system deps in Docker/CI. Currently local dev uses
   `--assume-depexts` (requires pre-installing system deps manually).

9. **Binding build dependencies** — z3's OCaml binding requires `zarith`
   at build time. Model per-binding opam deps so `build_binding` can
   ensure they're installed. Add `binding_deps` to `ocaml_tool_config`.

11. **tqdm-style progress display** — redirect verbose build output
    (cmake/ninja) to a log file, show a `\r`-overwriting single-line
    status on tty. `run_cmd_logged` already has the logging layer.
    *Half done (verified 2026-08-30):* every step's output already lands
    in `<tag>.out.log` — `run_step` wraps the command in `… 2>&1 | tee`,
    deliberately mirroring to the terminal so a long build shows
    progress. What is left is only the `\r` single-line rendering, i.e.
    replacing the mirror, not adding the capture.

13b. **Driver mode: read `run_info.json`** — allow `canary action --from
    run_info.json` to replay or reconfigure a run. Enables reproducibility.

14. **z3 cmake `Z3_BUILD_LIBZ3_CORE=OFF` bug** — cmake ignores `Z3_ROOT`
    and binding flags. Workaround: always build libz3 from source in opam
    template. See `doc/note/z3_bug_api.md`.

16, 20, 31, 35, 41, 42. **API compatibility model** — binding_api.deps
    split, C API surface (consumer/provider cross-check + provider-vs-
    provider delta), mismatch prediction, Python summary enhancements.
    The shipped portion (Steps C1, D-basic for OCaml + Python) is
    documented in `doc/canary/research/surface_draft/implementation.md` §2.7. Open items
    (#35, #20, #41, #42) remain.

44. **L2 — typed signatures via clang AST or libclang** — c6 `cmp_type`
    ships today as a trivial-grep inspector (`check_type` in
    `surface/canary_compat.ml`; `inspect_tiny_typed.py`'s `header` layer
    is a regex, other layers hardcoded). Replace the grep with real
    clang-AST / libclang extraction so `check_type` becomes true subtyping
    — contravariance on argument types, covariance on results, refinement
    on value domains — rather than name+shape matching. Catches "same name,
    different signature" drift the grep can miss. Not a blocker for
    anything, but the type_wrong triage (2026-08-05, status §B) sharpened
    the payoff: a BODY-only c6 lie (header/stub declarations agree, the .c
    body lies) is invisible to every static layer today — the oracle
    confirms it only as an UNATTRIBUTED xfail. A body-reading inspector is
    what turns that `[]` into `[c6]` and moves tiny1 coverage past 12/24.
    *Deprioritized (user, 2026-08-05)*: enhancement, not milestone work —
    no real project's derived contracts consume typed inputs today, and
    the proper clang path drags preprocessor/include/typedef handling;
    revisit when a real project needs a typed C surface. (If it is ever
    picked up: the impl/body layer must feed the PROBE firing only —
    type_wrong's build is legitimately green, per the 2026-08-05
    probe-class strengthening.)
    Prior art: the dead-code example at
    `doc/_legacy_code/canary_dead_code.ml`. See
    `doc/canary/research/surface_draft/surface.md` §2.4 (Type contract) and
    §10.3 (Toward a formal model).

17. **Module surfaces (.mli)** — define contracts for PM modules
    (`canary_pm_{apt,brew,opam,pip}`) and project modules (`canary_project_*.ml`).


27. **Opam template taxonomy** — `llvm.dev-shared` is an "install pre-built"
    package (copies artifacts from `CANARY_BUILD_DIR`); `z3.dev` is a
    "build from source" package (runs cmake+ninja inside opam build phase).
    Distinguish by a header comment convention or directory structure so the
    intent is explicit and future templates know which pattern to follow.

29, 32. **New project spec auto-generation.** (#30 — the `store_config`
    type — **shipped** as S3 on 2026-07-23, `tool/canary_store_config.ml`:
    artifact provenance is a typed `provider` and `fetch_lib` resolves as
    `Derived` from it. The remaining half is `fetch_binding`, where
    `Derived` can't yet reproduce opam `install_args`
    (`--assume-depexts`).)

    Trigger: worth doing when project count reaches ~10. At 8 projects
    (2026-08-05) the hand-written approach still holds — and the
    `project_run` data-spec shape already moved much of what step 2 below
    wanted from code into declared tables, so **re-scope before acting**.

    **Step 1 — `package_locator` as a first-class type (#29).** Locator
    logic (`llvm-config`, `pkg-config`, `brew --prefix`) is currently
    ad-hoc shell inside each project's `probe_lib`. Factor into:

    ```ocaml
    type discovery_method =
      | Pkg_config of string          (* pkg-config --variable=libdir <name> *)
      | Llvm_config of string         (* llvm-config-N --libdir *)
      | Brew_prefix of string         (* $(brew --prefix <name>)/lib *)
      | Glob of string                (* ls /usr/lib/.../lib<name>.so* *)

    type package_locator = { linux : discovery_method; macos : discovery_method }
    ```

    `probe_lib` shell becomes derivable. `lib_locator` in
    `canary_opam_binding.ml` is the prototype.

    **Step 2 — auto-generated `runner_spec` (#32).** Given a sketch +
    locator + store_config, generate the full `runner_spec`:

    ```ocaml
    val mk_runner_spec_from_sketch :
      name:string -> locator:package_locator -> stores:store_config ->
      api_source:Canary_artifact_api.t -> source:source_repo ->
      unit -> runner_spec
    ```

    Covers the Pattern A case. Source-build projects (z3, llvm) stay
    hand-written but adopted `store_config` for their provider tables in
    A8. Project shapes + landing mechanics: `doc/canary/project/landing.md`.


33. **Adopt `<pkg>.dev-src` naming convention for source-only opam packages** —
    rename `z3.dev` → `z3.dev-src` in `canary/templates/opam-local-repo/` and
    update `canary_project_z3.ml` accordingly. Apply the same convention to all
    future canary packages that build entirely from source with no system PM
    dependency. The `-src` suffix signals: this package is self-contained,
    transparent to source code, and not affected by what the system PM provides.
    This matters for projects where the system PM lags far behind HEAD or is
    inconsistent across distros — the `-src` variant gives reproducible,
    system-independent testing. Contrast with `-sys` (system-backed) and the
    upstream opam packages (which build from source but are version-pinned).
    See `ops/opam_packaging.md` for the full naming rationale.

34. **GH CI multi-platform support** — `detect_pm ()` is called at derivation
    time on the local machine, baking Apt/Brew into the generated YAML. For
    macOS CI, the per-project spec constructors (`mk_runner_spec` and the
    `project_run` `realize` functions) need a `~target_pm` parameter
    (alongside `~tola_root`) so CI jobs can specify the target PM
    independently of the local host. Follow-on: add OS-conditional step support to
    `canary_gh.ml` (render `if: runner.os == 'Linux'` guards) and a
    matrix strategy (ubuntu-latest × macos-latest, OCaml version axis).
    *A5 note (2026-08-05):* the entry points are now distro-parametric
    (`z3_run`/`llvm_run : distro → project_run`), so `~target_pm` has a
    natural seam; the remaining local bind is `detect_pm ()` inside
    `mk_runner_spec` bodies.

    *2026-08-30 — the stated blocker is gone; half the item is done.* The
    PM is no longer sniffed at derivation time: `detect_pm () =
    system_pm_of_platform (platform ())`, and the platform is one carried
    session value, overridable with `--platform=macos|wsl` or
    `CANARY_PLATFORM` (see `design/platform.md`). So rendering a macOS
    view from a Linux host already works, and no `~target_pm` parameter
    is needed — the session value beat the threaded parameter.
    **What remains** is the follow-on half, untouched: OS-conditional
    steps in `canary_gh.ml` (`if: runner.os == 'Linux'` guards) and a
    matrix strategy (ubuntu × macos, OCaml version axis). Re-scope
    against `Canary_ci`, not the retired `*_ci_spec` path.

37. **Bundled mermaid.js for the HTML viewer** — `backend/canary_html.ml`
    loads mermaid from a CDN, so a run's `result.html` needs network access
    to render. Add a `--bundle-mermaid` flag that inlines the library for
    offline / archived viewing. (All the rest of the original #37 — inline
    render, per-view selector, log drill-down in a side drawer — shipped;
    see `design/diagram.md`.)

38. **`pack_python` action — local pip wheel packaging** — `pack_binding` is
    currently OCaml-only (opam packaging). A Python equivalent would build a
    pip wheel from the locally-compiled Python extension and install it into a
    local pip index or venv, enabling a `probe_python_pip` variant that tests
    the packaged wheel rather than the raw build artifact. Prerequisite:
    `probe_python` build-tree variant (test the raw `.so` before packaging)
    as the base to compare against. The co-provider design (pip wheels
    bundling their own native lib) is deferred to a future `package_theory.md`
    — see `doc/canary/research/surface_draft/package.md` for the deferral rationale. `pack_python` for
    z3 would produce a co-provider artifact.

39. **Dynamic scheduling / action dispatch** — `derive_steps` produces a static
    ordered list; `run_graph` walks it linearly. There is no mechanism to
    conditionally trigger steps, register follow-ups keyed by a trigger rule, or
    react to runtime outcomes (success, failure, produced artifact). Three ad-hoc
    cases in `derive_steps` (`scan_source`, `_inspect`, `probe_binding`
    multi-probe) all share the same shape — a parent rule emitting dependent
    follow-up steps — but each was wired in separately (action enumeration
    tension; see worklog history). A general dispatch model would let steps
    register themselves as followers of another rule, turning those special cases
    into declarations. Longer term, conditional dispatch (only run if upstream
    produced artifact X, or only on failure) would enable retry logic, staged
    probes, and the driver-mode replay from #13b. Not urgent while the step list
    stays small and manually curated; revisit when #40 (real cmake --install) adds
    another follow-up shape or when conditional execution is needed for CI.

    *2026-08-30: that trigger has fired.* #40 shipped and did add the
    shape — `install_lib` → `probe_lib_staged` is a fourth ad-hoc
    parent-emits-follow-up case, and it is gated on a provision
    (`ar_needs`), which the other three are not. So the general dispatch
    model now has four instances and one of them already carries a
    condition. Worth re-scoping against `ar_needs` before designing.

40. **Replace fake `install_lib` with real `cmake --install`** — **DONE**
    (z3 2026-08-17/19, llvm earlier; verified 2026-08-30). Both projects
    install for real, through typed templates rather than `cp`:
    z3 `Cmake_install { prefix; assert_staged }` gated `ar_needs = Some
    Installed` at `<project>-all/install-<ref>` (per ref, never shared);
    llvm `Cmake_install_component { component = "LLVM" }` at
    `<build>/../install`, firing under the default `Built` rule.
    `emit llvm --stage realize` on a dev scenario shows `install_lib` →
    `probe_lib_staged`. The `$PREFIX` convention landed as predicted, and
    `cmake_install_cmd` additionally refuses an empty prefix at run time
    so no caller can fall through to `/usr/local`.

    The install-time transformations this was for (RPATH rewriting,
    versioned symlinks, config-file generation) are now exercised, and the
    first finding came straight out of them — see the arbipher-fork entry
    in `project/issues.md` §1. Remaining install work is tracked there
    (`Open — install inspection gaps`), not here.
    Reference: `doc/canary/ops/install_targets.md`. (The same entry
    subsumes the old #25, which never had its own line in this file.)

45. **z3-solver pip wheel is a co-provider (bundles its own libz3.so)** —
    `z3-solver` is not a pure Python binding that depends on a separately
    installed `libz3.so`; it ships its own copy of `libz3.so` inside the
    wheel. This makes it a *co-provider*: one pip install delivers both the
    native lib and the Python extension. Two gaps follow:

    **Diagram**: a `lib -.->|runtime|` edge into the python fetch/probe
    nodes is misleading — z3-solver does not consume the externally built
    lib at runtime; it carries its own. The correct diagram would show the
    python binding node as self-contained (no runtime edge from the lib
    kind). (The entry originally named `lib_build_tree_node`; that symbol
    no longer exists — re-locate the edge in `backend/canary_diagram.ml`
    before acting. Note the runtime edge is exactly what `dep_mode`
    now models — `Ambient` is this case — so the fix may be to declare
    it rather than to special-case the drawing.)

    **Action enumeration**: `derive_steps` models Python bindings as always
    depending on the native lib for runtime. A co-provider package violates
    this assumption. The spec needs a way to declare that a pip package is
    self-contained (co-provider), suppressing the lib runtime edge and
    potentially adding a separate inspect step to surface the bundled lib's
    symbol set for compat checking.

    See the (future) `package_theory.md` (co-provider design — deferred) and
    backlog #38 (`pack_python` wheel packaging, which has the same
    co-provider shape on the producer side).

    *2026-08-05 evidence (A5/A7, status §A):* the co-provider behavior is
    now MEASURED on the generic runner — z3's parser_context xfail fires
    identically in both chains because the wheel's bundled libz3 never
    varies with the lib axis (the Ambient-edge scenario-invariance).
    "Declare the package self-contained" is the Ambient instance of the
    `dep_mode` value-source question (status §A, A5 residue (ii)) — solve
    them as one declaration.

46. **Engine vocabulary alignment in code (post-stabilisation polish)** —
    After `doc/canary/research/draft.md` (the manuscript) stabilises, audit
    OCaml sources for engine vocabulary alignment. The
    store / runner / producer factoring already permeates the code; adding
    explicit *mutation engine* / *combinator engine* naming would clarify
    the header comments of `src/canary/projects/canary_project_tiny.ml`
    (combinator-side) and `canary_tiny_workspace.ml` (mutation-side).
    Background: the engine framing is the manuscript's backbone distinction
    between concrete-trace (mutation, the tiny factory) and abstract-trace
    (combinator, canary on per-kind stores) machinery; see
    `draft.md` §Implementation slots. Low priority; part of the
    post-stabilisation polish pass driven by the "uniformity eventually"
    principle.

    (Was written against `research/surface.md` and the Python harness at
    `canary/examples/tiny/scenarios/scenarios.py`; the manuscript is now
    `draft.md` and the Python harness was retired to
    `doc/_legacy_code/tiny_python_harness/` in Phase E of the tiny
    migration, so the mutation side is OCaml now.)


## Polish (moved from status.md §E, 2026-08-06)

No hurry — all items below are queued for when their forcing function arrives.

- **Global output/cache root env var** (user, 2026-08-13). `_out` is the
  literal string at ~10 bin-layer call sites (`canary_main.ml`
  `~root:"_out"`), and it carries real build caches worth keeping across
  cleanups. Wanted: one env var (`CANARY_OUT`, name TBD), default `_out`,
  so the cache can live outside the repo or on another disk. The string
  already flows through `~root` params everywhere — a one-helper
  refactor. Companion to the 2026-08-13 dune fix (`(dirs :standard \
  {docs,_out})`): an external root needs no dune change; `_out` stays
  excluded either way.
- **docs/canary copy bloat** (found 2026-08-13).
  `canary_diagram.ml` L2349 `cp -r <run_dir>/* docs/canary/projects/
  <project>/` copies WHOLE run dirs — fetched source checkouts (with
  `.git`), build trees, install trees — into the tracked docs tree:
  27G / 520k files today, 880 untracked files churning git status. It
  also made dune walk docs/ on every invocation (~2-3s startup; fixed at
  the dune level by the same-day `(dirs ...)` exclusion). **DONE
  2026-08-13**: `write_project_output` now does a filtered recursive
  copy (ext whitelist json/log/mmd/html + artifact-dir blocklist, in
  OCaml — no shell), verified via `canary view llvm`; the accumulated
  junk pruned (docs 27G → 53M, 501k → 3.2k files; untracked churn
  868 → ~120); the 4 tracked ssl probe binaries deleted +
  gitignored (`docs/**/ssl_app_*`).
- **Env/PATH discipline utility** (user, 2026-08-06). Step
  commands splice PATH-like variables ad hoc (`LD_LIBRARY_PATH=$PWD/…:$…`
  probe repoints, `PYTHONPATH` in the tiny workspace, `OCAMLPATH`,
  `eval $(opam env)` sprinkled per command) — string surgery on
  `:`-separated variables is exactly what produced the born-safe-id bug
  (a `:` in a workspace name silently split PYTHONPATH; see Gotchas).
  Wanted: a small tool/ utility for typed env manipulation (prepend/set
  per variable, emitted as the command's export preamble — the
  `probe_ocaml_env_cmd ~env` list is the seed) + a ratchet-style guard
  against new raw `VAR=…:$VAR` splices in project specs. Do when a case
  next touches probe envs.
- **Version definitions + printers: centralize** — **DONE 2026-08-06.**
  `string_of_channel` + `string_of_version` in `Canary_basic`;
  `source_repo.version` typed (`Canary_basic.version`); `build_id`
  rebased on it; all 5 inline printers killed; `version_printer_ratchet`
  guards against regression. The DEEPER typed unification (version as
  artifact identity across enumeration/store/cache) stays
  `design/enumeration/stage1_declare_spec.md` §5 — not this
  item.
- **Tool-routing ratchet burn-down** (guard shipped 2026-08-05, user
  to-do: `harness.tool_routing_ratchet` in `project-test` freezes
  per-file counts of raw shell verbs in `projects/` — cmake / ninja /
  gcc / curl / unzip / pip install / opam install / nm -D / git clone /
  tar; any NEW raw use fails: route it through a `src/canary/tool`
  primitive). Remaining = shrink the baseline to zero — sqlite
  `built_spec`'s raw gcc/curl/unzip + nm (§1c #5), llvm's pip/opam
  raws — the cleanup half of TODO #18, natural with A9-step-2; lower
  the baseline in the same commit as each cleanup. (sqlite burned to
  ZERO 2026-08-05 via new `curl_unzip_cmd`/`cc_shared_lib_cmd` +
  `native_lib_probe_cmd`; remaining: llvm pip chain — needs a
  pip-install-any primitive with the uv fallback — and the opam-install
  raws.)
- Tri-view command (factory / tiny1 / tiny-full on the `Bs.N` key).
- Factory comment sweep (resource → cached artifact in
  `canary_tiny_scenario.ml`, minding the legit `Vendored` *provision*).
- Full-lazy `detect_pm` (skip entirely for `spec`/`paths`/`graph` — needs
  deferring runner_spec construction; §1c #2).
- Wire the `latest` channel (§1c #3).
- Scenario names + `docs/canary` output volume.
- **Terminology sweep: `variant_*` code identifiers → `scenario_*`**
  (display unified 2026-08-05; the id rename touches cache/filename keys —
  one deliberate pass, not ad hoc).
- **"scenario" overload vs the abstract senses** (`Sc.N` patterns, coverage
  *stages*; the `canary scenarios` CLI shows stages with a stale count) —
  audit + T0/T1/T2 options + open questions in
  the OPEN "scenario" terminology to-do in [`status.md`](status.md) M2 "Canonical naming settle". OPEN — no
  decision; do T2 together with F5 + the `variant_*` sweep as ONE
  terminology pass. **Deliberately LAST (user, 2026-08-05, bottom-up):**
  the canonical scenario↔action relation should be WRITTEN DOWN only
  after the near-term concrete actions land (build-for-install, probe
  roles, two-instance scenarios) — the added cases decide the terms,
  not the reverse. (Candidate frame to test against them, kept in mind
  not committed: action = a pattern with slots; scenario = a consistent
  slot-filling; dep_mode = a constraint on fillings.)

47. **`has_build_*` boolean-branching residue** — **DONE 2026-08-06.**
    Both `has_build_lib` and `has_build_binding` removed from
    `source_repo`. z3/llvm `mk_runner_spec` takes explicit
    `~build_lib`/`~build_binding` bool parameters passed from
    `realize`; CI passes them directly. The
    `build_flags_match_declared_provisions` pin retired.
    `cmake_build_binding` stays as a finer CI knob.
    The entry's original
    framing ("two store-selection conventions; promote `stores` to a
    first-class field of `script_spec`") is **superseded**: `store_config`
    (S3, 2026-07-23) made provenance a typed `provider`, and A8 made the
    whole project spec DATA (`pr_spec` universe table + `pr_provenance`).
    `script_spec` and `mk_script_spec` no longer exist.

    What remains is the narrow residue: `source_repo.has_build_lib` /
    `has_build_binding` booleans
    ([canary_artifact_source.ml:26-27](../../src/canary/tool/canary_artifact_source.ml))
    plus per-project `if source.has_build_lib then … else None` branches
    in z3/llvm's `realize`. On the generic path that information is
    already carried by the spec — an artifact's `Built` provision in
    `ps_universe` says the same thing — so the booleans are a second,
    unreconciled encoding of build capability. Fold them into the
    provision axis; the enable/disable semantics then come from the
    declared universe rather than a flag. Not urgent. Originally
    discovered while designing the §9.3 Task 1.6 factory
    (`worklog_2026_07.md`).

    *A5 note (2026-08-05, promoted to status §A A5 residue):* z3/llvm now
    declare `ps_universe` AND still branch on the booleans inside their
    realizations — the double encoding is live on the generic path, and
    `has_build_binding` is exactly the binding-follows-chain information
    (A5 residue (iii)) in boolean disguise. Fold them together.

48. **A general staleness check — docs, comments, and any citation of a
    name that can be deleted** (2026-08-23, user: *"the test check for doc
    pin and staleness may be a good idea but it can be a general feature
    instead of only for doc"*).

    Built and then removed the same day: a pure test read
    `doc/canary/design/enumeration/*.md`, extracted backticked tokens
    shaped like a pin name, and failed if one was not a registered test.
    It worked — it caught two pin names invented from memory
    (`vocab.artifact_ids`, `surface.split`) and one record field cited as
    a pin (`source_repo.artifacts`) — but it was one narrow instance of a
    general problem, wired to one directory, with a hand-maintained
    exclusion list. Reverted so the general shape can be designed
    instead. Implementation reference:
    `git show 70c1cbb -- src/canary/main/canary_projects_test.ml`.

    The general problem: **a reference to a name that can be deleted goes
    stale silently, and prose cannot notice.** Live instances beyond doc
    pin citations —

    - **Docs → pins.** What the removed check did.
    - **Docs → source paths.** Already an ad-hoc shell sweep (it found
      four docs whose every `../../src/…` link was broken by depth, and
      `ssot.md` citing a module deleted in A6).
    - **Source comments → docs.** Comments cite doc paths and section
      numbers; three pointed at docs deleted in `b822d88` / `9edf15b`,
      and two still cite `api_surface.md` §13/§15 and
      `surface_theory.md` §2.5, which exist nowhere.
      *Counted 2026-08-30:* **~16 live citations of `status §A`/`§B`/`§C`
      (plus `status.md §1a`/`§1b`) across `src/canary/`** — status.md has
      had no lettered sections since it was reorganised, so every one of
      them resolves to nothing. They are spread over ten files, which
      makes this the largest single instance and a good first target for
      whatever resolver gets built.
    - **Docs → CLI subcommands and flags.** `testing_plan.md` proposes
      `canary pipeline-test`; nothing asserts a cited subcommand exists,
      or that a documented flag (`--refs`, `--thin`) is still parsed.
    - **Docs → project / scenario names.** A doc naming a project that
      left the registry, or a scenario dir the enumeration no longer
      produces.

    Shape worth considering: ONE citation checker over a small typed
    vocabulary of reference kinds (pin name, source path, doc path, CLI
    verb, project name), fed by a resolver per kind, run as part of
    `make canary-test` — rather than per-kind greps. The exclusion
    problem (record fields and package names that look like pin names)
    is the part that needs real design: a marker convention at the
    citation site would beat a blacklist.

49. **ONE pipeline, one set of docs — merge `enumeration/` and
    `agreement/`** (2026-09-15, user: *"now both the canary and the
    checking are integrated well, so I am thinking shall we have one
    unified pipeline so that we can reorganize the doc"*. Explicitly
    **no hurry**).

    The two directories were written when checking was a separate
    concern bolted onto a run. It is not any more: a step carries an
    `agreement_ctx`, the runner calls `evaluate_in_context`, and
    `canary result`'s columns are `pre → action → artifact → post`.
    Checking is a phase of the pipeline, and the docs still describe two
    pipelines.

    What the merge would have to settle, and why it is not a file move:

    - **Where the check phase sits.** The enumeration is six passes
      ending at `realize` (`world → steps`). Evaluation happens INSIDE
      pass 6's execution, per step — so it is either a further pass over
      a different IR (verdicts), or a property of pass 6 that pass 6's
      doc does not currently mention. Both readings are defensible and
      they produce different documents.

      **Half of it is settled since 2026-09-16.** APPLICABILITY — can
      this project carry this claim — is world-free, so it is pass 2
      ([`design/enumeration/stage2_analyse_spec.md`](design/enumeration/stage2_analyse_spec.md)).
      FIRING needs a world and stays at realize. So the seam does not
      run between the two directories: part of the CLAIM's own
      machinery is already an enumeration pass.
    - **Two action-column orders still exist** (`registry.md` §7.4.4):
      `canary result` uses `Canary_matrix.compare_column`, `--firing`
      uses `Canary_basic.actions_of_lang`. A unified pipeline doc that
      shows one grid has to pick.
    - **The reading path.** `enumeration/README.md`'s four-step *How to
      read this, if you are new* is the best thing in either directory;
      `agreement/README.md` is a map of four files. One merged entry
      point should keep the first shape.

    **The seam, stated (2026-09-15, user):** *agreement/ owns the CLAIM,
    enumeration/ owns the OCCASION.* Everything that decides WHEN a check
    fires is a function of `(world, action, mechanism, lang)`, which is
    enumeration's vocabulary, not the agreement layer's. Two things make
    it more than a preference:

    - `stage6_realize_steps.md` mentions "agreement" **zero times**, and
      it is the doc for the pass that attaches `agreement_ctx` to every
      step;
    - `agreement/pipeline.md` already IS that document, filed in the
      wrong directory — its §§2–5 are *the enumeration produces a
      world*, *derive_steps attaches the action context*, *the step
      runs*, *evaluate_step*. So the merge relocates a spine rather than
      inventing a section.
    - `enumeration/README.md`'s **"What is NOT here"** is where the
      boundary is currently declared, and it is wrong on both halves:
      it sends "which contract fires" away (that is the occasion, which
      should come IN) and it points at `surface/`, renamed to
      `agreement/` in 2026-09-01.

    **And evaluation is NOT a further pass.** Pass 6 attaches the context;
    the RUNNER BACKEND evaluates. The step list is object code consumed
    by four backends and only one of them checks anything — GH-render,
    Mermaid and HTML evaluate nothing. A further pass would put a stage
    above the IR that one consumer reaches.

    **Sequence it after §50's placement bullet.** The doc split says
    "where evidence lives is enumeration's" while the code keeps
    `binding_evidence_tag` in `canary_agreement_common.ml`. Moving the
    text first leaves a paragraph saying "lives in agreement/ for
    layering reasons, conceptually enumeration's" — honest, and the kind
    of note that never gets cleaned up.

50. **Review the evidence workflow itself — the runner writes an
    inspection, an external reader checks it** (2026-09-15, user: *"the
    previous approach is to let the runner generate the inspection JSON
    into the summary, while the external reader read it as checker …
    maybe it's a good time to review it and think about the better
    workflow"*).

    The split is load-bearing and mostly right — a comparator over a
    recorded fact is re-runnable, diffable and testable, which a shell
    assertion inside a command is not (that distinction is the whole
    reason `assert_staged` and the source-ref check are PROPOSALS rather
    than lifts). What is worth reviewing is everything around it:

    - **Placement — and this is now the whole of §50's first half.**
      The largest single class of `unavailable` is not a missing
      inspection but one written at a tag the derivation does not name.
      The producer chooses a step, the consumer derives one, and
      nothing makes them agree. **Four instances, each fixed
      individually and none of them fixing the class:**

      | instance | the mismatch | fixed |
      | --- | --- | --- |
      | tiny's filenames | framework wrote `inspect.json`+`inspect_stub.json`, tiny the reverse | list both conventions, select by declared `kind` |
      | sqlite's binding | inspected at `probe_binding`, derivation names the INSTALL step | relocated |
      | `lib_evidence_tags` | named only `probe_lib` — the build-tree probe's tag | made world-aware |
      | the opam-binding template's `anp` | inspected at `probe_binding`, derivation names the PROVISIONING step | relocated (2026-09-15) |

      **A DIRECTION, from the user (2026-09-16), that dissolves the
      question rather than answering it.** Bundle the producer (the
      inspection) and the consumer (reading and comparing) into ONE
      action, *because that is what checking is*. Then there is no
      address to negotiate: the check produces what it needs. Multiple
      consumers of the same evidence stay agnostic of each other
      because the ACTION RESULT is cached — the second consumer's
      inspection is a cache hit, not a coordination problem.

      What makes this more than a preference is that the codebase is
      already drifting toward it, twice, both times to fix exactly this
      class: `Native_lib_probe` emits its native summary INSIDE the
      probe's own command (2026-09-13) rather than as a child step, and
      `probe_ocaml_env_cmd` emits the consumer's ABI summary inline
      after `RC=$?` (2026-09-15) — the second with a comment saying why
      a child step would be too late to be read by the step that needs
      it.

      What it costs, and this is the part to design rather than assume:
      the cache would have to key on **artifact identity**, not step
      identity. Today the run cache keys on `variant_id` + the step
      fingerprint, and its documented blind spot is precisely
      input-artifact identity
      ([`design/enumeration/stage6_realize_steps.md`](design/enumeration/stage6_realize_steps.md)
      §4). Bundling without fixing that trades a placement bug for a
      staleness bug. `canary inspect-diff --old A --new B` also wants
      evidence to stay a durable file at a nameable path, which a
      content-addressed cache satisfies and an in-memory one does not.

      The alternative shape — a typed evidence ADDRESS produced and
      consumed from one place — keeps the producer/consumer split and
      makes the two sides share one spelling. It also settles where the
      address BELONGS: `binding_evidence_tag` / `lib_evidence_tags` map
      a world to a step tag, which is world-arranging by nature, and
      they live in `canary_agreement_common.ml`. That is the ownership
      line backlog §49's doc split turns on — see there. NOTE the
      bundling direction makes §49 EASIER, not harder: if a check
      produces its own evidence there is no world→tag map to own, and
      the seam stops running through a shared module.
    - ~~**`unavailable` is one word for four situations**~~ — **done
      2026-09-15** (`83f43ecb`). `unavailable_cause = Missing_evidence |
      Missing_declaration | Nothing_to_check`, carried in distinct
      outcome LABELS (`unavailable` / `undeclared` / `vacuous`) so every
      reader gets the split at once. Note the count came down from four
      to three: "no inspector anywhere" and "an inspector exists and
      this project does not run it" are both `Missing_evidence` and the
      evaluator cannot tell them apart — it knows only which paths it
      looked for. Distinguishing THOSE two is the placement bullet
      above, not an outcome question.
    - **Who writes it.** An inspection is attached by `derive_steps`
      from the project's declarations. `Native_lib_probe` emitting a
      summary (2026-09-13) removed a whole class of per-project work,
      and `binding_stub_archive` (2026-09-15) did the same for a BUILT
      binding's compiled stub — the project declares the one thing it
      alone knows (the directory), the framework does the rest.

      **Still open, and it is ONE PROJECT, not a class** (corrected
      2026-09-16, user asked whether it was sqlite-only — it is).
      sqlite's Python side is 40 of its `no-evid` cells. The reason is
      specific: sqlite is the registry's ONLY project declaring a
      **Cext** Python binding (`binding-python-cext`), and its Cext
      happens to be CPython's stdlib `sqlite3` — held by a dummy
      action, with no step that compiles or inspects an extension
      module. z3 and llvm declare `binding-python-ctypes`, whose
      mechanism compiles no stub at all, so the stub-reading agreements
      report `not_applicable` there and are CORRECT to. zarith and
      cairo have no Python binding.

      So this is not "the interpreter's extension modules" in general.
      It is one project whose declaration meets an unmodelled part of
      the world: `_sqlite3` is built INTO the interpreter on the venv
      Python and is a `.so` on `/usr/bin/python3`, and canary models no
      interpreter. That makes it a SPEC question first (what is the
      Python binding's artifact, when the interpreter provides it?) and
      an inspector question second — which is why it is not simply the
      next `Native_lib_probe`-shaped win.
