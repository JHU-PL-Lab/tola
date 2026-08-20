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
(* The FULL stub-required surface (2026-08-17, the user's call for the
   binding decl): every GMP symbol caml_z.c's stubs reference — the live
   c1 consumer surface, taken from the built binding's inspect `requires`
   (libzarith.a's undefined GMP symbols; 42 of libgmp's 620 exports). It
   spans the mpz_/mpq_/mpf_/mpn_ prefixes (no single prefix scopes it —
   hence the decl's empty prefix), and includes the low-level mpn_* half
   (integer arithmetic the library exposes internally; a break there
   breaks zarith just as surely). Rebuild the dev binding and re-run its
   inspect to refresh. *)
let zarith_native_watchlist = [
  "__gmpn_add_n";
  "__gmpn_divexact";
  "__gmpn_gcd";
  "__gmpn_gcdext";
  "__gmpn_get_str";
  "__gmpn_hamdist";
  "__gmpn_lshift";
  "__gmpn_mul";
  "__gmpn_mul_1";
  "__gmpn_mul_n";
  "__gmpn_perfect_square_p";
  "__gmpn_popcount";
  "__gmpn_rshift";
  "__gmpn_scan1";
  "__gmpn_set_str";
  "__gmpn_sqr";
  "__gmpn_sqrtrem";
  "__gmpn_sub_n";
  "__gmpn_tdiv_qr";
  "__gmpz_2fac_ui";
  "__gmpz_bin_ui";
  "__gmpz_clear";
  "__gmpz_congruent_p";
  "__gmpz_divisible_p";
  "__gmpz_fac_ui";
  "__gmpz_fib_ui";
  "__gmpz_init";
  "__gmpz_invert";
  "__gmpz_jacobi";
  "__gmpz_lucnum_ui";
  "__gmpz_mfac_uiui";
  "__gmpz_nextprime";
  "__gmpz_perfect_power_p";
  "__gmpz_pow_ui";
  "__gmpz_powm";
  "__gmpz_powm_sec";
  "__gmpz_primorial_ui";
  "__gmpz_probab_prime_p";
  "__gmpz_realloc2";
  "__gmpz_remove";
  "__gmpz_root";
  "__gmpz_rootrem";
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

(* GMP's own repo — the OFF-TREE lib source, DECLARED but UNWIRED
   (2026-08-17, conf_survey.md §6 + the prebuilt-shadows-source rule):
   the system ships exactly one GMP (6.3.0); the dev is gmplib.org's
   canonical MERCURIAL repo ([Hg] remote — the hg checkout lives in
   contrib/gmp-all/gmp). NO source-built lib column: building the C lib
   (bootstrap/libtool/VPATH traps) is a last resort reserved for fixing
   the lib or confirming a blame — a second GMP enters the matrix only
   as a PREBUILT (the shadow-preference mechanism). The repo builds the
   lib only — GMP ships no binding. *)
let gmp_source_master : Canary_artifact_source.source_repo =
  { Canary_artifact_source.name = "gmp";
    remote = Some (Canary_artifact_source.Hg "https://gmplib.org/repo/gmp/");
    locals = Canary_artifact_source.mk_locals "contrib/gmp-all/gmp";
    version = Canary_basic.{ channel = Dev; id = "master" };
    (* hg's default branch IS the dev line (the release tarballs branch off it) *)
    ref_ = "default";
    official = true;
    build_sys_deps = [ "m4" ];
    api_source = None;
    label = None;
    artifacts = [ Canary_artifact.a_lib ];
  }

(* The wrapper decl (2026-08-17, active plan 2): renders the committed
   canary/templates/opam-local-repo/packages/zarith/zarith-no-conf.dev/opam.in
   byte-equal (pinned in the layer tests) — the pattern's Publish step
   installs this package over the scenario's worktree. *)
let zarith_wrapper_decl : Canary_opam_template.wrapper_decl = {
  pkg = "zarith-no-conf";
  src_var = "CANARY_ZARITH_SRC";
  maintainer = "weng@cs.jhu.edu";
  authors = "Antoine Miné, Xavier Leroy, Pascal Cuoq";
  homepage = "https://github.com/ocaml/Zarith";
  bug_reports = "https://github.com/ocaml/Zarith/issues";
  license = "LGPL-2.0-only WITH OCaml-LGPL-linking-exception";
  dev_repo = "git+https://github.com/ocaml/Zarith.git";
  build_body = "[ \"sh\" \"-ec\" \"./configure && make\" ]";
  install_body = "[ \"sh\" \"-ec\" \"make install\" ]";
  remove_body = "\"ocamlfind\" \"remove\" \"zarith\"";
  depends = [ "\"ocaml\" {>= \"4.08.0\"}"; "\"ocamlfind\"" ];
  conflicts = [ "zarith" ];
  synopsis = "Zarith without the conf-gmp hop — builds directly against the system GMP";
  description =
    "Canary-local package: zarith built WITHOUT the conf-gmp virtual package\n\
     (the conf-free prototype — doc/canary/project/conf_survey.md). The build\n\
     runs zarith's own ./configure, which probes GMP via pkg-config — the\n\
     same check conf-gmp performs — so the system GMP dependency is real but\n\
     not declared through opam's conf layer. Same findlib name (zarith), so\n\
     it conflicts with the stock package; scenarios pin-switch between them\n\
     (the z3 stable/dev store-pin dance, algorithm_explainer.md §10).";
}

let decl : Canary_opam_binding.t = {
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
  (* the FULL declared surface: __gmpn_ added 2026-08-17 — the stub-
     required watchlist spans the mpn block, and the c1 inclusion check
     runs against THIS prefix-filtered symbol list; without __gmpn_ the
     list omits ~264 exports and a required mpn symbol would read as
     MISSING when it is present. *)
  native_inspect_prefixes = [ "__gmpz_"; "__gmpq_"; "__gmpf_"; "__gmpn_"; "__gmp_" ];
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
  (* ocaml/Zarith.git is the OCAML BINDING's repo, not the lib's
     (2026-08-19, user): the C lib here is apt libgmp, and GMP's own repo
     is declared separately + unwired. Before this, zarith's refs
     (1.14 / master) landed in [a_source], so the matrix's ref column
     presented a binding's repo as the project's lib source. *)
  source_of_binding = Some Canary_lang.OCaml;
  binding_mechanism = Canary_mechanism.Cstubs;
  (* measured: `opam show zarith --field=depends` carries `conf-gmp` with
     NO version constraint — the conf proves GMP is present, it does not
     pin a version. So opam already allows any system GMP: zarith's lib
     axis is limited by AVAILABILITY (apt ships one), not by the gate, and
     `zarith-no-conf` is not what buys that freedom (it publishes a
     binding built from OUR worktree — the binding axis). *)
  pm_gate = Canary_binding_decl.Free_with_conf "conf-gmp";
  (* NO prebuilt latest exists (landing.md §3, measured 2026-08-19): GMP's
     newest upstream release is 6.3.0 (2023-07-30), gmplib.org publishes
     source only, conda-forge's newest is also 6.3.0 — and apt already
     ships 6.3.0. When upstream and the distro agree, the lib axis has ONE
     point. That is a fact about GMP, not a gap in this spec, and it is
     also NOT an opam problem: conf-gmp constrains no version. zarith's
     pair therefore lives on the BINDING axis (opam release vs the
     worktree build) alone. *)
  prebuilt_latest = None;
  wrapper = Some zarith_wrapper_decl;
}

let runner_spec = Canary_opam_binding.runner_spec decl

(* The binding declaration (2026-08-17, active plan 4 — the M2 pattern):
   zarith's Cstubs binding wraps the system GMP. prefix = "" (GMP spans
   mpz_/mpq_/mpf_/mpn_ — no single prefix; the FULL watchlist above is the
   scoping, per the user's call). The stub archive is libzarith.a (the
   built binding's inspect path — zarith links caml_z.c into it), and the
   user surface is zarith.mli. *)
let zarith_binding_decls : Canary_binding_decl.binding_decl list =
  let open Canary_binding_decl in
  [ { mechanism = Canary_mechanism.Cstubs;
      c_api = { functions = zarith_native_watchlist; enums = [] };
      native =
        { prefix = "";
          soname = "libgmp.so.10";
          headers = { dir = "."; files = [ "gmp.h" ] } };
      coupling =
        Stub_archive
          { sources = [ "caml_z.c" ];
            archive = "libzarith.a" };
      surface_path = "zarith.mli";
      (* measured: opam `zarith` depends on `conf-gmp` with NO version
         constraint, so any system GMP the conf check accepts is already
         installable — the lib axis is free of opam here, and the
         `zarith-no-conf` wrapper is NOT what buys that freedom (it
         publishes a binding built from OUR worktree; see the wrapper
         decl). What limits zarith's lib axis is availability: apt ships
         exactly one GMP. *)
      (* one source: the gate declared on [decl] above *)
      pm_gate = Some decl.Canary_opam_binding.pm_gate } ]

(* Registry entry: Pattern A's typed artifact table + the template's
   runner_spec (C1: TWO scenarios — source@release-1.14 and source@master,
   each over the stable lib + binding, Fetched). *)
let zarith_run : Canary_project_run.project_run =
  { (Canary_opam_binding.run decl) with
    Canary_project_run.pr_binding_decls = zarith_binding_decls }
