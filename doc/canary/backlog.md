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
    anything. Prior art: the dead-code example at
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
    `canary_pattern_a.ml` is the prototype.

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
    A8. Project shapes + landing mechanics: `doc/canary/projects.md` §4.


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

40. **Replace fake `install_lib` with real `cmake --install`** — z3 and
    llvm's `install_lib` scripts currently copy build artifacts with `cp`
    (fake install). Replace with `cmake --install --prefix $PREFIX` to
    actually exercise cmake's install-time transformations: RPATH rewriting,
    versioned symlink creation, `pkg-config`/`FindPackage` config file
    generation. The `probe_lib Staged` step then tests the installed artifact
    rather than a hand-copied one, giving the install step real diagnostic
    value. See `doc/canary/ops/install_targets.md` for z3 vs LLVM cmake
    install patterns (z3 needs `ocamlfind install` separately; LLVM uses
    `LLVM_OCAML_INSTALL_PATH`). Prerequisite: a fixed `$PREFIX` convention
    per project run, likely `$build/../install`.

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


47. **`has_build_*` boolean-branching residue** — the entry's original
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
