(** Action-variant templates (A9-step-2, typed 2026-08-14 — M1 "typed
    template dispatch"). Each project declares a flat list of [action_row]s;
    [realize_from_rows] turns the matching subset into a [runner_spec] by
    dispatching each typed template to its tool/ builder and passing [Raw]
    closures through unchanged.

    The template hub is the abstraction center: project rows name WHAT
    each action does via a typed constructor; the tool/ layer owns HOW
    the shell is built. No string-keyed primitive dispatch — a bad
    param name or primitive name is a compile error. *)

open Base
open Canary_basic
open Canary_store
open Canary_lang
open Canary_step_builder

(* ── row types ── *)

(** Where a native lib probe resolves its library. Typed per location —
    the old ["build_tree"|"staged"|"pm"] string dispatch. *)
type probe_lib_location =
  | Build_tree_lib of { lib : string }
      (** direct path to the built lib *)
  | Build_tree_glob of { lib_glob : string; build : string }
      (** glob form: resolve with [ls <build>/<lib_glob> | head -1] *)
  | Staged_lib of { lib : string }
  | Pm_lib of {
      pm_pkg        : string;    (** pkg-config package name *)
      lib_name      : string;    (** lib basename, e.g. "libsqlite3.so" *)
      dpkg_pkg      : string option;   (** dpkg -L fallback package *)
      ldconfig_name : string option;   (** ldconfig -p fallback name *)
      brew_pkg      : string option;   (** brew --prefix fallback package *)
    }

type action_template =
  | Fetch_lib of { linux_pkg : string; macos_pkg : string }
  | Fetch_binding_opam of { pkg : string }
  | Pip_install of { pkg : string }
  | Ocaml_probe of { binding_lib : string; example : string; target : string }
  | Python_probe of { snippet : string }
  | Curl_unzip of { url : string; dest : string }
  | Cc_shared_lib of { c_src : string; out : string; ldlibs : string list }
  | Inspect_opam of { pkg : string }
  | Inspect_python of { pkg : string }
  | Inspect_native_build of { lib : string; prefixes : string list }
  | Source_fetch of {
      name   : string;
      ver_str : string;
      ref_   : string;
      url    : string;
      local  : string option;
          (** a declared local checkout — when present AND existing, fetch
              is a free [test -d] instead of a full clone (the old
              [source_fetch_cmd] behavior, restored 2026-08-14) *)
    }
  | Scan_source of { root : string; hdr_file : string }
  | Build_headers of { root : string; hdr_dir : string }
  | Cmake_configure of {
      cmake_exec : string;
      flags      : string list;
      src        : string;
      build      : string;
    }
  | Ninja_build of { target : string; build : string }
  | Ninja_build_binding of {
      target    : string;
      build     : string;
      env_guard : string option;
          (** optional env guard between `eval $(opam env)` and ninja *)
    }
  | Cmake_install of {
      build : string;
      prefix : string;
      assert_staged : string list option;
          (** prefix-relative paths that must exist after [cmake
              --install] — the bugfix-commit regression primitive
              (2026-08-17, z3 #10549: the OCaml package was never
              staged). The cmd fails with "OCAML INSTALL MISSING: <path>"
              per absent path — the signature a declared expectation
              greps. [None] = install completeness unchecked. *)
    }
  | Native_lib_probe of { location : probe_lib_location; prefix : string }
  | Cmake_install_component of { build : string; prefix : string; component : string }
  | Raw of (output_dir:string -> variant_key:string -> string)
      (** Escape hatch for project-specific shell. *)

type action_row = {
  ar_action : Canary_basic.action;
  ar_template : action_template;
}

(** Does [action] require the target artifact to have provision [pv]?
    [Build_*] actions need [Built]; [Fetch *] actions need [Fetched];
    [Configure]/[Scan_sources]/[Build_headers] are build-chain steps and
    also need [Built] (2026-08-12 — before, an all-Fetched chain inherited
    them, scanning/building against a source it never fetches);
    everything else ([Probe_*], etc.) fires regardless. *)
let action_requires_provision (action : Canary_basic.action) :
    Canary_store.provision option =
  match action with
  | Configure | Scan_sources | Build_lib | Build_headers ->
      Some Canary_store.Built
  | Build_binding _ -> Some Canary_store.Built
  | Fetch _ -> Some Canary_store.Fetched
  | Install_lib -> Some Canary_store.Built
  | Publish _ -> Some Canary_store.Built
  | _ -> None

(* ── template realization ── *)

(** The [Canary_store.location] a probe_lib_location realizes as. *)
let location_of_probe_location (loc : probe_lib_location) : Canary_store.location =
  match loc with
  | Build_tree_lib _ | Build_tree_glob _ -> Build_tree
  | Staged_lib _ -> Staged
  | Pm_lib _ -> Pm (Sys_pm { pm = Canary_store.detect_pm () })

(** Realize a typed template into the [runner_spec] slot it fills.
    Each constructor dispatches to its tool/ builder — the hub calls
    tool facts, never re-implements their shell. [Raw] is not realized
    here — [realize_from_rows] routes it by action. *)
let realize_template (tpl : action_template) : runner_spec =
  let spec = empty_runner_spec in
  match tpl with
  | Fetch_lib { linux_pkg; macos_pkg } ->
      let system_pkg =
        Canary_store.mk_system_package_spec ~linux_pkg ~macos_pkg ()
      in
      { spec with fetch_lib = Some (Derived Fetch_lib);
                 stores = { spec.stores with
                            lib = Some { provider = Sys_pkg system_pkg;
                                         components = []; headers = None } } }
  | Fetch_binding_opam { pkg } ->
      let opam_spec =
        Canary_toolchain.mk_opam_package_spec ~install_name:pkg ()
      in
      { spec with fetch_binding = [ (OCaml, Raw (fetch_binding_cmd opam_spec)) ] }
  | Pip_install { pkg } ->
      let py_binding : Canary_toolchain.python_binding =
        { pip_package = (if String.equal pkg "stdlib" then None else Some pkg);
          probe_snippet = "" }
      in
      { spec with fetch_binding =
                   [ (Python, Raw (fun ~output_dir ~variant_key ->
                        Canary_toolchain.pip_install_cmd py_binding ~output_dir ~variant_key)) ] }
  | Ocaml_probe { binding_lib; example; target } ->
      { spec with probe_binding =
                   [ (OCaml, Pm (Lang_pm { lang = OCaml; pm = Opam }),
                      probe_ocaml_cmd ~binding_lib ~example ~target) ] }
  | Python_probe { snippet } ->
      let py_binding : Canary_toolchain.python_binding =
        { pip_package = None; probe_snippet = snippet }
      in
      { spec with probe_binding =
                   [ (Python, Pm (Lang_pm { lang = Python; pm = Pip }),
                      fun ~output_dir ~variant_key ->
                        Canary_toolchain.python_probe_only_cmd py_binding ~output_dir ~variant_key) ] }
  | Curl_unzip { url; dest } ->
      { spec with fetch_source =
                   Some (fun ~output_dir ~variant_key ->
                       Canary_build_cmd.curl_unzip_cmd ~url ~dest ()
                       |> Canary_build_cmd.with_marker ~marker:"source.ok" ~output_dir ~variant_key) }
  | Cc_shared_lib { c_src; out; ldlibs } ->
      { spec with build_lib =
                   Some (fun ~output_dir ~variant_key ->
                       Canary_build_cmd.cc_shared_lib_cmd ~c_src ~out ~ldlibs ()
                       |> Canary_build_cmd.with_marker ~marker:"build.ok" ~output_dir ~variant_key) }
  | Inspect_opam { pkg } ->
      { spec with inspect = (fun action _loc ->
                    match action with
                    | Probe_binding OCaml ->
                        Some (fun ~output_dir ~variant_key ->
                            Canary_artifact_lang.inspect_opam_pkg_cmd ~pkg ~output_dir ~variant_key ())
                    | _ -> None) }
  | Inspect_python { pkg } ->
      { spec with inspect = (fun action _loc ->
                    match action with
                    | Probe_binding Python ->
                        Some (fun ~output_dir ~variant_key ->
                            Canary_artifact_lang.python_inspect_cmd ~pkg ~output_dir ~variant_key ())
                    | _ -> None) }
  | Inspect_native_build { lib; prefixes } ->
      { spec with inspect = (fun action _loc ->
                    match action with
                    | Build_lib ->
                        Some (fun ~output_dir ~variant_key ->
                            Canary_artifact_native.inspect_cmd ~lib ~prefixes ~output_dir ~variant_key ())
                    | _ -> None) }
  | Source_fetch { name; ver_str; ref_; url; local } ->
      { spec with fetch_source =
                   Some (fun ~output_dir ~variant_key ->
                       let ok = Canary_basic.variant_file ~variant_key "source.ok" in
                       match local with
                       (* A declared local checkout exists → fetch is a free
                          existence check; the shell [test -d] keeps a stale
                          path failing loudly instead of silently passing. *)
                       | Some path ->
                           Printf.sprintf "test -d %s && echo '%s' > %s/%s"
                             path path output_dir ok
                       | None ->
                           let clone_dir =
                             Printf.sprintf "_out/canary/projects/%s/%s_%s/src" name ver_str ref_
                           in
                           Printf.sprintf
                             "if [ -d %s/.git ]; then cd %s && git fetch && git checkout %s; \
                              else git clone %s %s && cd %s && git checkout %s; fi && echo '%s' > %s/%s"
                             clone_dir clone_dir ref_ url clone_dir clone_dir ref_ clone_dir
                             output_dir ok) }
  | Scan_source { root; hdr_file } ->
      { spec with scan_source =
                   Some (fun ~output_dir ~variant_key ->
                       let scan_ok = Canary_basic.variant_file ~variant_key "scan.ok" in
                       Printf.sprintf "test -f %s/%s && echo 'scan ok' > %s/%s"
                         root hdr_file output_dir scan_ok) }
  | Build_headers { root; hdr_dir } ->
      { spec with build_headers =
                   Some (fun ~output_dir ~variant_key ->
                       let hdr_ok = Canary_basic.variant_file ~variant_key "headers.ok" in
                       Printf.sprintf "test -d %s/%s && echo 'ok' > %s/%s"
                         root hdr_dir output_dir hdr_ok) }
  | Cmake_configure { cmake_exec; flags; src; build } ->
      { spec with configure =
                   Some (fun ~output_dir ~variant_key ->
                       Canary_build_cmd.cmake_configure_cmd ~cmake_exec
                         ~flags ~src ~build ()
                       |> Canary_build_cmd.with_marker ~marker:"conf.ok" ~output_dir ~variant_key) }
  | Ninja_build { target; build } ->
      { spec with build_lib =
                   Some (fun ~output_dir ~variant_key ->
                       Canary_build_cmd.ninja_build_cmd ~target ~build ()
                       |> Canary_build_cmd.with_marker ~marker:"build.ok" ~output_dir ~variant_key) }
  | Ninja_build_binding { target; build; env_guard } ->
      (* Optional env guard between `eval $(opam env)` and ninja: z3's binding
         target runs a POST_BUILD self-check (bytecode + native example) that
         resolves dlls ambiently — the opam switch's stale dllz3ml.so/stublibs
         shadows the fresh one (CAML_LD_LIBRARY_PATH beats the bytecode's
         -dllpath), and the native check needs LD_LIBRARY_PATH for the fresh
         libz3.so (DYLD_LIBRARY_PATH is a macOS-only no-op). *)
      let guard =
        match env_guard with
        | Some g -> g ^ " "
        | None -> ""
      in
      { spec with build_binding =
                   [ (OCaml, fun ~output_dir ~variant_key ->
                         Printf.sprintf "eval $(opam env) && %s%s"
                           guard
                           (Canary_build_cmd.ninja_build_cmd ~target ~build ())
                         |> Canary_build_cmd.with_marker ~marker:"build.ok" ~output_dir ~variant_key) ] }
  | Cmake_install { build; prefix; assert_staged } ->
      { spec with install_lib =
                   Some (fun ~output_dir ~variant_key ->
                       let install_ok = Canary_basic.variant_file ~variant_key "install.ok" in
                       (* the marker is CONDITIONAL on the install (2026-08-16,
                          C2 cold-audit fix): the old newline-separated echo
                          wrote install.ok even when cmake --install died (z3's
                          missing executable — "file INSTALL cannot find"), so a
                          failed install cached as success (the bug-B class). *)
                       (* [assert_staged] (2026-08-17, the z3 #10549
                          regression): each prefix-relative path must exist
                          AFTER the install — the named failure signature is
                          what a project's declared expectation greps (the
                          bugfix-commit regression shape: absent pre-fix,
                          present post-fix). *)
                       let staged_checks =
                         match assert_staged with
                         | None -> ""
                         | Some paths ->
                             String.concat ~sep:"\n"
                               (List.map paths ~f:(fun p ->
                                    (* the signature ALSO lands in a file:
                                       [output_contains_any] reads files in
                                       the step dir (stderr isn't captured),
                                       and a declared Expect_failure greps
                                       them — the probe.log precedent *)
                                    Printf.sprintf
                                      "test -f \"$PREFIX/%s\" || { echo \"OCAML INSTALL MISSING: %s\" >&2; echo \"OCAML INSTALL MISSING: %s\" > %s/install_fail.log; exit 1; }"
                                      p p p output_dir))
                       in
                       Printf.sprintf "PREFIX=\"%s\"\n%s && %s%s && echo 'ok' > %s/%s"
                         prefix
                         (Canary_build_cmd.cmake_install_cmd ~build ~prefix ())
                         (Canary_build_cmd.prefix_layout_inspect_cmd ~prefix ~output_dir ~variant_key)
                         (if String.is_empty staged_checks then "" else "\n" ^ staged_checks)
                         output_dir install_ok) }
  | Native_lib_probe { location; prefix } ->
      let cmd =
        match location with
        | Build_tree_lib { lib } ->
            fun ~output_dir ~variant_key ->
              Canary_artifact_native.native_lib_probe_cmd ~lib ~prefix ~output_dir ~variant_key
        | Build_tree_glob { lib_glob; build } ->
            fun ~output_dir ~variant_key ->
              let resolve =
                Printf.sprintf "LIB=$(ls %s/%s 2>/dev/null | head -1)\ntest -n \"$LIB\"" build lib_glob
              in
              Printf.sprintf "%s\n%s" resolve
                (Canary_artifact_native.native_lib_probe_cmd ~lib:"$LIB" ~prefix ~output_dir ~variant_key)
        | Staged_lib { lib } ->
            fun ~output_dir ~variant_key ->
              Canary_artifact_native.native_lib_probe_cmd ~lib ~prefix ~output_dir ~variant_key
        | Pm_lib { pm_pkg; lib_name; dpkg_pkg; ldconfig_name; brew_pkg } ->
            let extra_fallbacks =
              let open Printf in
              let lines = ref [] in
              (match dpkg_pkg with
               | Some pkg ->
                   lines :=
                     sprintf
                       "test -f \"$LIB\" || LIB=$(dpkg -L %s 2>/dev/null | grep '/%s' | head -1)"
                       pkg lib_name
                     :: !lines
               | None -> ());
              (match ldconfig_name with
               | Some name ->
                   lines :=
                     sprintf
                       "test -f \"$LIB\" || LIB=$(ldconfig -p 2>/dev/null | grep '%s' | awk '{print $NF}' | head -1)"
                       name
                     :: !lines
               | None -> ());
              (match brew_pkg with
               | Some pkg ->
                   lines :=
                     sprintf
                       "test -f \"$LIB\" || LIB=$(brew --prefix %s 2>/dev/null)/lib/%s"
                       pkg lib_name
                     :: !lines
               | None -> ());
              String.concat ~sep:"\n" (List.rev !lines)
            in
            fun ~output_dir ~variant_key ->
              let resolve =
                Printf.sprintf
                  "LIB=$(pkg-config --variable=libdir %s 2>/dev/null)/%s\n\
                   test -f \"$LIB\" || LIB=$(pkg-config --variable=libdir %s 2>/dev/null)/%s.dylib\n\
                   %s\n\
                   test -f \"$LIB\""
                  pm_pkg lib_name pm_pkg lib_name extra_fallbacks
              in
              Printf.sprintf "%s\n%s" resolve
                (Canary_artifact_native.native_lib_probe_cmd ~lib:"$LIB" ~prefix ~output_dir ~variant_key)
      in
      { spec with probe_lib = [ (location_of_probe_location location, cmd) ] }
  | Cmake_install_component { build; prefix; component } ->
      { spec with install_lib =
                   Some (fun ~output_dir ~variant_key ->
                       let install_ok = Canary_basic.variant_file ~variant_key "install.ok" in
                       Printf.sprintf "%s && %s\necho 'ok' > %s/%s"
                         (Canary_build_cmd.cmake_install_cmd ~build ~prefix ~component ())
                         (Canary_build_cmd.prefix_layout_inspect_cmd ~prefix ~output_dir ~variant_key)
                         output_dir install_ok) }
  | Raw _ ->
      (* not realized here — [realize_from_rows] routes Raw by action *)
      spec

(* ── engine ── *)

(** Turn a list of rows into a [runner_spec]. Rows whose action requires a
    specific provision (e.g. [Build_lib] needs [Built], [Fetch Lib] needs
    [Fetched]) are filtered against [assignment]; others always fire.
    Rows processed left-to-right; later rows override earlier ones.
    [?base] supplies project-level defaults. *)
let realize_from_rows ?(base = empty_runner_spec)
    ~(assignment : Canary_artifact.assignment) (rows : action_row list) :
    runner_spec =
  let module EN = Canary_enumerate in
  (* Probe_lib location -> required lib provision. build_tree/staged probes
     need a Built lib; pm probes fire regardless (system lib always present). *)
  let probe_lib_needs (row : action_row) : Canary_store.provision option =
    match row.ar_template with
    | Native_lib_probe
        { location = (Build_tree_lib _ | Build_tree_glob _ | Staged_lib _); _ } ->
        Some Canary_store.Built
    | _ -> None
  in
  (* Probe_binding row -> required binding provision (2026-08-12). The PM
     probe primitives (ocaml_probe / python_probe) compile against the
     FETCHED package; Raw rows are build-tree probes (z3/llvm dev chains)
     and need a BUILT binding. Without this, the append merge lets a dev
     chain inherit the shared opam probe row (silently probing the switch)
     and a stable chain the build-tree row. *)
  let probe_binding_needs (row : action_row) : Canary_store.provision option =
    match row.ar_template with
    | Ocaml_probe _ | Python_probe _ -> Some Canary_store.Fetched
    | Raw _ -> Some Canary_store.Built
    | _ -> None
  in
  let row_applies (row : action_row) =
    match action_requires_provision row.ar_action with
    | None -> (
        match row.ar_action with
        | Probe_lib -> (
            match probe_lib_needs row with
            | Some needed ->
                EN.equal_provision
                  (Canary_enumerate.provision_of assignment Canary_artifact.a_lib)
                  needed
            | None -> true)
        | Probe_binding l -> (
            match probe_binding_needs row with
            | Some needed ->
                EN.equal_provision
                  (Canary_enumerate.provision_of assignment
                     (Canary_artifact.a_binding l Canary_mechanism.Cstubs))
                  needed
            | None -> true)
        | _ -> true)
    | Some needed ->
        let target_kind =
          match row.ar_action with
          | Build_lib | Fetch Lib | Install_lib | Probe_lib
          | Configure | Scan_sources | Build_headers ->
              Some Canary_artifact.a_lib
          | Build_binding l | Fetch (Binding l) | Publish (Binding l) ->
              Some (Canary_artifact.a_binding l Canary_mechanism.Cstubs)
          | Fetch Headers -> Some Canary_artifact.a_headers
          | Fetch Source -> Some Canary_artifact.a_source
          | _ -> None
        in
        (match target_kind with
         | None -> true
         | Some id -> EN.equal_provision (Canary_enumerate.provision_of assignment id) needed)
  in
  let matching = List.filter rows ~f:row_applies in
  List.fold_left matching ~init:base ~f:(fun acc row ->
      let row_spec =
        match row.ar_template with
        | Raw cmd ->
            { empty_runner_spec with
              fetch_source = (match row.ar_action with Fetch Source -> Some cmd | _ -> None);
              fetch_lib = (match row.ar_action with Fetch Lib -> Some (Raw (fun ~output_dir ~variant_key -> cmd ~output_dir ~variant_key)) | _ -> None);
              build_lib = (match row.ar_action with Build_lib -> Some cmd | _ -> None);
              build_headers = (match row.ar_action with Build_headers -> Some cmd | _ -> None);
              configure = (match row.ar_action with Configure -> Some cmd | _ -> None);
              install_lib = (match row.ar_action with Install_lib -> Some cmd | _ -> None);
              scan_source = (match row.ar_action with Scan_sources -> Some cmd | _ -> None);
              build_binding = (match row.ar_action with Build_binding l -> [ (l, cmd) ] | _ -> []);
              pack_binding = (match row.ar_action with Publish (Binding l) -> [ (l, cmd) ] | _ -> []);
              probe_lib = (match row.ar_action with Probe_lib -> [ (Build_tree, cmd) ] | _ -> []);
              (* Raw binding-probe rows are build-tree probes (z3/llvm's
                 dev-chain probes compile against the build tree) — the old
                 fabricated [Sys_pm] location was bogus (tag_of_probe_location
                 rejects it) and hid the append-merge duplication. *)
              probe_binding = (match row.ar_action with Probe_binding l -> [ (l, Build_tree, cmd) ] | _ -> []);
            }
        | tpl ->
            realize_template tpl
      in
      let merge_opt a b = match b with Some _ -> b | None -> a in
      (* Append semantics: multiple rows for the same action accumulate entries
         (e.g. probe_lib with build_tree + pm, fetch_binding with OCaml + Python).
         The old replace-iff-nonempty behaviour dropped earlier rows. *)
      let merge_list a b = a @ b in
      let merge_inspect a b =
        (* [Poly.equal] on closures crashes — the inspect field is a
           function. Use [inspect_note] as proxy: only templates that set
           inspect also set inspect_note. *)
        if Option.is_none row_spec.inspect_note then a else b in
      { acc with
        fetch_source = merge_opt acc.fetch_source row_spec.fetch_source;
        fetch_lib = merge_opt acc.fetch_lib row_spec.fetch_lib;
        fetch_binding = merge_list acc.fetch_binding row_spec.fetch_binding;
        build_lib = merge_opt acc.build_lib row_spec.build_lib;
        (* the missing half (2026-08-12): the fold dropped every other
           action field — a dev chain lost configure/build_headers/scan/
           install/build_binding/publish silently (z3's ninja ran with no
           cmake cache). *)
        configure = merge_opt acc.configure row_spec.configure;
        scan_source = merge_opt acc.scan_source row_spec.scan_source;
        build_headers = merge_opt acc.build_headers row_spec.build_headers;
        install_lib = merge_opt acc.install_lib row_spec.install_lib;
        build_binding = merge_list acc.build_binding row_spec.build_binding;
        pack_binding = merge_list acc.pack_binding row_spec.pack_binding;
        probe_app = merge_list acc.probe_app row_spec.probe_app;
        probe_lib = merge_list acc.probe_lib row_spec.probe_lib;
        probe_binding = merge_list acc.probe_binding row_spec.probe_binding;
        inspect = merge_inspect acc.inspect row_spec.inspect;
        stores = if Poly.equal row_spec.stores empty_runner_spec.stores then acc.stores else row_spec.stores;
      })

(* ── generic realize ── *)

(** The generic [realize]: turns a project's action rows + an assignment
    into a [runner_spec]. Each project's [realize] becomes a one-liner:
    [let realize a = Canary_action_templates.realize (my_table_rows ~chan ~distro) a]. *)
let realize (rows : action_row list) (a : Canary_artifact.assignment) :
    runner_spec =
  realize_from_rows ~assignment:a rows
