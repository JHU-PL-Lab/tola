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

let script_spec : Canary_action.script_spec =
  {
    Canary_action.empty_script_spec with

    (* No fetch_source: tiny is in-tree. *)
    api_source = Some tiny_api_source;

    (* Configure: cmake -S c -B c/build. The marker-write suffix is added
       via [Canary_build_cmd.with_marker] so check_post sees conf.ok. *)
    configure = Some (fun ~output_dir ~variant_key ->
      Canary_build_cmd.cmake_configure_cmd
        ~src:[%string "%{tiny_root}/c"]
        ~build:[%string "%{tiny_root}/c/build"] ()
      |> Canary_build_cmd.with_marker
           ~marker:"conf.ok" ~output_dir ~variant_key);

    (* Build_lib produces lib_native.so (n4) at c/build/libtiny.so.1. *)
    build_lib = Some (fun ~output_dir ~variant_key ->
      Canary_build_cmd.cmake_build_cmd
        ~build:[%string "%{tiny_root}/c/build"] ()
      |> Canary_build_cmd.with_marker
           ~marker:"build.ok" ~output_dir ~variant_key);

    (* Build_binding OCaml: dune build under canary/examples/tiny/ocaml/.
       Produces:
       - compiled_binding_ocaml.cmxa (bo6)
       - compiled_binding_ocaml.stub-a (bo7) = libtiny_stubs.a
       - examples/probe_baseline.exe (the s6 carrier)
       Invoked from the tola root with the example tree as an explicit
       target (avoids dune-project context errors when cd'ing into the
       subdir). LIBRARY_PATH lets the cstubs link find libtiny;
       LD_RUN_PATH bakes the rpath into the binding. *)
    build_binding = [
      (Canary_lang.OCaml,
       fun ~output_dir ~variant_key ->
         Canary_build_cmd.dune_build_cmd
           ~env_extra:[
             [%string "LIBRARY_PATH=%{tiny_lib_dir}"];
             [%string "LD_RUN_PATH=%{tiny_lib_dir}"];
           ]
           ~target:[%string "%{tiny_root}/ocaml"] ()
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
      (* Build_binding Python: invoke tiny's Makefile python_cext target,
         which runs `uv build --wheel` and copies _native.cpython-*.so back
         next to __init__.py. Produces bpe3 compiled_binding_cext.so. *)
      (Canary_lang.Python,
       fun ~output_dir ~variant_key ->
         Printf.sprintf "make -C %s python_cext" tiny_root
         |> Canary_build_cmd.with_marker
              ~marker:"build.ok" ~output_dir ~variant_key);
    ];

    (* Probe_lib: minimal "the lib exists and is loadable" check. The real
       payload of this step is the attached _inspect (see [inspect] field
       below) which runs inspect_native.py against n4 lib_native.so with
       the stable_symbols watchlist — that's what would catch
       {i e1 symbol_missing} via {i c1 cmp_symbol}. *)
    probe_lib = [
      (Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_output_path.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "nm -D %s/c/build/libtiny.so.1 | grep -E '^[0-9a-f]+ T tiny_' \
            > %s/%s 2>&1"
           tiny_root output_dir probe_log);
    ];

    (* Probe_binding OCaml: run probe_baseline.exe. *)
    probe_binding = [
      (Canary_lang.OCaml,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_output_path.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "LD_LIBRARY_PATH=%s _build/default/%s/ocaml/examples/probe_baseline.exe \
            > %s/%s 2>&1"
           tiny_lib_dir tiny_root output_dir probe_log);
      (* Probe_binding Python (cext): import + invoke wrappers. The
         standalone harness's probe_baseline.py asserts the same value set;
         here we use the same script. *)
      (Canary_lang.Python,
       Canary_store.Build_tree,
       fun ~output_dir ~variant_key ->
         let probe_log = Canary_output_path.variant_file ~variant_key "probe.log" in
         Printf.sprintf
           "LD_LIBRARY_PATH=%s PYTHONPATH=%s/python_cext python3 \
            %s/python_cext/examples/probe_baseline.py > %s/%s 2>&1"
           tiny_lib_dir tiny_root tiny_root output_dir probe_log);
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
      let ocaml_build_dir =
        Printf.sprintf "_build/default/%s/ocaml" tiny_root in
      match rule with
      | Probe Lib ->
          (* n4 lib_native.so via inspect_native.py; the stable_symbols
             watchlist drives the c1 cmp_symbol equivalent on the
             provider side. *)
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_native.inspect_cmd
              ~lib:(Printf.sprintf "%s/c/build/libtiny.so.1" tiny_root)
              ~prefixes:[ "tiny_" ]
              ~watchlist:tiny_native_stable_symbols
              ~output_dir ~variant_key ())
      | Build_binding Canary_lang.OCaml ->
          Some (fun ~output_dir ~variant_key ->
            (* base="inspect" matches the default tag_suffix="_inspect" that
               attach_inspect uses when wiring the explicit `inspect` field.
               The standalone harness names this JSON `ocaml_stub.json`; in
               canary the per-parent output_dir separates it from other
               binding inspectors. *)
            let out_file =
              Canary_output_path.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind stub \
               --path %s/libtiny_stubs.a --prefix tiny_ > %s/%s"
              ocaml_build_dir output_dir out_file)
      | Build_binding Canary_lang.Python ->
          Some (fun ~output_dir ~variant_key ->
            let cext_so =
              Printf.sprintf
                "%s/python_cext/tiny_cext/_native.cpython-*.so" tiny_root in
            Canary_artifact_native.inspect_cmd
              ~lib:cext_so ~prefixes:[ "tiny_" ]
              ~watchlist:tiny_native_stable_symbols
              ~output_dir ~variant_key ())
      | Probe (Binding Canary_lang.OCaml) ->
          Some (fun ~output_dir ~variant_key ->
            let out_file =
              Canary_output_path.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_ocaml_module_watchlist in
            Printf.sprintf
              "python3 canary/scripts/inspect_binding.py --kind mli \
               --path %s/ocaml/tiny.mli --watchlist '%s' > %s/%s"
              tiny_root watchlist_csv output_dir out_file)
      | Probe (Binding Canary_lang.Python) ->
          Some (fun ~output_dir ~variant_key ->
            let out_file =
              Canary_output_path.filename ~variant_key
                ~base:"inspect" ~ext:"json" in
            let watchlist_csv =
              String.concat ~sep:"," tiny_python_module_watchlist in
            Printf.sprintf
              "LD_LIBRARY_PATH=%s PYTHONPATH=%s/python_cext \
               python3 canary/scripts/inspect_python.py --pkg tiny_cext \
               --watchlist '%s' > %s/%s"
              tiny_lib_dir tiny_root watchlist_csv output_dir out_file)
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
