open Base
open Tola_std
open Canary_basic_store
open Canary_basic
open Canary_basic_ocaml
open Canary

type z3_instance = { root : string; external_libz3 : string }

let canary =
  Canary_basic.mk_canary_config ~pkg_name:"z3" ~versioned_name:"z3.dev" ()

let mk_instance root = { root; external_libz3 = root $/ ".helper/z3_root" }

let mk_deploy root =
  { contrib_abs = root $/ canary.paths.contrib_rel; gh_abs = root $/ ".github" }

(* ── Version specs ──
   Version is the primary key. Each version identifies both the source
   and which prebuilt libs (if any) exist for it.

   | Version | Source            | PM lib? | build_lib | build_binding |
   |---------|-------------------|---------|-----------|---------------|
   | dev     | arbipher/z3 HEAD  | no      | yes       | yes           |
   | latest  | Z3Prover/z3 HEAD  | no      | yes       | yes           |
   | 4.15.2  | Z3Prover/z3 tag   | yes     | no        | yes           |

   dev must build lib (no PM ships HEAD of a fork).
   latest must build lib (no PM ships official HEAD).
   stable can skip lib build (PM has this version). *)

let z3_source_dev : source_repo =
  {
    name = "z3";
    remote = Git_remote "https://github.com/arbipher/z3.git";
    locals = mk_locals "contrib/z3-all/z3";
    version = "dev";
    ref_ = "HEAD";
    official = false;
    has_build_lib = true;
    has_build_binding = true;
  }

let z3_source_latest : source_repo =
  {
    name = "z3";
    remote = Git_remote "https://github.com/Z3Prover/z3.git";
    locals = [];
    version = "latest";
    ref_ = "HEAD";
    official = true;
    has_build_lib = true;
    has_build_binding = true;
  }

let z3_source_stable : source_repo =
  {
    name = "z3";
    remote = Git_remote "https://github.com/Z3Prover/z3.git";
    locals = mk_locals "contrib/z3-all/z3-stable";
    version = "4.15.2";
    ref_ = "bd3e722";
    official = true;
    has_build_lib = false;
    has_build_binding = true;
  }

let z3_sources = [ z3_source_dev; z3_source_latest; z3_source_stable ]

let root_of_source distro (src : source_repo) =
  match source_root distro src with
  | Some p -> p
  | None ->
      (* No local checkout — use canary local cache *)
      [%string "_out/canary/_local/z3/%{src.version}_%{src.ref_}/src"]

(* z3 capabilities shared across versions *)
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

let missing_symbols =
  [ "Z3_solver_register_on_clause"; "Z3_mk_seq_replace_all" ]

let expected_symbol_failure =
  Expect_failure_contains
    {
      contains_any = [ "undefined symbol"; "Z3_mk_u32string" ];
      expected_returncode = None;
    }

let expected_python_failure =
  Expect_failure_contains
    { contains_any = missing_symbols; expected_returncode = Some 1 }

let z3_ocaml_config : Canary_basic_ocaml.ocaml_tool_config =
  {
    toolchain = Canary_basic_ocaml.default;
    ocaml =
      {
        example_target = "z3_example";
        example_name = "z3_example";
        example_file = "canary/examples/z3/z3_example.ml";
        binding_lib_name = "z3";
        build_api_path = Some "build/src/api/ml";
      };
    prebuilt = None;
  }

let out_h_json ver = [%string "_out/z3_h_%{ver}.json"]

let clang_header_parse header_path json_path =
  [%string
    "clang -fsyntax-only -Xclang -ast-dump=json -Xclang -I%{header_path} \
     %{header_path}/z3.h > %{json_path}"]

let lib_so_path root = [%string "%{root}/build/libz3.so"]

let shared_flags =
  {| -B build -G Ninja \
  -DCMAKE_VERBOSE_MAKEFILE=ON \
  -DZ3_BUILD_LIBZ3_SHARED=ON \
  -DZ3_BUILD_EXECUTABLE=OFF \
  -DZ3_BUILD_TEST_EXECUTABLES=OFF \
  -DZ3_LINK_TIME_OPTIMIZATION=ON \
  -DZ3_BUILD_JAVA_BINDINGS=OFF|}

let cmake_configure =
  [%string
    {|eval $(opam env) && cmake \
  %{shared_flags} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=ON|}]

(* Interactive shell version with trailing \ for pasting more flags *)
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

let build_z3_in_opam =
  let toolchain = z3_ocaml_config.toolchain in
  [%string
    {|cmake \
  %{shared_flags}
  -DZ3_BUILD_LIBZ3_CORE=OFF \
  -DZ3_ROOT=%{toolchain.prefix_var} \
  -DZ3_BUILD_OCAML_BINDINGS=ON \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF|}]

(* opam switch 5.3.0 && eval $(opam env) *)

let binding_build =
  {|eval $(opam env)
ninja -C build build_z3_ocaml_bindings
ninja -C build build_z3_python_bindings|}

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
          expectation = Expect_success;
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
              { kind = Binding; name = "z3"; location = Build_tree };
            ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = OCaml };
          location = Build_tree;
          requires = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          produces = [];
          expectation = Expect_success;
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
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "z3"; location = System_pm } ];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_buildgen
              (run_step ~name:"Configure with CMake"
                 (binding_buildgen_use_external
                    z3_ocaml_config.toolchain.prefix_envar));
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_build
              (run_step ~name:"Build OCaml and Python bindings" binding_build);
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = Python };
          location = Build_tree;
          requires =
            [ { kind = Binding; name = "z3-python"; location = Build_tree } ];
          produces = [];
          expectation = expected_python_failure;
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
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "z3"; location = System_pm } ];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_buildgen
              (run_step ~name:"Configure with CMake (external libz3)"
                 (binding_buildgen_use_external
                    z3_ocaml_config.toolchain.prefix_envar));
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [];
          expectation = Expect_success;
        };
        {
          kind =
            Cmake_build
              (run_step ~name:"Build OCaml and Python bindings" binding_build);
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          expectation = Expect_success;
        };
        {
          kind = Pm_install_local Opam;
          location = Lang_pm;
          requires = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          produces = [ { kind = App; name = "z3"; location = Lang_pm } ];
          expectation = Expect_success;
        };
        {
          kind = Probe_test { lang = OCaml };
          location = Lang_pm;
          requires = [ { kind = App; name = "z3"; location = Lang_pm } ];
          produces = [];
          expectation = expected_symbol_failure;
        };
      ];
    if_disabled = false;
  }

(* ── Action steps (derived from script_spec) ── *)

(* Resolve the native lib path based on whether we built it or fetched it.
   build tree: {root}/build/libz3.so  (or .dylib)
   system PM:  discovered at runtime via pkg-config *)
let lib_cmd_of_source ~has_build_lib ~root =
  if has_build_lib then
    (* Static path — known at spec generation time *)
    [%string {|LIB_Z3=$(ls %{root}/build/libz3.so %{root}/build/libz3.dylib 2>/dev/null | head -1)
test -n "$LIB_Z3"|}]
  else
    (* Dynamic discovery — resolved at probe runtime *)
    {|LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.so
test -f "$LIB_Z3" || LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.dylib
test -f "$LIB_Z3"|}

(* Resolve the binding archive paths based on whether we built it.
   build tree: {root}/build/src/api/ml/
   opam-installed: $(ocamlfind query z3)/ *)
let binding_dir_cmd_of_source ~has_build_binding ~root =
  if has_build_binding then
    [%string {|BINDING_DIR="%{root}/build/src/api/ml"
test -d "$BINDING_DIR"|}]
  else
    {|eval $(opam env)
BINDING_DIR=$(ocamlfind query z3 2>/dev/null)
test -d "$BINDING_DIR"|}

let mk_script_spec ~source distro : Canary_action.script_spec =
  let root = root_of_source distro source in
  let pm = Canary_basic_store.detect_pm () in
  let example =
    Unix.getcwd () ^ "/" ^ z3_ocaml_config.ocaml.example_file
  in
  let target = z3_ocaml_config.ocaml.example_target in
  let binding_lib = z3_ocaml_config.ocaml.binding_lib_name in
  let api_path = Option.value_exn z3_ocaml_config.ocaml.build_api_path in
  let lib_resolve = lib_cmd_of_source ~has_build_lib:source.has_build_lib ~root in
  let binding_resolve =
    binding_dir_cmd_of_source ~has_build_binding:source.has_build_binding ~root
  in
  {
    Canary_action.empty_script_spec with
    fetch_source =
      Some
        (fun ~output_dir ->
          Canary_basic_store.source_fetch_cmd distro source ~output_dir);
    configure =
      (if source.has_build_lib || source.has_build_binding then
         Some
           (fun ~output_dir ->
             [%string
               "cd %{root} && %{cmake_configure} \
                && echo 'ok' > %{output_dir}/conf.ok"])
       else None);
    build_lib =
      (if source.has_build_lib then
         Some
           (fun ~output_dir ->
             [%string
               "cd %{root} && ninja -C build libz3 \
                && echo 'ok' > %{output_dir}/build.ok"])
       else None);
    build_binding =
      (if source.has_build_binding then
         Some
           (fun ~output_dir ->
             [%string
               "cd %{root} && eval $(opam env) && ninja -C build \
                build_z3_ocaml_bindings && echo 'ok' > %{output_dir}/build.ok"])
       else None);
    fetch_lib =
      Some
        (fun ~output_dir ->
          let install = Canary_basic_store.pm_install_cmd pm ~pkg:"z3" in
          [%string "%{install} && echo 'installed' > %{output_dir}/lib.ok"]);
    pack_binding =
      (if source.has_build_binding then
         Some
           (fun ~output_dir ->
             let tola_root = Unix.getcwd () in
             let repo_abs = tola_root ^ "/canary/templates/opam-local-repo" in
             let repo_rel = "canary/templates/opam-local-repo" in
             let pkg_full =
               Canary_basic_ocaml.pkg_full z3_ocaml_config.toolchain
             in
             let pkg_name = z3_ocaml_config.toolchain.package_name in
             let opam_rel =
               [%string "%{repo_rel}/packages/%{pkg_name}/%{pkg_full}/opam"]
             in
             let repo_name = z3_ocaml_config.toolchain.local_repo_name in
             let src_var = z3_ocaml_config.toolchain.canary_src_var in
             let prefix_name = z3_ocaml_config.toolchain.prefix_name in
             let libdir_name = z3_ocaml_config.toolchain.libdir_name in
             [%string
               "eval $(opam env) && OPAMVAR_%{src_var}=\"git+file://%{root}\" \
                opam config subst %{opam_rel} && opam repo add %{repo_name} \
                \"file://%{repo_abs}\" --rank=1 || opam repo set-url %{repo_name} \
                \"file://%{repo_abs}\" && opam update %{repo_name} && opam remove \
                -y %{pkg_full} || true && \
                OPAMVAR_%{prefix_name}=\"%{root}/build\" \
                OPAMVAR_%{libdir_name}=\"%{root}/build\" \
                CANARY_BUILD_DIR=\"%{root}/build\" opam install -y %{pkg_full} \
                --verbose --keep-build-dir --assume-depexts && echo 'ok' > \
                %{output_dir}/pack.ok"])
       else None);
    probe_lib =
      Some
        (fun ~output_dir ->
          let probe = Canary_artifact_check.native_lib_probe_cmd
              ~lib:"$LIB_Z3" ~prefix:"Z3_" ~output_dir in
          [%string "%{lib_resolve}\n%{probe}"]);
    probe_binding =
      Some
        (fun ~output_dir ->
          let script = "canary/scripts/assert_binary_symbols.py" in
          (* Resolve lib and binding dir, then symbol check + compile probes.
             All paths come from $LIB_Z3 and $BINDING_DIR — not hardcoded. *)
          [%string
            {|%{lib_resolve}
%{binding_resolve}
STUB=$(ls "$BINDING_DIR"/libz3ml.a 2>/dev/null | head -1)
test -n "$STUB"
python3 %{script} --provided-lib "$LIB_Z3" --required-lib "$STUB" \
  --symbol-prefix Z3_ 2>&1 | tee %{output_dir}/symbols.log
grep -q 'OK:' %{output_dir}/symbols.log
cd %{root} && eval $(opam env)
ocamlfind ocamlopt -package zarith -linkpkg \
  -I %{api_path} %{api_path}/z3ml.cmxa %{example} \
  -o %{output_dir}/%{target}_build
%{output_dir}/%{target}_build 2>&1 | tee %{output_dir}/probe_build.log
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} \
  -o %{output_dir}/%{target}_pkg
%{output_dir}/%{target}_pkg 2>&1 | tee %{output_dir}/probe_pkg.log|}]);
    check_post =
      (function
      | Fetch Source -> Some Canary_basic_store.source_check_post
      | Build_lib ->
          Some (Canary_artifact_check.check_build_lib
                  ~marker:"build.ok" ~lib_path:(lib_so_path root))
      | Build_binding ->
          Some (Canary_artifact_check.check_build_binding
                  ~marker:"build.ok"
                  ~archive_path:[%string "%{root}/build/src/api/ml/z3ml.cmxa"])
      | Probe Binding ->
          Some (Canary_artifact_check.check_markers
                  [ "symbols.log"; "probe_build.log"; "probe_pkg.log" ])
      | _ -> None);
  }

(* Full spec: all actions including build-from-source *)
let action_steps ?(quick = false) ?(source = z3_source_dev) ~root ~project
    distro =
  let spec = mk_script_spec ~source distro in
  let spec = if quick then Canary_action.no_source spec else spec in
  Canary_action.derive_steps ~root ~project spec

let run_info ?(source = z3_source_dev) distro steps =
  let source_str =
    match Canary_basic_store.source_root distro source with
    | Some p -> "local:" ^ p
    | None ->
        let (Canary_basic_store.Git_remote url) = source.remote in
        "git:" ^ url
  in
  Canary_action.mk_run_info ~project:"z3" ~version:source.version
    ~ref_:source.ref_ ~source:source_str
    ~extra:
      [
        ("official", if source.official then "true" else "false");
        ( "remote",
          let (Canary_basic_store.Git_remote url) = source.remote in
          url );
      ]
    steps

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
