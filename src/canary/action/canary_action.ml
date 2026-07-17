(** [Canary_action] — the action-graph schema.

    The {i first} of the two main action-layer files. Defines what an
    action is (the [rule] vocabulary lives in {!Canary_basic}) and how
    artifact nodes chain together into the universal graph. The
    {i runner} half lives in {!Canary_runner}.

    Split from [Canary] on 2026-06-01 (Phase 5); renamed from
    [Canary_action_rule] to [Canary_action] shortly after as part of
    the action/runner naming pass. Holds:
    - [mk_node], [node_tag]: artifact-node constructor and stable string
      tag (used for dedup + diagram labels).
    - [type action_rule]: the rule list + materialised pools per
      [artifact_kind].
    - [pool_get], [store_rules]: standard rule sets and pool access.
    - [make_action_rule]: instantiate an action_rule by applying every
      rule to a starting source.
    - [nodes_of_action_rule]: flatten the pools to a deduped node list.
    - [type node_status]: per-step verdict for diagram rendering. *)

open Base
open Canary_store
open Canary_basic

let mk_node a_kind a_name ~origin ~location ?built_from ?runtime_dep () :
    artifact_node =
  { a_kind; a_name; origin; a_location = location; built_from; runtime_dep }

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
  [ Fetch Source; Configure; Scan_sources; Build_headers; Fetch Headers; Build_lib; Install_lib; Fetch Lib ]
  @ List.concat_map langs ~f:(fun lang ->
      [ Build_binding lang; Fetch (Binding lang);
        Publish (Binding lang); Probe_binding lang;
        Build_app { lang }; Probe_app { lang } ])
  @ [ Fetch App; Publish Lib; Publish App; Probe_lib ]

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
        | Build_app { lang } ->
            let bindings = get pools (Binding lang) in
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
        (* Scan_sources doesn't produce new artifact nodes — it just
           emits inspect JSONs into the runner's output dirs.
           Configure / Install_lib / Publish / Probe likewise. *)
        | Configure | Scan_sources | Install_lib | Publish _
        | Probe_lib | Probe_binding _ | Probe_app _ -> pools)
  in
  { rules; pools }

let nodes_of_action_rule (ar : action_rule) =
  List.concat_map ar.pools ~f:snd
  |> List.dedup_and_sort ~compare:(fun a b ->
      String.compare (node_tag a) (node_tag b))

(** Per-step verdict the diagram renderer uses. Lives here because the
    natural place to attach status to an action graph is alongside the
    rule/node definitions; the actual mermaid emission lives in
    [Canary_diagram]. *)
type node_status =
  | Done       (* expected success, confirmed *)
  | Done_fail  (* expected failure, confirmed *)
  | Failed     (* unexpected: expected success but failed, or expected failure but succeeded/mismatched *)
  | Skipped
  | Not_in_spec
