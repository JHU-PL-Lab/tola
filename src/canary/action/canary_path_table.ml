(** [Canary_path_table] — the maximal-enumeration table of every
    structurally possible artifact + probe path that a action list can
    produce.

    Split from [Canary] on 2026-06-01 (Phase 5). Drives the CLI [paths]
    and [paths-md] subcommands and is consumed by the diagram renderer
    to label nodes with their path id.

    Each artifact node in the action_graph's pools has a provenance
    chain (built_from, runtime_dep) back to source or store. A
    [job_path] flattens that chain into one record with depth,
    origin (built vs fetched), action-path string, and an annotation
    (description + frequency + feasibility). [pattern_row] groups
    structurally identical paths to count version combos.

    The table is independent of any project spec — it is the universal
    enumeration of what could be built. Probe paths are derived from
    artifact paths (one probe per artifact). *)

open Base
open Canary_store
open Canary_basic
open Canary_action

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
     | Binding lang -> [%string "fetch_binding_%{Canary_lang.string_of_lang lang}"]
     | kind -> [%string "fetch_%{string_of_artifact_kind kind}"])
  else
    (* Built: trace the chain *)
    let build_action = match n.a_kind with
      | Headers -> "build_headers"
      | Lib -> "build_lib"
      | Binding lang -> [%string "build_binding_%{Canary_lang.string_of_lang lang}"]
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

(* Extract job paths from action action pools, sorted by depth.
   Probes are not separate rows — every artifact can be probed
   (probe = action_path + → probe_<kind>, depth = d+1). *)
let job_paths_of_action_graph (ar : action_graph) : job_path list =
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
