open Base
open Canary_store
open Canary_basic
open Canary_toolchain

type project_config = {
  canary : canary_config;
  workflow_name : string;
  name : string;
  project : project_spec;
  ocaml : ocaml_tool_config;
  job_specs : job_spec list;
  deploy : deploy_target option;
  opam_template_bindings : (string * string) list;
}

let verify_of_phase (config : project_config) (phase : step_phase) =
  let name = [%string "Verify: %{name_of_phase phase}"] in
  match phase.kind with
  | Pm_install _system_pkg -> (
      match phase.location with
      | Pm _ ->
          let info = prebuilt_info_exn config.ocaml in
          verify_opam_install_spec_step ~name info.opam_package_spec
      | _ -> [])
  | Pm_install_local Opam ->
      let pkg = pkg_full config.ocaml.toolchain in
      verify_opam_install_step ~name pkg
  | Pm_install_local _ -> []
  | Cmake_buildgen _ | Cmake_build _ -> []
  | Probe_test _ -> []
  | Run_command _ -> []

let steps_of_phase (config : project_config) (phase : step_phase) =
  let name = name_of_phase phase in
  let action_steps =
    match phase.kind with
    | Pm_install _system_pkg -> (
        match phase.location with
        | Pm _ ->
            let info = prebuilt_info_exn config.ocaml in
            install_opam_package_spec_step ~name info.opam_package_spec
        | _ -> failwith "Pm_install: unsupported location")
    | Pm_install_local pm -> (
        match pm with
        | Opam ->
            [
              run_step ~name
                (install_local_cmd config.ocaml.toolchain
                   ~canary_contrib_rel:config.canary.paths.contrib_rel);
            ]
        | _ -> failwith "Pm_install_local: only Opam is currently supported")
    | Cmake_buildgen step | Cmake_build step -> [ step ]
    | Probe_test { lang } -> (
        match lang with
        | OCaml ->
            mk_ocaml_test_steps ~ocaml:config.ocaml
              ~binding_location:phase.location ()
        | Python ->
            let pkg = config.ocaml.ocaml.binding_lib_name in
            [
              run_step ~name
                [%string
                  {|env PYTHONPATH="build/python" python3 -S -c "import %{pkg}; print(%{pkg}.__file__)"|}];
            ]
        | _ -> failwith "Probe_test: unsupported lang")
    | Run_command { name = _; command } ->
        [ run_step ~name command ]
  in
  action_steps @ verify_of_phase config phase

let mk_node a_kind a_name ~origin ~location ?built_from ?runtime_dep () :
    artifact_node =
  { a_kind; a_name; origin; a_location = location; built_from; runtime_dep }

let string_of_artifact_kind = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding lang -> [%string "%{Canary_artifact_api.string_of_lang lang}_binding"]
  | App -> "app"

let rec node_tag (n : artifact_node) =
  let name = n.a_name in
  let base =
    [%string
      "%{string_of_artifact_kind n.a_kind}(%{name})@%{string_of_location \
       n.a_location}"]
  in
  let with_built =
    match n.built_from with
    | None -> base
    | Some dep -> [%string "%{base}(%{node_tag dep})"]
  in
  match n.runtime_dep with
  | None -> with_built
  | Some rt -> [%string "%{with_built}[rt=%{node_tag rt}]"]

(* ── Action rule ──
   Rules are typed actions: each variant has implicit input/output sorts.
   Pools are indexed by artifact_kind, built incrementally by applying rules.
   The rule list defines both the action chain and which pools get populated. *)

type version = Dev | Stable

let version_suffix = function Dev -> "" | Stable -> "-stable"

(* Version configurations *)
let single_version = [ Dev ]
let two_versions = [ Dev; Stable ]

type rule =
  | Configure
  | Build_headers
  | Build_lib
  | Build_binding of Canary_artifact_api.lang
  | Install_lib
  | Build_app
  | Fetch of artifact_kind
  | Publish of artifact_kind
  | Probe of artifact_kind

let string_of_rule = function
  | Configure -> "configure"
  | Build_headers -> "build_headers"
  | Build_lib -> "build_lib"
  | Build_binding lang -> [%string "build_binding_%{Canary_artifact_api.string_of_lang lang}"]
  | Install_lib -> "install_lib"
  | Build_app -> "build_app"
  | Fetch (Binding lang) -> [%string "fetch_binding_%{Canary_artifact_api.string_of_lang lang}"]
  | Fetch kind -> [%string "fetch_%{string_of_artifact_kind kind}"]
  | Publish (Binding lang) -> [%string "pack_binding_%{Canary_artifact_api.string_of_lang lang}"]
  | Publish kind -> [%string "pack_%{string_of_artifact_kind kind}"]
  | Probe (Binding lang) -> [%string "probe_binding_%{Canary_artifact_api.string_of_lang lang}"]
  | Probe kind -> [%string "probe_%{string_of_artifact_kind kind}"]

let rule_of_string s =
  let module A = Canary_artifact_api in
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
  | "build_headers" -> Some Build_headers
  | "build_lib"     -> Some Build_lib
  | "install_lib"   -> Some Install_lib
  | "build_app"     -> Some Build_app
  | "fetch_source"  -> Some (Fetch Source)
  | "fetch_headers" -> Some (Fetch Headers)
  | "fetch_lib"     -> Some (Fetch Lib)
  | "fetch_app"     -> Some (Fetch App)
  | "pack_lib"      -> Some (Publish Lib)
  | "probe_lib"     -> Some (Probe Lib)
  | "probe_app"     -> Some (Probe App)
  | _ ->
      try_binding "build_binding_" (fun l -> Build_binding l)
      |> Option.first_some (try_binding "fetch_binding_" (fun l -> Fetch (Binding l)))
      |> Option.first_some (try_binding "pack_binding_" (fun l -> Publish (Binding l)))
      |> Option.first_some (try_binding "probe_binding_" (fun l -> Probe (Binding l)))

type action_rule = {
  rules : rule list;
  pools : (artifact_kind * artifact_node list) list;
}

let pool_get ar kind =
  List.Assoc.find ar.pools ~equal:Poly.equal kind |> Option.value ~default:[]

(* Standard rule sets.
   ~langs: binding languages this project supports (external loop).
   Each lang gets its own Build_binding / Fetch / Publish / Probe rules. *)
let store_rules ~langs =
  [ Fetch Source; Configure; Build_headers; Fetch Headers; Build_lib; Install_lib; Fetch Lib ]
  @ List.concat_map langs ~f:(fun lang ->
      [ Build_binding lang; Fetch (Binding lang);
        Publish (Binding lang); Probe (Binding lang) ])
  @ [ Build_app; Fetch App; Publish Lib; Publish App; Probe Lib; Probe App ]

let make_action_rule ~rules ~versions ~name ~source () =
  let vs = version_suffix in
  let get pools kind =
    List.Assoc.find pools ~equal:Poly.equal kind |> Option.value ~default:[]
  in
  let add pools kind nodes =
    let existing = get pools kind in
    List.Assoc.add pools ~equal:Poly.equal kind (existing @ nodes)
  in
  let pools =
    List.fold rules ~init:[] ~f:(fun pools rule ->
        match rule with
        | Build_lib ->
            let nodes =
              List.map versions ~f:(fun v ->
                  mk_node Lib
                    (name ^ vs v)
                    ~origin:Build_tree ~location:Build_tree ())
            in
            add pools Lib nodes
        | Fetch kind ->
            let nodes =
              List.map versions ~f:(fun v ->
                  mk_node kind (name ^ vs v) ~origin:source ~location:source ())
            in
            add pools kind nodes
        | Build_binding lang ->
            let libs = get pools Lib in
            let nodes =
              List.concat_map versions ~f:(fun v ->
                  List.map libs ~f:(fun lib ->
                      mk_node (Binding lang)
                        (name ^ vs v)
                        ~origin:Build_tree ~location:Build_tree ~built_from:lib
                        ()))
            in
            add pools (Binding lang) nodes
        | Build_app ->
            (* App depends on OCaml binding by convention; take first Binding pool found *)
            let bindings =
              let ocaml_bindings = get pools (Binding OCaml) in
              if not (List.is_empty ocaml_bindings) then ocaml_bindings
              else List.concat_map Canary_artifact_api.[ OCaml; Python; Rust; Cpp; CSharp; Java ]
                     ~f:(fun l -> get pools (Binding l))
            in
            let libs = get pools Lib in
            let nodes =
              List.concat_map bindings ~f:(fun binding ->
                  List.map libs ~f:(fun runtime_lib ->
                      mk_node App name ~origin:Build_tree ~location:Build_tree
                        ~built_from:binding ~runtime_dep:runtime_lib ()))
            in
            add pools App nodes
        | Build_headers ->
            let nodes =
              List.map versions ~f:(fun v ->
                  mk_node Headers (name ^ vs v)
                    ~origin:Build_tree ~location:Build_tree ())
            in
            add pools Headers nodes
        | Configure | Install_lib | Publish _ | Probe _ -> pools)
  in
  { rules; pools }

let nodes_of_action_rule (ar : action_rule) =
  List.concat_map ar.pools ~f:snd
  |> List.dedup_and_sort ~compare:(fun a b ->
      String.compare (node_tag a) (node_tag b))

(* Human-readable label: "binding_ocaml" → "binding ocaml" *)
let label_of_artifact_kind k =
  String.tr ~target:'_' ~replacement:' ' (string_of_artifact_kind k)


(* ── Job path table ──
   Each artifact node in the pools has a provenance chain (built_from,
   runtime_dep) back to source or store. A job_path captures this chain
   as a flat record for tabular display and annotation.

   The table is the universal maximum enumeration: every structurally
   possible artifact from a rule list, independent of any project spec.
   Probe paths are derived from artifact paths (one probe per artifact). *)

type path_origin = Built | Fetched

type path_annotation = {
  description : string;     (* what this combination tests *)
  frequency : string;       (* common | rare | edge *)
  feasibility : string;     (* feasible | infeasible | tbd *)
}

type job_path = {
  path_id : string;
  target_kind : artifact_kind;
  origin : path_origin;
  depth : int;              (* number of actions to produce this artifact *)
  node : artifact_node;
  deps : (string * artifact_node) list;
  annotation : path_annotation;
}

let string_of_path_origin = function Built -> "build" | Fetched -> "store"

let path_origin_of_node (n : artifact_node) =
  if is_source_location n.origin then Built else Fetched

(* Build the action path string — the chain of actions from source to target.
   For build nodes: traces built_from chain. For fetch nodes: just "fetch".
   Probes append "→ probe_<kind>" at the end. *)
let rec action_path_of_node (n : artifact_node) =
  if not (is_source_location n.origin) then
    (* Fetched from store *)
    (match n.a_kind with
     | Binding lang -> [%string "fetch_binding_%{Canary_artifact_api.string_of_lang lang}"]
     | kind -> [%string "fetch_%{string_of_artifact_kind kind}"])
  else
    (* Built: trace the chain *)
    let build_action = match n.a_kind with
      | Headers -> "build_headers"
      | Lib -> "build_lib"
      | Binding lang -> [%string "build_binding_%{Canary_artifact_api.string_of_lang lang}"]
      | App -> "build_app"
      | Source -> "build_source"
    in
    let bf_path = match n.built_from with
      | None -> None
      | Some dep -> Some (action_path_of_node dep)
    in
    let rt_path = match n.runtime_dep with
      | None -> None
      | Some dep ->
          let rt_str = action_path_of_node dep in
          (* Only show rt if different from built_from's chain *)
          (match n.built_from with
           | Some bf ->
               (match bf.built_from with
                | Some bf_dep when String.equal (node_tag bf_dep) (node_tag dep) -> None
                | _ -> Some [%string "rt:%{rt_str}"])
           | None -> Some [%string "rt:%{rt_str}"])
    in
    let parts = List.filter_opt [ bf_path; rt_path ] in
    match parts with
    | [] -> [%string "fetch_source → %{build_action}"]
    | _ ->
        let inputs = String.concat parts ~sep:", " in
        [%string "%{inputs} → %{build_action}"]

(* Count the number of distinct actions in the provenance tree.
   Each node = 1 action (build or fetch). Dependencies add their depth.
   Built leaf nodes (no built_from, consuming source) include fetch_source.
   Shared nodes (e.g. same lib as built_from and runtime) counted once. *)
let rec node_depth (n : artifact_node) =
  let bf = match n.built_from with None -> 0 | Some d -> node_depth d in
  let rt = match n.runtime_dep with None -> 0 | Some d -> node_depth d in
  (* If runtime_dep = built_from's dep, don't double-count *)
  let shared =
    match n.built_from, n.runtime_dep with
    | Some bf_node, Some rt_node ->
        (match bf_node.built_from with
         | Some bf_dep when String.equal (node_tag bf_dep) (node_tag rt_node) ->
             node_depth rt_node
         | _ -> 0)
    | _ -> 0
  in
  (* Built leaf nodes include fetch_source as an implicit predecessor *)
  let fetch_source =
    if is_source_location n.origin
       && Option.is_none n.built_from
       && Option.is_none n.runtime_dep
    then 1 else 0
  in
  1 + bf + rt - shared + fetch_source

(* Derive annotation from the structural properties of a path *)
let annotate_path ~is_probe (node : artifact_node) : path_annotation =
  let origin = path_origin_of_node node in
  let kind = node.a_kind in
  if is_probe then
    let kind_s = string_of_artifact_kind kind in
    let orig_s = string_of_path_origin origin in
    { description = [%string "smoke-test %{kind_s} (%{orig_s})"];
      frequency = "common";
      feasibility = "feasible" }
  else
  match kind, origin with
  | Lib, Built ->
      { description = "build lib from source";
        frequency = "common"; feasibility = "feasible" }
  | Lib, Fetched ->
      { description = "lib from package manager";
        frequency = "common"; feasibility = "feasible" }
  | Binding _, Built ->
      let lib_origin = match node.built_from with
        | Some lib -> string_of_path_origin (path_origin_of_node lib)
        | None -> "?"
      in
      { description = [%string "build binding, lib from %{lib_origin}"];
        frequency = (if String.equal lib_origin "store" then "common" else "common");
        feasibility = "feasible" }
  | Binding _, Fetched ->
      { description = "binding from package manager";
        frequency = "common"; feasibility = "feasible" }
  | App, Built ->
      let bind_origin = match node.built_from with
        | Some b -> string_of_path_origin (path_origin_of_node b)
        | None -> "?"
      in
      let rt_origin = match node.runtime_dep with
        | Some r -> string_of_path_origin (path_origin_of_node r)
        | None -> "?"
      in
      let rt_matches_link =
        match node.built_from, node.runtime_dep with
        | Some bind, Some rt ->
            (match bind.built_from with
             | Some link_lib -> String.equal (node_tag link_lib) (node_tag rt)
             | None -> false)
        | _ -> false
      in
      let freq =
        if rt_matches_link then "common"    (* same lib for link and runtime *)
        else "important"                    (* version mismatch — key canary case *)
      in
      let desc =
        if rt_matches_link then
          [%string "app: bind(%{bind_origin}) + same rt lib"]
        else
          [%string "app: bind(%{bind_origin}) + rt(%{rt_origin}), version mismatch possible"]
      in
      { description = desc; frequency = freq; feasibility = "feasible" }
  | App, Fetched ->
      { description = "pre-built app from package manager";
        frequency = "common"; feasibility = "feasible" }
  | _ ->
      { description = ""; frequency = "tbd"; feasibility = "tbd" }

(* Extract job paths from action rule pools, sorted by depth.
   Probes are not separate rows — every artifact can be probed
   (probe = action_path + → probe_<kind>, depth = d+1). *)
let job_paths_of_action_rule (ar : action_rule) : job_path list =
  let counters = Hashtbl.create (module String) in
  let next_id prefix =
    let n = Hashtbl.find counters prefix |> Option.value ~default:0 in
    Hashtbl.set counters ~key:prefix ~data:(n + 1);
    [%string "%{prefix}%{Int.to_string (n + 1)}"]
  in
  let kind_prefix = function
    | Source -> "S" | Headers -> "H" | Lib -> "L" | Binding _ -> "B" | App -> "A"
  in
  let paths =
    List.concat_map ar.pools ~f:(fun (kind, nodes) ->
        List.map nodes ~f:(fun node ->
            let prefix = kind_prefix kind in
            let deps =
              (match node.built_from with
               | None -> []
               | Some dep -> [ ("built_from", dep) ])
              @ (match node.runtime_dep with
                 | None -> []
                 | Some rt -> [ ("runtime", rt) ])
            in
            { path_id = next_id prefix;
              target_kind = kind;
              origin = path_origin_of_node node;
              depth = node_depth node;
              node;
              deps;
              annotation = annotate_path ~is_probe:false node }))
  in
  List.sort paths ~compare:(fun a b ->
      let c = Int.compare a.depth b.depth in
      if c <> 0 then c else String.compare a.path_id b.path_id)

(* Find path_id for a node by matching node_tag *)
let path_id_of_node paths (n : artifact_node) =
  List.find_map paths ~f:(fun p ->
      if String.equal (node_tag p.node) (node_tag n) then Some p.path_id
      else None)
  |> Option.value ~default:"?"

(* A pattern row: one structural action pattern with version combo count *)
type pattern_row = {
  pat_id : string;
  pat_depth : int;
  pat_origin : string;
  pat_target : string;
  pat_action_path : string;
  pat_description : string;
  pat_freq : string;
  pat_versions : int;  (* number of version combos that instantiate this pattern *)
}

(* Group job paths by structural pattern (action_path, origin, target_kind)
   and produce one pattern_row per group. *)
let pattern_rows_of_paths (paths : job_path list) : pattern_row list =
  let counter = ref 0 in
  let next_id () = Int.incr counter; Int.to_string !counter in
  (* Group by structural key *)
  let groups = Hashtbl.create (module String) in
  List.iter paths ~f:(fun p ->
      let ap = action_path_of_node p.node in
      let key = [%string "%{string_of_path_origin (path_origin_of_node p.node)}:%{string_of_artifact_kind p.target_kind}:%{ap}"] in
      Hashtbl.update groups key ~f:(function
          | None -> (p, 1)
          | Some (rep, n) -> (rep, n + 1)));
  (* Sort by target kind (source→lib→binding→app), then depth, then action_path *)
  let sorted =
    Hashtbl.to_alist groups
    |> List.sort ~compare:(fun (_, (a, _)) (_, (b, _)) ->
           let c = Int.compare (kind_order a.target_kind) (kind_order b.target_kind) in
           if c <> 0 then c
           else let c = Int.compare a.depth b.depth in
           if c <> 0 then c
           else String.compare
               (action_path_of_node a.node)
               (action_path_of_node b.node))
  in
  List.map sorted ~f:(fun (_key, (rep, count)) ->
      { pat_id = next_id ();
        pat_depth = rep.depth;
        pat_origin = string_of_path_origin (path_origin_of_node rep.node);
        pat_target = string_of_artifact_kind rep.target_kind;
        pat_action_path = action_path_of_node rep.node;
        pat_description = rep.annotation.description;
        pat_freq = rep.annotation.frequency;
        pat_versions = count })

(* Pretty-print the pattern table (plain text) *)
let pp_job_path_table ppf (paths : job_path list) =
  let rows = pattern_rows_of_paths paths in
  Fmt.pf ppf "%-4s %s %-7s %-10s %-55s %-50s %-10s %s@."
    "id" "d" "origin" "target" "action_path" "description" "freq" "versions";
  Fmt.pf ppf "%s@." (String.make 190 '-');
  List.iter rows ~f:(fun r ->
      Fmt.pf ppf "%-4s %d %-7s %-10s %-55s %-50s %-10s %d@."
        r.pat_id r.pat_depth r.pat_origin r.pat_target r.pat_action_path
        r.pat_description r.pat_freq r.pat_versions)

(* Pretty-print the pattern table as a markdown table *)
let pp_job_path_table_md ppf (paths : job_path list) =
  let rows = pattern_rows_of_paths paths in
  Fmt.pf ppf "| id | d | origin | target | action_path | description | freq | versions |@.";
  Fmt.pf ppf "| --- | - | ------ | ------ | ----------- | ----------- | ---- | -------- |@.";
  List.iter rows ~f:(fun r ->
      Fmt.pf ppf "| %s | %d | %s | %s | %s | %s | %s | %d |@."
        r.pat_id r.pat_depth r.pat_origin r.pat_target r.pat_action_path
        r.pat_description r.pat_freq r.pat_versions)

(* ── Mermaid rendering of action_rule ──
   Derived directly from the rule list — no separate schema type needed.
   Each rule variant implies its inputs and outputs:
     Build_lib:     source → lib pool
     Build_binding: source + lib pool → binding pool
     Build_app:     binding pool + lib pool → app pool
     Fetch kind:    store → pool (uniform action node)
     Probe kind:    pool → test result *)

let node_id_of_kind k =
  [%string "%{string_of_artifact_kind k}_node"]

type node_status =
  | Done       (* expected success, confirmed *)
  | Done_fail  (* expected failure, confirmed *)
  | Failed     (* unexpected: expected success but failed, or expected failure but succeeded/mismatched *)
  | Skipped
  | Not_in_spec

(* Diagram display label for a surface-inspection step tag (ends in _summary or
   _stub_summary).  Converts the internal step tag to a concise `inspect_*`
   verb form that reads well at its position in the diagram without the full
   parent-action prefix.

   Examples:
     pack_binding_ocaml_summary      → inspect_ocaml
     pack_binding_ocaml_stub_summary → inspect_ocaml_stub
     probe_lib_summary               → inspect_lib
     probe_lib_staged_summary        → inspect_lib_staged
     fetch_binding_python_summary    → inspect_python *)
let inspect_label_of_tag tag =
  let stub = String.is_suffix tag ~suffix:"_stub_summary" in
  let base =
    if stub then String.chop_suffix_exn tag ~suffix:"_stub_summary"
    else String.chop_suffix_exn tag ~suffix:"_summary"
  in
  let subject =
    List.find_map
      [ "pack_binding_"; "probe_binding_"; "fetch_binding_"; "build_binding_"
      ; "pack_"; "probe_"; "fetch_"; "build_"; "install_"; "scan_" ]
      ~f:(fun pfx -> String.chop_prefix base ~prefix:pfx)
    |> Option.value ~default:base
  in
  if stub then [%string "inspect_%{subject}_stub"]
  else [%string "inspect_%{subject}"]

(* summary_rules : list of (parent rule, tag_suffix) pairs.
   - One pair per summary follow-up step that appears in the run.
   - Same rule can appear with multiple suffixes (e.g.
     Fetch (Binding OCaml) has both "_summary" — mli — and
     "_stub_summary" — c_stub).
   - The diagram emits one summary node per pair.

   step_ids : optional table from step tag to its step index (1-based,
   execution order). When supplied, action labels show all step indices
   that map to a given rule kind, like "probe_lib [3][4][5]" — useful
   when multiple step variants (apt / staged / build_tree) collapse into
   one schema-level node. Empty table → labels use a fresh sequential
   counter (legacy behaviour). *)
let mermaid_of_action_rule_schema ?status ?(has_scan = false) ?(chain_scan = false)
    ?(summary_rules : (rule * string) list = [])
    ?(step_ids : (string, int) Hashtbl.t option)
    ?(steps_by_rule_tag : (string, string list) Hashtbl.t option)
    ?(summary_tags_by_canonical : (string, string list) Hashtbl.t option)
    ?(expand_artifact : (artifact_kind * (string * string) list) option)
    ?(expand_probe_kinds : (artifact_kind * (string * string * string) list) list = [])
    ?(view_title : string option)
    ?(focal_predicate : (string -> bool) option)
    (rules : rule list) =
  let get_status tag = match status with
    | None -> None
    | Some tbl -> Hashtbl.find tbl tag
  in
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  let has_configure = List.exists rules ~f:(fun r ->
      match r with Configure -> true | _ -> false)
  in
  let fetch_kinds =
    List.filter_map rules ~f:(fun r -> match r with Fetch k -> Some k | _ -> None)
  in
  let build_rules =
    List.filter rules ~f:(fun r ->
        match r with
        | Build_headers | Build_lib | Build_binding _ | Build_app -> true
        | _ -> false)
  in
  let install_rules =
    List.filter rules ~f:(fun r ->
        match r with
        | Install_lib -> true
        | _ -> false)
  in
  let publish_kinds =
    List.filter_map rules ~f:(fun r ->
        match r with Publish k -> Some k | _ -> None)
  in
  let probe_kinds =
    List.filter_map rules ~f:(fun r ->
        match r with Probe k -> Some k | _ -> None)
  in
  (* Artifact pool kinds: derived from rules — includes Binding lang variants *)
  let artifact_pool_kinds =
    List.filter_map rules ~f:(fun r ->
        match r with
        | Build_headers | Fetch Headers -> Some Headers
        | Build_lib | Fetch Lib -> Some Lib
        | Build_binding lang | Fetch (Binding lang) -> Some (Binding lang)
        | Build_app | Fetch App -> Some App
        | _ -> None)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let all_pool_kinds = Source :: artifact_pool_kinds in
  let scan_nid = "A_scan_source" in
  (* Parent node id for a summary follow-up's incoming edge.
     Probe and Publish have their own action nodes; Fetch has no
     separate action node — the fetch ID is embedded in the artifact
     label — so the edge originates from the artifact pool node.
     Defined after kind_nid below as parent_action_nid_ex (expanded-aware). *)
  (* Summary nodes are uniquely identified by (parent rule, tag suffix).
     suffix is e.g. "_summary" or "_stub_summary". *)
  let summary_nid rule suffix =
    [%string "A_%{string_of_rule rule}%{suffix}"]
  in
  let summary_label rule suffix =
    (* e.g. fetch_binding_ocaml_stub_summary *)
    string_of_rule rule ^ suffix
  in
  let source_upstream =
    if chain_scan && has_scan then scan_nid else node_id_of_kind Source
  in
  (* Action labels: when [step_ids] + [steps_by_rule_tag] are supplied,
     each schema-level node lists ALL step indices that map to it
     (e.g. probe_lib [3][4][5] when there are apt/staged/build_tree
     variants). Slots without any matching step (not-in-spec) get just
     the name; standalone callers (no step info) fall back to a fresh
     sequential counter so they still get [N] labels. *)
  let have_step_info =
    Option.is_some step_ids && Option.is_some steps_by_rule_tag
  in
  let action_counter = ref 0 in
  let next_id () = Int.incr action_counter; !action_counter in
  let label_with_ids name rule_tag =
    let ids =
      match steps_by_rule_tag, step_ids with
      | Some by_tag, Some id_tbl ->
          (match Hashtbl.find by_tag rule_tag with
           | Some tags ->
               List.filter_map tags ~f:(Hashtbl.find id_tbl)
               |> List.sort ~compare:Int.compare
           | None -> [])
      | _ -> []
    in
    if List.is_empty ids then
      if have_step_info then name (* not-in-spec slot — no bracket *)
      else
        let n = next_id () in
        [%string "%{name} [%{Int.to_string n}]"]
    else
      let id_str =
        List.map ids ~f:(fun i -> [%string "[%{Int.to_string i}]"])
        |> String.concat ~sep:""
      in
      [%string "%{name} %{id_str}"]
  in
  let action_label name = label_with_ids name name in
  (* Direct tag lookup — for follow-up steps (scan_source, *_summary)
     that have a 1:1 step mapping but were excluded from the rule-tag
     bucket so they don't pollute parent labels. *)
  let direct_tag_label tag =
    let disp =
      if String.is_suffix tag ~suffix:"_summary"
      then inspect_label_of_tag tag else tag
    in
    match step_ids with
    | Some tbl ->
        (match Hashtbl.find tbl tag with
         | Some n -> [%string "%{disp} [%{Int.to_string n}]"]
         | None -> if have_step_info then disp else action_label disp)
    | None -> action_label disp
  in
  (* Helpers for expand_artifact support.
     When expand_artifact = Some (kind, [(vid, label),...]), the focused
     artifact kind is split into per-variant docs nodes instead of the
     single collapsed node used in the overview. *)
  let is_expanded kind =
    match expand_artifact with
    | Some (exp_kind, _) -> Poly.equal kind exp_kind
    | None -> false
  in
  let expand_vars () =
    match expand_artifact with Some (_, vs) -> vs | None -> []
  in
  let expand_variant_nid kind vid =
    [%string "%{string_of_artifact_kind kind}_%{vid}_node"]
  in
  (* Canonical node id for a kind: for the expanded kind, use the
     "canonical consumer" variant (staged > build_tree > first pm).
     For other kinds, fall back to the normal node id. *)
  let kind_nid kind =
    if is_expanded kind then begin
      let vs = expand_vars () in
      let vid =
        if List.exists vs ~f:(fun (v,_) -> String.equal v "staged") then "staged"
        else if List.exists vs ~f:(fun (v,_) -> String.equal v "build_tree") then "build_tree"
        else (match vs with (v,_) :: _ -> v | [] -> "default")
      in
      expand_variant_nid kind vid
    end else node_id_of_kind kind
  in
  (* The artifact variant node produced by a pack (Publish) step: the first
     PM-like variant (opam/pip/fetch) that is not the consumed build_tree/staged
     input. Returns None when the kind is not expanded or has no distinct produced
     variant (e.g. only one variant = build_tree). *)
  let pack_produced_nid kind =
    if is_expanded kind then
      let vs = expand_vars () in
      (* The variant consumed by build_tree → pack (i.e. the build_tree or staged
         variant that feeds into the pack action). Exclude it so we don't produce
         a self-loop when Python binding has only one PM variant. *)
      let consumed_vid =
        if List.exists vs ~f:(fun (v, _) -> String.equal v "staged") then "staged"
        else if List.exists vs ~f:(fun (v, _) -> String.equal v "build_tree") then "build_tree"
        else (match vs with (v, _) :: _ -> v | [] -> "default")
      in
      let pm_like = List.filter vs ~f:(fun (v, _) ->
          not (String.equal v "build_tree")
          && not (String.equal v "staged")
          && not (String.equal v "default")
          && not (String.equal v consumed_vid)) in
      match pm_like with
      | [(v, _)] -> Some (expand_variant_nid kind v)
      | _ -> None
    else None
  in
  (* Helpers for expand_probe_kinds support.
     When expand_probe_kinds = Some (kind, [(probe_tag, variant_id, label),...]),
     the focused probe kind is split into one pill node per variant instead of
     a single collapsed node. variant_id matches the artifact expand_artifact
     variant, enabling per-variant edge routing. *)
  let is_probe_expanded kind =
    List.exists expand_probe_kinds ~f:(fun (k, _) -> Poly.equal k kind)
  in
  (* A Publish summary is "inlined" into the pack action label when the binding
     probe for that kind is NOT expanded (i.e. we're in a non-binding-focused view).
     In that case no separate pill node or dashed edge is emitted for it. *)
  (* A summary is "inlined" (no pill node, IDs go into parent's label) when the
     artifact kind it belongs to is not expanded in this view.
     Covers Publish, Probe, and Fetch binding summaries.  Inlined summaries keep
     their status entry (for edge colouring) but lose the separate pill node. *)
  let is_inlined_summary rule =
    match rule with
    | Publish kind | Probe kind | Fetch kind -> not (is_probe_expanded kind)
    | _ -> false
  in
  (* Raw int IDs from steps_by_rule_tag for a given canonical rule name. *)
  let action_int_ids name =
    match steps_by_rule_tag, step_ids with
    | None, _ | _, None -> []
    | Some tbl, Some sids ->
        let tags = Option.value (Hashtbl.find tbl name) ~default:[] in
        List.filter_map tags ~f:(fun t -> Hashtbl.find sids t)
  in
  (* Raw int IDs for all summary entries of a rule — used when inlining. *)
  let summary_int_ids rule =
    List.concat_map summary_rules ~f:(fun (srule, suffix) ->
        if not (Poly.equal srule rule) then []
        else
          let canonical = string_of_rule rule ^ suffix in
          match summary_tags_by_canonical, step_ids with
          | None, _ | _, None -> []
          | Some stbc, Some sids ->
              let tags = Option.value (Hashtbl.find stbc canonical) ~default:[] in
              List.filter_map tags ~f:(fun t -> Hashtbl.find sids t))
  in
  (* Build an action label with action + summary IDs merged and sorted together. *)
  let action_label_with_summary name rule =
    let all_ids =
      (action_int_ids name @ summary_int_ids rule)
      |> List.sort ~compare:Int.compare
      |> List.map ~f:(fun n -> [%string "[%{Int.to_string n}]"])
      |> String.concat ~sep:""
    in
    name ^ (if String.is_empty all_ids then "" else " " ^ all_ids)
  in
  (* Formatted summary-only ID suffix — used for fetch artifact labels where the
     fetch action IDs are already embedded by label_with_ids. *)
  let inline_summary_ids rule =
    summary_int_ids rule
    |> List.sort ~compare:Int.compare
    |> List.map ~f:(fun n -> [%string "[%{Int.to_string n}]"])
    |> String.concat ~sep:""
  in
  let probe_expand_items kind =
    match List.find expand_probe_kinds ~f:(fun (k, _) -> Poly.equal k kind) with
    | Some (_, items) -> items
    | None -> []
  in
  (* parent_action_nid for summary edges: Fetch → artifact node (expanded-aware);
     Probe → first expanded probe node when probe is expanded. *)
  let parent_action_nid_ex rule =
    match rule with
    | Fetch kind -> kind_nid kind
    | Probe kind when is_probe_expanded kind ->
        (match probe_expand_items kind with
         | (first_tag, _, _) :: _ -> [%string "A_%{first_tag}"]
         | [] -> [%string "A_%{string_of_rule rule}"])
    | _ -> [%string "A_%{string_of_rule rule}"]
  in
  (* For a summary (rule, suffix), return a list of (node_id, tag, parent_nid) triples.
     When the probe kind is expanded and per-variant summary tags exist in step_ids,
     emit one triple per probe variant so every concrete action has a diagram node.
     Falls back to one canonical triple otherwise. *)
  let summary_item_triples rule suffix =
    let canonical =
      (summary_nid rule suffix, summary_label rule suffix, parent_action_nid_ex rule)
    in
    match rule with
    | Probe kind when is_probe_expanded kind && String.equal suffix "_summary" ->
        let variants = List.filter_map (probe_expand_items kind) ~f:(fun (probe_tag, _, _) ->
            let stag = probe_tag ^ "_summary" in
            let known = match step_ids with
              | Some sids -> Hashtbl.mem sids stag
              | None -> false
            in
            if known then
              Some ([%string "A_%{probe_tag}_summary"], stag, [%string "A_%{probe_tag}"])
            else None)
        in
        if List.is_empty variants then [ canonical ] else variants
    | _ -> [ canonical ]
  in
  (* Label for a canonical summary node in the overview (non-expanded) case.
     Looks up ALL concrete step tags that map to this canonical tag and shows
     all their IDs: e.g. "probe_lib_summary [18][20][22]". Falls back to
     direct_tag_label when no table is provided. *)
  let summary_all_ids_label canonical_tag =
    let disp = inspect_label_of_tag canonical_tag in
    match summary_tags_by_canonical, step_ids with
    | None, _ | _, None -> direct_tag_label canonical_tag
    | Some stbc, Some sids ->
        let concretes =
          Option.value (Hashtbl.find stbc canonical_tag) ~default:[canonical_tag]
        in
        let ids =
          List.filter_map concretes ~f:(fun t -> Hashtbl.find sids t)
          |> List.sort ~compare:Int.compare
          |> List.map ~f:(fun n -> [%string "[%{Int.to_string n}]"])
          |> String.concat ~sep:""
        in
        disp ^ (if String.is_empty ids then "" else " " ^ ids)
  in
  Option.iter view_title ~f:(fun t -> add ("%% " ^ t));
  add "graph LR";
  (* Artifact nodes — fetch action ID embedded in label when a Fetch rule
     exists, so it cross-references the log without adding a separate
     node. Multiple Fetch step variants (e.g. fetch_lib + fetch_lib_apt)
     all map to the same artifact pool node, so we collect their step
     ids together. *)
  List.iter all_pool_kinds ~f:(fun kind ->
      if is_expanded kind then begin
        (* Emit per-variant doc nodes wrapped in subgraph(s), mirroring mermaid_full.
           When a pack step produces a distinct PM variant (opam/pip), split into
           an input subgraph (build_tree / fetch variants) and a product subgraph. *)
        let vs = expand_vars () in
        let kind_lbl = label_of_artifact_kind kind in
        let kind_str = string_of_artifact_kind kind in
        (* Identify the product variant (output of install/pack) based on which rules
           are present in the schema.  "staged" comes from Install_lib; "opam"/"pip"
           come from the relevant Publish rule.  Everything else is an input variant. *)
        let product_vid =
          match kind with
          | Lib ->
              if List.exists rules ~f:(fun r -> Poly.equal r Install_lib)
              then Some "staged" else None
          | Binding lang ->
              if List.mem publish_kinds kind ~equal:Poly.equal then
                Some (match lang with
                  | Canary_artifact_api.OCaml -> "opam"
                  | Canary_artifact_api.Python -> "pip"
                  | _ -> "packed")
              else None
          | _ -> None
        in
        let input_vs = List.filter vs ~f:(fun (v, _) ->
            not (Option.equal String.equal (Some v) product_vid)) in
        let product_vs = List.filter vs ~f:(fun (v, _) ->
            Option.equal String.equal (Some v) product_vid) in
        let emit_doc_nodes indent vs =
          List.iter vs ~f:(fun (vid, vlabel) ->
              let nid = expand_variant_nid kind vid in
              add [%string "%{indent}%{nid}@{ shape: doc, label: \"%{vlabel}\" }"])
        in
        (match product_vs with
         | [] ->
             add [%string "    subgraph %{kind_str}_sg [\"%{kind_lbl}\"]"];
             emit_doc_nodes "      " input_vs;
             add "    end"
         | _ ->
             add [%string "    subgraph %{kind_str}_input_sg [\"%{kind_lbl}\"]"];
             emit_doc_nodes "      " input_vs;
             add "    end";
             let product_suffix = match kind with
               | Lib -> "product"
               | _ -> (match product_vs with (v, _) :: _ -> v | [] -> "packed")
             in
             add [%string "    subgraph %{kind_str}_product_sg [\"%{kind_lbl} (%{product_suffix})\"]"];
             emit_doc_nodes "      " product_vs;
             add "    end")
      end
      else begin
        let nid = node_id_of_kind kind in
        let lbl = label_of_artifact_kind kind in
        let label =
          if List.mem fetch_kinds kind ~equal:Poly.equal then begin
            let rule_tag = string_of_rule (Fetch kind) in
            let base = label_with_ids lbl rule_tag in
            (* In non-expanded views, fetch summaries are inlined into the artifact
               label rather than shown as separate pills. *)
            if is_inlined_summary (Fetch kind) then
              base ^ inline_summary_ids (Fetch kind)
            else base
          end else lbl
        in
        add [%string "    %{nid}@{ shape: docs, label: \"%{label}\" }"]
      end);
  add "";
  (* Scan action — hexagon, same as other active-transformation actions *)
  if has_scan then
    add [%string "    %{scan_nid}{{\"%{direct_tag_label \"scan_source\"}\"}}"];
  (* Configure + build actions — hexagon shape (active transformation) *)
  if has_configure then
    add [%string "    A_configure{{\"%{action_label \"configure\"}\"}}"];
  List.iter build_rules ~f:(fun r ->
      let name = string_of_rule r in
      add [%string "    A_%{name}{{\"%{action_label name}\"}}"]);
  (* Install actions — hexagon shape *)
  List.iter install_rules ~f:(fun r ->
      let name = string_of_rule r in
      add [%string "    A_%{name}{{\"%{action_label name}\"}}"]);
  (* Publish actions — hexagon shape.
     In non-binding-focused views the summary pill nodes are suppressed and their
     IDs are appended directly to the pack action label instead. *)
  List.iter publish_kinds ~f:(fun kind ->
      let name = string_of_rule (Publish kind) in
      let lbl = if is_inlined_summary (Publish kind)
                then action_label_with_summary name (Publish kind)
                else action_label name in
      add [%string "    A_%{name}{{\"%{lbl}\"}}"]);
  (* Probe actions — pill shape.
     Expanded probes emit one node per step variant instead of one collapsed node.
     Non-expanded probes inline their summary IDs into the label, all IDs sorted. *)
  List.iter probe_kinds ~f:(fun kind ->
      if is_probe_expanded kind then
        List.iter (probe_expand_items kind) ~f:(fun (probe_tag, _vid, label) ->
            add [%string "    A_%{probe_tag}([\"%{label}\"])"])
      else begin
        let name = string_of_rule (Probe kind) in
        let lbl = action_label_with_summary name (Probe kind) in
        add [%string "    A_%{name}([\"%{lbl}\"])"]
      end);
  (* Summary actions — pill shape, one per (rule, suffix) pair.
     Covers Probe Lib (_summary), Fetch (Binding lang) (_summary +
     _stub_summary), Publish (Binding lang) (same as Fetch), etc.
     Each summary tag is a real step tag, so use direct lookup to
     surface its individual step id. *)
  List.iter summary_rules ~f:(fun (rule, suffix) ->
      if not (is_inlined_summary rule) then begin
        let triples = summary_item_triples rule suffix in
        (* One triple = collapsed overview node → show all concrete IDs.
           Multiple triples = expanded focused nodes → each shows its own ID. *)
        let collapsed = match triples with [ _ ] -> true | _ -> false in
        List.iter triples ~f:(fun (nid, tag, _parent) ->
            let label =
              if collapsed then summary_all_ids_label tag else direct_tag_label tag
            in
            add [%string "    %{nid}([\"%{label}\"])"])
      end);

  add "";
  (* Edges *)
  let edge_idx = ref 0 in
  let edge_tags = ref [] in
  let add_edge ?tag edge_str =
    add [%string "    %{edge_str}"];
    (match tag with
     | Some t -> edge_tags := (!edge_idx, t) :: !edge_tags
     | None -> ());
    Int.incr edge_idx
  in
  (* Scan edge: source_node -.-> scan (annotation/follow-up).
     The downstream scan -> configure edge stays solid (real dep ordering). *)
  if has_scan then begin
    add_edge ~tag:"scan_source"
      [%string "%{node_id_of_kind Source} -.-> %{scan_nid}"]
  end;
  (* Configure edge: source_upstream → configure *)
  if has_configure then
    add_edge ~tag:"configure"
      [%string "%{source_upstream} --> A_configure"];
  (* Build edges *)
  List.iter build_rules ~f:(fun r ->
      let name = string_of_rule r in
      let action_id = [%string "A_%{name}"] in
      match r with
      | Build_headers ->
          if has_configure then
            add_edge ~tag:name [%string "A_configure --> %{action_id}"]
          else
            add_edge ~tag:name [%string "%{source_upstream} --> %{action_id}"];
          add_edge ~tag:name [%string "%{action_id} --> %{node_id_of_kind Headers}"]
      | Build_lib ->
          if has_configure then
            add_edge ~tag:name [%string "A_configure --> %{action_id}"]
          else
            add_edge ~tag:name [%string "%{source_upstream} --> %{action_id}"];
          (* When lib is expanded, build_lib produces the build_tree variant *)
          let lib_dest =
            if is_expanded Lib
               && List.exists (expand_vars ()) ~f:(fun (v,_) -> String.equal v "build_tree")
            then expand_variant_nid Lib "build_tree"
            else kind_nid Lib
          in
          add_edge ~tag:name [%string "%{action_id} --> %{lib_dest}"]
      | Build_binding lang ->
          if has_configure then
            add_edge ~tag:name [%string "A_configure --> %{action_id}"];
          add_edge ~tag:name
            [%string "%{kind_nid Headers} -.->|headers| %{action_id}"];
          add_edge ~tag:name [%string "%{kind_nid Lib} -.->|link| %{action_id}"];
          add_edge ~tag:name [%string "%{action_id} --> %{kind_nid (Binding lang)}"]
      | Build_app ->
          let app_binding_nid =
            match List.find_map rules ~f:(fun r ->
                match r with Build_binding lang -> Some lang | _ -> None) with
            | Some lang -> kind_nid (Binding lang)
            | None -> kind_nid (Binding OCaml)
          in
          add_edge ~tag:name [%string "%{app_binding_nid} --> %{action_id}"];
          add_edge ~tag:name [%string "%{kind_nid Lib} -.->|link| %{action_id}"];
          add_edge ~tag:name [%string "%{action_id} --> %{kind_nid App}"]
      | _ -> ());
  (* Install edges: build → install.
     When lib is expanded, route through build_tree/staged artifact nodes. *)
  List.iter install_rules ~f:(fun r ->
      let name = string_of_rule r in
      match r with
      | Install_lib ->
          let vs = expand_vars () in
          let has_var v = List.exists vs ~f:(fun (vi,_) -> String.equal vi v) in
          if is_expanded Lib && has_var "build_tree" then begin
            add_edge ~tag:name
              [%string "%{expand_variant_nid Lib \"build_tree\"} --> A_%{name}"];
            if has_var "staged" then
              add_edge ~tag:name
                [%string "A_%{name} --> %{expand_variant_nid Lib \"staged\"}"]
          end else
            add_edge ~tag:name [%string "A_build_lib --> A_%{name}"]
      | _ -> ());
  (* Publish edges: consumed variant → pack action → produced variant (if distinct) *)
  List.iter publish_kinds ~f:(fun kind ->
      let tag = string_of_rule (Publish kind) in
      add_edge ~tag [%string "%{kind_nid kind} --> A_%{tag}"];
      Option.iter (pack_produced_nid kind) ~f:(fun produced ->
          add_edge ~tag [%string "A_%{tag} --> %{produced}"]));
  (* Probe edges.
     Expanded probes emit one edge-set per variant.
     Non-expanded use the original logic (Binding+Publish routes through pack). *)
  List.iter probe_kinds ~f:(fun kind ->
      let base_tag = string_of_rule (Probe kind) in
      if is_probe_expanded kind then
        (* Expanded: one edge-set per probe step variant, routed through the
           matching artifact variant node when the artifact is also expanded. *)
        List.iter (probe_expand_items kind) ~f:(fun (probe_tag, variant_id, _label) ->
            let source_nid =
              if is_expanded kind
                 && List.exists (expand_vars ()) ~f:(fun (v,_) -> String.equal v variant_id)
              then expand_variant_nid kind variant_id
              else kind_nid kind
            in
            add_edge ~tag:probe_tag
              [%string "%{source_nid} -->|test| A_%{probe_tag}"];
            (match kind with
             | Binding _ | App ->
                 add_edge ~tag:probe_tag
                   [%string "%{kind_nid Lib} -.->|runtime| A_%{probe_tag}"]
             | _ -> ()))
      else begin
        (* Non-expanded: original logic *)
        (match kind with
         | Binding _ ->
             (* In the non-expanded overview, probe routes from the binding artifact
                pool node directly — the abstract rule is "test the binding", whether
                build_tree or packed.  Routing through the packed variant would falsely
                imply probe can't run until after pack. *)
             add_edge ~tag:base_tag [%string "%{kind_nid kind} -->|test| A_%{base_tag}"];
             add_edge ~tag:base_tag [%string "%{kind_nid Lib} -.->|runtime| A_%{base_tag}"]
         | App ->
             add_edge ~tag:base_tag [%string "%{kind_nid kind} -->|test| A_%{base_tag}"];
             add_edge ~tag:base_tag [%string "%{kind_nid Lib} -.->|runtime| A_%{base_tag}"]
         | _ ->
             add_edge ~tag:base_tag [%string "%{kind_nid kind} -->|test| A_%{base_tag}"])
      end);
  (* Summary edges: parent action → summary action.
     Dashed edge to signal "follow-up annotation" rather than data flow. *)
  List.iter summary_rules ~f:(fun (rule, suffix) ->
      if not (is_inlined_summary rule) then
        List.iter (summary_item_triples rule suffix) ~f:(fun (nid, tag, parent_nid) ->
            add_edge ~tag [%string "%{parent_nid} -.-> %{nid}"]));
  add "";
  (* Styling *)
  add "    classDef artifact fill:#fff3e0,stroke:#ff9800,stroke-width:2px";
  add "    classDef action fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px";
  add "    classDef st_done fill:#c8e6c9,stroke:#4caf50,stroke-width:3px";
  add "    classDef st_done_ctx fill:#e8f5e9,stroke:#a5d6a7,stroke-width:1.5px";
  add "    classDef st_expected_fail fill:#fff9c4,stroke:#f9a825,stroke-width:2px";
  add "    classDef st_failed fill:#ffcdd2,stroke:#c62828,stroke-width:2px";
  add "    classDef st_skipped fill:#f5f5f5,stroke:#9e9e9e,stroke-dasharray:5";
  add "    classDef st_nospec fill:#fafafa,stroke:#bdbdbd,stroke-dasharray:5";
  let all_artifact_nids =
    List.concat_map all_pool_kinds ~f:(fun kind ->
        if is_expanded kind then
          List.map (expand_vars ()) ~f:(fun (vid,_) -> expand_variant_nid kind vid)
        else [ node_id_of_kind kind ])
  in
  if not (List.is_empty all_artifact_nids) then
    add [%string "    class %{String.concat all_artifact_nids ~sep:\",\"} artifact"];
  (* action_entries: (node_id, status_tag) pairs for rendered action nodes.
     Fetch steps are embedded in artifact labels — not listed here. *)
  let scan_entries =
    if has_scan then [ (scan_nid, "scan_source") ] else []
  in
  let summary_entries =
    List.concat_map summary_rules ~f:(fun (rule, suffix) ->
        if is_inlined_summary rule then []
        else List.map (summary_item_triples rule suffix) ~f:(fun (nid, tag, _) -> (nid, tag)))
  in
  let action_entries =
    scan_entries
    @ (if has_configure then [ ("A_configure", "configure") ] else [])
    @ List.map build_rules ~f:(fun r ->
          ([%string "A_%{string_of_rule r}"], string_of_rule r))
    @ List.map install_rules ~f:(fun r ->
          ([%string "A_%{string_of_rule r}"], string_of_rule r))
    @ List.map publish_kinds ~f:(fun k ->
          let name = string_of_rule (Publish k) in
          ([%string "A_%{name}"], name))
    @ List.concat_map probe_kinds ~f:(fun k ->
          if is_probe_expanded k then
            List.map (probe_expand_items k) ~f:(fun (probe_tag, _, _) ->
                ([%string "A_%{probe_tag}"], probe_tag))
          else
            let name = string_of_rule (Probe k) in
            [ ([%string "A_%{name}"], name) ])
    @ summary_entries
  in
  (match status with
   | None ->
       let action_ids = List.map action_entries ~f:fst in
       if not (List.is_empty action_ids) then
         add [%string "    class %{String.concat action_ids ~sep:\",\"} action"]
   | Some _ ->
       List.iter action_entries ~f:(fun (node_id, tag) ->
           let cls = match get_status tag with
             | Some Done ->
                 (match focal_predicate with
                  | None -> "st_done"
                  | Some pred -> if pred tag then "st_done" else "st_done_ctx")
             | Some Done_fail -> "st_expected_fail"
             | Some Failed -> "st_failed"
             | Some Skipped -> "st_skipped"
             | Some Not_in_spec | None -> "st_nospec"
           in
           add [%string "    class %{node_id} %{cls}"]));
  (match status with
   | None -> ()
   | Some _ ->
       List.iter (List.rev !edge_tags) ~f:(fun (idx, tag) ->
           let style = match get_status tag with
             | Some Done -> Some "stroke:#4caf50,stroke-width:3px"
             | Some Done_fail -> Some "stroke:#f9a825,stroke-width:3px"
             | Some Failed -> Some "stroke:#ef5350,stroke-width:3px"
             | Some Skipped -> Some "stroke:#9e9e9e,stroke-width:1px,stroke-dasharray:5"
             | Some Not_in_spec | None -> Some "stroke:#bdbdbd,stroke-width:1px,stroke-dasharray:5"
           in
           Option.iter style ~f:(fun s ->
               add [%string "    linkStyle %{Int.to_string idx} %{s}"])));
  Buffer.contents buf
