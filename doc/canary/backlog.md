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

28. **Lift shared `pack_binding` preamble into `canary_ocaml.ml`** — both
    z3 and llvm's `pack_binding` repeat the same opam setup sequence:
    `eval $(opam env) && opam config subst <opam_rel> && opam repo add/set-url
    && opam update && opam remove -y <pkg> || true && ... opam install`.
    Extract into `Canary_ocaml.opam_pack_cmd ~repo_name ~repo_abs ~opam_rel
    ~pkg_full ~env_bindings` returning the full command string. Each project
    only provides the project-specific env vars.
