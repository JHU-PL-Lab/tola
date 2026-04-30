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
  | Pm_install system_pkg -> (
      match phase.location with
      | Pm { lang = Canary_artifact_api.Native; _ } ->
          let info = prebuilt_info_exn config.ocaml in
          let spec =
            match system_pkg with
            | Some p ->
                {
                  info.system_package with
                  linux_pkg = p.linux_pkg;
                  macos_pkg = p.macos_pkg;
                }
            | None -> info.system_package
          in
          verify_system_package_steps ~name spec
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
    | Pm_install system_pkg -> (
        match phase.location with
        | Pm { lang = Canary_artifact_api.Native; _ } ->
            let info = prebuilt_info_exn config.ocaml in
            let spec =
              match system_pkg with
              | Some p ->
                  {
                    info.system_package with
                    linux_pkg = p.linux_pkg;
                    macos_pkg = p.macos_pkg;
                  }
              | None -> info.system_package
            in
            install_system_package_steps ~name config.ocaml.toolchain spec
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
            ])
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
  | Binding -> "binding"
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
  | Build_binding
  | Build_app
  | Fetch of artifact_kind
  | Publish of artifact_kind
  | Probe of artifact_kind

let string_of_rule = function
  | Configure -> "configure"
  | Build_headers -> "build_headers"
  | Build_lib -> "build_lib"
  | Build_binding -> "build_binding"
  | Build_app -> "build_app"
  | Fetch kind -> [%string "fetch_%{string_of_artifact_kind kind}"]
  | Publish kind -> [%string "pack_%{string_of_artifact_kind kind}"]
  | Probe kind -> [%string "probe_%{string_of_artifact_kind kind}"]

type action_rule = {
  rules : rule list;
  pools : (artifact_kind * artifact_node list) list;
}

let pool_get ar kind =
  List.Assoc.find ar.pools ~equal:Poly.equal kind |> Option.value ~default:[]

(* Standard rule sets *)
let store_rules =
  [
    Fetch Source;
    Configure;
    Build_headers;
    Fetch Headers;
    Build_lib;
    Fetch Lib;
    Build_binding;
    Fetch Binding;
    Build_app;
    Fetch App;
    Publish Lib;
    Publish Binding;
    Publish App;
    Probe Lib;
    Probe Binding;
    Probe App;
  ]

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
        | Build_binding ->
            let libs = get pools Lib in
            let nodes =
              List.concat_map versions ~f:(fun v ->
                  List.map libs ~f:(fun lib ->
                      mk_node Binding
                        (name ^ vs v)
                        ~origin:Build_tree ~location:Build_tree ~built_from:lib
                        ()))
            in
            add pools Binding nodes
        | Build_app ->
            let bindings = get pools Binding in
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
        | Configure | Publish _ | Probe _ -> pools)
  in
  { rules; pools }

let nodes_of_action_rule (ar : action_rule) =
  List.concat_map ar.pools ~f:snd
  |> List.dedup_and_sort ~compare:(fun a b ->
      String.compare (node_tag a) (node_tag b))


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
    [%string "fetch_%{string_of_artifact_kind n.a_kind}"]
  else
    (* Built: trace the chain *)
    let build_action = match n.a_kind with
      | Headers -> "build_headers"
      | Lib -> "build_lib"
      | Binding -> "build_binding"
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
  | Binding, Built ->
      let lib_origin = match node.built_from with
        | Some lib -> string_of_path_origin (path_origin_of_node lib)
        | None -> "?"
      in
      { description = [%string "build binding, lib from %{lib_origin}"];
        frequency = (if String.equal lib_origin "store" then "common" else "common");
        feasibility = "feasible" }
  | Binding, Fetched ->
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
    | Source -> "S" | Headers -> "H" | Lib -> "L" | Binding -> "B" | App -> "A"
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

let store_id_of_kind k =
  [%string "%{string_of_artifact_kind k}_store"]

type node_status = Done | Failed | Skipped | Not_in_spec

let mermaid_of_action_rule_schema ?status ?(split_probe_tags = []) (rules : rule list) =
  let get_status tag = match status with
    | None -> None
    | Some tbl -> Hashtbl.find tbl tag
  in
  let buf = Buffer.create 1024 in
  let add s = Buffer.add_string buf s; Buffer.add_char buf '\n' in
  let has_configure = List.exists rules ~f:(fun r ->
      match r with Configure -> true | _ -> false)
  in
  let build_rules =
    List.filter rules ~f:(fun r ->
        match r with
        | Build_headers | Build_lib | Build_binding | Build_app -> true
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
  (* All pool kinds: source is always present, plus artifact kinds from rules *)
  let artifact_pool_kinds =
    [ Headers; Lib; Binding; App ]
    |> List.filter ~f:(fun k ->
           List.exists rules ~f:(fun r ->
               match r with
               | Build_headers -> Poly.equal k Headers
               | Build_lib -> Poly.equal k Lib
               | Build_binding -> Poly.equal k Binding
               | Build_app -> Poly.equal k App
               | Fetch fk -> Poly.equal k fk
               | Configure | Publish _ | Probe _ -> false))
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let all_pool_kinds = Source :: artifact_pool_kinds in
  add "graph LR";
  (* Artifact nodes — multi-document shape to reflect multiple versions *)
  List.iter all_pool_kinds ~f:(fun kind ->
      let nid = node_id_of_kind kind in
      let k = string_of_artifact_kind kind in
      add [%string "    %{nid}@{ shape: docs, label: \"%{k}\" }"]);
  (* Store nodes — one per pool kind, labeled with kind + versions *)
  List.iter all_pool_kinds ~f:(fun kind ->
      let sid = store_id_of_kind kind in
      let k = string_of_artifact_kind kind in
      add [%string "    %{sid}[(\"%{k}_store\")]"]);
  add "";
  (* Action nodes — configure, build, and probe *)
  if has_configure then
    add "    A_configure{{\"configure\"}}";
  List.iter build_rules ~f:(fun r ->
      let name = string_of_rule r in
      add [%string "    A_%{name}{{\"%{name}\"}}"]);
  List.iter publish_kinds ~f:(fun kind ->
      let k = string_of_artifact_kind kind in
      add [%string "    A_pack_%{k}{{\"%{(string_of_rule (Publish kind))}\"}}"]);
  List.iter probe_kinds ~f:(fun kind ->
      match kind with
      | Binding when not (List.is_empty split_probe_tags) ->
          List.iter split_probe_tags ~f:(fun stag ->
              add [%string "    A_%{stag}([\"%{stag}\"])"])
      | _ ->
          let k = string_of_artifact_kind kind in
          add [%string "    A_probe_%{k}([\"%{(string_of_rule (Probe kind))}\"])"]);
  add "";
  (* Edges — collected with action tags for status-based styling *)
  let edge_idx = ref 0 in
  let edge_tags = ref [] in  (* (index, action_tag) pairs *)
  let add_edge ?tag edge_str =
    add [%string "    %{edge_str}"];
    (match tag with
     | Some t -> edge_tags := (!edge_idx, t) :: !edge_tags
     | None -> ());
    Int.incr edge_idx
  in
  (* Configure edge: Source → Configure *)
  if has_configure then (
    add_edge ~tag:"configure"
      [%string "%{node_id_of_kind Source} --> A_configure"]);
  (* Build edges *)
  List.iter build_rules ~f:(fun r ->
      let name = string_of_rule r in
      let action_id = [%string "A_%{name}"] in
      (match r with
       | Build_headers ->
           (* headers come from configured source, or directly from source if no configure *)
           if has_configure then
             add_edge ~tag:name [%string "A_configure --> %{action_id}"]
           else
             add_edge ~tag:name [%string "%{node_id_of_kind Source} --> %{action_id}"];
           add_edge ~tag:name [%string "%{action_id} --> %{node_id_of_kind Headers}"]
       | Build_lib ->
           if has_configure then
             add_edge ~tag:name [%string "A_configure --> %{action_id}"]
           else
             add_edge ~tag:name [%string "%{node_id_of_kind Source} --> %{action_id}"];
           add_edge ~tag:name [%string "%{action_id} --> %{node_id_of_kind Lib}"]
       | Build_binding ->
           (* configure sets up the cmake build system *)
           if has_configure then
             add_edge ~tag:name [%string "A_configure --> %{action_id}"];
           (* headers consumed at compile time *)
           add_edge ~tag:name
             [%string "%{node_id_of_kind Headers} -.->|headers| %{action_id}"];
           add_edge ~tag:name [%string "%{node_id_of_kind Lib} -.->|link| %{action_id}"];
           add_edge ~tag:name [%string "%{action_id} --> %{node_id_of_kind Binding}"]
       | Build_app ->
           add_edge ~tag:name [%string "%{node_id_of_kind Binding} --> %{action_id}"];
           add_edge ~tag:name [%string "%{node_id_of_kind Lib} -.->|link| %{action_id}"];
           add_edge ~tag:name [%string "%{action_id} --> %{node_id_of_kind App}"]
       | _ -> ()));
  (* Fetch edges *)
  List.iter all_pool_kinds ~f:(fun kind ->
      let pid = node_id_of_kind kind in
      let sid = store_id_of_kind kind in
      let tag = [%string "fetch_%{string_of_artifact_kind kind}"] in
      add_edge ~tag [%string "%{sid} -.->|fetch| %{pid}"]);
  (* Publish edges *)
  List.iter publish_kinds ~f:(fun kind ->
      let k = string_of_artifact_kind kind in
      let pid = node_id_of_kind kind in
      let sid = store_id_of_kind kind in
      let tag = [%string "pack_%{k}"] in
      add_edge ~tag [%string "%{pid} --> A_pack_%{k}"];
      add_edge ~tag [%string "A_pack_%{k} -->|publish| %{sid}"]);
  add_edge [%string "%{node_id_of_kind Source} -.->|publish| %{store_id_of_kind Source}"];
  (* Probe edges *)
  List.iter probe_kinds ~f:(fun kind ->
      let pid = node_id_of_kind kind in
      match kind with
      | Binding when not (List.is_empty split_probe_tags) ->
          List.iter split_probe_tags ~f:(fun stag ->
              add_edge ~tag:stag [%string "%{pid} -->|test| A_%{stag}"];
              add_edge ~tag:stag [%string "%{node_id_of_kind Lib} -.->|runtime| A_%{stag}"])
      | _ ->
          let k = string_of_artifact_kind kind in
          let tag = [%string "probe_%{k}"] in
          add_edge ~tag [%string "%{pid} -->|test| A_probe_%{k}"];
          if Poly.equal kind Binding || Poly.equal kind App then
            add_edge ~tag [%string "%{node_id_of_kind Lib} -.->|runtime| A_probe_%{k}"]);
  add "";
  (* Styling *)
  add "    classDef source fill:#fafafa,stroke:#999";
  add "    classDef lib fill:#e8f5e9,stroke:#4caf50";
  add "    classDef binding fill:#e3f2fd,stroke:#2196f3";
  add "    classDef app fill:#e8eaf6,stroke:#3f51b5";
  add "    classDef action fill:#f3e5f5,stroke:#9c27b0,stroke-width:2px";
  add "    classDef store fill:#fff3e0,stroke:#ff9800,stroke-width:2px";
  add "    classDef st_done fill:#c8e6c9,stroke:#4caf50,stroke-width:3px";
  add "    classDef st_failed fill:#ffcdd2,stroke:#e53935,stroke-width:3px";
  add "    classDef st_skipped fill:#e0e0e0,stroke:#9e9e9e,stroke-dasharray:5";
  add "    classDef st_nospec fill:#fafafa,stroke:#bdbdbd,stroke-dasharray:5";
  (* Artifact nodes: colored by status if available *)
  List.iter all_pool_kinds ~f:(fun kind ->
      let nid = node_id_of_kind kind in
      let default_cls = string_of_artifact_kind kind in
      (* An artifact is "done" if any action that produces it succeeded:
         build_<kind> or fetch_<kind> *)
      let cls = match status with
        | None -> default_cls
        | Some _ ->
            let build_tag = match kind with
              | Headers -> Some "build_headers"
              | Lib -> Some "build_lib"
              | Binding -> Some "build_binding"
              | App -> Some "build_app"
              | Source -> None
            in
            let fetch_tag = Some [%string "fetch_%{string_of_artifact_kind kind}"] in
            let any_done tag_opt =
              match tag_opt with
              | None -> false
              | Some t -> Poly.equal (get_status t) (Some Done)
            in
            let any_failed tag_opt =
              match tag_opt with
              | None -> false
              | Some t -> Poly.equal (get_status t) (Some Failed)
            in
            if any_done build_tag || any_done fetch_tag then "st_done"
            else if any_failed build_tag || any_failed fetch_tag then "st_failed"
            else default_cls
      in
      add [%string "    class %{nid} %{cls}"]);
  (* Action + store nodes: status-aware or default *)
  let action_entries =
    (if has_configure then [ ("A_configure", "configure") ] else [])
    @ List.map build_rules ~f:(fun r ->
          ([%string "A_%{string_of_rule r}"], string_of_rule r))
    @ List.map publish_kinds ~f:(fun k ->
          let k_s = string_of_artifact_kind k in
          ([%string "A_pack_%{k_s}"], [%string "pack_%{k_s}"]))
    @ List.concat_map probe_kinds ~f:(fun kind ->
          match kind with
          | Binding when not (List.is_empty split_probe_tags) ->
              List.map split_probe_tags ~f:(fun stag -> ([%string "A_%{stag}"], stag))
          | _ ->
              let k_s = string_of_artifact_kind kind in
              [ ([%string "A_probe_%{k_s}"], [%string "probe_%{k_s}"]) ])
  in
  (match status with
   | None ->
       (* No status: all actions get default style *)
       let action_ids = List.map action_entries ~f:fst in
       add [%string "    class %{String.concat action_ids ~sep:\",\"} action"]
   | Some _ ->
       (* With status: color each action node by its result *)
       List.iter action_entries ~f:(fun (node_id, tag) ->
           let cls = match get_status tag with
             | Some Done -> "st_done"
             | Some Failed -> "st_failed"
             | Some Skipped -> "st_skipped"
             | Some Not_in_spec -> "st_nospec"
             | None -> "st_nospec"
           in
           add [%string "    class %{node_id} %{cls}"]));
  let store_ids = List.map all_pool_kinds ~f:store_id_of_kind in
  add [%string "    class %{String.concat store_ids ~sep:\",\"} store"];
  (* Edge styles based on action status *)
  (match status with
   | None -> ()
   | Some _ ->
       List.iter (List.rev !edge_tags) ~f:(fun (idx, tag) ->
           let style = match get_status tag with
             | Some Done -> Some "stroke:#4caf50,stroke-width:3px"
             | Some Failed -> Some "stroke:#e53935,stroke-width:3px"
             | Some Skipped -> Some "stroke:#9e9e9e,stroke-width:1px,stroke-dasharray:5"
             | Some Not_in_spec -> Some "stroke:#bdbdbd,stroke-width:1px,stroke-dasharray:5"
             | None -> Some "stroke:#bdbdbd,stroke-width:1px,stroke-dasharray:5"
           in
           Option.iter style ~f:(fun s ->
               add [%string "    linkStyle %{Int.to_string idx} %{s}"])));
  Buffer.contents buf
