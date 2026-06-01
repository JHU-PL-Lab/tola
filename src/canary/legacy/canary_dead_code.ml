(* Dead code parking lot — all callers removed.
   See CLAUDE.md §"Retire legacy config distro / project_config / job_spec plumbing".
   Delete this file when cleanup lands. *)

(* ── Z3 dead code ── *)
module Z3 = struct
  [@@@warning "-32"]
  open Tola_std
  open Canary_store
  open Canary_artifact_source
  open Canary_artifact_api
  open Canary_basic
  open Canary_yaml_backend
  open Canary_toolchain
  open Canary_project_z3

  (* ── example_sp.ml only — pre-canary inspection utilities ──
     Superseded by mk_script_spec + derive_steps for the canary pipeline.
     clang_header_parse preserved as reference for future source-artifact summary
     (clang AST-dump enables symbol-level header diff, unlike test-f scan). *)

  type z3_instance = { root : string; external_libz3 : string }

  let mk_instance root = { root; external_libz3 = root $/ ".helper/z3_root" }

  let root_of_source distro (src : source_repo) =
    match source_root distro src with
    | Some p -> p
    | None ->
        [%string "_out/canary/projects/z3/%{src.version}_%{src.ref_}/src"]

  let z3_project_spec distro (src : source_repo) : project_spec =
    {
      root = root_of_source distro src;
      version = src.version;
      commit = src.ref_;
      bindings = [ (OCaml, Opam); (Python, Unsupported) ];
      system_pm = Brew;
      has_source = true;
      has_system_pkg = true;
      has_lang_pkg = true;
      can_package = true;
    }

  let out_h_json ver = [%string "_out/z3_h_%{ver}.json"]

  let clang_header_parse header_path json_path =
    [%string
      "clang -fsyntax-only -Xclang -ast-dump=json -Xclang -I%{header_path} \
       %{header_path}/z3.h > %{json_path}"]

  let lib_so_path root = [%string "%{root}/build/libz3.so"]

  (* Superseded by z3_cmake_build_flags + mk_script_spec configure step
     (dynamic -S/-B paths; explicit -DZ3_BUILD_PYTHON_BINDINGS=OFF). *)
  let shared_flags =
    {| -B build -G Ninja \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DZ3_BUILD_LIBZ3_SHARED=ON \
  -DZ3_BUILD_EXECUTABLE=OFF \
  -DZ3_BUILD_TEST_EXECUTABLES=OFF \
  -DZ3_LINK_TIME_OPTIMIZATION=ON \
  -DZ3_BUILD_JAVA_BINDINGS=OFF|}

  let binding_buildgen =
    [%string
      {|eval $(opam env)
cmake \
  %{shared_flags} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=ON \|}]

  let binding_buildgen_use_external libz3_path =
    [%string
      {|eval $(opam env)
cmake \
  %{shared_flags}
	-DZ3_BUILD_LIBZ3_CORE=OFF \
  -DZ3_ROOT=%{libz3_path} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=ON|}]

  let binding_build =
    {|eval $(opam env)
ninja -C build build_z3_ocaml_bindings
ninja -C build build_z3_python_bindings|}

  (* ── end example_sp.ml only ── *)

  let canary =
    Canary_yaml_backend.mk_canary_config ~pkg_name:"z3" ~versioned_name:"z3.dev" ()

  let mk_deploy root =
    { contrib_abs = root $/ canary.paths.contrib_rel; gh_abs = root $/ ".github" }

  let z3_sources = [ z3_source_dev; z3_source_latest; z3_source_stable ]

  let cmake_configure =
    [%string
      {|eval $(opam env) && cmake \
  %{shared_flags} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=ON|}]

  let build_z3_in_opam =
    let toolchain = z3_ocaml_config.toolchain in
    [%string
      {|cmake \
  %{shared_flags}
  -DZ3_BUILD_LIBZ3_CORE=OFF \
  -DZ3_ROOT=%{toolchain.prefix_var} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF|}]

  let cc_env_fields =
    [
      ( "CC",
        "${{ matrix.os == 'macos-latest' && 'ccache clang' || 'ccache gcc' }}" );
      ( "CXX",
        "${{ matrix.os == 'macos-latest' && 'ccache clang++' || 'ccache g++' }}"
      );
    ]

  let source_source_spec distro : job_spec =
    {
      distro;
      id = "source-source";
      description =
        "Build libz3 from source, build binding from source tree, probe";
      phases =
        [
          {
            kind =
              Cmake_buildgen
                (run_step ~env_fields:cc_env_fields ~name:"Configure with CMake"
                   binding_buildgen);
            location = Build_tree;
            requires = [];
            produces = [];
          };
          {
            kind =
              Cmake_build
                (run_step ~name:"Build Z3 and OCaml binding" binding_build);
            location = Build_tree;
            requires = [];
            produces =
              [
                { kind = Lib; name = "z3"; location = Build_tree };
                { kind = Binding OCaml; name = "z3"; location = Build_tree };
              ];
          };
          {
            kind = Probe_test { lang = OCaml };
            location = Build_tree;
            requires = [ { kind = Binding OCaml; name = "z3"; location = Build_tree } ];
            produces = [];
          };
        ];
      if_disabled = true;
    }

  let prebuilt_source_spec distro : job_spec =
    {
      distro;
      id = "prebuilt-source";
      description =
        "Install libz3 from system PM, build binding from source tree, probe";
      phases =
        [
          {
            kind = Pm_install (Some { linux_pkg = "z3"; macos_pkg = "z3" });
            location = Build_tree;
            requires = [];
            produces = [ { kind = Lib; name = "z3"; location = Build_tree } ];
          };
          {
            kind =
              Cmake_buildgen
                (run_step ~name:"Configure with CMake"
                   (binding_buildgen_use_external
                      z3_ocaml_config.toolchain.prefix_envar));
            location = Build_tree;
            requires = [ { kind = Lib; name = "z3"; location = Build_tree } ];
            produces = [];
          };
          {
            kind =
              Cmake_build
                (run_step ~name:"Build OCaml and Python bindings" binding_build);
            location = Build_tree;
            requires = [ { kind = Lib; name = "z3"; location = Build_tree } ];
            produces = [ { kind = Binding OCaml; name = "z3"; location = Build_tree } ];
          };
          {
            kind = Probe_test { lang = Python };
            location = Build_tree;
            requires =
              [ { kind = Binding OCaml; name = "z3-python"; location = Build_tree } ];
            produces = [];
          };
        ];
      if_disabled = false;
    }

  let prebuilt_packaged_spec distro : job_spec =
    {
      distro;
      id = "prebuilt-packaged";
      description =
        "Install libz3 from system PM, build binding, package into local opam, \
         probe";
      phases =
        [
          {
            kind = Pm_install (Some { linux_pkg = "z3"; macos_pkg = "z3" });
            location = Build_tree;
            requires = [];
            produces = [ { kind = Lib; name = "z3"; location = Build_tree } ];
          };
          {
            kind =
              Cmake_buildgen
                (run_step ~name:"Configure with CMake (external libz3)"
                   (binding_buildgen_use_external
                      z3_ocaml_config.toolchain.prefix_envar));
            location = Build_tree;
            requires = [ { kind = Lib; name = "z3"; location = Build_tree } ];
            produces = [];
          };
          {
            kind =
              Cmake_build
                (run_step ~name:"Build OCaml and Python bindings" binding_build);
            location = Build_tree;
            requires = [ { kind = Lib; name = "z3"; location = Build_tree } ];
            produces = [ { kind = Binding OCaml; name = "z3"; location = Build_tree } ];
          };
          {
            kind = Pm_install_local Opam;
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = Binding OCaml; name = "z3"; location = Build_tree } ];
            produces = [ { kind = App; name = "z3"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
          };
          {
            kind = Probe_test { lang = OCaml };
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = App; name = "z3"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
            produces = [];
          };
        ];
      if_disabled = false;
    }

  let config distro =
    let z3_dev = z3_project_spec distro z3_source_dev in
    {
      canary;
      workflow_name = "Canary Testing for Bindings and Packages";
      name = "z3";
      project = z3_dev;
      ocaml = z3_ocaml_config;
      job_specs =
        [
          source_source_spec distro;
          prebuilt_source_spec distro;
          prebuilt_packaged_spec distro;
        ];
      deploy = Some (mk_deploy z3_dev.root);
      opam_template_bindings = [ ("%{BUILD_Z3_IN_OPAM}%", build_z3_in_opam) ];
    }
end

(* ── LLVM dead code ── *)
module Llvm = struct
  [@@@warning "-32"]
  open Canary_basic
  open Canary_yaml_backend
  open Canary_artifact_api
  open Canary_store
  open Canary_toolchain
  open Canary_project_llvm

  let prebuilt_prebuilt_spec distro : job_spec =
    {
      distro;
      id = "prebuilt-prebuilt";
      description =
        "Install system LLVM, install opam llvm binding and llvmlite, probe";
      phases =
        [
          {
            kind =
              Pm_install
                (Some
                   {
                     linux_pkg =
                       (prebuilt_info_exn llvm_ocaml_config).system_package_linux;
                     macos_pkg =
                       (prebuilt_info_exn llvm_ocaml_config).system_package_macos;
                   });
            location = Build_tree;
            requires = [];
            produces = [ { kind = Lib; name = "llvm"; location = Build_tree } ];
          };
          {
            kind = Pm_install None;
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = Lib; name = "llvm"; location = Build_tree } ];
            produces = [ { kind = Binding OCaml; name = "llvm"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
          };
          {
            kind =
              Run_command
                {
                  name = "Install llvmlite";
                  command = "python3 -m pip install llvmlite";
                };
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = Lib; name = "llvm"; location = Build_tree } ];
            produces = [ { kind = App; name = "llvmlite"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
          };
          {
            kind = Probe_test { lang = OCaml };
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = Binding OCaml; name = "llvm"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
            produces = [];
          };
          {
            kind = Probe_test { lang = Python };
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = App; name = "llvmlite"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
            produces = [];
          };
        ];
      if_disabled = false;
    }

  let config distro =
    {
      canary = Canary_yaml_backend.mk_canary_config ();
      workflow_name = "Canary Testing for LLVM OCaml and Python";
      name = "llvm";
      project =
        {
          root = "";
          version = "system";
          commit = "";
          bindings = [ (OCaml, Opam); (Python, Unsupported) ];
          system_pm = Brew;
          has_source = false;
          has_system_pkg = true;
          has_lang_pkg = true;
          can_package = false;
        };
      ocaml = llvm_ocaml_config;
      job_specs = [ prebuilt_prebuilt_spec distro ];
      deploy = None;
      opam_template_bindings = [];
    }
end

(* ── SQLite dead code ── *)
module Sqlite = struct
  [@@@warning "-32"]
  open Canary_basic
  open Canary_yaml_backend
  open Canary_artifact_api
  open Canary_toolchain
  open Canary_project_sqlite

  let prebuilt_prebuilt_spec distro : job_spec =
    {
      distro;
      id = "prebuilt-prebuilt";
      description = "Install system sqlite, install opam sqlite3 binding, probe";
      phases =
        [
          {
            kind =
              Pm_install
                (Some
                   {
                     linux_pkg =
                       (prebuilt_info_exn sqlite_ocaml_config)
                         .system_package_linux;
                     macos_pkg =
                       (prebuilt_info_exn sqlite_ocaml_config)
                         .system_package_macos;
                   });
            location = Build_tree;
            requires = [];
            produces = [ { kind = Lib; name = "sqlite3"; location = Build_tree } ];
          };
          {
            kind = Pm_install None;
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = Lib; name = "sqlite3"; location = Build_tree } ];
            produces = [ { kind = App; name = "sqlite3"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
          };
          {
            kind = Probe_test { lang = OCaml };
            location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam });
            requires = [ { kind = App; name = "sqlite3"; location = Pm (Lang_pm { lang = Canary_lang.OCaml; pm = Opam }) } ];
            produces = [];
          };
        ];
      if_disabled = false;
    }

  let config distro =
    {
      canary = Canary_yaml_backend.mk_canary_config ();
      workflow_name = "Canary Testing for SQLite3 OCaml";
      name = "sqlite";
      project =
        {
          root = "";
          version = "system";
          commit = "";
          bindings = [ (OCaml, Opam) ];
          system_pm = Brew;
          has_source = false;
          has_system_pkg = true;
          has_lang_pkg = true;
          can_package = false;
        };
      ocaml = sqlite_ocaml_config;
      job_specs = [ prebuilt_prebuilt_spec distro ];
      deploy = None;
      opam_template_bindings = [];
    }
end
