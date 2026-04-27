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

16. **Mismatch prediction system** *(Opus)* — derive expected failures from
    version metadata. "z3 4.15 binding against z3 4.13 lib → missing symbols
    X, Y, Z" computable from API diffs. TODO #20 is the nm-based foundation.

17. **Module interfaces (.mli)** — define contracts for PM modules
    (`canary_pm_{apt,brew,opam,pip}`) and project modules (`canary_project_*.ml`).

18. **ocamlmklib stub archive convention** — factor `lib<name>.a` naming
    into OCaml toolchain layer so each binding declares its stub archive path.

22. **Bundle check_post with action slots** — refactor `script_spec` action
    slots from `cmd option` to `{ cmd; check } option`.

27. **Opam template taxonomy** — `llvm.dev-shared` is an "install pre-built"
    package (copies artifacts from `CANARY_BUILD_DIR`); `z3.dev` is a
    "build from source" package (runs cmake+ninja inside opam build phase).
    Distinguish by a header comment convention or directory structure so the
    intent is explicit and future templates know which pattern to follow.

29. **Package locator as first-class type** — locator logic (llvm-config,
    pkg-config, brew --prefix) is currently embedded in project shell
    commands. Factor into a `package_locator` type with `discovery_method`
    variants so the System PM → Locator → Conf chain is testable and uniform.
    See `design/index.md` "Open Design" for the proposed type.

30. **Store config type** — `fetch_*` and `pack_*` slot scripts are
    hardcoded in `mk_script_spec`. A `store_config = store_entry list`
    type would let `derive_steps` generate these slots from declarations
    rather than from filled-in `script_spec` fields.

31. **C API surface model** — `Expect_symbols { required; missing }` is
    currently hand-written per probe step. A declarative `api_surface`
    type (symbols + version, derived from `nm -D` or clang AST dump) would
    make expected mismatches derivable from version metadata. Depends on
    #20 (`assert_binary_symbols.py --provided-lib-old/new`).

32. **Auto-generated project configs** — given a project sketch (library
    name, binding languages, PM presence, source layout), generate the full
    `script_spec`. Depends on #29 (locator), #30 (store config), #31
    (C API surface).

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

28. **Lift shared `pack_binding` preamble into `canary_ocaml.ml`** — both
    z3 and llvm's `pack_binding` repeat the same opam setup sequence:
    `eval $(opam env) && opam config subst <opam_rel> && opam repo add/set-url
    && opam update && opam remove -y <pkg> || true && ... opam install`.
    Extract into `Canary_ocaml.opam_pack_cmd ~repo_name ~repo_abs ~opam_rel
    ~pkg_full ~env_bindings` returning the full command string. Each project
    only provides the project-specific env vars.
