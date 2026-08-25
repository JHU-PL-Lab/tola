(** tiny-full — the PROJECT (peer of [canary_project_z3] / [_sqlite]).

    The mutation-agnostic general project over tiny's cached artifacts
    (ssot §4.2.5). The split this module realizes:

    - the **factory** ([Canary_tiny_scenario] + [Canary_tiny_workspace]) MAKES
      the ingredients — every artifact variant as a cached artifact — and holds
      the tiny1 oracle (`canary tiny run`);
    - this **project_spec** DECLARES those ingredients + the scenario space;
    - the **runner** ([canary_main]) EXPLORES them via `canary action tiny-full`:
      enumerate → runner_spec (which assembles tiny's vendored tree) → run, with
      canary computing the expectation ([expectation_agnostic]).

    A project DECLARES; canary COMPUTES. The declarative surface is the
    [project_run] below ([tiny_full_run]); `action tiny-full` runs it through
    the generic [canary_main.run_project_run] — the SAME path sqlite uses (the
    convergence: one runner, per-project specs). The scenario set is NOT
    declared here: [pr_spec] is the static declaration and the general
    algorithm ([Canary_project_run.scenarios_of]) enumerates it. Remaining
    convergence work: relocate the spec internals, which physically live in
    the factory file for now (tightly coupled to its [engine_*] data); the
    multi-bad [tiny_full_combinations] stay tiny-factory machinery. *)

module TS = Canary_tiny_scenario

(* Project identity IS [tiny_full_run] below (SSOT §6.1 top level; A6: the
   never-read [Canary_project.project] bundle was deleted 2026-08-05). The
   contract firing table stays where it is consumed:
   [TS.tiny_contract_bindings] → [tiny_expectation_agnostic]. *)

(* ── the declarative project surface ── *)

(* ── binding declarations (M2 step 4, mechanism_payload.md) ──
   One typed record per binding: mechanism label + facts. The facts are
   what the binding IS; the analysis (watchlists, contract rows, probe)
   stays on canary's side. c_api/native are shared across tiny's three
   bindings — a project factor hoists them. The declarations physically
   live in the factory file ([TS.tiny_binding_decls] — its
   [make_base_runner_spec] consumes them via
   [Canary_binding_templates]); re-exported here for the project
   interface. *)

let tiny_binding_decls = TS.tiny_binding_decls

(** tiny-full's declared artifact set (source, lib, the three binding
    instances, both app wirings) — all [Vendored]. *)
let artifacts : Canary_artifact.artifact_info list = TS.tiny_full_artifacts

(** The mutation-agnostic spec: which artifacts, and the bad-variant catalogue
    (tags) per artifact. *)
let spec : TS.tiny_full_spec = TS.tiny_full_spec

(** tiny-full's GENERAL declared spec (NO mutations): the good baseline +
    built-lib variants all fall out of enumerating this — the general axes,
    like sqlite. The mutation faults (flavor-1) are tiny1's oracle
    (`canary tiny run`), decoupled from tiny-full;
    [TS.tiny_full_assignments]/[TS.tiny_full_combinations] remain in the
    tiny-factory for tiny1 / a future post-process. *)
let general_spec : Canary_artifact.project_spec =
  TS.tiny_full_general_spec spec

(** The expectation canary uses: derived by inspection alone (no oracle) —
    canary decides per step whether to expect a failure. *)
let expectation_agnostic
  : Canary_basic.action -> Canary_store.location option ->
    Canary_step_model.step_expectation
  = TS.tiny_expectation_agnostic

(* ── the run entry consumed by `action tiny-full` ── *)

(* ── tiny-full's implementation of the [Canary_project_run.project_run]
   interface (shared with sqlite; the generic runner consumes it) ── *)
type project_run = Canary_project_run.project_run

(** The cached-artifact overlays a bad assignment asks for: each [Bad]-quality
    placement → (artifact key, tag). All-good ⇒ []. The general half is
    [Canary_enumerate.bad_placements]; only the tag → cache-key mapping is
    tiny's. *)
let overlays_of (a : Canary_artifact.assignment) : (string * string) list =
  Base.List.filter_map (Canary_enumerate.bad_placements a) ~f:(fun (_, tag) ->
      Base.Option.map (Canary_tiny_workspace.artifact_key_of_tag tag)
        ~f:(fun key -> (key, tag)))

(* THE artifact table (typed data, A8; 2026-08-06: identity + provider per
   row — the old separate [tiny_providers] assoc merged in; the real
   vendored layout — canary_tiny_workspace.ml paths). All Vendored (the
   lib is a Cached built artifact); tiny-full is agnostic to tiny's
   prepare layer beyond these paths. Built from the declared artifact list
   via a per-kind map so the artifact set stays single-source. *)
let tiny_artifact_table : Canary_project_spec.artifact_row list =
  let provider_of_kind : Canary_basic.artifact_kind ->
      Canary_store_config.provider option = function
    | Canary_basic.Source ->
        Some (Canary_store_config.Vendored "canary/examples/tiny/c (C source + include)")
    | Canary_basic.Lib ->
        Some (Canary_store_config.Cached "_out/canary/tiny/scenarios/_cache (libtiny.so.1)")
    | Canary_basic.Binding Canary_lang.OCaml ->
        Some (Canary_store_config.Vendored "canary/examples/tiny/ocaml (cstubs source)")
    | Canary_basic.Binding Canary_lang.Python ->
        Some (Canary_store_config.Vendored "canary/examples/tiny/python_cext/tiny_cext (cext + ctypes)")
    | Canary_basic.App ->
        Some (Canary_store_config.Vendored "tiny probe example (assembled)")
    | _ -> None
  in
  Base.List.map artifacts ~f:(fun id ->
      (* tiny is the in-tree witness: every artifact is vendored from the
         repo by construction, which is the whole point of it. The path
         each one sits at was [provider_of_kind]'s [Vendored] payload and
         is now the [Vendored_at] the row declares. *)
      let at =
        match provider_of_kind (Canary_artifact.kind_of id) with
        | Some (Canary_store_config.Vendored p) -> p
        | _ -> "canary/examples/tiny (in-tree witness)"
      in
      Canary_project_spec.artifact_row ~artifact:id
        ~universe:
          [ (Canary_store_config.Vendored_at at, [ Canary_basic.Stable ]) ]
        ())

(** tiny-full as a [project_run] the generic runner consumes. Its [pr_runner_spec]
    ASSEMBLES tiny's vendored cached artifacts into a tree (all-good ⇒ the witness
    base; built-lib ⇒ compiled source tree; bad ⇒ overlay) and returns the base
    spec over that tree with the AGNOSTIC expectation. The assemble step is the
    tiny-factory concern ([Canary_tiny_workspace]) — it lives INSIDE the runner_spec
    closure and the general interface has no pre-placement hook for it. tiny-full
    ignores the runner-provided [workspace] dir (it runs over its assembled tree);
    a real project (sqlite) builds into that dir instead. *)
(* ── dispatch / realization split ──
   [scenario_case] is the PURE dispatch result — inspectable data computed
   from enumeration coordinates only (general reads:
   [Canary_enumerate.provision_of]/[channel_of]/[provided]/[bad_placements]);
   [realize] maps a case to its realization: WHICH tiny-factory materializer
   assembles the tree + the base command templates. [pr_runner_spec] is just
   their composition — no placement digging inside it. *)
type scenario_case =
  | Base                               (* the all-vendored good witness *)
  | Built_lib of Canary_basic.channel  (* lib compiled from source @channel *)
  | Dev_binding of { lib_built : Canary_basic.channel option }
      (* dev OCaml cstubs binding (the tiny_scale consumer — the mismatch
         axis); [lib_built = Some ch] when the lib is also Built @ch,
         [None] = over the vendored stable lib *)
  | Assembled of (string * string) list
      (* bad-overlay scenarios: (cache key, tag) — tiny1/factory machinery *)

let dispatch (a : Canary_artifact.assignment) : scenario_case =
  let module E = Canary_enumerate in
  let a_oc = Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs in
  match overlays_of a with
  | (_ :: _) as overlays -> Assembled overlays
  | [] ->
      let lib_built =
        match Canary_enumerate.provision_of a Canary_artifact.a_lib with E.Built -> true | _ -> false
      in
      let binding_dev =
        Canary_enumerate.provided a a_oc
        && (match Canary_enumerate.channel_of a a_oc with
            | Canary_basic.Dev -> true
            | Canary_basic.Stable -> false)
      in
      if binding_dev then
        Dev_binding
          { lib_built =
              (if lib_built then Some (Canary_enumerate.channel_of a Canary_artifact.a_lib) else None) }
      else if lib_built then Built_lib (Canary_enumerate.channel_of a Canary_artifact.a_lib)
      else Base

let realize (c : scenario_case) : Canary_step_builder.runner_spec =
  (* the lib's channel drives the channel-aware build (Dev ⇒ -DTINY_DEV +
     dev version script) on the Built path; Stable otherwise. *)
  let channel =
    match c with
    | Built_lib ch | Dev_binding { lib_built = Some ch } -> ch
    | Base | Dev_binding { lib_built = None } | Assembled _ ->
        Canary_basic.Stable
  in
  (* WHICH materializer assembles the tree (tiny-factory; labels carry the
     axes so distinct cases get distinct trees + variant_ids — cache.md). *)
  let assembled =
    match c with
    | Base -> Some (Canary_tiny_workspace.witness_base_workspace ())
    | Built_lib ch ->
        Canary_tiny_workspace.materialize_built_lib
          ~label:("positive-built-lib-" ^ Canary_basic.string_of_channel ch)
    | Dev_binding { lib_built } ->
        let lib_desc =
          match lib_built with
          | Some ch -> "built-lib-" ^ Canary_basic.string_of_channel ch
          | None -> "vendored-lib"
        in
        Canary_tiny_workspace.materialize_dev_binding
          ~lib_built:(Base.Option.is_some lib_built)
          ~label:("dev-binding-over-" ^ lib_desc)
    | Assembled overlays ->
        let label =
          Base.String.concat ~sep:"+"
            (Base.List.map overlays ~f:(fun (id, t) -> id ^ "#" ^ t))
        in
        Canary_tiny_workspace.materialize_assembled ~overlays ~label
  in
  let tree =
    match assembled with
    | Some w -> w
    | None -> failwith "tiny-full: workspace assembly failed"
  in
  let lib_filename =
    Canary_tiny_workspace.detect_lib_filename ~workspace:tree
  in
  let stores = TS.stores_of_workspace ~lib_filename ~workspace_root:tree () in
  (* A9-step-2: tiny-full uses the action-variant table like the other three
     projects, but its commands are all workspace-specific Raw closures (gcc,
     dune, nm, python3). [make_base_runner_spec] produces the runner_spec; the
     table wraps it so tiny-full participates in the mechanism. Template
     extraction can follow when a second project shares one of these commands. *)
  { (TS.make_base_runner_spec ~channel ~stores ()) with
    Canary_step_builder.expectation = expectation_agnostic }

let tiny_full_run : project_run =
  { pr_name = "tiny-full";
    pr_artifacts = tiny_artifact_table;
    (* the STATIC declaration (good baseline + built-lib axes; no mutations —
       those are tiny1's oracle). The generic runner enumerates it
       ([Canary_project_run.scenarios_of]) — like sqlite, a positive-only
       general project_run with no scenario list of its own. *)
    (* tiny-full ignores the runner-provided [workspace]: its realizations
       assemble the vendored tree themselves (tiny-factory concern). *)
    pr_runner_spec =
      (fun a ~workspace:_ () -> realize (dispatch a));
    (* the ocaml_dev cstubs variant is the DESIGNED forward probe: it
       requires the dev-only [tiny_scale], so deploying it over a stable lib
       reveals the forward mismatch (shipped 2026-08-05; status §B). No
       backward probe in the general run — backward breaks are tiny1's
       mutations (Bs.3/Bs.4). *)
    pr_mismatch_probes =
      [ ( Canary_artifact.a_binding Canary_lang.OCaml Canary_mechanism.Cstubs,
          Canary_basic.Dev, Canary_basic.Forward ) ];
    pr_wrapper_pkgs = [];
    (* the in-tree witness declares its api_source HERE (its source row is
       Vendored, not repo-carried) — the spec audit reads this field. *)
    pr_api_source = Some Canary_tiny_scenario.tiny_api_source;
    pr_binding_decls = TS.tiny_binding_decls;
    pr_raw_build_overrides = [];
    pr_tier = Canary_project_run.Light }

(* ── THIN subset run (ssot §4.2 config level = Subset) ──
   The thin slice is a RUNNER policy ([Canary_project_run.thin_policy] —
   version [Subset [Stable]]) applied to the SAME declared spec; nothing
   thin-specific lives in the project. This record only renames the run so
   its cache never clashes with the full run's; `action/spec tiny-full
   --thin` pairs it with [thin_policy]. *)
let tiny_full_thin_run : project_run =
  { tiny_full_run with pr_name = "tiny-full-thin" }

(* ── tiny1-via-general-path bridge (2026-08-09) ──
   Convert a tiny1 scenario into a [project_run] the general pipeline
   consumes. The mutation is baked into the pre-built workspace —
   canary's project spec knows nothing about it: all artifacts are
   Vendored@Stable, the expectation is agnostic.

   Call [run_project_run] on the result to run canary's detection over
   the scenario workspace; compare with the oracle
   ([TS.expectation_of_entry]) to verify the agnostic detection matches
   the oracle prediction.

   Requires the workspace to be pre-built ([tiny prepare <name>]). *)
let project_run_of_tiny1 ~(name : string) : project_run =
  let workspace = Canary_tiny_workspace.cache_workspace_of ~scenario:name in
  let stores = TS.stores_of_workspace ~workspace_root:workspace () in
  let lib_filename = Canary_tiny_workspace.detect_lib_filename ~workspace in
  let stores = { stores with TS.lib_filename } in
  { pr_name = [%string "tiny1/%{name}"];
    pr_artifacts = tiny_artifact_table;
    pr_runner_spec =
      (fun _a ~workspace:_ () ->
        { (TS.make_base_runner_spec ~stores ()) with
          Canary_step_builder.expectation = expectation_agnostic });
    pr_mismatch_probes = [];
    pr_wrapper_pkgs = [];
    pr_api_source = Some Canary_tiny_scenario.tiny_api_source;
    pr_binding_decls = TS.tiny_binding_decls;
    pr_raw_build_overrides = [];
    pr_tier = Canary_project_run.Light }

(* ── tiny1 run helpers (moved from bin 2026-08-10) ── *)

let run_tiny_scenario ?workspace_override ?(agnostic = false) ~root ~failfast
    ~cache_path ~(cli_disabled : Canary_compat.contract_id list) ~name () =
  let name = TS.name_of_string name in
  let workspace =
    match workspace_override with
    | Some w -> w
    | None ->
        let workspace = Canary_tiny_workspace.cache_workspace_of ~scenario:name in
        if not (Stdlib.Sys.file_exists workspace) then begin
          if not (Stdlib.Sys.file_exists Canary_tiny_workspace.baseline_workspace)
          then Canary_tiny_workspace.run_baseline ();
          if not (String.equal name "baseline") then
            Canary_tiny_workspace.run_prepare ~name
        end;
        workspace
  in
  let mutated_stores = TS.stores_of_workspace ~workspace_root:workspace () in
  let spec = TS.runner_spec_of_name ~mutated_stores name in
  let spec = { spec with Canary_step_builder.disabled_contracts =
      spec.Canary_step_builder.disabled_contracts @ cli_disabled } in
  let spec =
    if agnostic then
      { spec with Canary_step_builder.expectation = expectation_agnostic }
    else spec
  in
  let project = "tiny/" ^ name in
  let steps =
    Canary_step_builder.derive_steps ~root ~project
      ~langs:Canary_lang.[ OCaml; Python ] spec
  in
  let _ =
    Canary_run_info.run_project ~failfast ~run_info:
      (Canary_run_info.mk_run_info ~project:"tiny" ~version:"in_tree"
         ~ref_:"" ~source:"prebuilt" ~extra:[] steps)
      ?cache_path ~root ~project steps
  in
  ()

let run_assembled ~root ~failfast ~tag : unit =
  match TS.find_by_id tag with
  | None -> Fmt.pr "unknown tag: %s (see `tiny assemble-check`)\n" tag
  | Some s ->
      let key = Option.value (Canary_tiny_workspace.artifact_key_of_tag tag)
          ~default:"lib" in
      let label = key ^ "#" ^ tag in
      (match Canary_tiny_workspace.materialize_assembled
               ~overlays:[ (key, tag) ] ~label with
       | None -> Fmt.pr "assemble failed for %s\n" label
       | Some assembled ->
           Fmt.pr "assembled tree: %s\n" assembled;
           run_tiny_scenario ~workspace_override:assembled ~root ~failfast
             ~cache_path:None ~cli_disabled:[] ~name:s.scenario.name ();
           Fmt.pr "\n. tiny-full assembled run [%s %s -> %s]: %s\n"
             tag s.scenario.name key
             (Canary_project_run.scenario_status_of_run_state ()))

let run_built_lib ~root : unit =
  match Canary_tiny_workspace.materialize_built_lib
          ~label:"lib-built-from-src" with
  | None -> Fmt.pr "materialize (source-only lib) failed\n"
  | Some ws ->
      Fmt.pr "source-only-lib tree: %s\n  (no pre-built libtiny.so)\n" ws;
      (try run_tiny_scenario ~workspace_override:ws ~agnostic:true ~root
             ~failfast:false ~cache_path:None ~cli_disabled:[]
             ~name:"app_over_binding_ocaml" ()
       with _ -> ());
      Fmt.pr "\n. tiny-full built-lib (provision=Built): %s\n"
        (Canary_project_run.scenario_status_of_run_state ())

let run_assembled_combo ~root ~tags : unit =
  let overlays =
    Stdlib.List.filter_map (fun tag ->
        match Canary_tiny_workspace.artifact_key_of_tag tag with
        | Some key -> Some (key, tag)
        | None -> None) tags in
  if List.length overlays <> List.length tags then
    Fmt.pr "some tags unresolved; check `tiny assemble-list`\n"
  else
    let label = String.concat "+"
        (List.map (fun (key, t) -> key ^ "#" ^ t) overlays) in
    match Canary_tiny_workspace.materialize_assembled ~overlays ~label with
    | None -> Fmt.pr "assemble failed for %s\n" label
    | Some ws ->
        Fmt.pr "assembled combo tree: %s\n" ws;
        run_tiny_scenario ~workspace_override:ws ~agnostic:true ~root
          ~failfast:false ~cache_path:None ~cli_disabled:[]
          ~name:"app_over_binding_ocaml" ();
        Fmt.pr "\n. tiny-full combo [%s]: %s\n" label
          (Canary_project_run.scenario_status_of_run_state ())
