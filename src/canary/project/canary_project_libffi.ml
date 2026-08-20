(* Project: libffi — Pattern A (system libffi + opam ctypes-foreign binding).
   First project on the Dynamic_ffi mechanism (ctypes resolves and calls C
   functions at RUNTIME via libffi) — zarith/cairo/ssl are all Static_c_abi.
   Positive-only (Level A): the binding compiles and a dynamic call
   round-trips. The binding is INDIRECT: ctypes-foreign uses libffi
   internally and does not expose ffi_* symbols itself — the native probe
   checks the C lib, the binding probe checks ctypes-foreign works. *)

(* The C API declaration (2026-08-13, spec-check fulfillment): the public
   ffi.h surface + the bellwether watchlist. The binding mechanism is
   honestly [Ctypes] (the recorded M2 issue — ctypes-foreign is Dynamic_ffi). *)
let libffi_native_watchlist = [
  "ffi_prep_cif";
  "ffi_call";
  "ffi_prep_closure_loc";
  "ffi_closure_alloc";
  "ffi_closure_free";
]

let libffi_ocaml_watchlist = [ "Foreign"; "Ctypes_foreign_basis" ]

let libffi_api_source : Canary_artifact.t =
  { Canary_artifact.native_api =
      { kind = Canary_artifact.C;
        components = [ Canary_artifact.Headers; Canary_artifact.Runtime_lib ];
        headers =
          Some
            { Canary_artifact.dir = "include";
              files = [ "ffi.h"; "ffitarget.h" ] };
        symbol_prefixes = [ "ffi_" ];
        stable_symbols = libffi_native_watchlist;
        versioned_symbols = [];
        soname = None;
        c_runtime = None;
        cxx_abi = None };
    binding_apis =
      [ { Canary_artifact.lang = Canary_lang.OCaml;
          source_dir = None;
          module_watchlist = libffi_ocaml_watchlist;
          type_watchlist = [] } ] }

let libffi_source_stable : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "libffi";
    remote = Some (Git "https://github.com/libffi/libffi.git");
    locals = [];
    version = Canary_basic.{ channel = Canary_basic.Stable; id = "3.8.0" };
    ref_ = "v3.8.0";
    official = true;
    build_sys_deps = [];
    api_source = Some libffi_api_source;
    label = None;
    (* the repo builds the C lib; ctypes-foreign (opam) is off-tree *)
    artifacts = [ Canary_artifact.a_lib ] }

let decl : Canary_opam_binding.t =
  { name = "libffi";
    opam_pkg = "ctypes-foreign";
    ocamlfind_pkg = "ctypes-foreign";
    system_pkg_linux = "libffi-dev";
    system_pkg_macos = "libffi";
    example_file = "canary/examples/libffi/libffi_example.ml";
    example_target = "libffi_example";
    binding_lib = "ctypes-foreign";
    lib =
      { linux_glob =
          "/usr/lib/x86_64-linux-gnu/libffi.so* /usr/lib*/libffi.so*";
        brew_pkg = "libffi";
        brew_dylib = "libffi.dylib" };
    native_probe_prefix = "ffi_";
    native_inspect_prefixes = [ "ffi_" ];
    (* Core libffi entry points: cif preparation + call/closure machinery.
       Present since libffi 3.0 (2005); removing one would be a major
       upstream break — the bellwether the watchlist is for. *)
    native_watchlist = libffi_native_watchlist;
    (* ctypes-foreign ships several compilation units under the findlib
       package (foreign.cmx, dl.cmx, ctypes_ffi.cmx, …). The user-facing
       surface is Foreign + Ctypes_foreign_basis; drift here would be a
       major ctypes version bump. *)
    ocaml_module_watchlist = libffi_ocaml_watchlist;
    sources = [ libffi_source_stable ];
    (* the C LIB's own repo (libffi/libffi.git) — the default *)
    source_of_binding = None;
    (* ctypes-foreign resolves and calls C functions at RUNTIME via libffi —
       genuinely Dynamic_ffi, so [Ctypes] (2026-08-13; was the hardcoded
       [Cstubs] of [Canary_project_run.simple], the recorded M2 issue). *)
    binding_mechanism = Canary_mechanism.Ctypes;
    (* measured: opam `ctypes-foreign` depends on
       `conf-libffi {>= "2.0.0"}` — a lower BOUND, and note what it bounds:
       the conf package's own version (opam packaging), not libffi's.
       CONFIRMED at the source (2026-08-20): conf-libffi.2.0.0's entire
       build is `pkg-config libffi`, a bare presence check that never sees
       its own version, while the library it finds is 3.x. So the bound
       does not reach the lib — [tracks_lib = false], and the derived
       freedom is [Any_version], the same as conf-gmp's. Only the 13
       measured version-carrying conf packages set this true; see
       surveys/conf_packages.md §G1a and raw/conf_version_carriers.py. *)
    pm_gate =
      Canary_binding_decl.Bounded_with_conf
        { conf = "conf-libffi";
          lower = Some "2.0.0";
          upper = None;
          tracks_lib = false };
    (* the lib's LATEST point, by the sourcing rule (landing.md §3):
       libffi's own GitHub release (3.8.0) ships source plus MSVC/Windows
       binaries only — no Linux artifact — so step 2 falls through to
       conda-forge, whose newest linux-64 build is 3.7.0 (one release
       behind upstream, which is the measured cost of the fallback). *)
    prebuilt_latest =
      Some
        { Canary_prebuilt.project = "libffi";
          tag = "libffi-3.7.0";
          version = "3.7.0";
          url =
            "https://conda.anaconda.org/conda-forge/linux-64/libffi-3.7.0-h3435931_0.conda";
          lib_glob = "lib/libffi.so*";
          note =
            "conda-forge 3.7.0 (upstream 3.8.0 publishes no Linux binary; \
             apt ships 3.4.6). Same soname (libffi.so.8) as apt's, so the \
             pair tests version drift WITHIN an ABI generation — which is \
             what a ctypes-foreign consumer resolving symbols at dlsym \
             time would notice first." };
    wrapper = None }

let runner_spec = Canary_opam_binding.runner_spec decl

(* Registry entry: Pattern A's typed artifact table + the template's
   runner_spec (single scenario: source + lib + binding Fetched@Stable). *)
let libffi_run : Canary_project_run.project_run = Canary_opam_binding.run decl
