open Base
open Tola_std
open Canary_store
open Canary_basic
open Canary_ocaml
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
    build_sys_deps = [ "cmake"; "ninja-build"; "libgmp-dev"; "python3-dev" ];
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
    build_sys_deps = [ "cmake"; "ninja-build"; "libgmp-dev"; "python3-dev" ];
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
    (* No build — use fetch_binding (opam install z3) for the stable path.
       probe_binding_pkg will compile the example against the installed binding. *)
    has_build_binding = false;
    build_sys_deps = [];
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


let z3_ocaml_config : Canary_ocaml.ocaml_tool_config =
  {
    toolchain = Canary_ocaml.default;
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

        };
        {
          kind = Probe_test { lang = OCaml };
          location = Build_tree;
          requires = [ { kind = Binding; name = "z3"; location = Build_tree } ];
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
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "z3"; location = System_pm } ];

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

        };
        {
          kind =
            Cmake_build
              (run_step ~name:"Build OCaml and Python bindings" binding_build);
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [ { kind = Binding; name = "z3"; location = Build_tree } ];

        };
        {
          kind = Probe_test { lang = Python };
          location = Build_tree;
          requires =
            [ { kind = Binding; name = "z3-python"; location = Build_tree } ];
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
          location = System_pm;
          requires = [];
          produces = [ { kind = Lib; name = "z3"; location = System_pm } ];

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

        };
        {
          kind =
            Cmake_build
              (run_step ~name:"Build OCaml and Python bindings" binding_build);
          location = Build_tree;
          requires = [ { kind = Lib; name = "z3"; location = System_pm } ];
          produces = [ { kind = Binding; name = "z3"; location = Build_tree } ];

        };
        {
          kind = Pm_install_local Opam;
          location = Lang_pm;
          requires = [ { kind = Binding; name = "z3"; location = Build_tree } ];
          produces = [ { kind = App; name = "z3"; location = Lang_pm } ];

        };
        {
          kind = Probe_test { lang = OCaml };
          location = Lang_pm;
          requires = [ { kind = App; name = "z3"; location = Lang_pm } ];
          produces = [];
        };
      ];
    if_disabled = false;
  }

(* ── Action steps (derived from script_spec) ── *)

(* Resolve the native lib path based on whether we built it or fetched it.
   build tree: {build}/libz3.so  (or .dylib)
   system PM:  discovered at runtime via pkg-config *)
let lib_cmd_of_source ~has_build_lib ~build =
  if has_build_lib then
    (* Static path — known at spec generation time *)
    [%string {|LIB_Z3=$(ls %{build}/libz3.so %{build}/libz3.dylib 2>/dev/null | head -1)
test -n "$LIB_Z3"|}]
  else
    (* Dynamic discovery — resolved at probe runtime *)
    {|LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.so
test -f "$LIB_Z3" || LIB_Z3=$(pkg-config --variable=libdir z3 2>/dev/null)/libz3.dylib
test -f "$LIB_Z3"|}

(* Resolve the binding archive paths based on whether we built it.
   build tree: {build}/src/api/ml/
   opam-installed: $(ocamlfind query z3)/ *)
let binding_dir_cmd_of_source ~has_build_binding ~build =
  if has_build_binding then
    [%string {|BINDING_DIR="%{build}/src/api/ml"
test -d "$BINDING_DIR"|}]
  else
    {|eval $(opam env)
BINDING_DIR=$(ocamlfind query z3 2>/dev/null)
test -d "$BINDING_DIR"|}

let mk_script_spec ~source ?(tola_root = Unix.getcwd ())
    ?(cmake_build_binding = source.has_build_binding) distro
    : Canary_action.script_spec =
  let local = local_for distro source in
  let root =
    match local with
    | Some l -> l.path
    | None -> [%string "_out/canary/_local/z3/%{source.version}_%{source.ref_}/src"]
  in
  let build =
    match local with
    | Some l -> l.build_path
    | None -> [%string "_out/canary/_local/z3/%{source.version}_%{source.ref_}/build"]
  in
  (* When no local checkout, opam fetches from the remote git URL directly.
     When a local checkout exists, opam installs from the local file:// path. *)
  let pack_src_url =
    match local with
    | Some l -> [%string "git+file://%{l.path}"]
    | None ->
        let (Git_remote url) = source.remote in
        [%string "git+%{url}"]
  in
  let pm = Canary_store.detect_pm () in
  let example = tola_root ^ "/" ^ z3_ocaml_config.ocaml.example_file in
  let target = z3_ocaml_config.ocaml.example_target in
  let binding_lib = z3_ocaml_config.ocaml.binding_lib_name in
  let lib_resolve = lib_cmd_of_source ~has_build_lib:source.has_build_lib ~build in
  let binding_resolve =
    binding_dir_cmd_of_source ~has_build_binding:source.has_build_binding ~build
  in
  {
    Canary_action.empty_script_spec with
    (* Skip fetch_source when opam will handle source fetching (pack_binding remote flow) *)
    fetch_source =
      (if source.has_build_lib || cmake_build_binding then
         Some
           (fun ~output_dir ->
             Canary_store.source_fetch_cmd distro source ~output_dir)
       else None);
    configure =
      (if source.has_build_lib || cmake_build_binding then
         let cmake_cmd = if cmake_build_binding then "opam exec -- cmake" else "cmake" in
         let ocaml_flag = if cmake_build_binding then "ON" else "OFF" in
         Some
           (fun ~output_dir ->
             [%string
               "%{cmake_cmd} -S %{root} -B %{build} -G Ninja \
                -DCMAKE_VERBOSE_MAKEFILE=ON \
                -DZ3_BUILD_LIBZ3_SHARED=ON \
                -DZ3_BUILD_EXECUTABLE=OFF \
                -DZ3_BUILD_TEST_EXECUTABLES=OFF \
                -DZ3_LINK_TIME_OPTIMIZATION=ON \
                -DZ3_BUILD_JAVA_BINDINGS=OFF \
                -DZ3_BUILD_OCAML_BINDINGS=%{ocaml_flag} \
                -DZ3_BUILD_PYTHON_BINDINGS=ON \
                && echo 'ok' > %{output_dir}/conf.ok"])
       else None);
    build_lib =
      (if source.has_build_lib then
         Some
           (fun ~output_dir ->
             [%string
               "ninja -C %{build} libz3 \
                && echo 'ok' > %{output_dir}/build.ok"])
       else None);
    build_binding =
      (if cmake_build_binding then
         Some
           (fun ~output_dir ->
             [%string
               "eval $(opam env) && ninja -C %{build} \
                build_z3_ocaml_bindings && echo 'ok' > %{output_dir}/build.ok"])
       else None);
    fetch_lib =
      Some
        (fun ~output_dir ->
          let install = Canary_store.pm_install_cmd pm ~pkg:"z3" in
          [%string "%{install} && echo 'installed' > %{output_dir}/lib.ok"]);
    fetch_binding =
      (if not source.has_build_binding then
         Some
           (fun ~output_dir ->
             [%string
               "eval $(opam env) && opam install z3.%{source.version} -y \
                --assume-depexts \
                && echo 'installed' > %{output_dir}/binding.ok"])
       else None);
    pack_binding =
      (if source.has_build_binding then
         Some
           (fun ~output_dir ->
             let src_template =
               [%string
                 "%{tola_root}/canary/templates/opam-local-repo/packages/%{z3_ocaml_config.toolchain.package_name}/%{Canary_ocaml.pkg_full z3_ocaml_config.toolchain}/opam.in"]
             in
             let pkg_full = Canary_ocaml.pkg_full z3_ocaml_config.toolchain in
             let pkg_dir =
               [%string "%{output_dir}/pack-repo/packages/%{z3_ocaml_config.toolchain.package_name}/%{pkg_full}"]
             in
             let pack_repo = [%string "%{output_dir}/pack-repo"] in
             let repo_name = [%string "%{z3_ocaml_config.toolchain.local_repo_name}-pack"] in
             let src_var = z3_ocaml_config.toolchain.canary_src_var in
             let prefix_name = z3_ocaml_config.toolchain.prefix_name in
             let libdir_name = z3_ocaml_config.toolchain.libdir_name in
             (* When opam fetches from a remote URL, the source is in the opam
                build dir (S=. by default). Don't pass CANARY_SRC/BUILD_DIR or
                opam will try to use a relative path that doesn't exist there. *)
             let install_env = match local with
               | Some _ ->
                   [%string
                     "OPAMVAR_%{prefix_name}=\"%{build}\" \
                      OPAMVAR_%{libdir_name}=\"%{build}\" \
                      CANARY_BUILD_DIR=\"%{build}\" CANARY_SRC_DIR=\"%{root}\" "]
               | None -> ""
             in
             [%string
               {|eval $(opam env)
mkdir -p "%{pkg_dir}"
cp "%{src_template}" "%{pkg_dir}/opam.in"
(cd "%{pack_repo}" && OPAMVAR_%{src_var}="%{pack_src_url}" opam config subst "packages/%{z3_ocaml_config.toolchain.package_name}/%{pkg_full}/opam")
opam repo add %{repo_name} "file://%{pack_repo}" --rank=1 \
  || opam repo set-url %{repo_name} "file://%{pack_repo}"
opam update %{repo_name}
opam remove -y %{pkg_full} || true
%{install_env}opam install -y %{pkg_full} --verbose --keep-build-dir --assume-depexts \
  && echo 'ok' > %{output_dir}/pack.ok|}])
       else None);
    probe_lib =
      Some
        (fun ~output_dir ->
          let probe = Canary_artifact_check.native_lib_probe_cmd
              ~lib:"$LIB_Z3" ~prefix:"Z3_" ~output_dir in
          [%string "%{lib_resolve}\n%{probe}"]);
    probe_binding =
      List.filter_opt [
        (* Build_tree: probe against build tree artifacts (only when cmake built them) *)
        (if source.has_build_binding && cmake_build_binding then
           Some (Build_tree, (fun ~output_dir ->
             let script = "canary/scripts/assert_binary_symbols.py" in
             [%string
               {|%{lib_resolve}
%{binding_resolve}
STUB=$(ls "$BINDING_DIR"/libz3ml.a 2>/dev/null | head -1)
test -n "$STUB"
python3 %{script} --provided-lib "$LIB_Z3" --required-lib "$STUB" \
  --symbol-prefix Z3_ 2>&1 | tee %{output_dir}/symbols.log
grep -q 'OK:' %{output_dir}/symbols.log
eval $(opam env)
ocamlfind ocamlopt -package zarith -linkpkg \
  -I "$BINDING_DIR" "$BINDING_DIR"/z3ml.cmxa %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/probe.log 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/probe.log 2>&1|}]))
         else None);
        (* Lang_pm: probe against opam-installed package *)
        Some (Lang_pm, (fun ~output_dir ->
          [%string
            {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} \
  -o %{output_dir}/%{target} > %{output_dir}/probe.log 2>&1 || exit 1
%{output_dir}/%{target} >> %{output_dir}/probe.log 2>&1|}]));
      ];
    check_post =
      (function
      | Fetch Source -> Some Canary_store.source_check_post
      | Configure ->
          Some (fun ~output_dir ->
            Canary_artifact_check.check_markers [ "configure.ok" ] ~output_dir
            || Stdlib.Sys.file_exists [%string "%{build}/CMakeCache.txt"])
      | Build_lib ->
          Some (Canary_artifact_check.check_build_lib
                  ~marker:"build.ok" ~lib_path:[%string "%{build}/libz3.so"])
      | Build_binding ->
          Some (Canary_artifact_check.check_build_binding
                  ~marker:"build.ok"
                  ~archive_path:[%string "%{build}/src/api/ml/z3ml.cmxa"])
      | Fetch Binding when not source.has_build_binding ->
          let pkg = [%string "z3.%{source.version}"] in
          Some (fun ~output_dir ->
            Canary_artifact_check.check_markers [ "binding.ok" ] ~output_dir
            || Canary_pm_opam.is_installed ~pkg)
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
    match Canary_store.source_root distro source with
    | Some p -> "local:" ^ p
    | None ->
        let (Canary_store.Git_remote url) = source.remote in
        "git:" ^ url
  in
  Canary_action.mk_run_info ~project:"z3" ~version:source.version
    ~ref_:source.ref_ ~source:source_str
    ~extra:
      [
        ("official", if source.official then "true" else "false");
        ( "remote",
          let (Canary_store.Git_remote url) = source.remote in
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
