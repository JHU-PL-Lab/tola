(** Project: tiny — the in-tree foundational witness for surface theory.

    {b Phase 4 milestone (2026-05-28; expanded 2026-05-29).} This module
    drives the production canary pipeline over tiny's minimal C library +
    OCaml binding + Python cext binding. It is the integration check that
    closes the loop between [doc/canary/research/surface_theory.md],
    [tiny.md], and the canary code.

    {b Relationship to the standalone tiny harness.} Tiny's
    [scenarios/scenarios.py] + [_harness/run_cached.py] is the {i golden
    truth} for what breakage can be induced and detected on this minimal
    target — the perturbation matrix runs 12 scenarios against handwritten
    comparators. canary_project_tiny.ml's job is to declare the same
    surfaces + watchlists in canary's vocabulary so that canary's standard
    inspectors + comparators would detect the same violations when
    presented with the same {i ill artifacts} (the perturbations are
    treated as "versioned variants the canary may encounter from stores").

    Unlike z3/llvm/sqlite (which fetch from package managers or upstream
    source repos), tiny lives in the repository at [canary/examples/tiny/]
    and builds entirely from in-tree source:

    - {i n4 lib_native.so} produced by [cmake -S c -B c/build]
    - {i bo3..bo7 compiled_binding_ocaml.*} produced by [dune build]
      with [LIBRARY_PATH] pointed at the cmake output dir
    - {i bpe3 compiled_binding_cext.so} produced by [uv build] (via the
      tiny Makefile's [python_cext] target)
    - {i bo4 / bpe2} user-facing surfaces extracted by the standard
      inspector scripts ([inspect_binding.py --kind mli], [inspect_python.py])

    Python ctypes ({i bpc2}) is intentionally not driven from canary today
    — it's pure-Python (no compiled binding artifact = no {i s5} for the
    ctypes column, by §2.3 of surface theory) and the canary pipeline
    needs a build_binding artifact for the [Binding Python] arm. The
    standalone harness covers it; canary models the static cext case.

    Aligned vocabulary: this spec uses canonical names in commentary
    ({i lib_native}, {i compiled_binding_ocaml.cmxa}, etc.) and ties
    each command to the artifact it produces / consumes via the same
    aliases the tiny harness uses. *)

open Base
open Canary_basic
open Canary

(** Tiny lives in-tree. All shell commands here run from the tola
    repository root (canary's runner inherits the invoker's cwd, which
    for [dune exec] is the project root). Relative paths anchor to
    [canary/examples/tiny/] explicitly. *)
let tiny_root = "canary/examples/tiny"

(** Absolute path to tiny's cmake build directory (where {i n4
    lib_native.so} ends up). Used for [LIBRARY_PATH] / [LD_LIBRARY_PATH]
    so the OCaml binding's cstubs link against the right libtiny. *)
let tiny_lib_dir = Printf.sprintf "$PWD/%s/c/build" tiny_root

(** The three C symbols the tiny native lib exports — what every binding
    requires. Drift here is what {i e1 symbol_missing} induces; canary
    catches it via the [stable_symbols] watchlist in [api_source]. *)
let tiny_native_stable_symbols = [ "tiny_sum"; "tiny_diff"; "tiny_offset" ]

(** Module + val watchlist on {i bo4 user_binding_ocaml.mli}. The dotted
    paths resolve against the [Tiny] module's vals at inspect time.
    Dropping one of these from [Tiny.mli] (= {i e6 api_complete}) makes
    {i c2 cmp_api_completeness} predict the failure. *)
let tiny_ocaml_module_watchlist =
  [ "Tiny"; "Tiny.sum"; "Tiny.diff"; "Tiny.offset" ]

(** Attribute watchlist on {i bpe2 user_binding_cext.py} (and equivalently
    on {i bpc2 user_binding_ctypes.py} when the standalone harness checks
    it). Dropping one of these from [tiny_cext/__init__.py] (= {i e11
    api_complete_python}) makes {i c2 cmp_api_completeness} on the Python
    side predict the failure. *)
let tiny_python_module_watchlist = [ "sum"; "diff"; "offset" ]

(** Canary's [api_source] is the typed declaration of what tiny's surfaces
    are. [derive_steps] uses this to auto-generate inspect-and-watchlist
    steps after each Build/Probe, which is how canary detects drift the
    same way the standalone harness does.

    - [native_api.headers] declares {i n3 header_native.h}.
    - [native_api.components = [Headers; Runtime_lib; Link_lib]] declares
      that tiny exposes a header file, a runtime [.so] ({i n4}), and a
      link-time symlink (also {i n4} via [libtiny.so → libtiny.so.1]).
    - [stable_symbols] drives a symbol-level watchlist that {i c1
      cmp_symbol} would check against {i n4}'s exported set (catches {i e1
      symbol_missing}).
    - The OCaml binding_api carries the module watchlist (catches
      {i e6 api_complete}).
    - The Python binding_api carries the attr watchlist (catches
      {i e11 api_complete_python}). *)
let tiny_api_source : Canary_artifact_api.t =
  let native_api : Canary_artifact_api.native_api =
    {
      kind = C;
      components = [ Headers; Runtime_lib; Link_lib ];
      headers =
        Some
          {
            dir = "c/include";
            files = [ "tiny.h" ];
          };
      symbol_prefixes = [ "tiny_" ];
      stable_symbols = tiny_native_stable_symbols;
      versioned_symbols = [];
      soname    = Some "libtiny.so.1";   (** {i c4 cmp_abi} reference (placeholder until c4 wires up) *)
      c_runtime = None;
      cxx_abi   = None;
    }
  in
  let ocaml_binding : Canary_artifact_api.binding_api =
    {
      lang = OCaml;
      source_dir = Some "ocaml";
      module_watchlist = tiny_ocaml_module_watchlist;
      type_watchlist = [];
    }
  in
  let python_binding : Canary_artifact_api.binding_api =
    {
      lang = Python;
      source_dir = Some "python_cext/tiny_cext";
      module_watchlist = tiny_python_module_watchlist;
      type_watchlist = [];
    }
  in
  { native_api; binding_apis = [ ocaml_binding; python_binding ] }

(** {1 Variants}

    Tiny is multi-variant. Each variant is a named [script_spec] value
    whose expectation field encodes which surface-theory contracts canary
    expects to fire at which stages — {i not} which scenario produced the
    artifacts. The harness↔canary mapping lives in
    [doc/canary/research/tiny.md] (or a wrapper script), not here.

    - [base_script_spec]: positive coverage. Every step is expected to
      succeed (Expect_success). Corresponds to the unperturbed tiny
      build / harness scenarios [e12 baseline_canary] / [e13
      baseline_unbroken].
    - [lib_broken_script_spec]: at probe_binding_ocaml, expect c1
      cmp_symbol to fire. Used when the lib at runtime lacks a symbol
      the OCaml binding stub requires. Maps to harness scenario
      [e1 symbol_missing] but doesn't know it.

    More variants land as we expand coverage (next candidates:
    [binding_mli_broken] for c2, [binding_python_attrs_broken] for c2
    Python, [binding_overdeclares_stubs] for c1 from the orphan
    direction).

    Convenience: [script_spec] aliases [base_script_spec] for callers
    that don't need to distinguish variants.
*)

(** [make_base_script_spec ~workspace_root] produces tiny's spec
    operating against a self-contained dune workspace at
    [workspace_root]. All source/build paths thread [workspace_root]
    rather than the live [canary/examples/tiny/] tree. Dune commands
    pass [--root workspace_root] so the workspace is the dune root
    (since the materialized cache lives outside the tola workspace
    boundary; see [scenarios.py:_snapshot_workspace]).

    Variants pick their own [workspace_root]:
    - baseline → [_cache/baseline/workspace/] (or live tree as a
      fallback for development)
    - lib_broken → [_cache/symbol_missing/workspace/]
    - binding_mli_broken → [_cache/api_complete/workspace/]
    The harness↔canary mapping lives in [canary_main.ml]'s variant
    table, not here. The spec is uniform across variants. *)
let make_base_script_spec ~workspace_root : Canary_step_builder.script_spec =
  let lib_dir = [%string "$PWD/%{workspace_root}/c/build"] in
  let ocaml_build_dir =
    [%string "%{workspace_root}/_build/default/ocaml"] in
  {
    Canary_step_builder.empty_script_spec with

    (* No fetch_source: workspace is pre-materialized. *)
    api_source = Some tiny_api_source;

    (* Configure / Build_lib: the workspace store provides libtiny.so.*
       pre-built (the harness ran cmake at prepare-all time). Canary
       verifies the cached artifact rather than re-running cmake — the
       workspace deliberately omits CMakeCache.txt because it encodes
       the live tree's absolute source path. This matches the long-term
       "store provides artifacts" model: a perturbed-lib variant just
       points at a different store. *)
    configure = Some (fun ~output_dir ~variant_key ->
      Printf.sprintf
        "test -d %s/c/build || { echo 'workspace c/build missing'; exit 1; }"
        workspace_root
      |> Canary_build_cmd.with_marker
           ~marker:"conf.ok" ~output_dir ~variant_key);

    build_lib = Some (fun ~output_dir ~variant_key ->
      Printf.sprintf
        "test -f %s/c/build/libtiny.so.1 || { echo 'libtiny.so.1 missing'; exit 1; }"
        workspace_root
      |> Canary_build_cmd.with_marker
           ~marker:"build.ok" ~output_dir ~variant_key);

    (* Build_binding OCaml: build the binding {b library} only —
       tiny.cmxa (bo6) and libtiny_stubs.a (bo7). dune --root pins the
       workspace; targets are relative to that root. Consumer compile
       (examples/probe_baseline.exe) is deferred to Probe so that mli
       mismatches surface there rather than here. *)
    build_binding = [
      (Canary_lang.OCaml,
       fun ~output_dir ~variant_key ->
         Canary_build_cmd.dune_build_cmd
           ~env_extra:[
             [%string "LIBRARY_PATH=%{lib_dir}"];
             [%string "LD_RUN_PATH=%{lib_dir}"];
           ]
           ~root:workspace_root
           ~target:"ocaml/tiny.cmxa ocaml/libtiny_stubs.a" ()
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
      (* Build_binding Python: tiny's Makefile python_cext target ran
         at workspace prep time; here we just verify the artifact is in
         place. The workspace materialization captured
         tiny_cext/_native.cpython-*.so. *)
      (Canary_lang.Python,
       fun ~output_dir ~variant_key ->
         Printf.sprintf
           "ls %s/python_cext/tiny_cext/_native.cpython-*.so > /dev/null"
           workspace_root
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
    ];

    (* Probe_lib: nm against the workspace's libtiny.so.1. *)
    probe_lib = [
      (Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "nm -D %s/c/build/libtiny.so.1 | grep -E '^[0-9a-f]+ T tiny_' \
            > %s/%s 2>&1"
           workspace_root output_dir probe_log);
    ];

    (* Probe_binding OCaml: dune build + exec probe_baseline.exe inside
       the workspace. mli mismatches surface here as consumer-compile
       failures; runtime symbol failures show up when exec runs. Both
       redirect to probe.log. *)
    probe_binding = [
      (Canary_lang.OCaml,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         let example_exe = "ocaml/examples/probe_baseline.exe" in
         Printf.sprintf
           "(LIBRARY_PATH=%s LD_RUN_PATH=%s dune build --root %s %s \
            && LD_LIBRARY_PATH=%s %s/_build/default/%s) > %s/%s 2>&1"
           lib_dir lib_dir workspace_root example_exe
           lib_dir workspace_root example_exe output_dir probe_log);
      (* Probe_binding Python (cext): import + invoke wrappers from the
         workspace's python_cext/. *)
      (Canary_lang.Python,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "LD_LIBRARY_PATH=%s PYTHONPATH=%s/python_cext python3 \
            %s/python_cext/examples/probe_baseline.py > %s/%s 2>&1"
           lib_dir workspace_root workspace_root output_dir probe_log);
    ];

    (* binding_user_facing_pkg drives auto-generation of inspect steps
       after each Probe (Binding lang) — OCaml gets an [mli]
       inspect on the bo4 user_binding_ocaml.mli; Python gets a [dir(pkg)]
       inspect on bpe2 user_binding_cext.py. The pkg names match the
       package containing the user-facing surface. *)
    binding_user_facing_pkg = [
      (Canary_lang.OCaml, "tiny");
      (Canary_lang.Python, "tiny_cext");
    ];

    (* Inspect overrides — produce per-artifact JSON for each binding-side
       artifact. These are what the standard tiny harness comparators
       consume, restated in canary's vocabulary so [canary action tiny]
       writes the same JSONs as [make scenarios-cached] does:

       - Build_binding OCaml   → bo7 compiled_binding_ocaml.stub-a
         (libtiny_stubs.a). Feeds c1 cmp_symbol.
       - Build_binding Python  → bpe3 compiled_binding_cext.so
         (_native.cpython-*.so). Feeds c1 cmp_symbol (cext flavor).
       - Probe (Binding OCaml) → bo4 user_binding_ocaml.mli (tiny.mli)
         with module + val watchlist. Feeds c2 cmp_api_completeness.
       - Probe (Binding Python)→ bpe2 user_binding_cext.py (dir(tiny_cext))
         with attr watchlist. Feeds c2 cmp_api_completeness (Python). *)
    inspect = (fun rule _loc ->
      let lib_inspect_cmd ~output_dir ~variant_key =
        Canary_artifact_native.inspect_cmd
          ~lib:(Printf.sprintf "%s/c/build/libtiny.so.1" workspace_root)
          ~prefixes:[ "tiny_" ]
          ~watchlist:tiny_native_stable_symbols
          ~output_dir ~variant_key () in
      match rule with
      | Build_lib ->
          (* Inspect the lib as soon as we've verified it exists in the
             workspace. Critical for c1 cmp_symbol ordering: the runner's
             topological sort can put probe_lib after probe_binding, but
             c1's expectation at probe_binding needs the lib JSON
             already-present. Attaching the inspect to build_lib makes
             the JSON available before any Probe step evaluates. *)
          Some lib_inspect_cmd
      | Probe Lib ->
          (* Same nm-derived JSON, now redundant with build_lib's
             inspect. Kept for callers that read probe_lib/inspect.json
             (e.g. lib_broken originally; switch them to build_lib over
             time). *)
          Some lib_inspect_cmd
      | Build_binding Canary_lang.OCaml ->
          Some (fun ~output_dir ~variant_key ->
            (* Two-file inspect: stub (c1) + mli (c2). Both JSONs live
               in build_binding_ocaml/ so Probe's expectation can cite
               them before it runs. *)
            let stub_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let mli_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect_mli" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_ocaml_module_watchlist in
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind stub \
               --path %s/libtiny_stubs.a --prefix tiny_ > %s/%s && \
               python3 canary/scripts/inspect_binding.py --kind mli \
               --module-prefix Tiny \
               --path %s/ocaml/tiny.mli --watchlist '%s' > %s/%s"
              ocaml_build_dir output_dir stub_file
              workspace_root watchlist_csv output_dir mli_file)
      | Build_binding Canary_lang.Python ->
          Some (fun ~output_dir ~variant_key ->
            let cext_so =
              Printf.sprintf
                "%s/python_cext/tiny_cext/_native.cpython-*.so"
                workspace_root in
            Canary_artifact_native.inspect_cmd
              ~lib:cext_so ~prefixes:[ "tiny_" ]
              ~watchlist:tiny_native_stable_symbols
              ~output_dir ~variant_key ())
      | Probe (Binding Canary_lang.OCaml) ->
          Some (fun ~output_dir ~variant_key ->
            let out_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_ocaml_module_watchlist in
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind mli \
               --module-prefix Tiny \
               --path %s/ocaml/tiny.mli --watchlist '%s' > %s/%s"
              workspace_root watchlist_csv output_dir out_file)
      | Probe (Binding Canary_lang.Python) ->
          Some (fun ~output_dir ~variant_key ->
            let out_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_python_module_watchlist in
            Printf.sprintf
              "LD_LIBRARY_PATH=%s PYTHONPATH=%s/python_cext \
               python3 canary/scripts/inspect_python.py --pkg tiny_cext \
               --watchlist '%s' > %s/%s"
              lib_dir workspace_root watchlist_csv output_dir out_file)
      | _ -> None);

    (* Diagram labels: bind the canary kinds to the canonical names tiny uses. *)
    artifact_name = (function
      | Headers -> Some "header_native.h (tiny.h)"
      | Lib -> Some "lib_native.so (libtiny.so.1)"
      | Binding Canary_lang.OCaml ->
          Some "compiled_binding_ocaml (tiny.cmxa + libtiny_stubs.a)"
      | Binding Canary_lang.Python ->
          Some "compiled_binding_cext (_native.cpython-*.so)"
      | App -> Some "probe_baseline.exe / .py"
      | _ -> None);

    expectation = (fun _rule _loc -> Expect_success);
  }

(** [lib_broken_script_spec]: at [Probe (Binding OCaml)], expect c1
    [cmp_symbol] to fire. Same body as [base_script_spec] with one
    expectation override.

    The Expect_compat_failure inputs point at the cached inspector
    JSONs that the runner's [predicted_contains_any_v2] consumes:
    - [C_stub …]: the OCaml stub's required-symbol list (from
      [inspect_binding.py --kind stub] on libtiny_stubs.a).
    - [Native_lib …]: the lib's defined-symbol list (from
      [inspect_native.py --emit-symbols] on libtiny.so.1).

    Together they drive c1's set-inclusion check
    ([Canary_compat.check_c_compat]). If the lib lacks a symbol the
    stub requires (e.g. harness scenario [e1 symbol_missing] removes
    [tiny_offset]), the missing-symbols list becomes the predicted
    failure substring set, and the probe's failure must mention at
    least one of those substrings for the expectation to confirm. *)
let make_lib_broken_script_spec ~workspace_root
    : Canary_step_builder.script_spec =
  { (make_base_script_spec ~workspace_root) with
    expectation = (fun rule _loc ->
      match rule with
      | Probe (Binding Canary_lang.OCaml) ->
          Expect_compat_failure {
            inputs = Canary_compat.[
              C_stub     [ "build_binding_ocaml/inspect.json" ];
              (* Cite build_lib (runs earlier in dep order) rather than
                 probe_lib — c1's expectation evaluates at probe_binding
                 and probe_lib may not have run yet in multi-variant
                 scheduling. *)
              Native_lib [ "build_lib/inspect.json" ];
            ];
            version_info = None;
          }
      | Probe (Binding Canary_lang.Python) ->
          (* The cext .so was compiled from baseline source and calls
             tiny_sum at runtime. With the perturbed lib (tiny_sum →
             tiny_total) the cext fails to resolve the symbol on import.
             Hand-written substring for now; switching to a
             cext-equivalent c_stub inspect is a follow-up. *)
          Expect_failure {
            contains_any = [ "tiny_sum" ];
            version_info = None;
          }
      | _ -> Expect_success);
  }

(** [binding_mli_broken_script_spec]: at [Probe (Binding OCaml)], expect
    c2 [cmp_api_completeness] to fire.

    With the Build / Probe split (Build builds tiny.cmxa only; Probe
    builds + runs probe_baseline.exe), an OCaml mli mismatch shows up
    here: the library compiles fine against a sparser mli, but the
    consumer (probe_baseline) compile fails because it references a
    symbol the mli no longer exposes. Both the dune build and the
    runtime exec write to probe.log, so [output_contains_any] can grep
    the compile error.

    The Expect_compat_failure input cites the mli JSON produced by
    Build (Binding OCaml)'s two-file inspect step
    (`build_binding_ocaml/inspect_mli.json`). [predicted_contains_any_v2]
    feeds it to [load_watchlist_missing] which returns the watchlist
    members the mli no longer exposes; those names become the predicted
    failure substrings.

    Maps to harness scenario [e6 api_complete] (patches tiny.mli to
    remove `val sum`). When canary runs Probe under that perturbation,
    the dune build of probe_baseline.exe fails with "Unbound value
    Tiny.sum"; the predicted "Tiny.sum" matches. *)
let make_binding_mli_broken_script_spec ~workspace_root
    : Canary_step_builder.script_spec =
  { (make_base_script_spec ~workspace_root) with
    expectation = (fun rule _loc ->
      match rule with
      | Probe (Binding Canary_lang.OCaml) ->
          Expect_compat_failure {
            inputs = Canary_compat.[
              Ocaml_mli [ "build_binding_ocaml/inspect_mli.json" ];
            ];
            version_info = None;
          }
      | _ -> Expect_success);
  }

(** Default workspace path for tiny's harness-materialized caches.
    Variants append a scenario name to this. *)
let cache_workspace_of ~scenario =
  [%string "%{tiny_root}/scenarios/_cache/%{scenario}/workspace"]

(** Convenience aliases at the live-tree path for callers that don't
    distinguish variants. The live tree {b is} a valid dune workspace
    (the tola workspace root supplies dune-project), so passing
    [tiny_root] works for ad-hoc invocations even though the canonical
    flow points each variant at its own materialized cache. *)
let base_script_spec = make_base_script_spec ~workspace_root:tiny_root
let script_spec = base_script_spec
