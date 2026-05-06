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
    template. See `doc/z3_bug_api.md`.

16, 20, 31, 35, 41, 42. **API compatibility model** — binding_api.deps
    split, C API surface (consumer/provider cross-check + provider-vs-
    provider delta), mismatch prediction, Python summary enhancements.
    The shipped portion (Steps C1, D-basic for OCaml + Python) is
    documented in `doc/canary/design/api_surface.md` §13. Open items
    (#35, #20, #41, #42) remain.

43. **L1b — versioned symbol requirements in compat check** — `inspect_native.py`
    already records `versioned_req` (e.g. `{"GLIBC_2.31": 3}`) per artifact.
    Today's `check_c_compat` is L0 only (set inclusion of names). Lift it to
    L1b: a binding requires a specific @VER suffix on a symbol, the lib must
    provide that or higher. Adds glibc/libstdc++ floor checking — predicts
    failures from binaries built on newer distros that won't run on older
    ones, even when symbol names match. See `doc/canary/design/api_surface.md`
    §13.6.

44. **L2 — typed signatures via clang AST or libclang** — today's compat
    check is name-level (L0/L3 set inclusion). Lift to L2 by extracting
    typed signatures from C headers (clang AST dump, similar to the dead-code
    example at `canary_dead_code` line 47) and OCaml/Python signatures from
    compiler output. Then `check_compat` is real subtyping with contravariance
    on argument types, covariance on results, refinement on value domains.
    Gives a decidable-but-conservative type-system over artifact interfaces;
    catches "same name, different signature" version drift. See api_surface.md
    §13.1 "typing-rule shape" and §15 "open theoretical questions".

17. **Module surfaces (.mli)** — define contracts for PM modules
    (`canary_pm_{apt,brew,opam,pip}`) and project modules (`canary_project_*.ml`).


27. **Opam template taxonomy** — `llvm.dev-shared` is an "install pre-built"
    package (copies artifacts from `CANARY_BUILD_DIR`); `z3.dev` is a
    "build from source" package (runs cmake+ninja inside opam build phase).
    Distinguish by a header comment convention or directory structure so the
    intent is explicit and future templates know which pattern to follow.

29–30, 32. **New project spec auto-generation** — package locator, store
    config type, and auto-generated `script_spec` from a project sketch.
    Grouped into `doc/canary/design/new_project.md` §3.


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
    macOS CI, `mk_script_spec` needs a `~target_pm` parameter (alongside
    `~tola_root`) so CI jobs can specify the target PM independently of the
    local host. Follow-on: add OS-conditional step support to
    `canary_backend_gh.ml` (render `if: runner.os == 'Linux'` guards) and a
    matrix strategy (ubuntu-latest × macos-latest, OCaml version axis).

36. **Diagram fidelity: `scan_source` and `_inspect` steps have no nodes** —
    `scan_source` runs as a post-fetch check (verifying header/binding-dir
    claims) but shares the `fetch_source` output dir and is invisible in
    `result.mmd`. Similarly, `*_inspect` introspection steps are emitted by
    `derive_steps` as follow-ups after each probe but are not rendered in the
    diagram. Both gaps make the diagram an incomplete view of what canary
    actually runs. When the diagram is redesigned, add dedicated action nodes
    for `scan_source` and per-probe `*_inspect` steps. May require extending
    `store_rules` with new rule variants or a separate "annotation step" layer.

37. **HTML diagram viewer with node-group visibility toggles and log drill-down** —
    The static `.mmd` output works for quick review but becomes hard to read
    as more node groups are added (stores, summary steps, scan_source, etc.).
    Replace or augment with a self-contained HTML page that:
    (a) Renders the Mermaid diagram inline (via mermaid.js CDN or bundled);
    (b) Provides checkboxes / toggle buttons to show/hide node groups:
        stores, summary steps, `scan_source`, disabled/`st_nospec` actions;
    (c) Makes each action node clickable to open (or inline) the corresponding
        log file (`probe.log`, `inspect.json`, `actions.log`) from the run
        output directory — enables reading results without leaving the viewer.
    The HTML file would live alongside `result.mmd` in each run's output dir.
    Consider whether a single template (`canary_backend_html.ml`) can serve
    all projects by embedding the per-run step list and output-dir paths as a
    JSON blob. Pairs with TODO #36 (scan_source / summary node fidelity) since
    toggling visibility makes those extra nodes practical to add.

38. **`pack_python` action — local pip wheel packaging** — `pack_binding` is
    currently OCaml-only (opam packaging). A Python equivalent would build a
    pip wheel from the locally-compiled Python extension and install it into a
    local pip index or venv, enabling a `probe_python_pip` variant that tests
    the packaged wheel rather than the raw build artifact. Prerequisite:
    `probe_python` build-tree variant (test the raw `.so` before packaging)
    as the base to compare against. See `api_surface.md §5` for the co-provider
    design — pip wheels often bundle their own native lib, so `pack_python` for
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

    **Diagram**: the current `lib -.->|runtime|` edge from `lib_build_tree_node`
    into `A_fetch_binding_python` and `A_probe_binding_python` is misleading —
    z3-solver does not consume the externally built lib at runtime; it carries
    its own. The correct diagram would show the python binding node as
    self-contained (no runtime edge from the lib kind).

    **Action enumeration**: `derive_steps` models Python bindings as always
    depending on the native lib for runtime. A co-provider package violates
    this assumption. The spec needs a way to declare that a pip package is
    self-contained (co-provider), suppressing the lib runtime edge and
    potentially adding a separate inspect step to surface the bundled lib's
    symbol set for compat checking.

    See `doc/canary/design/api_surface.md §5` (co-provider design) and
    backlog #38 (`pack_python` wheel packaging, which has the same
    co-provider shape on the producer side).
