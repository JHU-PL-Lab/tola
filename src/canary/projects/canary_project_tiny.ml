(** Project: tiny — the in-tree foundational witness for surface theory.

    {b Phase 4 milestone (2026-05-28; expanded 2026-05-29).} This module
    drives the production canary pipeline over tiny's minimal C library +
    OCaml binding + Python cext binding. It is the integration check that
    closes the loop between [doc/canary/research/surface_theory.md],
    [tiny.md], and the canary code.

    {b Relationship to the standalone tiny harness.} Tiny's
    [doc/_legacy_code/tiny_python_harness/scenarios.py] (archived Phase E) + [doc/_legacy_code/tiny_python_harness/_harness/run_cached.py] (archived Phase E) is the {i golden
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

(** Attribute watchlist on {i bpe2 user_binding_cext.py}. Dropping one
    of these from [tiny_cext/__init__.py] (= {i e11 api_complete_python})
    makes {i c2 cmp_api_completeness} on the Python side predict the
    failure. (Python ctypes — {i bpc2} — is intentionally not driven
    by canary; see header docstring.) *)
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
      soname    = Some "libtiny.so.1";   (** {i c4 cmp_abi} reference SONAME (live via [lib_soname_bumped] variant) *)
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

(** {1 Per-artifact-kind stores (Phase 14b', 2026-06-02)}

    The spec is parameterized by [stores] rather than a single
    workspace path. Each field is a directory serving one artifact
    kind:

    - [source]: tree root containing [c/], [ocaml/], [python_cext/].
      Provides source files for all builds (dune compiles binding from
      [source/ocaml/], cmake configures from [source/c/], Python probe
      reads [source/python_cext/examples/]). Also the dune workspace
      root ([dune build --root source] — outputs land at
      [source/_build/default/]).

    - [lib_dir]: directory containing [libtiny.so*]. The provider for
      the Lib artifact. Canary's [build_lib] verifies presence here
      rather than running cmake; [LIBRARY_PATH] and [LD_LIBRARY_PATH]
      point at this dir.

    - [python_cext_root]: directory under which the [tiny_cext/]
      package lives. The provider for the Python Binding artifact
      ([python_cext_root/tiny_cext/_native.cpython-*.so]). Used as
      [PYTHONPATH] when running Python probes.

    For today's three variants every store points into the same
    materialized workspace (via [stores_of_workspace]). Cross-product
    variants — e.g. baseline source + perturbed lib — would construct
    stores with paths from different workspaces. Cross-products are
    parked under Phase 14c in [plan.md]; this layout opens the door. *)
type tiny_stores = {
  source : string;
  lib_dir : string;
  lib_filename : string;  (* basename within lib_dir, e.g. "libtiny.so.1" *)
  python_cext_root : string;
}

(** Default stores derived from a single materialized workspace —
    the common case when a variant uses one harness scenario.
    [lib_filename] defaults to [libtiny.so.1]; SONAME-bump variants
    override it (e.g. abi_soname_bump's workspace has [libtiny.so.2]). *)
let stores_of_workspace ?(lib_filename = "libtiny.so.1") ~workspace_root () = {
  source = workspace_root;
  lib_dir = [%string "%{workspace_root}/c/build"];
  lib_filename;
  python_cext_root = [%string "%{workspace_root}/python_cext"];
}

let make_base_script_spec
    ?(probe_exe = "ocaml/examples/probe_baseline.exe")
    ~(stores : tiny_stores) () : Canary_step_builder.script_spec =
  let { source; lib_dir; lib_filename; python_cext_root } = stores in
  (* Absolute lib_dir for {LIBRARY,LD_LIBRARY,LD_RUN}_PATH — $PWD
     anchors to canary's invocation cwd (the tola root). *)
  let abs_lib_dir = [%string "$PWD/%{lib_dir}"] in
  let lib_path = [%string "%{lib_dir}/%{lib_filename}"] in
  let ocaml_build_dir =
    [%string "%{source}/_build/default/ocaml"] in
  let cext_so_glob =
    [%string "%{python_cext_root}/tiny_cext/_native.cpython-*.so"] in
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
        "test -d %s || { echo 'lib_dir missing: %s'; exit 1; }"
        lib_dir lib_dir
      |> Canary_build_cmd.with_marker
           ~marker:"conf.ok" ~output_dir ~variant_key);

    build_lib = Some (fun ~output_dir ~variant_key ->
      Printf.sprintf
        "test -f %s || { echo '%s missing'; exit 1; }"
        lib_path lib_path
      |> Canary_build_cmd.with_marker
           ~marker:"build.ok" ~output_dir ~variant_key);

    (* Scan_sources: emit typed-signature JSONs derived directly from
       source files (Phase 15.5a). Runs after Configure (the default
       scan_sources_after), so it's available to any downstream step
       — critically including Build_binding_<lang>, which is where c6's
       type-mismatch perturbations cause compile failure. *)
    scan_sources = Some (fun ~output_dir ~variant_key ->
      let mk base layer src =
        let out = Canary_basic.filename ~variant_key ~base ~ext:"json" in
        Printf.sprintf
          "python3 canary/scripts/inspect_tiny_typed.py --layer %s \
           --path %s/%s > %s/%s"
          layer source src output_dir out
      in
      let cmds = [
        mk "inspect_typed_header" "header"
          "c/include/tiny.h";
        mk "inspect_typed_binding_stub_ocaml" "stub_ocaml"
          "ocaml/tiny_raw.mli";
        mk "inspect_typed_binding_user_ocaml" "user_ocaml"
          "ocaml/tiny.mli";
        mk "inspect_typed_binding_stub_python" "stub_python"
          "python_cext/tiny_cext/_native.c";
        mk "inspect_typed_binding_user_python" "user_python"
          "python_cext/tiny_cext/__init__.py";
      ] in
      String.concat ~sep:" && " cmds
      |> Canary_build_cmd.with_marker
           ~marker:"scan.ok" ~output_dir ~variant_key);

    (* Build_binding OCaml: build the binding {b library} only —
       tiny.cmxa (bo6) and libtiny_stubs.a (bo7). dune --root pins the
       source tree as workspace; targets are relative to that root.
       Consumer compile (examples/probe_baseline.exe) is deferred to
       Probe so that mli mismatches surface there rather than here. *)
    build_binding = [
      (Canary_lang.OCaml,
       fun ~output_dir ~variant_key ->
         (* Capture dune's stderr into output_dir/build.log so c6's
            substring-match has something to grep against when the
            cstub compile fails (header arity mismatch etc.). The
            marker echo runs only on dune success. *)
         let build_log =
           Canary_basic.variant_file ~variant_key "build.log" in
         let dune_cmd =
           Canary_build_cmd.dune_build_cmd
             ~env_extra:[
               [%string "LIBRARY_PATH=%{abs_lib_dir}"];
               [%string "LD_RUN_PATH=%{abs_lib_dir}"];
             ]
             ~root:source
             ~target:"ocaml/tiny.cmxa ocaml/libtiny_stubs.a" () in
         Printf.sprintf
           "(%s) > %s/%s 2>&1"
           dune_cmd output_dir build_log
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
      (* Build_binding Python: verify the prebuilt cext exists in the
         python_cext_root store. *)
      (Canary_lang.Python,
       fun ~output_dir ~variant_key ->
         Printf.sprintf "ls %s > /dev/null" cext_so_glob
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
    ];

    (* Probe_lib: nm against the lib_dir store's actual libtiny. *)
    probe_lib = [
      (Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "nm -D %s | grep -E '^[0-9a-f]+ T tiny_' \
            > %s/%s 2>&1"
           lib_path output_dir probe_log);
    ];

    (* Probe_binding OCaml: dune build + exec probe_baseline.exe with
       source as the dune workspace root. mli mismatches surface here
       as consumer-compile failures; runtime symbol failures show up
       when exec runs against [abs_lib_dir]'s libtiny. *)
    probe_binding = [
      (Canary_lang.OCaml,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "(LIBRARY_PATH=%s LD_RUN_PATH=%s dune build --root %s %s \
            && LD_LIBRARY_PATH=%s %s/_build/default/%s) > %s/%s 2>&1"
           abs_lib_dir abs_lib_dir source probe_exe
           abs_lib_dir source probe_exe output_dir probe_log);
      (* Probe_binding Python (cext): the probe script lives with the
         source tree (probes are source-coupled); the cext .so it
         imports lives in [python_cext_root]. *)
      (Canary_lang.Python,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "LD_LIBRARY_PATH=%s PYTHONPATH=%s python3 \
            %s/python_cext/examples/probe_baseline.py > %s/%s 2>&1"
           abs_lib_dir python_cext_root source output_dir probe_log);
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
        (* Native nm-derived inspect of libtiny.so for c1 / c4 / c5.
           typed_header.json moved to scan_sources in Phase 15.5a so
           it's available even when later build steps fail. *)
        Canary_artifact_native.inspect_cmd
          ~lib:lib_path
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
      | Build_binding Canary_lang.OCaml ->
          Some (fun ~output_dir ~variant_key ->
            (* Two-file inspect: stub (c1) + mli (c2). Typed signatures
               moved to scan_sources in Phase 15.5a — they live at
               scan_sources/inspect_typed_*.json so c6 can cite them
               even when Build (Binding OCaml) fails. *)
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
              source watchlist_csv output_dir mli_file)
      | Build_binding Canary_lang.Python ->
          Some (fun ~output_dir ~variant_key ->
            (* Two-file inspect on the Python side. Mirrors the OCaml
               binding's two-file inspect.
               - inspect.json (c_stub via [inspect_binding.py --kind
                 stub] on the cext .so) — undefined refs into libtiny,
                 the Python analog of libtiny_stubs.a. Feeds c1
                 cmp_symbol's C_stub input.
               - inspect_attrs.json (Python dir() attrs via
                 [inspect_python.py]) — user-facing surface for
                 c2 cmp_api_completeness's Python_attrs input.

               The cext .so doesn't {b export} tiny_* — those are
               undefined refs satisfied by libtiny at load time. So we
               use the stub inspector here, not the native one
               (which would always report zero defined tiny_* symbols
               and was misleading before Phase 14c-followup,
               2026-06-02). *)
            let stub_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let attrs_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect_attrs" ~ext:"json" in
            let attrs_watchlist_csv =
              String.concat ~sep:"," tiny_python_module_watchlist in
            (* Two-file inspect at Build (Binding Python): c_stub (c1)
               + attrs (c2). Typed-signature inspects moved to
               scan_sources (Phase 15.5a). *)
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind stub \
               --path %s --prefix tiny_ > %s/%s && \
               LD_LIBRARY_PATH=%s PYTHONPATH=%s \
               python3 canary/scripts/inspect_python.py --pkg tiny_cext \
               --watchlist '%s' > %s/%s"
              cext_so_glob output_dir stub_file
              abs_lib_dir python_cext_root
              attrs_watchlist_csv output_dir attrs_file)
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
              source watchlist_csv output_dir out_file)
      | Probe (Binding Canary_lang.Python) ->
          Some (fun ~output_dir ~variant_key ->
            let out_file =
              Canary_basic.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_python_module_watchlist in
            Printf.sprintf
              "LD_LIBRARY_PATH=%s PYTHONPATH=%s \
               python3 canary/scripts/inspect_python.py --pkg tiny_cext \
               --watchlist '%s' > %s/%s"
              abs_lib_dir python_cext_root watchlist_csv output_dir out_file)
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


(** Default workspace path for tiny's harness-materialized caches.
    Variants append a scenario name to this. *)
let cache_workspace_of ~scenario =
  [%string "%{tiny_root}/scenarios/_cache/%{scenario}/workspace"]

(** Convenience aliases at the live-tree path for callers that don't
    distinguish variants. The live tree {b is} a valid dune workspace
    (the tola workspace root supplies dune-project), so passing
    live-tree stores works for ad-hoc invocations even though the
    canonical flow points each variant at its own materialized cache. *)
let base_script_spec =
  make_base_script_spec
    ~stores:(stores_of_workspace ~workspace_root:tiny_root ()) ()
let script_spec = base_script_spec
