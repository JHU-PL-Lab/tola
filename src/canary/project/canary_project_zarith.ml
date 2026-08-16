(* Project: zarith — Pattern A (system libgmp + opam zarith binding).
   25 reverse deps in opam (most-used Pattern A; classic A-shape benchmark).
   Spec is a thin declaration over canary_pattern_a; the real shape is in
   canary_pattern_a.runner_spec. *)

(* The C API declaration (2026-08-13, spec-check fulfillment): the native
   surface is GMP (system libgmp-dev — headers come from the -dev package,
   not the source repo, so [headers = None]; the symbol watchlists carry
   the surface). The declared SOURCE is the ocaml/Zarith repo (the
   binding + its C stubs — the fixable, github-reportable half; GMP's own
   tar/mailing-list repo is a later refinement). *)
let zarith_native_watchlist = [
  "__gmpz_init";
  "__gmpz_clear";
  "__gmpz_set_str";
  "__gmpz_add";
  "__gmpz_mul";
  "__gmpz_pow_ui";
  "__gmpz_get_str";
]

let zarith_ocaml_watchlist = [ "Z"; "Q"; "Big_int_Z"; "Zarith_version" ]

let zarith_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { kind = Canary_artifact.C;
        components = [ Canary_artifact.Runtime_lib ];
        headers = None;
        symbol_prefixes = [ "__gmpz_"; "__gmpq_"; "__gmpf_"; "__gmp_" ];
        stable_symbols = zarith_native_watchlist;
        versioned_symbols = [];
        soname = None;
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist = zarith_ocaml_watchlist;
          type_watchlist = [] } ] }

let zarith_source_stable : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "zarith";
    remote = Some (Git "https://github.com/ocaml/Zarith.git");
    locals = [];
    version = Canary_basic.{ channel = Canary_basic.Stable; id = "1.14" };
    ref_ = "release-1.14";
    official = true;
    build_sys_deps = [];
    api_source = Some zarith_api_source;
    label = None;
    (* the repo builds the BINDING (caml_z.c against the system gmp);
       the C lib itself (GMP) is off-tree — its own repo *)
    artifacts =
      [ Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs ]
  }

(* master stays declared as the unwired latest channel — the
   per-(artifact × channel) source provider is the not-yet-wired
   provenance refinement. *)
let zarith_source_dev : Canary_artifact_source.source_repo =
  { zarith_source_stable with
    version = Canary_basic.{ channel = Canary_basic.Dev; id = "master" };
    ref_ = "master" }

let decl : Canary_pattern_a.t = {
  name = "zarith";
  opam_pkg = "zarith";
  ocamlfind_pkg = "zarith";
  system_pkg_linux = "libgmp-dev";
  system_pkg_macos = "gmp";
  example_file = "canary/examples/zarith/zarith_example.ml";
  example_target = "zarith_example";
  binding_lib = "zarith";
  lib = {
    linux_glob = "/usr/lib/x86_64-linux-gnu/libgmp.so* /usr/lib*/libgmp.so*";
    brew_pkg = "gmp";
    brew_dylib = "libgmp.dylib";
  };
  native_probe_prefix = "__gmp";
  native_inspect_prefixes = [ "__gmpz_"; "__gmpq_"; "__gmpf_"; "__gmp_" ];
  (* Decades-stable GMP integer ops. Removing one would be a major upstream
     break — exactly the bellwether the watchlist is for. *)
  native_watchlist = zarith_native_watchlist;
  (* zarith ships four compilation units (verified via ocamlobjinfo on
     zarith.cmxa). Drift here would be a major version bump. *)
  ocaml_module_watchlist = zarith_ocaml_watchlist;
  (* C1 (2026-08-16): the 3-way — stable release-1.14 + dev master as
     first-class per-channel repos (one scenario each). The fork slot
     stays empty until a dev bug worth fixing appears. *)
  sources = [ zarith_source_stable; zarith_source_dev ];
  binding_mechanism = Canary_mechanism.Cstubs;
}

let runner_spec = Canary_pattern_a.runner_spec decl

(* Registry entry: Pattern A's typed artifact table + the template's
   runner_spec (C1: TWO scenarios — source@release-1.14 and source@master,
   each over the stable lib + binding, Fetched). *)
let zarith_run : Canary_project_run.project_run = Canary_pattern_a.run decl
