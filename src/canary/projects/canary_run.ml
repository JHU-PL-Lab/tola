open Base
open Canary_basic
open Canary

(* ── GH CI backend ── *)

(* Restore/save the sccache local disk dir across runs.
   sccache-action sets SCCACHE_GHA_ENABLED but opam's bwrap sandbox drops the
   GH Actions env vars, so sccache always falls back to local disk.
   actions/cache bridges that: the local ~/.cache/sccache is persisted by GH. *)
let sccache_cache_step =
  {|      - name: Restore sccache disk cache
        uses: actions/cache@v4
        with:
          path: ~/.cache/sccache
          key: sccache-z3-${{ runner.os }}-${{ hashFiles('canary/templates/opam-local-repo/packages/z3/z3.dev/opam.in') }}
          restore-keys: |
            sccache-z3-${{ runner.os }}-|}

let sccache_step =
  {|      - name: Setup sccache
        uses: mozilla-actions/sccache-action@v0.0.9|}

(* CI step derivation: skip source builds for LLVM (expensive, CI-unfriendly).
   Z3 is a special case: its OCaml binding requires building from source. *)
let ci_jobs ~root distro : Canary_gh.job_spec list =
  let open Canary_gh in
  let gh_root = "$GITHUB_WORKSPACE" in
  (* Z3: opam fetches from GitHub remote and builds the OCaml binding entirely.
     has_build_lib=false + cmake_build_binding=false: no cmake steps in CI;
     pack_binding substitutes CANARY_Z3_SRC with the remote git URL so opam
     clones and builds from source internally.
     sccache caches C++ compilation; mold speeds up linking. *)
  let z3_ci_source =
    { Canary_project_z3.z3_source_dev with locals = []; has_build_lib = false }
  in
  let z3_ci_tag = Canary_artifact_source.version_cache_tag distro z3_ci_source in
  let z3_ci_project = [%string "z3/%{z3_ci_tag}"] in
  [
    (* LLVM 19: system lib + opam binding only, no source build *)
    { id = "llvm-19";
      name = "LLVM 19 — fetch + probe";
      project = "llvm/19";
      sys_deps = [];
      preamble_steps = [];
      steps =
        Canary_step_builder.(derive_steps ~root ~project:"llvm/19" ~cache_project:"llvm-19"
          (no_source (Canary_project_llvm.mk_runner_spec
             ~source:Canary_project_llvm.llvm_source_stable
             ~tola_root:gh_root distro))) };
    (* Z3: build from source (no prebuilt OCaml binding in opam).
       sccache caches C++ compilation across runs; mold replaces ld for faster links. *)
    { id = "z3-dev";
      name = "Z3 dev — build from source + probe";
      project = z3_ci_project;
      sys_deps = z3_ci_source.build_sys_deps @ [ "mold" ];
      preamble_steps = [ sccache_cache_step; sccache_step ];
      steps =
        Canary_step_builder.derive_steps ~root ~project:z3_ci_project ~cache_project:"z3-dev"
          (Canary_project_z3.mk_runner_spec ~source:z3_ci_source
             ~tola_root:gh_root ~cmake_build_binding:false distro) };
    (* SQLite: system lib + opam binding *)
    { id = "sqlite";
      name = "SQLite — fetch + probe";
      project = "sqlite";
      sys_deps = [];
      preamble_steps = [];
      steps =
        Canary_step_builder.(derive_steps ~root ~project:"sqlite" ~cache_project:"sqlite"
          (no_source Canary_project_sqlite.runner_spec)) };
    (* zarith: classic Pattern A — apt libgmp-dev + opam zarith binding *)
    { id = "zarith";
      name = "zarith — fetch + probe";
      project = "zarith";
      sys_deps = [];
      preamble_steps = [];
      steps =
        Canary_step_builder.(derive_steps ~root ~project:"zarith" ~cache_project:"zarith"
          (no_source Canary_project_zarith.runner_spec)) };
    (* ssl: Pattern A second datapoint — apt libssl-dev + opam ssl binding;
       libssl/libcrypto symbol watchlist surfaces OpenSSL 1.x→3.x drift. *)
    { id = "ssl";
      name = "ssl — fetch + probe";
      project = "ssl";
      sys_deps = [];
      preamble_steps = [];
      steps =
        Canary_step_builder.(derive_steps ~root ~project:"ssl" ~cache_project:"ssl"
          (no_source Canary_project_ssl.runner_spec)) };
  ]

let sqlite_job ~root : Canary_gh.job_spec =
  let open Canary_gh in
  { id = "sqlite";
    name = "SQLite — fetch + probe";
    project = "sqlite";
    sys_deps = [];
    preamble_steps = [];
    steps =
      Canary_step_builder.(derive_steps ~root ~project:"sqlite"
        (no_source Canary_project_sqlite.runner_spec)) }

let render_ci ~root distro =
  let jobs = ci_jobs ~root distro in
  Canary_gh.render_workflow ~workflow_name:"Canary CI" jobs

let render_debug_ci ~root _distro =
  Canary_gh.render_workflow
    ~triggers:"on:\n  workflow_dispatch:"
    ~workflow_name:"Canary Debug CI"
    [ sqlite_job ~root ]

(* ── Introspection ── *)

let dump_graph _distro =
  let graph_dir = "_out/canary/graph" in
  ignore (Stdlib.Sys.command [%string "mkdir -p %{graph_dir}"]);
  let path = [%string "%{graph_dir}/action_rule.mmd"] in
  Tola_std.write_file path (Canary_diagram.mermaid_of_action_rule_schema (store_rules ~langs:[ OCaml ]));
  Fmt.pr "Wrote %s@." path

let dump_job_paths_with ~pp =
  Fmt.pr "=== Action Pattern Table ===@.@.";
  Fmt.pr "Each row is a structural action pattern. The `versions` column shows@.";
  Fmt.pr "how many version combinations instantiate that pattern (with 2 versions).@.";
  Fmt.pr "Every artifact can be probed (probe = action_path → probe_<kind>, d+1).@.@.";
  let ar =
    make_action_rule ~rules:(store_rules ~langs:[ OCaml ]) ~versions:two_versions ~name:"pkg"
      ~source:Canary_store.store ()
  in
  let paths = job_paths_of_action_rule ar in
  pp Fmt.stdout paths;
  Fmt.pr "@.%d structural patterns, %d total artifacts@."
    (List.length (pattern_rows_of_paths paths))
    (List.length paths)

let dump_job_paths () = dump_job_paths_with ~pp:pp_job_path_table
let dump_job_paths_md () = dump_job_paths_with ~pp:pp_job_path_table_md
