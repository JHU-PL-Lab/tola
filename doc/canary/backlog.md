# Canary Backlog

Lower-priority TODOs moved out of CLAUDE.md to keep it concise.
Numbers are stable (never renumbered). See CLAUDE.md for active TODOs.

5. **CI mode for opam depexts** — use `--confirm-level=unsafe-yes` to let
   opam auto-install system deps in Docker/CI. Currently local dev uses
   `--assume-depexts` (requires pre-installing system deps manually).

9. **Binding build dependencies** — z3's OCaml binding requires `zarith`
   at build time. Model per-binding opam deps so `build_binding` can
   ensure they're installed. Add `binding_deps` to `ocaml_tool_config`.

10. **Unified build cache schema** — canary's `_out/canary/_local/` and
    opam's `~/.opam/.../build/` need a shared cache key scheme
    (project × version × ref) for version combination testing.

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
