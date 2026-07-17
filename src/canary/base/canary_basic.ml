open Base
open Canary_store

(* ── Type definitions ── *)

type runner_os = Ubuntu | MacOS
type probe_action = Compile_example | Run_example
type compile_mode = Native | Bytecode

(** Coarse artifact grouping used for action dispatch (rule selection in
    {!Canary.store_rules}). Each constructor here corresponds to a
    {i group} of fine-grained artifact roles from the surface-theory
    vocabulary used in [doc/canary/research/surface_theory.md] §2.1
    and [doc/canary/research/tiny.md] "Artifact inventory":

    - [Source]        — pre-build C sources (no surface; build input for s2).
                        Canonical: [source_native.*]. Aliased as [n0..] in tiny.
    - [Headers]       — public C headers carrying s1. Canonical:
                        [header_native.h]. Aliased as [n3] in tiny.
    - [Lib]           — compiled native library carrying s2. Canonical:
                        [lib_native.so]. Aliased as [n4] in tiny.
    - [Binding lang]  — a whole language binding, internally a chain of
                        roles {i stub} (s3) → {i user} (s4) → {i compiled}
                        (s5). For tiny's OCaml binding this group is the
                        union of bo1..bo7; for cext it's bpe1..bpe3; for
                        ctypes bpc1..bpc2 (no s5 — pure-Python dynamic).
    - [App]           — consumer executable / probe. No surface; runtime
                        carrier of s6 ([runtime_trace]).

    Surface-theory's fine vocabulary refines [Binding lang] but does not
    replace this coarse grouping — action dispatch (fetch/build/pack/probe)
    still operates at the [Binding lang] grain. The fine roles surface in
    inspector/comparator code under canonical names. *)
(* Binding language vocabulary lives in [Canary_lang] — a sibling file
   so [Canary_store] can use [lang] without circular import via
   [Canary_basic]. *)

type artifact_kind = Source | Headers | Lib | Binding of Canary_lang.lang | App

let kind_order = function
  | Source -> 0 | Headers -> 1 | Lib -> 2 | Binding _ -> 3 | App -> 4

(** A concrete artifact instance: a [kind] tag plus an identifier ([name])
    and a [location] (filesystem path / package coordinates).

    Naming convention for [name]: prose-style, mirrors the canonical-name
    forms from surface theory where applicable. For [Lib] artifacts, [name]
    is the project name (e.g. ["libz3"]); for [Binding lang], it's the
    binding's user-facing package label (e.g. ["z3ml"], ["z3-solver"]). *)
type artifact = { kind : artifact_kind; name : string; location : location }

(** Build-graph node: an artifact plus how it was produced ([built_from])
    and what it needs at runtime ([runtime_dep]). The graph is materialised
    by {!Canary.run_graph}. *)
type artifact_node = {
  a_kind : artifact_kind;
  a_name : string;
  origin : location;
  a_location : location;
  built_from : artifact_node option;
  runtime_dep : artifact_node option;
}

type artifact_op = Compile | Fetch | Pack | Test

let all_compile_modes = [ Bytecode; Native ]
let all_probe_actions = [ Compile_example; Run_example ]

let all_cc_and_modes =
  List.cartesian_product all_compile_modes all_probe_actions

type condition = On_runner_os of runner_os

type project_spec = {
  root : string;
  version : string;
  commit : string;
  bindings : (Canary_lang.lang * package_manager) list;
  (* graph capabilities *)
  system_pm : package_manager;
  has_source : bool;
  has_system_pkg : bool;
  has_lang_pkg : bool;
  can_package : bool;
}

type cmdline = string

type step = {
  name : string;
  guard : condition option;
  shell : string option;
  env_fields : (string * string) list;
  requires : artifact list;
  produces : artifact list;
  action : cmdline;
}

(* ── Functions ── *)
(* Retired YAML/backend types (system_pkg, phase_kind, step_phase,
   job_spec, deploy_target, yaml_preamble_action, job, template_vars,
   backend_scripts, canary_paths, canary_backends, canary_opam,
   canary_config) moved to [doc/_legacy_code/canary_yaml_backend.ml] on
   2026-06-01. They have no live callers — only canary_dead_code.ml
   consumed them. *)

(** Stringify an {!artifact_kind} for action tags and log output. Output
    strings map to surface-theory canonical-name groups:

    - ["source"]         ↔ [source_native.*] group
    - ["headers"]        ↔ [header_native.h] (s1)
    - ["lib"]            ↔ [lib_native.so] (s2)
    - ["<lang>_binding"] ↔ the binding chain
                           {i {stub,user,compiled}_binding_<lang>.*} for that
                           language. E.g. ["ocaml_binding"] covers tiny's
                           bo1..bo7. ["python_binding"] covers the cext
                           {i and} ctypes mechanisms unless a [mechanism]
                           subtype refines later.
    - ["app"]            ↔ consumer / probe (no surface; runtime carrier
                           of s6 [runtime_trace]). *)
let string_of_artifact_kind = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding lang -> [%string "%{Canary_lang.string_of_lang lang}_binding"]
  | App -> "app"


(* name_of_phase, name_of_job_spec, default_template_vars,
   mk_canary_config, project_yaml_path, project_shell_path,
   yaml_preamble_action (constructor), multiline, indent_block,
   resolve_backend_scripts, resolve_job_scripts, checkout_step,
   setup_step, checkout_and_setup_preamble, job_of_spec, make_job,
   pp_step, pp_job, dump_step, dump_job, check_file_exists_exn
   all moved to doc/_legacy_code/canary_yaml_backend.ml on 2026-06-01 —
   the live pipeline never called any of them. *)

let detect_distro () =
  match Stdlib.Sys.command "uname -s 2>/dev/null | grep -q Darwin" with
  | 0 -> MacOS_local
  | _ -> Wsl

let run_step ?guard ?shell ?(env_fields = []) ?(requires = []) ?(produces = [])
    ~name action =
  ({ name; guard; shell; env_fields; requires; produces; action } : step)

let mk_system_dep_steps ~name ~linux_cmd ~macos_cmd =
  [
    run_step ~name:[%string "%{name} (Linux)"] ~guard:(On_runner_os Ubuntu)
      ~shell:"bash" linux_cmd;
    run_step ~name:[%string "%{name} (macOS)"] ~guard:(On_runner_os MacOS)
      ~shell:"bash" macos_cmd;
  ]

let run_cmd ?(strict = true) cmd =
  Fmt.pr "[Command] %s@." cmd;
  let code = Stdlib.Sys.command cmd in
  Fmt.pr "[Command][Output]@.";
  if code <> 0 then
    let msg = [%string "Command failed (%{Int.to_string code}): %{cmd}"] in
    if strict then failwith msg else Fmt.pr "[Command][Warning] %s@." msg

let run_cmd_exn cmd = run_cmd ~strict:true cmd

(* ── Action rule vocabulary ──
   Lifted from action/canary.ml on 2026-06-01: [rule] and [version] are
   vocabulary primitives every layer (surface/, tool/, action/, backend/,
   projects/) names — the rule-as-a-type was action-graph-flavoured only
   incidentally. [action_rule] (the rule-plus-pools structure) and the
   diagram generators remain in action/canary.ml because they're the
   action graph proper. *)

type version = Dev | Stable

let version_suffix = function Dev -> "" | Stable -> "-stable"

(* Common version-list configurations *)
let single_version = [ Dev ]
let two_versions = [ Dev; Stable ]

(** App-flavored rules carry an [app_info] record so the app's
    binding language is explicit at the type level (no
    reach-into-belongs_to needed downstream). Record shape (not
    a bare [lang]) leaves room for future fields — helper name,
    build flags, etc. — without a second breaking change. *)
type app_info = {
  lang : Canary_lang.lang;
}

let string_of_app_info (a : app_info) : string =
  Canary_lang.string_of_lang a.lang

(** Rules are typed actions: each variant has implicit input/output sorts.
    Pools in the action graph are indexed by [artifact_kind], built
    incrementally by applying rules.

    [Probe] was formerly [Probe of artifact_kind] with [Probe App]
    lang-oblivious; split into three variants (2026-07-10) so
    every probe carries its target's language explicitly.
    [Build_app] was formerly nullary; now carries [app_info]. *)
type rule =
  | Configure
  | Scan_sources
      (** Project-specific step that inspects source files (typically
          producing typed-signature JSONs for c6/c7/c8). Placement in
          the dep graph is project-controlled — for hand-written
          bindings (tiny) it runs early after Configure; for
          generated bindings (z3) the project's spec overrides the
          dep so it runs after Build_lib (which generates the
          binding's source). The rule itself is structurally just
          "inspect source files"; the spec decides when those
          files are available. *)
  | Build_headers
  | Build_lib
  | Build_binding of Canary_lang.lang
  | Install_lib
  | Build_app of app_info
  | Fetch of artifact_kind
  | Publish of artifact_kind
  | Probe_lib
  | Probe_binding of Canary_lang.lang
  | Probe_app of app_info

let string_of_rule = function
  | Configure -> "configure"
  | Scan_sources -> "scan_sources"
  | Build_headers -> "build_headers"
  | Build_lib -> "build_lib"
  | Build_binding lang -> [%string "build_binding_%{Canary_lang.string_of_lang lang}"]
  | Install_lib -> "install_lib"
  | Build_app a -> [%string "build_app_%{string_of_app_info a}"]
  | Fetch (Binding lang) -> [%string "fetch_binding_%{Canary_lang.string_of_lang lang}"]
  | Fetch kind -> [%string "fetch_%{string_of_artifact_kind kind}"]
  | Publish (Binding lang) -> [%string "pack_binding_%{Canary_lang.string_of_lang lang}"]
  | Publish kind -> [%string "pack_%{string_of_artifact_kind kind}"]
  | Probe_lib -> "probe_lib"
  | Probe_binding lang -> [%string "probe_binding_%{Canary_lang.string_of_lang lang}"]
  | Probe_app a -> [%string "probe_app_%{string_of_app_info a}"]

let rule_of_string s =
  let module A = Canary_lang in
  let lang_of_str = function
    | "ocaml"  -> Some A.OCaml  | "python" -> Some A.Python
    | "cpp"    -> Some A.Cpp    | "rust"   -> Some A.Rust
    | "csharp" -> Some A.CSharp | "java"   -> Some A.Java
    | _ -> None
  in
  let try_binding prefix wrap =
    Option.bind (String.chop_prefix s ~prefix) ~f:(fun l ->
        Option.map (lang_of_str l) ~f:wrap)
  in
  match s with
  | "configure"     -> Some Configure
  | "scan_sources"  -> Some Scan_sources
  | "build_headers" -> Some Build_headers
  | "build_lib"     -> Some Build_lib
  | "install_lib"   -> Some Install_lib
  | "fetch_source"  -> Some (Fetch Source)
  | "fetch_headers" -> Some (Fetch Headers)
  | "fetch_lib"     -> Some (Fetch Lib)
  | "fetch_app"     -> Some (Fetch App)
  | "pack_lib"      -> Some (Publish Lib)
  | "probe_lib"     -> Some Probe_lib
  | _ ->
      try_binding "build_binding_" (fun l -> Build_binding l)
      |> Option.first_some (try_binding "build_app_" (fun l -> Build_app { lang = l }))
      |> Option.first_some (try_binding "fetch_binding_" (fun l -> Fetch (Binding l)))
      |> Option.first_some (try_binding "pack_binding_" (fun l -> Publish (Binding l)))
      |> Option.first_some (try_binding "probe_binding_" (fun l -> Probe_binding l))
      |> Option.first_some (try_binding "probe_app_" (fun l -> Probe_app { lang = l }))

(* ── Output Layout v3 helpers (inlined from canary_output_path.ml on
   2026-06-01, Phase 10c) ──────────────────────────────────────────────
   Centralises three derivations that must stay in sync:
     step_dir_of_tag : string → string   action-first directory path
     filename        : base, ext, variant_key → string
     variant_file    : existing filename → variant-keyed filename

   All three obey the same convention:
     - Binding tags use action-first grouping: "build_binding/ocaml"
     - variant_key="" → unchanged names (backward-compat for single-variant)
     - variant_key="X" → "base_X.ext" suffix *)

(* Map a step tag to its filesystem directory path relative to project_dir.
   Binding tags ("build_binding_ocaml", "probe_binding_python_pip", …) are
   grouped action-first:  verb_binding/<rest>  so that all variants of the
   same binding action land in a single parent directory.
   Non-binding tags are their own directory (unchanged). *)
let step_dir_of_tag tag =
  let verbs = [ "build"; "probe"; "fetch"; "pack" ] in
  match
    List.find_map verbs ~f:(fun verb ->
        let prefix = verb ^ "_binding_" in
        match String.chop_prefix tag ~prefix with
        | Some rest -> Some (verb ^ "_binding/" ^ rest)
        | None -> None)
  with
  | Some d -> d
  | None -> tag

(* Variant-qualified filename.
   variant_key = ""  → "base.ext"       (single-variant: unchanged)
   variant_key = "19" → "base_19.ext"   (multi-variant: type-first, version last) *)
let filename ~variant_key ~base ~ext =
  if String.is_empty variant_key then base ^ "." ^ ext
  else base ^ "_" ^ variant_key ^ "." ^ ext

(* Apply variant_key to an already-formed "base.ext" filename.
   Useful when the base name is not split (e.g., "probe.log" → "probe_19.log"). *)
let variant_file ~variant_key fname =
  if String.is_empty variant_key then fname
  else
    match String.rsplit2 fname ~on:'.' with
    | Some (base, ext) -> base ^ "_" ^ variant_key ^ "." ^ ext
    | None -> fname ^ "_" ^ variant_key
