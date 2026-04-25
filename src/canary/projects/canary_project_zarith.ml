open Canary_basic
open Canary_toolchain_ocaml
open Canary

(* ── Project: zarith (Pattern A — system libgmp + opam zarith binding) ──
   - 25 reverse deps in opam (most-used Pattern A; classic A-shape benchmark).
   - No source build: zarith installs from opam, links to system libgmp.
   - Native lib lives at /usr/lib/.../libgmp.so on Linux, brew prefix on macOS.
   - opam package "zarith" depends on conf-gmp (Pattern A canonical). *)

let zarith_ocaml_config : ocaml_tool_config =
  {
    toolchain =
      {
        prefix_name = "GMP_PREFIX";
        prefix_var = "$GMP_PREFIX";
        prefix_envar = "${GMP_PREFIX}";
        libdir_name = "GMP_LIB_DIR";
        libdir_var = "$GMP_LIB_DIR";
        local_repo_name = "canary-local";
        package_name = "zarith";
        package_version = "system";
        canary_src_var = "CANARY_GMP_SRC";
      };
    ocaml =
      {
        example_file = "canary/examples/zarith/zarith_example.ml";
        example_target = "zarith_example";
        example_name = "zarith example";
        binding_lib_name = "zarith";
        build_api_path = None;
      };
    prebuilt =
      Some
        (mk_prebuilt_info ~opam_package:"zarith"
           ~system_package_linux:"libgmp-dev" ~system_package_macos:"gmp" ());
  }

(* ── Action steps ── *)

let prebuilt = prebuilt_info_exn zarith_ocaml_config

(* OCaml-side watchlist: zarith ships four compilation units (verified via
   ocamlobjinfo on zarith.cmxa). Drift here would be a major version bump. *)
let zarith_ocaml_watchlist = [ "Z"; "Q"; "Big_int_Z"; "Zarith_version" ]

(* Native libgmp.so watchlist. The __gmpz_* prefix covers integer ops, the
   cornerstone of zarith. Specific entries chosen for stability — these have
   been in GMP for decades and removing one would be a major upstream break. *)
let gmp_native_watchlist = [
  "__gmpz_init";
  "__gmpz_clear";
  "__gmpz_set_str";
  "__gmpz_add";
  "__gmpz_mul";
  "__gmpz_pow_ui";
  "__gmpz_get_str";
]

(* Locate libgmp.so on the host. macOS Homebrew keeps it under brew --prefix
   gmp; on Linux it's via the standard multilib path. Result is exported
   as $LIB_GMP for downstream commands. *)
let lib_gmp_resolve =
  {|LIB_GMP=$(ls /usr/lib/x86_64-linux-gnu/libgmp.so* 2>/dev/null \
        /usr/lib*/libgmp.so* 2>/dev/null \
        "$(brew --prefix gmp 2>/dev/null)/lib/libgmp.dylib" 2>/dev/null \
        | head -1)
test -n "$LIB_GMP" -a -e "$LIB_GMP"|}

let script_spec : Canary_action.script_spec =
  let pm = Canary_store.detect_pm () in
  let ocaml = zarith_ocaml_config.ocaml in
  {
    Canary_action.empty_script_spec with
    fetch_lib = Some (Canary_action.fetch_lib_cmd pm prebuilt.system_package);
    fetch_binding =
      Some (Canary_action.fetch_binding_cmd prebuilt.opam_package_spec);
    probe_lib =
      Some (fun ~output_dir ->
        let probe = Canary_artifact_native.native_lib_probe_cmd
          ~lib:"$LIB_GMP" ~prefix:"__gmp" ~output_dir in
        [%string "%{lib_gmp_resolve}\n%{probe}"]);
    probe_binding =
      [
        (Canary_store.Lang_pm,
         (fun ~output_dir ->
           Canary_action.probe_ocaml_cmd ~binding_lib:ocaml.binding_lib_name
             ~example:ocaml.example_file ~target:ocaml.example_target
             ~output_dir));
      ];
    summary = (fun rule loc -> match rule, loc with
      | Probe Lib, _ ->
          Some (fun ~output_dir ->
            let sum = Canary_artifact_native.summary_cmd
              ~lib:"$LIB_GMP"
              ~prefixes:[ "__gmpz_"; "__gmpq_"; "__gmpf_"; "__gmp_" ]
              ~watchlist:gmp_native_watchlist
              ~output_dir () in
            [%string "%{lib_gmp_resolve}\n%{sum}"])
      | Probe Binding, _ ->
          Some (fun ~output_dir ->
            Canary_artifact_ocaml.summary_opam_pkg_cmd
              ~pkg:"zarith" ~watchlist:zarith_ocaml_watchlist ~output_dir ())
      | _ -> None);
  }

let action_steps ~root ~project =
  Canary_action.derive_steps ~root ~project script_spec

let run_info steps =
  Canary_action.mk_run_info ~project:"zarith" ~version:"system" ~ref_:""
    ~source:"prebuilt" steps
