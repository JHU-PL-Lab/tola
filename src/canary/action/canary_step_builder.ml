(** [Canary_runner] — the action-graph runner.

    The {i second} of the two main action-layer files. Takes the
    project's {!runner_spec} (per-action shell commands + api_source +
    expectations), translates the action-graph schema in
    {!Canary_action} into concrete [step]s via {!derive_steps},
    and executes them with {!run_step} / {!run_graph}.

    Renamed from [Canary_action] on 2026-06-01 as part of the
    action/runner naming pass: [Canary_action] now holds the schema
    (actions + pools), [Canary_runner] holds the execution.

    Holds:
    - [type runner_spec] + [empty_runner_spec] + [no_source]: the
      per-action contract every project fills in.
    - [run_step], [run_graph], [merge_step_statuses]: the step
      executor.
    - [output_dir_for], [project_dir_of], logging glue.
    - Shared command templates ([fetch_lib_cmd], [fetch_binding_cmd],
      [probe_ocaml_cmd]) — project-spec building blocks.
    - [has_file] + [check_build_lib] / [check_build_binding] /
      [check_markers]: [check_post] compositors.
    - [default_check_post], [marker_of_action]: per-action default
      verdict logic.
    - [derive_steps]: the bridge between the action-graph schema and
      a concrete [step list]. *)

open Base
open Canary_basic
open Canary_store
open Canary

(* ── Script spec ──
   A project provides shell commands per action kind.
   None = project doesn't support this action (also determines capabilities).
   Commands are templates that receive output_dir at runtime.

   Scripts for fetch/pack come from the store (uniform per PM).
   Scripts for build/probe come from the project (project-specific). *)

(* probe_binding is the action; each entry is keyed by the location
   of the artifact being probed. Location determines deps and tag:
   - Build_tree: depends on build_binding (raw build artifact)
   - Staged: depends on an installed (cmake --install) artifact
   - Pm { lang; pm }: depends on pack_binding or fetch_binding (PM-installed) *)

(* Tag for a split probe step: probe_<lang>_binding[_<pm>].
   Build_tree/Staged use the action's lang; Pm entries use the location's lang.
   This matches string_of_action (Probe (Binding lang)) for the Build_tree base case. *)
let tag_of_probe_lib_location loc =
  let base = string_of_action Probe_lib in
  match loc with
  | Build_tree -> base
  | Staged -> base ^ "_staged"
  | Pm (Sys_pm { pm }) -> [%string "%{base}_%{string_of_pm pm}"]
  | Pm (Lang_pm _) -> failwith "tag_of_probe_lib_location: Lang_pm is not a lib probe location"

let tag_of_probe_location ~lang location =
  let base l = string_of_action (Probe_binding l) in
  match location with
  | Build_tree -> base lang
  | Staged -> base lang ^ "_staged"
  | Pm (Lang_pm { lang = loc_lang; pm }) ->
      [%string "%{base loc_lang}_%{string_of_pm pm}"]
  | Pm (Sys_pm _) -> failwith "tag_of_probe_location: Sys_pm is not a binding probe location"

(* Whether this probe reads from the packed/installed store (vs. raw build tree) *)
let probe_from_store = function
  | Build_tree -> false
  | _ -> true




(* DESIGN NOTE — adding new per-action fields to runner_spec:
   When a property of an step varies per-location for multi-probe
   actions (probe_binding has multiple location entries), the property's
   accessor in runner_spec MUST take `location option` from the start.
   Both [expectation] and [summary] originally took only [action] and had
   to be retrofitted to [action -> location option -> ...] when their first
   per-location use case appeared (sqlite/z3/llvm pip probes). Mismatch
   between action and the location entry led to silent miscategorisation
   (pip probes wrapped as Expect_failure). For any future field of shape
   `action -> X` ask: could two probe_binding variants want different X?
   If yes, take location option upfront. [check_post] and [symbol_check]
   are still action-only because no current project needs per-location
   variation; revisit when one does. *)
(* A store-backed command slot (S2, project_definition.md §3.1). A slot is
   either [Derived] from the project's store_config (the clean path — wired
   in S3) or a [Raw] closure (escape hatch, identical to the pre-S2 command
   closures). Only [Raw] is inhabited in S2; every existing closure is
   wrapped as [Raw f], so behaviour is unchanged.

   (The strawman [Canary_project_def] carries an isomorphic copy; the two
   merge when that file dissolves in S3.) *)
type store_slot =
  | Fetch_lib
  | Fetch_binding of Canary_lang.lang
  | Probe_lib
  | Probe_binding of Canary_lang.lang
  | Scan_source

type step_source =
  | Derived of store_slot
  | Raw of (output_dir:string -> variant_key:string -> string)

(* Resolve a [step_source] to its command. S2: only [Raw] is reachable;
   [Derived] resolution against store_config arrives in S3. *)
let command_of_step (s : step_source)
  : output_dir:string -> variant_key:string -> string =
  match s with
  | Raw f -> f
  | Derived _ ->
      failwith
        "command_of_step: Derived not resolved until S3 (store_config)"

type runner_spec = {
  fetch_source : (output_dir:string -> variant_key:string -> string) option;
  (* Declarative API spec for this source version. When present, derive_steps
     checks consistency: binding_api.source_dir = Some _ ↔ build_binding = Some _. *)
  api_source : Canary_artifact_api.t option;
  (* Scan step: verifies api_source header/binding claims against the fetched
     source tree. Emitted after fetch_source; configure/build depend on it.
     None when no source build (stable fetch-only sources). *)
  scan_source : (output_dir:string -> variant_key:string -> string) option;
  (* Source-derived inspections (typed signatures, etc.) for c6/c7/c8.
     Placement in the dep graph is project-controlled via
     [scan_sources_after]:
     - hand-written bindings (tiny): runs after Configure (default).
     - generated bindings (z3): set scan_sources_after = Some Build_lib
       so it runs after the binding source has been generated.
     Emits JSONs into the scan_sources/ output dir; comparators
     downstream reference [scan_sources/<file>.json] via the
     [Typed_*] inspect_input cases. *)
  scan_sources : (output_dir:string -> variant_key:string -> string) option;
  scan_sources_after : Canary_basic.action option;
  configure : (output_dir:string -> variant_key:string -> string) option;
  (* Headers: public C API headers consumed by build_binding.
     build_headers: headers from the source/build tree (after configure).
     fetch_headers: headers from a system -dev package (e.g. apt install libz3-dev). *)
  build_headers : (output_dir:string -> variant_key:string -> string) option;
  fetch_headers : (output_dir:string -> variant_key:string -> string) option;
  build_lib : (output_dir:string -> variant_key:string -> string) option;
  build_binding : (Canary_lang.lang * (output_dir:string -> variant_key:string -> string)) list;
  install_lib : (output_dir:string -> variant_key:string -> string) option;
  build_app : (output_dir:string -> variant_key:string -> string) option;
  fetch_lib : step_source option;
  fetch_binding : (Canary_lang.lang * step_source) list;
  fetch_app : (output_dir:string -> variant_key:string -> string) option;
  pack_lib : (output_dir:string -> variant_key:string -> string) option;
  pack_binding : (Canary_lang.lang * (output_dir:string -> variant_key:string -> string)) list;
  pack_app : (output_dir:string -> variant_key:string -> string) option;
  probe_lib : (location * (output_dir:string -> variant_key:string -> string)) list;
  probe_binding : (Canary_lang.lang * location * (output_dir:string -> variant_key:string -> string)) list;
  probe_app : (output_dir:string -> variant_key:string -> string) option;
  (* Optional per-action check_post override. None = use default (non-empty dir). *)
  check_post : (action -> (output_dir:string -> variant_key:string -> bool) option);
  (* Per-action expectation. Default: Expect_success.
     loc carries the per-location variant for multi-probe actions (e.g., a
     Probe Binding that has opam AND pip variants — the opam one may be
     Expect_failure while the pip one is Expect_success). None for
     single-location actions. *)
  expectation : action -> location option -> step_expectation;
  (* Optional per-action artifact symbol check. None = no symbol check. *)
  symbol_check : (action -> symbol_check option);
  (** Per-language user-facing package name(s) carrying the
      {i s4 user_binding} surface for this project. Used by
      [derive_steps] to auto-generate an inspector step after each
      Probe (Binding lang) step:
      - OCaml  → [mli_inspect_opam_pkg_cmd ~pkg ~watchlist:(binding_api[lang].module_watchlist)]
                 (produces the {i bo4 user_binding_ocaml.mli} JSON)
      - Python → [python_inspect_cmd ~pkg ~watchlist:(binding_api[lang].module_watchlist)]
                 (produces the {i bpe2 user_binding_cext.py} or
                 {i bpc2 user_binding_ctypes.py} JSON depending on
                 which mechanism the package ships as)

      Example: z3 sets [[(OCaml, "z3"); (Python, "z3")]]; llvm sets
      [[(OCaml, "llvm"); (Python, "llvmlite.binding")]]. Typical
      projects set this and omit binding arms from [summary].

      Renamed 2026-05-28 (Phase 4 Pass 2) from [binding_summary] —
      the old name reflected the pre-Phase-2 "summary" terminology
      that became "inspect" everywhere else. *)
  binding_user_facing_pkg : (Canary_lang.lang * string) list;
  (* Optional note prepended to auto-generated binding summaries (shell echo).
     Used by stable-fetch specs to warn that watchlists were declared for the
     dev version. Ignored when the explicit [summary] override is used. *)
  inspect_note : string option;
  (* Explicit per-action inspect override. Wins over auto-generation.
     Use for native probe summaries (lib path is always project-specific)
     or any case needing custom logic beyond what api_source provides.
     loc is Some _ for per-location probe variants, None for single-location actions.
     See doc/canary/design/api_surface.md. *)
  inspect : action -> location option -> (output_dir:string -> variant_key:string -> string) option;
  (* Human-readable artifact name per kind for diagram labels. *)
  artifact_name : artifact_kind -> string option;
  (** Per-project list of surface-theory contracts this project opts out
      of. Empty by default; populate when a contract gives systematic
      false positives on the project's idiomatic patterns. Threaded
      through to {!Canary_compat_run.predicted_contains_any_v2} via
      its [?disabled] argument. Layered with the CLI's
      [--disable-contract] flag — both contribute to the per-run
      disabled set. *)
  disabled_contracts : Canary_compat.contract_id list;
}

let empty_runner_spec = {
  fetch_source = None;
  api_source = None;
  scan_source = None;
  scan_sources = None;
  scan_sources_after = None;
  configure = None;
  build_headers = None; fetch_headers = None;
  build_lib = None; build_binding = []; install_lib = None;
  build_app = None;
  fetch_lib = None; fetch_binding = []; fetch_app = None;
  pack_lib = None; pack_binding = []; pack_app = None;
  probe_lib = []; probe_binding = [];
  probe_app = None;
  check_post = (fun _ -> None);
  expectation = (fun _ _ -> Expect_success);
  symbol_check = (fun _ -> None);
  binding_user_facing_pkg = [];
  inspect_note = None;
  inspect = (fun _ _ -> None);
  artifact_name = (fun _ -> None);
  disabled_contracts = [];
}

(* Remove build-from-source actions. Keeps fetch + probe only. *)
let no_source spec =
  { spec with fetch_source = None; scan_source = None;
    scan_sources = None; scan_sources_after = None;
    configure = None;
    build_headers = None;
    build_lib = None; build_binding = []; install_lib = None;
    build_app = None;
    pack_lib = None; pack_binding = []; pack_app = None;
    probe_lib = List.filter spec.probe_lib ~f:(fun (loc, _) ->
        match loc with Build_tree | Staged -> false | _ -> true) }

(* Look up the script for a action *)
let script_of_action spec = function
  | Fetch Source -> spec.fetch_source
  | Configure -> spec.configure
  | Scan_sources -> spec.scan_sources
  | Build_headers -> spec.build_headers
  | Fetch Headers -> spec.fetch_headers
  | Fetch Lib -> Option.map spec.fetch_lib ~f:command_of_step
  | Fetch (Binding lang) ->
      Option.map (List.Assoc.find spec.fetch_binding ~equal:Poly.equal lang)
        ~f:command_of_step
  | Fetch App -> spec.fetch_app
  | Build_lib -> spec.build_lib
  | Build_binding lang -> List.Assoc.find spec.build_binding ~equal:Poly.equal lang
  | Install_lib -> spec.install_lib
  | Build_app _ -> spec.build_app
  | Publish Lib -> spec.pack_lib
  | Publish (Binding lang) -> List.Assoc.find spec.pack_binding ~equal:Poly.equal lang
  | Publish App -> spec.pack_app
  | Probe_lib ->
      (match spec.probe_lib with [] -> None | (_, cmd) :: _ -> Some cmd)
  | Probe_binding lang ->
      (* For has-check purposes: Some _ when any probe entry exists for this lang. *)
      (match List.filter spec.probe_binding ~f:(fun (l, _, _) -> Poly.equal l lang) with
       | [] -> None
       | (_, _, cmd) :: _ -> Some cmd)
  | Probe_app _ -> spec.probe_app
  | Publish Source | Publish Headers -> None

(* ── Action step protocol ── *)

(* Step execution moved to backend/canary_local_runner.ml on 2026-06-01:
   - run_cmd_logged, exec_step, output_contains_any
   - run_step, run_graph
   - merge_step_statuses

   This file now keeps the step-building half only — runner_spec,
   derive_steps, shared command templates, check_post compositors,
   defaults, and dep helpers. Renamed to canary_step_builder.ml in
   the same commit. *)

(* project = "z3/stable" → project_name="z3", variant_id="stable"
   project = "sqlite"   → project_name="sqlite", variant_id=""
   Output Layout v3: step_dir uses action-first grouping for binding tags
   ("build_binding_ocaml" → "build_binding/ocaml"); NO variant subdir.
   Variants are encoded as filename suffixes (_19.json, _stable.log).
   All variants of a step share the same output_dir. *)
let output_dir_for ~root ~project ~tag =
  let (project_name, _variant_id) =
    match String.rsplit2 project ~on:'/' with
    | Some (name, vid) -> (name, vid)
    | None -> (project, "")
  in
  let step_dir = Canary_basic.step_dir_of_tag tag in
  let base = [%string "%{root}/canary/projects/%{project_name}/%{step_dir}"] in
  if Stdlib.Filename.is_relative base then
    Stdlib.Filename.concat (Unix.getcwd ()) base
  else base

let project_dir_of ~root ~project =
  let project_name = match String.rsplit2 project ~on:'/' with
    | Some (name, _) -> name
    | None -> project
  in
  let base = [%string "%{root}/canary/projects/%{project_name}"] in
  if Stdlib.Filename.is_relative base then
    Stdlib.Filename.concat (Unix.getcwd ()) base
  else base


(* ── Shared command templates ──
   These generate shell commands for common action patterns.
   Project specs use these instead of writing raw shell strings. *)

(* fetch_lib: install a system package and write marker *)
let fetch_lib_cmd pm (spec : Canary_store.system_package_spec) ~output_dir ~variant_key =
  let lib_ok = Canary_basic.variant_file ~variant_key "lib.ok" in
  [%string "%{Canary_pm.system_install_cmd pm spec} && echo 'installed' > %{output_dir}/%{lib_ok}"]

(* fetch_binding: install an opam package + ocamlfind, then write marker.
   We add ocamlfind explicitly because some bindings (e.g. ssl, dune-only
   pkgs) don't pull it transitively, but probe_ocaml_cmd uses
   `ocamlfind ocamlopt` to compile probes. Bindings that DO pull ocamlfind
   (e.g. zarith) treat the second install as a no-op. *)
let fetch_binding_cmd (spec : Canary_toolchain.opam_package_spec) ~output_dir ~variant_key =
  let binding_ok = Canary_basic.variant_file ~variant_key "binding.ok" in
  [%string "%{Canary_toolchain.opam_install_cmd spec} && eval $(opam env) && opam install -y ocamlfind && echo 'installed' > %{output_dir}/%{binding_ok}"]

(* probe_binding (simple): compile and run an OCaml example against an opam package *)
let probe_ocaml_cmd ~binding_lib ~example ~target ~output_dir ~variant_key =
  (* On failure (compile or run), dump probe.log to stdout and re-raise the
     original exit code. Without this, CI step failures show only "exit 127"
     with no context — the actual ocamlfind / dynamic-link error is hidden in
     the file. Successful runs print probe.log too (cheap, useful confirmation). *)
  let probe_log = Canary_basic.variant_file ~variant_key "probe.log" in
  [%string {|eval $(opam env)
ocamlfind ocamlopt -package %{binding_lib} -linkpkg %{example} -o %{output_dir}/%{target} > %{output_dir}/%{probe_log} 2>&1 && %{output_dir}/%{target} >> %{output_dir}/%{probe_log} 2>&1
RC=$?
cat %{output_dir}/%{probe_log}
exit $RC|}]

(* ── Convenience helpers for building steps ── *)


let has_file ~output_dir name =
  Stdlib.Sys.file_exists [%string "%{output_dir}/%{name}"]

(* ── check_post compositors ──
   Thin functions for common check_post patterns used by project specs.
   Each returns a bool; project specs wire them into [runner_spec.check_post]. *)

(** Marker file present AND a native .so/.dylib exists at [lib_path]. *)
let check_build_lib ~marker ~lib_path ~output_dir ~variant_key =
  has_file ~output_dir (Canary_basic.variant_file ~variant_key marker)
  && Canary_artifact_native.exists_native_lib_or_dylib lib_path

(** Marker file present AND an OCaml archive exists at [archive_path]. *)
let check_build_binding ~marker ~archive_path ~output_dir ~variant_key =
  has_file ~output_dir (Canary_basic.variant_file ~variant_key marker)
  && Canary_artifact_lang.exists_ocaml_archive archive_path

(** All listed marker files exist in [output_dir]. *)
let check_markers markers ~output_dir ~variant_key =
  List.for_all markers ~f:(fun m ->
    has_file ~output_dir (Canary_basic.variant_file ~variant_key m))

(* ── Default check_post per action category ──
   Derived from the action type. Projects can override via runner_spec.check_post.

   | Rule category | Marker file | What it means |
   |---------------|-------------|---------------|
   | Fetch _       | <kind>.ok   | Store op completed, wrote marker |
   | Build_*       | build.ok    | Build command succeeded |
   | Publish _     | pack.ok     | Pack/install completed |
   | Probe _       | probe.log   | Test ran and produced output |
*)

let marker_of_action = function
  | Fetch Source -> "source.ok"
  | Configure -> "conf.ok"
  | Scan_sources -> "scan.ok"
  | Build_headers | Fetch Headers -> "headers.ok"
  | Fetch Lib -> "lib.ok"
  | Fetch (Binding _) -> "binding.ok"
  | Fetch App -> "app.ok"
  | Build_lib | Build_binding _ | Build_app _ -> "build.ok"
  | Install_lib -> "install.ok"
  | Publish _ -> "pack.ok"
  | Probe_lib | Probe_binding _ | Probe_app _ -> "probe.log"

let default_check_post action ~output_dir ~variant_key =
  has_file ~output_dir (Canary_basic.variant_file ~variant_key (marker_of_action action))

let out_of ~root ~project ~tag =
  output_dir_for ~root ~project ~tag

let mk_step ~root ~project ~cache_project ~tag ?output_tag ~action ~deps ~cmd
    ?(expectation = Expect_success) ?(symbol_check = None)
    ?(disabled_contracts = []) ~check_post () =
  let output_tag = Option.value output_tag ~default:tag in
  let output_dir = output_dir_for ~root ~project ~tag:output_tag in
  let project_dir = project_dir_of ~root ~project in
  let variant_id = match String.rsplit2 project ~on:'/' with
    | Some (_, vid) -> vid
    | None -> ""
  in
  { tag;
    cache_key = cache_project ^ ":" ^ tag;
    output_tag;
    output_dir;
    project_dir;
    variant_id;
    action; deps;
    expectation; symbol_check;
    disabled_contracts;
    check_pre = (fun () ->
      List.for_all deps ~f:(fun dep ->
          let out = output_dir_for ~root ~project ~tag:dep in
          Stdlib.Sys.file_exists out));
    cmd;
    check_post;
  }

(* ── Derive action steps from store_actions + runner_spec ── *)

let deps_of_action spec action =
  let has r = Option.is_some (script_of_action spec r) in
  let tag r = string_of_action r in
  let scan_or_fetch_source () =
    if has (Fetch Source) then
      Some (if Option.is_some spec.scan_source then "scan_source"
            else tag (Fetch Source))
    else None
  in
  match action with
  | Fetch _ -> []
  | Configure ->
      List.filter_opt [ scan_or_fetch_source () ]
  | Scan_sources ->
      (* Default to Configure when wired, else fall back to source/scan.
         Override via spec.scan_sources_after for projects whose
         binding source is generated at a later step (e.g. z3 sets
         scan_sources_after = Some Build_lib). *)
      let after =
        Option.value spec.scan_sources_after
          ~default:(if has Configure then Configure
                    else if has (Fetch Source) then Fetch Source
                    else Configure)
      in
      List.filter_opt [ if has after then Some (tag after) else None ]
  | Build_headers ->
      (* headers come from configured source; fall back to scan/fetch if no configure *)
      List.filter_opt [
        if has Configure then Some (tag Configure)
        else scan_or_fetch_source ()
      ]
  | Build_lib ->
      List.filter_opt [
        if has Configure then Some (tag Configure)
        else scan_or_fetch_source ()
      ]
  | Install_lib ->
      List.filter_opt [ if has Build_lib then Some (tag Build_lib) else None ]
  | Build_binding _lang ->
      let lib_dep =
        if has Build_lib then Some (tag Build_lib)
        else if has (Fetch Lib) then Some (tag (Fetch Lib))
        else None
      in
      let headers_dep =
        if has Build_headers then Some (tag Build_headers)
        else if has (Fetch Headers) then Some (tag (Fetch Headers))
        else None
      in
      (* configure needed separately when cmake drives the binding build *)
      let configure_dep =
        if has Configure then Some (tag Configure)
        else None
      in
      List.filter_opt [ configure_dep; headers_dep; lib_dep ]
  | Build_app { lang } ->
      let binding_dep =
        if has (Build_binding lang) then Some (tag (Build_binding lang))
        else if has (Fetch (Binding lang)) then Some (tag (Fetch (Binding lang)))
        else None
      in
      let lib_dep =
        if has Build_lib then Some (tag Build_lib)
        else if has (Fetch Lib) then Some (tag (Fetch Lib))
        else None
      in
      List.filter_opt [ binding_dep; lib_dep ]
  | Publish kind ->
      let produce_action = match kind with
        | Headers -> if has Build_headers then Some Build_headers else Some (Fetch Headers)
        | Lib -> if has Build_lib then Some Build_lib else Some (Fetch Lib)
        | Binding lang ->
            if has (Build_binding lang) then Some (Build_binding lang)
            else Some (Fetch (Binding lang))
        | App ->
            (* Publish App: pick OCaml Build_app if present, else any lang. *)
            let langs = Canary_lang.[ OCaml; Python; Rust; Cpp; CSharp; Java ] in
            (match List.find langs ~f:(fun l -> has (Build_app { lang = l })) with
             | Some l -> Some (Build_app { lang = l })
             | None -> Some (Fetch App))
        | Source -> Some (Fetch Source)
      in
      Option.to_list
        (Option.bind produce_action ~f:(fun r ->
             if has r then Some (tag r) else None))
  | Probe_lib ->
      let produce_dep =
        if has Build_lib then Some (tag Build_lib)
        else if has (Fetch Lib) then Some (tag (Fetch Lib))
        else None
      in
      Option.to_list produce_dep
  | Probe_binding lang ->
      let produce_dep =
        if has (Build_binding lang) then Some (tag (Build_binding lang))
        else if has (Fetch (Binding lang)) then Some (tag (Fetch (Binding lang)))
        else None
      in
      let runtime_lib_dep =
        if has (Fetch Lib) then Some (tag (Fetch Lib))
        else if has Build_lib then Some (tag Build_lib)
        else None
      in
      List.filter_opt [ produce_dep; runtime_lib_dep ]
  | Probe_app { lang } ->
      let produce_dep =
        if has (Build_app { lang }) then Some (tag (Build_app { lang }))
        else if has (Fetch App) then Some (tag (Fetch App))
        else None
      in
      let runtime_lib_dep =
        if has (Fetch Lib) then Some (tag (Fetch Lib))
        else if has Build_lib then Some (tag Build_lib)
        else None
      in
      List.filter_opt [ produce_dep; runtime_lib_dep ]

(* Deps for a specific probe entry: Build_tree depends on build_binding,
   all other locations depend on pack_binding or fetch_binding. *)
let deps_of_probe_entry spec ~lang loc =
  let has r = Option.is_some (script_of_action spec r) in
  let tag r = string_of_action r in
  let produce_dep = match loc with
    | Build_tree ->
        if has (Build_binding lang) then Some (tag (Build_binding lang)) else None
    | _ ->
        if has (Publish (Binding lang)) then Some (tag (Publish (Binding lang)))
        else if has (Fetch (Binding lang)) then Some (tag (Fetch (Binding lang)))
        else None
  in
  let runtime_lib_dep =
    if has (Fetch Lib) then Some (tag (Fetch Lib))
    else if has Build_lib then Some (tag Build_lib)
    else None
  in
  List.filter_opt [ produce_dep; runtime_lib_dep ]

let deps_of_probe_lib_entry spec loc =
  let has r = Option.is_some (script_of_action spec r) in
  let tag r = string_of_action r in
  let produce_dep = match loc with
    | Build_tree -> if has Build_lib then Some (tag Build_lib) else None
    | Staged     -> if has Install_lib then Some (tag Install_lib) else None
    | _          -> if has (Fetch Lib) then Some (tag (Fetch Lib)) else None
  in
  List.filter_opt [ produce_dep ]

let check_api_consistency (spec : runner_spec) =
  match spec.api_source with
  | None -> ()
  | Some api ->
      (* One-directional: build_binding being wired requires a declared source_dir.
         The reverse is not required — source may exist in the repo but a given
         run configuration may use a prebuilt binding instead of building it. *)
      if not (List.is_empty spec.build_binding) then
        let any_source_dir =
          List.exists api.Canary_artifact_api.binding_apis
            ~f:(fun b -> Option.is_some b.Canary_artifact_api.source_dir)
        in
        if not any_source_dir then
          failwith "api_source: runner_spec has build_binding but no binding_api declares source_dir"

let derive_steps ~root ~project ?(cache_project = project) ?(langs = Canary_lang.[ OCaml ]) (spec : runner_spec) : step list =
  check_api_consistency spec;
  let seen = Hashtbl.create (module String) in
  let mk_one ~tag ~action ~deps ~cmd =
    let check_post = match spec.check_post action with
      | Some cp -> cp
      | None -> default_check_post action
    in
    let expectation = spec.expectation action None in
    let symbol_check = spec.symbol_check action in
    mk_step ~root ~project ~cache_project ~tag ~action ~deps ~cmd ~check_post ~expectation ~symbol_check ~disabled_contracts:spec.disabled_contracts ()
  in
  (* Optional follow-up step that writes a summary file for an artifact.
     Writes into the PARENT's output_dir (alongside probe.log) rather than
     creating a separate <parent>_inspect/ directory. Depends on parent;
     check_post verifies the named file exists in that shared dir.
     [tag_suffix] is appended to parent_tag (e.g. "_inspect", "_stub_inspect");
     [filename] is the basename written by [inspect_cmd] (e.g. "inspect.json",
     "stub_inspect.json"). The cmd is responsible for redirecting to that file. *)
  let mk_inspect ~parent_tag ~action ~tag_suffix ~base_name ~inspect_cmd =
    let tag = parent_tag ^ tag_suffix in
    (* base_name is the variant-independent base (e.g. "inspect", "inspect_stub").
       The actual filename is base_name + "_" + variant_key + ".json" at run time. *)
    let check_post ~output_dir ~variant_key =
      has_file ~output_dir (Canary_basic.filename ~variant_key ~base:base_name ~ext:"json")
    in
    mk_step ~root ~project ~cache_project ~tag
      ~output_tag:parent_tag ~action
      ~deps:[ parent_tag ]
      ~cmd:inspect_cmd ~check_post ~expectation:Expect_success
      ~symbol_check:None ~disabled_contracts:spec.disabled_contracts ()
  in
  (* A summary attached to a parent step: (tag suffix, filename, command).
     OCaml bindings get two: mli (semantic) and stub (C-symbol consumer). *)
  let prepend_note (note : string option)
      (cmd : output_dir:string -> variant_key:string -> string) =
    match note with
    | None -> cmd
    | Some n -> fun ~output_dir ~variant_key ->
        [%string "%{n}\n%{cmd ~output_dir ~variant_key}"]
  in
  (* Tuples: (tag_suffix, base_name, cmd).
     base_name is the variant-independent part of the output filename:
       "inspect"      → summary.json / summary_19.json
       "inspect_stub" → inspect_stub.json / inspect_stub_19.json   (type-first) *)
  let auto_binding_summaries action
      : (string * string * (output_dir:string -> variant_key:string -> string)) list =
    match spec.api_source with
    | None -> []
    | Some api ->
        (* S1: checking-reads go through the [surface] abstraction (computed
           from api_source for now; becomes a stored field when api_source
           is removed in a later seam). *)
        let surf = Canary_surface.surface_of_api api in
        let ocaml_install_summaries pkg =
          (* mli summary: vals + constructors + module nesting at L3.
             stub summary: C symbols required by the binding at L0/L1.
             Both are functions of the installed binding (independent of
             which probe runs them) — attach to the install step
             (Fetch/Publish Binding) so they're cached *before*
             probe_binding evaluates Expect_compat_failure. *)
          let wl =
            Canary_surface.binding_watchlist_exn surf Canary_lang.OCaml
          in
          let mli =
            prepend_note spec.inspect_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.mli_inspect_opam_pkg_cmd
                ~pkg ~watchlist:wl ~output_dir ~variant_key ())
          in
          let prefix =
            match surf.native.symbol_prefixes with
            | p :: _ -> p
            | [] -> ""
          in
          let stub =
            prepend_note spec.inspect_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.stub_inspect_opam_pkg_cmd
                ~pkg ~prefix ~watchlist:[] ~output_dir ~variant_key ())
          in
          [ ("_inspect", "inspect", mli);
            ("_stub_inspect", "inspect_stub", stub) ]
        in
        let python_install_inspect pkg =
          (* Python summary attaches at Fetch (Binding Python) — the install
             step — so the cached summary.json is available before
             Probe (Binding Python) evaluates its (possibly compat-derived)
             expectation. Mirrors the OCaml mli/stub placement. *)
          let wl =
            Canary_surface.binding_watchlist_exn surf Canary_lang.Python
          in
          let py =
            prepend_note spec.inspect_note (fun ~output_dir ~variant_key ->
              Canary_artifact_lang.python_inspect_cmd
                ~pkg ~watchlist:wl ~output_dir ~variant_key ())
          in
          [ ("_inspect", "inspect", py) ]
        in
        match action with
        | Fetch (Binding OCaml) | Publish (Binding OCaml) ->
            (match List.Assoc.find spec.binding_user_facing_pkg
                     ~equal:Poly.equal Canary_lang.OCaml with
             | None -> []
             | Some pkg -> ocaml_install_summaries pkg)
        | Fetch (Binding Python) ->
            (match List.Assoc.find spec.binding_user_facing_pkg
                     ~equal:Poly.equal Canary_lang.Python with
             | None -> []
             | Some pkg -> python_install_inspect pkg)
        | _ -> []
  in
  (* spec.inspect is the explicit override (legacy, single-summary). When
     present, it wins and we skip auto generation entirely. *)
  let attach_inspect ~parent_tag ~action ?loc base_step =
    match spec.inspect action loc with
    | Some c ->
        [ base_step;
          mk_inspect ~parent_tag ~action ~tag_suffix:"_inspect"
            ~base_name:"inspect" ~inspect_cmd:c ]
    | None ->
        let summaries = auto_binding_summaries action in
        if List.is_empty summaries then [ base_step ]
        else
          base_step ::
          List.map summaries ~f:(fun (tag_suffix, base_name, inspect_cmd) ->
              mk_inspect ~parent_tag ~action ~tag_suffix ~base_name ~inspect_cmd)
  in
  (* scan_source: verifies api_source header/binding claims post-fetch.
     Shares fetch_source's output dir; configure/build depend on it. *)
  let mk_scan_source ~fetch_tag scan_cmd =
    let check_post ~output_dir ~variant_key =
      has_file ~output_dir (Canary_basic.variant_file ~variant_key "scan.ok")
    in
    mk_step ~root ~project ~cache_project ~tag:"scan_source"
      ~output_tag:fetch_tag ~action:(Fetch Source)
      ~deps:[ fetch_tag ]
      ~cmd:scan_cmd ~check_post ~expectation:Expect_success
      ~symbol_check:None ~disabled_contracts:spec.disabled_contracts ()
  in
  let raw_steps = List.concat_map (store_actions ~langs) ~f:(fun action ->
      let tag = string_of_action action in
      if Hashtbl.mem seen tag then []
      else
        (* Probe Lib / Probe Binding: expand per-location entries.
           Single entry uses the canonical action tag; multiple expand to per-location tags. *)
        match action with
        | Probe_lib ->
            Hashtbl.set seen ~key:tag ~data:true;
            List.concat_map spec.probe_lib ~f:(fun (loc, cmd) ->
                let ptag = if List.length spec.probe_lib = 1 then tag
                           else tag_of_probe_lib_location loc in
                let deps = deps_of_probe_lib_entry spec loc in
                let check_post = match spec.check_post action with
                  | Some cp -> cp
                  | None -> fun ~output_dir ~variant_key ->
                      has_file ~output_dir
                        (Canary_basic.variant_file ~variant_key "probe.log")
                in
                let expectation = spec.expectation action (Some loc) in
                let symbol_check = spec.symbol_check action in
                let base = mk_step ~root ~project ~cache_project ~tag:ptag ~action
                  ~deps ~cmd ~check_post ~expectation ~symbol_check ~disabled_contracts:spec.disabled_contracts () in
                attach_inspect ~parent_tag:ptag ~action ~loc base)
        | Probe_binding lang ->
            Hashtbl.set seen ~key:tag ~data:true;
            let entries = List.filter spec.probe_binding
                ~f:(fun (l, _, _) -> Poly.equal l lang) in
            List.concat_map entries ~f:(fun (_, loc, cmd) ->
                let ptag = if List.length entries = 1 then tag
                           else tag_of_probe_location ~lang loc in
                let deps = deps_of_probe_entry spec ~lang loc in
                let check_post = match spec.check_post action with
                  | Some cp -> cp
                  | None -> fun ~output_dir ~variant_key ->
                      has_file ~output_dir
                        (Canary_basic.variant_file ~variant_key "probe.log")
                in
                let expectation = spec.expectation action (Some loc) in
                let symbol_check = spec.symbol_check action in
                let base = mk_step ~root ~project ~cache_project ~tag:ptag ~action
                  ~deps ~cmd ~check_post ~expectation ~symbol_check ~disabled_contracts:spec.disabled_contracts () in
                attach_inspect ~parent_tag:ptag ~action ~loc base)
        | _ ->
            match script_of_action spec action with
            | None -> []
            | Some cmd ->
                Hashtbl.set seen ~key:tag ~data:true;
                let base = mk_one ~tag ~action ~deps:(deps_of_action spec action) ~cmd in
                let steps = attach_inspect ~parent_tag:tag ~action base in
                (* Emit scan_source after fetch_source when wired *)
                (match action, spec.scan_source with
                 | Fetch Source, Some scan_cmd
                   when not (Hashtbl.mem seen "scan_source") ->
                     Hashtbl.set seen ~key:"scan_source" ~data:true;
                     steps @ [ mk_scan_source ~fetch_tag:tag scan_cmd ]
                 | _ -> steps))
  in
  (* Resolve check_pre against actual sibling output_dirs.
     Step constructors set check_pre = "every dep tag's output_dir
     exists", but a dep's output_dir may differ from its tag's directory
     when output_tag is set (e.g. scan_source writes inside fetch_source/).
     Here we have the full step list, so re-bind each check_pre to look up
     deps via a tag → output_dir map. *)
  let by_tag = Hashtbl.create (module String) in
  List.iter raw_steps ~f:(fun s -> Hashtbl.set by_tag ~key:s.tag ~data:s.output_dir);
  List.map raw_steps ~f:(fun s ->
      let check_pre () =
        List.for_all s.deps ~f:(fun dep ->
            match Hashtbl.find by_tag dep with
            | Some out -> Stdlib.Sys.file_exists out
            | None ->
                (* Dep tag not in step list (filtered out by langs/spec).
                   Fall back to the old tag-based path. *)
                Stdlib.Sys.file_exists
                  (output_dir_for ~root ~project ~tag:dep))
      in
      { s with check_pre })

