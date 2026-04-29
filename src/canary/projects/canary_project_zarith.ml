(* Project: zarith — Pattern A (system libgmp + opam zarith binding).
   25 reverse deps in opam (most-used Pattern A; classic A-shape benchmark).
   Spec is a thin declaration over canary_pattern_a; the real shape is in
   canary_pattern_a.script_spec. *)

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
  native_summary_prefixes = [ "__gmpz_"; "__gmpq_"; "__gmpf_"; "__gmp_" ];
  (* Decades-stable GMP integer ops. Removing one would be a major upstream
     break — exactly the bellwether the watchlist is for. *)
  native_watchlist = [
    "__gmpz_init";
    "__gmpz_clear";
    "__gmpz_set_str";
    "__gmpz_add";
    "__gmpz_mul";
    "__gmpz_pow_ui";
    "__gmpz_get_str";
  ];
  (* zarith ships four compilation units (verified via ocamlobjinfo on
     zarith.cmxa). Drift here would be a major version bump. *)
  ocaml_module_watchlist = [ "Z"; "Q"; "Big_int_Z"; "Zarith_version" ];
}

let script_spec = Canary_pattern_a.script_spec decl
