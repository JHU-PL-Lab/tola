open Base
open Canary_store
open Canary_basic

(* project_config, verify_of_phase, steps_of_phase moved to
   legacy/canary_yaml_backend.ml on 2026-06-01 — they drove the retired
   yaml backend's phase model; the live pipeline uses script_spec →
   derive_steps in [Canary_action] instead. *)

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

(* The rule + version vocabulary moved to [Canary_basic] on 2026-06-01.
   The graph proper (action_rule, store_rules, derive_*, diagrams) stays
   here. *)

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
              else List.concat_map Canary_lang.[ OCaml; Python; Rust; Cpp; CSharp; Java ]
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

(* ── Step model types (shared with canary_action.ml + canary_diagram.ml) ── *)

type version_info = {
  provider_version : string;
  consumer_requires : string;
  since : string option;
  note : string option;
}

type symbol_entry = {
  sym_name : string;
  sym_version : string option;
}

let sym name = { sym_name = name; sym_version = None }
let sym_v name version = { sym_name = name; sym_version = Some version }

type symbol_check = {
  provided_lib : string;
  required : symbol_entry list;
  missing : symbol_entry list;
  version_info : version_info option;
}

(** Input descriptor for a compatibility prediction: pairs an artifact-role
    tag with the [paths] of inspector JSONs (produced by canary's Python
    inspector scripts) that {!Canary_compat_run.predicted_contains_any_v2}
    should read.

    Each constructor names a {i role}; the artifact-alias mapping (the
    [n*]/[b*] vocabulary from surface theory) is the same role-by-role:

    - [Native_lib]   — provider side {i s2 native_lib}. In tiny this is
                       the [n4] inspector's JSON (from [inspect_native.py]
                       on [c/build/libtiny.so.1]). For cext compiled
                       extensions, the same script reused on the binding
                       artifact ({i bpe3 compiled_binding_cext.so} in tiny).
    - [C_stub]       — consumer side carrying undefined refs to native C
                       symbols. Comes from [inspect_binding.py --kind stub]
                       on [libtiny_stubs.a] ({i bo7 compiled_binding_ocaml.stub-a}
                       in tiny), or [nm -u] on a cext [.so] reshaped to the
                       same JSON form ({i bpe3} in stub-like coercion mode).
                       Paired with [Native_lib] for {i c1 cmp_symbol} (set
                       inclusion: {i native.symbols ⊇ stub.requires}).
    - [Ocaml_mli]    — consumer side {i s4 user_binding_ocaml.mli}. From
                       [inspect_binding.py --kind mli] on the [.mli]
                       ({i bo4 user_binding_ocaml.mli} in tiny). Drives
                       {i c2 cmp_api_completeness} via watchlist check
                       against [vals].
    - [Python_attrs] — consumer side {i s4 user_binding_<python>.py}. From
                       [inspect_python.py --pkg <name>] ({i bpe2} or {i bpc2}
                       in tiny). Drives the Python flavour of {i c2
                       cmp_api_completeness} via watchlist check against
                       [attrs].
    - [Versioned_symbols] — provider side {i s2.versioned} (i.e. [@@VER]
                            annotations on [Native_lib]). Drives the
                            {i c5 cmp_sym_version} comparator (L1b
                            in canary's layered diagnostic — [@@GLIBC_X.YY]
                            tags). Comparator not yet wired.
    - [Abi_surface]  — provider side {i s2}'s SONAME / NEEDED / RPATH
                       (subset of [Native_lib]'s ELF metadata, surfaced
                       separately so an ABI-only prediction can be
                       expressed). L4 in canary's diagnostic layering.

    Each constructor's [paths] resolves at runtime to the cached inspector
    JSON written by the action that produced the artifact. *)
type compat_inspect_input =
  | C_stub           of { paths : string list }
  | Native_lib       of { paths : string list }
  | Ocaml_mli        of { paths : string list }
  | Python_attrs     of { paths : string list }
  | Versioned_symbols of { paths : string list }  (* L1b: @@GLIBC_X.YY version tags *)
  | Abi_surface      of { paths : string list }  (* L4: SONAME/NEEDED/RPATH mismatch *)

(** What an action step's outcome should be when {!Canary_action.run_step}
    runs it. Used by {!Canary_action.derive_steps} and the GH backend.

    - [Expect_success]              — step must exit 0.
    - [Expect_failure { contains_any; ... }] — step must fail; the failure
                                       output must contain at least one
                                       hand-written substring from
                                       [contains_any]. Brittle for multiline;
                                       use [Expect_compat_failure] when the
                                       prediction can be derived.
    - [Expect_compat_failure { inputs; version_info }] — step must fail;
                                       the expected failure substrings are
                                       {i derived} at run time by
                                       {!Canary_compat_run.predicted_contains_any_v2}
                                       from the cached inspector JSONs of
                                       [inputs]. Use when the surface delta
                                       between provider and consumer can
                                       predict the failure message. *)
type step_expectation =
  | Expect_success
  | Expect_failure of {
      contains_any : string list;
      version_info : version_info option;
    }
  | Expect_compat_failure of {
      inputs       : compat_inspect_input list;
      version_info : version_info option;
    }

type action_step = {
  tag : string;
  cache_key : string;
  output_tag : string;
  output_dir : string;
  project_dir : string;
  variant_id : string;
  rule : rule;
  deps : string list;
  cmd : output_dir:string -> variant_key:string -> string;
  check_pre : unit -> bool;
  check_post : output_dir:string -> variant_key:string -> bool;
  expectation : step_expectation;
  symbol_check : symbol_check option;
}

type logger = {
  log : tag:string -> event:string -> detail:string option -> unit;
  close : unit -> unit;
}

type step_status = Step_done | Step_failed | Step_skipped

let rec ensure_dir path =
  if not (Stdlib.Sys.file_exists path) then (
    ensure_dir (Stdlib.Filename.dirname path);
    Unix.mkdir path 0o755)

let now () =
  let t = Unix.gettimeofday () in
  let tm = Unix.localtime t in
  let frac = t -. Float.round_down t in
  Printf.sprintf "%04d-%02d-%02d %02d:%02d:%02d.%03d"
    (tm.tm_year + 1900) (tm.tm_mon + 1) tm.tm_mday
    tm.tm_hour tm.tm_min tm.tm_sec
    (Float.to_int (frac *. 1000.0))

let create_logger ~log_path =
  let oc = Stdlib.open_out_gen
      [Open_creat; Open_append; Open_wronly] 0o644 log_path in
  let log ~tag ~event ~detail =
    let ts = now () in
    let detail_str = match detail with
      | Some d -> Printf.sprintf "  (%s)" d
      | None -> ""
    in
    let padded_tag =
      if String.length tag < 25 then
        tag ^ String.make (25 - String.length tag) ' '
      else tag
    in
    let line = Printf.sprintf "[%s] %s  %s%s" ts padded_tag event detail_str in
    Stdlib.output_string oc (line ^ "\n");
    Stdlib.flush oc
  in
  let close () = Stdlib.close_out oc in
  { log; close }

(* Human-readable label: "binding_ocaml" → "binding ocaml" *)


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


type node_status =
  | Done       (* expected success, confirmed *)
  | Done_fail  (* expected failure, confirmed *)
  | Failed     (* unexpected: expected success but failed, or expected failure but succeeded/mismatched *)
  | Skipped
  | Not_in_spec

(* Diagram display label for a surface-inspection step tag (ends in _inspect or
   _stub_inspect).  Converts the internal step tag to a concise `inspect_*`
   verb form that reads well at its position in the diagram without the full
   parent-action prefix.

   Examples:
     pack_binding_ocaml_inspect      → inspect_ocaml
     pack_binding_ocaml_stub_inspect → inspect_ocaml_stub
     probe_lib_inspect               → inspect_lib
     probe_lib_staged_inspect        → inspect_lib_staged
     fetch_binding_python_inspect    → inspect_python *)
