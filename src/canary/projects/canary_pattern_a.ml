open Canary_basic
open Canary_toolchain

(* ── Pattern A template ──
   Pattern A in opam-survey terminology: a `conf-*` virtual package verifies a
   system C library is present, and an OCaml binding (opam pkg) links against
   that system lib. Examples: zarith via conf-gmp, ssl via conf-libssl,
   cairo2 via conf-cairo, etc.

   This module compresses the boilerplate. A new Pattern A project becomes
   ~25 lines of declaration vs. ~100 lines of hand-rolled runner_spec.
   Extracted from zarith + ssl as the second-data-point validation per
   doc/canary/project/index.md §3 sequencing.

   Coverage boundaries:
   - This template covers native_lib + ocaml binding probe only. Projects with
     additional probe variants (e.g. sqlite's stdlib pip probe, llvm's
     llvmlite pip probe) extend the resulting runner_spec rather than fitting
     it through the template.
   - Optional-C-dep cases (lwt + conf-libev) are NOT yet covered; would need
     a `with_optional_lib` extension.
   - Self-building (Pattern C, like z3) is out of scope. *)

(* Per-project lib locator: enough info to produce a shell snippet that
   resolves $LIB_NATIVE on Linux (multilib path) and macOS (brew keg). *)
type lib_locator = {
  linux_glob : string;     (* e.g. "/usr/lib/x86_64-linux-gnu/libgmp.so*"
                              or "/usr/lib/x86_64-linux-gnu/libssl.so.*" *)
  brew_pkg : string;       (* e.g. "gmp" or "openssl@3" — for $(brew --prefix ...) *)
  brew_dylib : string;     (* basename under brew prefix's lib dir, e.g. "libgmp.dylib" *)
}

(* The full Pattern A declaration. *)
type t = {
  name : string;                    (* "zarith" — project tag, dir name *)
  opam_pkg : string;                (* opam package; binding to install *)
  ocamlfind_pkg : string;           (* usually = opam_pkg; can differ (e.g. llvm) *)
  system_pkg_linux : string;        (* apt name, e.g. "libgmp-dev" *)
  system_pkg_macos : string;        (* brew name, e.g. "gmp" *)
  example_file : string;            (* path to canary/examples/<name>/<name>_example.ml *)
  example_target : string;          (* compile target name, e.g. "zarith_example" *)
  binding_lib : string;             (* `ocamlfind -package <binding_lib>`, usually = ocamlfind_pkg *)
  lib : lib_locator;                (* native lib resolution *)
  native_probe_prefix : string;     (* prefix for the count-symbols probe, e.g. "__gmp" / "SSL_" *)
  native_inspect_prefixes : string list; (* by_prefix breakdown for summary *)
  native_watchlist : string list;   (* hand-curated stable C symbols *)
  ocaml_module_watchlist : string list; (* hand-curated OCaml module names *)
  (* Optional declared source (2026-08-13, spec-check fulfillment): when
     [Some], the runner_spec gains a fetch_source step (a real one-time
     clone) and the project's artifact table carries a source row. *)
  source : Canary_artifact_source.source_repo option;
  (* The binding's honest mechanism (2026-08-13, the recorded M2 issue):
     [Cstubs] for static stub-linked bindings (zarith/cairo), [Ctypes] for
     genuinely Dynamic_ffi ones (libffi's ctypes-foreign resolves and
     calls C at runtime). *)
  binding_mechanism : Canary_mechanism.mechanism;
}

(* Build the lib resolve shell snippet. Sets $LIB_NATIVE. *)
let lib_resolve (l : lib_locator) =
  Printf.sprintf
    {|LIB_NATIVE=$(ls %s 2>/dev/null \
        "$(brew --prefix %s 2>/dev/null)/lib/%s" 2>/dev/null \
        | head -1)
test -n "$LIB_NATIVE" -a -e "$LIB_NATIVE"|}
    l.linux_glob l.brew_pkg l.brew_dylib

let ocaml_config (d : t) : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = String.uppercase_ascii d.name ^ "_PREFIX";
        prefix_var = "$" ^ String.uppercase_ascii d.name ^ "_PREFIX";
        prefix_envar = "${" ^ String.uppercase_ascii d.name ^ "_PREFIX}";
        libdir_name = String.uppercase_ascii d.name ^ "_LIB_DIR";
        libdir_var = "$" ^ String.uppercase_ascii d.name ^ "_LIB_DIR";
        local_repo_name = "canary-local";
        package_name = d.opam_pkg;
        package_version = "system";
        canary_src_var = "CANARY_" ^ String.uppercase_ascii d.name ^ "_SRC";
      };
    ocaml =
      {
        example_file = d.example_file;
        example_target = d.example_target;
        example_name = d.name ^ " example";
        binding_lib_name = d.binding_lib;
        build_api_path = None;
      };
    prebuilt =
      Some
        (mk_prebuilt_info ~opam_package:d.opam_pkg
           ~system_package_linux:d.system_pkg_linux
           ~system_package_macos:d.system_pkg_macos ());
  }

let runner_spec (d : t) : Canary_step_builder.runner_spec =
  let cfg = ocaml_config d in
  let prebuilt = prebuilt_info_exn cfg in
  let pm = Canary_store.detect_pm () in
  let resolve = lib_resolve d.lib in
  {
    Canary_step_builder.empty_runner_spec with
    (* Declarative lib store (S3/S4): fetch_lib is Derived from this. *)
    stores =
      { Canary_store_config.empty_store_config with
        lib = Some
          { Canary_store_config.provider =
              Canary_store_config.Sys_pkg prebuilt.system_package;
            components = []; headers = None } };
    fetch_lib = Some (Canary_step_builder.Derived Canary_step_builder.Fetch_lib);
    (* The declared source made runnable (Pattern A never builds from it —
       the fetch is the declaration, cached via the source.ok marker). *)
    fetch_source =
      Option.map
        (fun source ~output_dir ~variant_key ->
          Canary_artifact_source.source_fetch_cmd
            (Canary_basic.detect_distro ()) source ~output_dir ~variant_key)
        d.source;
    (* fetch_binding stays Raw (Derived can't reproduce opam install_args yet). *)
    fetch_binding =
      [ (Canary_lang.OCaml, Canary_step_builder.Raw (Canary_step_builder.fetch_binding_cmd prebuilt.opam_package_spec)) ];
    probe_lib =
      [ ( Canary_store.Pm (Canary_store.Sys_pm { pm }),
          fun ~output_dir ~variant_key ->
            let probe = Canary_artifact_native.native_lib_probe_cmd
              ~lib:"$LIB_NATIVE" ~prefix:d.native_probe_prefix ~output_dir ~variant_key in
            Printf.sprintf "%s\n%s" resolve probe ) ];
    probe_binding =
      [
        (Canary_lang.OCaml,
         Canary_store.Pm (Canary_store.Lang_pm { lang = Canary_lang.OCaml; pm = Canary_store.Opam }),
         (fun ~output_dir ~variant_key ->
           Canary_step_builder.probe_ocaml_cmd ~binding_lib:d.binding_lib
             ~example:d.example_file ~target:d.example_target
             ~output_dir ~variant_key));
      ];
    inspect = (fun action loc -> match action, loc with
      | Probe_lib, _ ->
          Some (fun ~output_dir ~variant_key ->
            let sum = Canary_artifact_native.inspect_cmd
              ~lib:"$LIB_NATIVE"
              ~prefixes:d.native_inspect_prefixes
              ~watchlist:d.native_watchlist
              ~output_dir ~variant_key () in
            Printf.sprintf "%s\n%s" resolve sum)
      | Probe_binding (_), _ ->
          Some (fun ~output_dir ~variant_key ->
            Canary_artifact_lang.inspect_opam_pkg_cmd
              ~pkg:d.ocamlfind_pkg
              ~watchlist:d.ocaml_module_watchlist
              ~output_dir ~variant_key ())
      | _ -> None);
  }

(* ── THE artifact table + run (2026-08-13, spec-check fulfillment) ──
   Typed rows replacing [Canary_project_run.simple]'s providerless rows:
   source (when declared) + system-pkg lib + opam binding — the spec
   audit reads providers off these rows. The runner_spec above is the
   realization (constant over the single scenario). *)

let artifacts (d : t) : Canary_project_spec.artifact_row list =
  let open Canary_artifact in
  let binding_row =
    Canary_project_spec.artifact_row
      ~artifact:(a_binding Canary_lang.OCaml d.binding_mechanism)
      ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:
        (Canary_store_config.Lang_pkg
           { lang = Canary_lang.OCaml; pm = Canary_store.Opam;
             package = d.opam_pkg; self_contained = false; versions = None })
      ()
  in
  let lib_row =
    Canary_project_spec.artifact_row ~artifact:a_lib
      ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
      ~provider:
        (Canary_store_config.Sys_pkg
           { Canary_store.linux_pkg = d.system_pkg_linux;
             macos_pkg = d.system_pkg_macos; version_tag = None;
             locator_hint = None; behavior = Canary_store.Stateful_global })
      ()
  in
  let source_rows =
    match d.source with
    | None -> []
    | Some source ->
        [ Canary_project_spec.artifact_row ~artifact:a_source
            ~universe:[ (Fetched, [ Canary_basic.Stable ]) ]
            ~provider:(Canary_store_config.Source_repo source) () ]
  in
  lib_row :: binding_row :: source_rows

let run (d : t) : Canary_project_run.project_run =
  { pr_name = d.name;
    pr_artifacts = artifacts d;
    pr_runner_spec = (fun _a ~workspace:_ -> runner_spec d);
    pr_mismatch_probes = [];
    pr_wrapper_pkgs = [];
    pr_api_source = None;
    pr_tier = Canary_project_run.Light }
