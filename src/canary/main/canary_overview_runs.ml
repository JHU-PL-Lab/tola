(** THE OVERVIEW'S RECORDED RUNS (2026-09-23, status.md §2.7 phase C).

    The overview page is general mechanism, and a recorded run meets it
    only as an OVERLAY: the generic diagram is the template, and a world
    is drawn on it by giving each edge a state, each claim badge an
    outcome and a few nodes a sublabel. Nothing is drawn here. This
    computes, per recorded world and binding language, the words the
    page's script applies — so every rule stays in OCaml, where the pins
    can hold it — and writes them to a per-machine file beside the page.

    A FILE, NOT THE PAGE. [overview_runs.js] adds to a global that the
    page reads through a plain [<script src>]: a browser refuses [fetch()]
    on [file://], so a page loading JSON would work on GitHub Pages and
    show nothing when opened locally (§2.7 finding 4). It is per machine,
    like [matrix.html] — [_mac] beside the Linux one — and a [--platform]
    render never writes the tracked copy. *)

open Base
module M = Canary_matrix
module T = Canary_topology
module S = Canary_status
module SC = Canary_store_config

(** One recorded world seen through one binding language. A world with
    two bindings is two chains on this layout, which is why the "no
    package manager between them" case is sqlite's PYTHON side. *)
type view = {
  vw_id : string;  (** the row's code and the language, e.g. [4ea4a4-ocaml] *)
  vw_project : string;
  vw_scenario : string;
  vw_lang : Canary_lang.lang;
  vw_recorded_on : string list;
  vw_span : (string * string) option;
      (** the earliest and the latest line the log dated for this view *)
  vw_edges : (string * string) list;
      (** EVERY edge of the template, with its state word *)
  vw_claims : (string * string) list;
      (** each claim the graph places that this view evaluates, with its
          outcome word *)
  vw_badges : (string * string) list;
      (** per edge carrying such claims: the word its badge takes *)
  vw_nodes : (string * string) list;  (** node id → sublabel *)
  vw_unplaced : (string * string) list;  (** step tag → why it has no edge *)
  vw_names : (string * (string * string)) list;
      (** node id → (what the node IS in this world, where that came
          from: [recorded] or [declared]) — phase D *)
  vw_dim : string list;
      (** nodes no realized edge touches and no evidence names *)
}

(* ── THE WORDS ─────────────────────────────────────────────────────── *)

(** What one step's state reads as on an edge. [Warm Fail] cannot occur —
    a failed step leaves no verdict marker to be served warm — and reads
    as a failure if it ever does. *)
let step_word : S.step_state -> string = function
  | S.Ran S.Pass -> "ran"
  | S.Warm S.Pass -> "warm"
  | S.Ran (S.Xfail _) | S.Warm (S.Xfail _) -> "xfail"
  | S.Ran S.Fail | S.Warm S.Fail -> "fail"
  | S.Blocked -> "blocked"
  | S.Unrecorded -> "unrecorded"

(** WORST FIRST, when several steps realize one edge: a failure outranks
    everything; a confirmed expected failure outranks a gap, because it is
    a finding; a gap outranks a pass, because a pass beside it is not the
    whole edge; a warm pass ranks above a fresh one, because it re-checked
    nothing. *)
let step_rank = function
  | "fail" -> 5
  | "blocked" -> 4
  | "xfail" -> 3
  | "unrecorded" -> 2
  | "warm" -> 1
  | "ran" -> 0
  | _ -> -1

(** What a claim's outcome reads as. *)
let outcome_word : string option -> string = function
  | None -> "unevaluated"
  | Some ("violated" | "error") -> "violated"
  | Some "holds" -> "holds"
  | Some _ -> "undecided"

(** A badge sums the claims on its edge: red if any is violated, green
    only if every one holds, otherwise how far short it fell. *)
let badge_word (words : string list) : string =
  if List.mem words "violated" ~equal:String.equal then "violated"
  else if List.for_all words ~f:(String.equal "holds") then "holds"
  else if List.mem words "holds" ~equal:String.equal then "partial"
  else if List.for_all words ~f:(String.equal "unevaluated") then "unevaluated"
  else "undecided"

(* ── THE NAMES (2026-09-23, status.md §2.7 phase D) ───────────────────

   What each node IS in one world, so a recorded world reads the way a
   hand-drawn case does. Two sources, in order, and a label keeps which it
   came from:

   - what the run RECORDED: the inspections the world's own steps wrote —
     only steps the graph placed, since a probe of an unused system copy
     is not this world's library;
   - what the project DECLARED: its providers, its binding declaration,
     its C API, its source repositories, its package gate.

   A node neither names keeps its generic label. *)

let read_inspection ~root ~project ~scenario ~tag ~base : Yojson.Basic.t option =
  let path =
    Printf.sprintf "%s/canary/projects/%s/%s/%s" root project
      (Canary_basic.step_dir_of_tag tag)
      (Canary_basic.filename ~variant_key:scenario ~base ~ext:"json")
  in
  try Some (Yojson.Basic.from_file path) with _ -> None

let jfield j k =
  match j with `Assoc kv -> List.Assoc.find kv k ~equal:String.equal | _ -> None

let jstr j k =
  match jfield j k with
  | Some (`String s) when not (String.is_empty s) -> Some s
  | _ -> None

let jlen j k = match jfield j k with Some (`List xs) -> Some (List.length xs) | _ -> None

(* the node an inspection's KIND describes, and what it calls it *)
let named_by_inspection (j : Yojson.Basic.t) : (string * string) option =
  let base = Stdlib.Filename.basename in
  match jstr j "kind" with
  | Some "native" ->
      Option.map
        (Option.first_some
           (Option.bind (jfield j "elf") ~f:(fun e -> jstr e "soname"))
           (Option.map (jstr j "path") ~f:base))
        ~f:(fun n -> ("lib_sys", n))
  | Some "c_stub" -> Option.map (jstr j "path") ~f:(fun p -> ("stub_lang", base p))
  | Some ("ocaml" | "python") ->
      Option.map (jstr j "path") ~f:(fun p ->
          ( "mod_lang",
            match (jlen j "modules", jlen j "attrs") with
            | Some n, _ -> Printf.sprintf "%s (%d modules)" p n
            | None, Some n -> Printf.sprintf "%s (%d names)" p n
            | None, None -> p ))
  (* NOT the surface: an mli summary's [path] is the PACKAGE, and the
     declaration names the file a user actually reads *)
  | _ -> None

let first_per_node (pairs : (string * 'a) list) : (string * 'a) list =
  List.fold pairs ~init:[] ~f:(fun acc (node, x) ->
      if List.Assoc.mem acc node ~equal:String.equal then acc else acc @ [ (node, x) ])

(* Every step's own directory holds what it and its inspections wrote.
   Two kinds of step are left out: an inspection (its parent's directory
   is read instead) and a probe of ANOTHER copy — the staged one, or a
   system package's this world does not use. A dummy is read: CPython's
   stdlib binding has no install step, and its inspection attaches to the
   dummy that holds its place. *)
let recorded_names ~root (r : M.row) (steps : M.world_step list) :
    (string * string) list =
  List.concat_map steps ~f:(fun w ->
      match w.M.ws_place with
      | T.Evidence_for _
      | T.Unplaced (T.Observes_staged_copy | T.Observes_unused_system_copy) ->
          []
      | T.On _ | T.Unplaced _ ->
          List.filter_map [ "inspect"; "inspect_stub" ] ~f:(fun base ->
              Option.bind
                (read_inspection ~root ~project:r.M.project ~scenario:r.M.scenario
                   ~tag:w.M.ws_tag ~base)
                ~f:named_by_inspection))
  |> first_per_node

(* a file a user reads, named the way they would: its basename, unless
   that is a Python package's [__init__.py], which says nothing without
   its directory *)
let surface_label (path : string) : string =
  let base = Stdlib.Filename.basename path in
  if String.equal base "__init__.py" then
    Stdlib.Filename.basename (Stdlib.Filename.dirname path) ^ "/" ^ base
  else base

(* the bridge as the package GATE states it — with its constraint, which
   the topology's bridge list drops *)
let bridge_of_gate : Canary_binding_decl.pm_dep_gate -> string option = function
  | Canary_binding_decl.Free_with_conf c -> Some c
  | Canary_binding_decl.Bounded_with_conf { conf; lower; upper; _ } ->
      Some
        (conf ^ " {"
        ^ String.concat ~sep:" & "
            (List.filter_opt
               [ Option.map lower ~f:(fun v -> ">= " ^ v);
                 Option.map upper ~f:(fun v -> "< " ^ v) ])
        ^ "}")
  | Canary_binding_decl.Fixed_with_conf { conf; version } ->
      Some (conf ^ " {= " ^ version ^ "}")
  | Canary_binding_decl.Pinned_depext { depext; bound } ->
      Some ("depext: " ^ depext ^ " " ^ bound)
  | Canary_binding_decl.Package_builds_lib | Canary_binding_decl.Bundled _ -> None

(* a declared package name may carry a gloss for the prose views —
   sqlite's python row is "sqlite3 (stdlib, pip no-op)" *)
let strip_gloss pkg =
  match String.substr_index pkg ~pattern:" (" with
  | Some i -> String.prefix pkg i
  | None -> pkg

let declared_names (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) (lang : Canary_lang.lang) :
    (string * string) list =
  let platform_pm = Canary_store.system_pm_of_platform (Canary_store.platform ()) in
  let id_of k =
    Option.map
      (List.find a ~f:(fun (id, _) -> Poly.equal (Canary_artifact.kind_of id) k))
      ~f:fst
  in
  let provider k = Option.bind (id_of k) ~f:(Canary_project_run.provenance_of pr) in
  let decl =
    let mech =
      Canary_project_analysis.mechanism_for (Canary_pipeline.analysed_of pr) lang
    in
    List.find pr.Canary_project_run.pr_binding_decls ~f:(fun d ->
        Poly.equal d.Canary_binding_decl.mechanism mech)
  in
  let native = Option.map (Canary_pipeline.declared_api_of pr) ~f:(fun api ->
      api.Canary_artifact.native_api) in
  (* the world's repo for a source artifact; a provider with ONE repo is
     that repo even when the placement pins no version id (torch's
     binding source) *)
  let repo k =
    Option.bind (id_of k) ~f:(fun id ->
        let r =
          match M.repo_of_source pr a id with
          | Some r -> Some r
          | None -> (
              match Canary_project_run.provenance_of pr id with
              | Some (SC.Repo r) | Some (SC.Repo_axes [ r ]) -> Some r
              | _ -> None)
        in
        Option.map r ~f:(fun r ->
            match r.Canary_artifact_source.remote with
            | Some (Canary_artifact_source.Git url) -> Stdlib.Filename.basename url
            | _ -> r.Canary_artifact_source.name))
  in
  let sys_pkg =
    match provider Canary_basic.Lib with Some (SC.Sys_pkg spec) -> Some spec | _ -> None
  in
  let lang_pkg =
    match provider (Canary_basic.Binding lang) with
    | Some (SC.Lang_pkg { pm; package; _ }) -> Some (pm, package)
    | _ -> None
  in
  let non_empty = function "" -> None | s -> Some s in
  List.filter_map ~f:(fun (node, v) -> Option.map v ~f:(fun l -> (node, l)))
    [ ("pm_sys", Option.map sys_pkg ~f:(fun _ -> Canary_store.string_of_pm platform_pm));
      ( "pkg_sys",
        Option.map sys_pkg ~f:(fun spec -> Canary_store.system_pkg_for_pm spec platform_pm) );
      ( "lib_sys",
        Option.first_some
          (Option.bind decl ~f:(fun d -> non_empty d.Canary_binding_decl.native.soname))
          (Option.bind native ~f:(fun n -> n.Canary_artifact.soname)) );
      ( "hdr_sys",
        Option.bind
          (Option.first_some
             (Option.map decl ~f:(fun d -> d.Canary_binding_decl.native.headers.files))
             (Option.bind native ~f:(fun n ->
                  Option.map n.Canary_artifact.headers ~f:(fun h -> h.Canary_artifact.files))))
          ~f:(fun files ->
            non_empty (String.concat ~sep:", " (List.map files ~f:Stdlib.Filename.basename))) );
      ("src_sys", repo Canary_basic.Source);
      ( "bridge",
        Option.first_some
          (Option.bind decl ~f:(fun d ->
               Option.bind d.Canary_binding_decl.pm_gate ~f:bridge_of_gate))
          (List.find_map (T.bridges_of_join (T.join_of pr lang)) ~f:(function
            | T.Conf_package { pkg; _ } -> Some pkg
            | T.Depext_field d -> Some ("depext: " ^ d)
            | T.Capability_file _ -> None)) );
      ("pm_lang", Option.map lang_pkg ~f:(fun (pm, _) -> Canary_store.string_of_pm pm));
      ("pkg_lang", Option.map lang_pkg ~f:(fun (_, p) -> strip_gloss p));
      ("src_lang", repo (Canary_basic.Binding_source lang));
      ( "stub_lang",
        Option.map decl ~f:(fun d ->
            match d.Canary_binding_decl.coupling with
            | Canary_binding_decl.Stub_archive { archive; _ } -> Stdlib.Filename.basename archive
            | Canary_binding_decl.Compiled_ext { product; _ } -> Stdlib.Filename.basename product
            | Canary_binding_decl.Dlopen { name } -> name) );
      ( "surf_lang",
        Option.map decl ~f:(fun d -> surface_label d.Canary_binding_decl.surface_path) ) ]

(* the world a row is, as an assignment — the registry's own enumeration,
   matched by scenario name *)
let assignment_of_row (r : M.row) :
    (Canary_project_run.project_run * Canary_artifact.assignment) option =
  Option.bind
    (List.Assoc.find Canary_registry.all_projects r.M.project ~equal:String.equal)
    ~f:(fun pr ->
      Option.map
        (List.find (Canary_project_run.scenarios_of pr) ~f:(fun a ->
             String.equal r.M.scenario
               (Stdlib.Filename.basename
                  (Canary_project_run.scenario_dir_of ~pr_name:r.M.project a))))
        ~f:(fun a -> (pr, a)))

(* ── ONE VIEW ──────────────────────────────────────────────────────── *)

(* a step or a column belongs to a language's view when its action speaks
   for that language, or for none — the lib side serves every binding *)
let in_lang (lang : Canary_lang.lang) (a : Canary_basic.action) : bool =
  match Canary_basic.lang_of_action a with
  | None -> true
  | Some l -> Poly.equal l lang

let langs_of_row (r : M.row) : Canary_lang.lang list =
  List.filter_map r.M.steps ~f:(fun w -> Canary_basic.lang_of_action w.M.ws_action)
  |> List.fold ~init:[] ~f:(fun acc l ->
         if List.mem acc l ~equal:Poly.equal then acc else acc @ [ l ])

let view_of_row ?(root = "_out") (m : M.t) (r : M.row) (lang : Canary_lang.lang)
    : view =
  let steps = List.filter r.M.steps ~f:(fun w -> in_lang lang w.M.ws_action) in
  let word_of_tag t =
    Option.map
      (List.find steps ~f:(fun w -> String.equal w.M.ws_tag t))
      ~f:(fun w -> step_word w.M.ws_state)
  in
  (* EVERY edge gets a word, so the template has nothing left over: a
     realized edge its worst step's, an action edge this world does not
     realize [absent], someone else's rule [not_ours], a claim edge
     [claim] *)
  let edges =
    List.map T.edges ~f:(fun e ->
        ( e.T.eg_id,
          match e.T.eg_annotation with
          | T.Info _ -> "not_ours"
          | T.Agreement _ -> "claim"
          | T.Action _ -> (
              let tags =
                Option.value
                  (List.Assoc.find r.M.edges e.T.eg_id ~equal:String.equal)
                  ~default:[]
              in
              match List.filter_map tags ~f:word_of_tag with
              | [] -> "absent"
              | w :: ws ->
                  List.fold ws ~init:w ~f:(fun acc x ->
                      if step_rank x > step_rank acc then x else acc)) ))
  in
  let column_in_lang label =
    match
      List.find m.M.typed_columns ~f:(fun c -> String.equal (M.label_of_col c) label)
    with
    | Some c -> in_lang lang (M.action_of_col c)
    | None -> false
  in
  (* one claim, several columns: the matrix's own merge, worst first *)
  let claims =
    List.filter_map r.M.claims ~f:(fun (slug, cols) ->
        let outcomes =
          List.filter_map cols ~f:(fun (label, o) ->
              if column_in_lang label then Some o else None)
        in
        let rank o = M.outcome_rank (Option.value o ~default:"") in
        match outcomes with
        | [] -> None
        | o :: os ->
            Some
              ( slug,
                outcome_word
                  (List.fold os ~init:o ~f:(fun acc x ->
                       if rank x > rank acc then x else acc)) ))
  in
  let badges =
    List.filter_map T.edges ~f:(fun e ->
        match
          List.filter_map (T.claim_sites_on e.T.eg_id) ~f:(fun cs ->
              List.Assoc.find claims cs.T.cs_claim ~equal:String.equal)
        with
        | [] -> None
        | words -> Some (e.T.eg_id, badge_word words))
  in
  (* the world's placements, under the node each artifact is — the setting
     columns are labelled by artifact kind, so the kind finds its column *)
  let setting kind =
    List.find_map r.M.settings ~f:(fun (label, s) ->
        if String.equal label (M.kind_label kind) then
          Option.map s ~f:(fun (s : M.setting) -> s.M.text)
        else None)
  in
  let nodes =
    List.filter_map
      [ ("src_sys", Canary_basic.Source); ("lib_sys", Canary_basic.Lib);
        ("src_lang", Canary_basic.Binding_source lang);
        ("mod_lang", Canary_basic.Binding lang) ]
      ~f:(fun (node, kind) -> Option.map (setting kind) ~f:(fun t -> (node, t)))
  in
  let unplaced =
    List.filter_map steps ~f:(fun w ->
        match w.M.ws_place with
        | T.Unplaced u -> Some (w.M.ws_tag, T.string_of_unplaced u)
        | T.On _ | T.Evidence_for _ -> None)
  in
  let stamps =
    List.filter_map steps ~f:(fun w -> w.M.ws_at)
    |> List.sort ~compare:String.compare
  in
  (* what the run recorded wins over what the project declared *)
  let names =
    let declared =
      match assignment_of_row r with
      | Some (pr, a) -> declared_names pr a lang
      | None -> []
    in
    first_per_node
      (List.map (recorded_names ~root r steps) ~f:(fun (n, l) -> (n, (l, "recorded")))
      @ List.map declared ~f:(fun (n, l) -> (n, (l, "declared"))))
  in
  (* A NODE IS IN THIS WORLD when a realized edge touches it or the run
     recorded something about it — the hand-drawn cases hide the rest;
     here they dim, so the layout never moves *)
  let live =
    List.concat_map T.edges ~f:(fun e ->
        match List.Assoc.find edges e.T.eg_id ~equal:String.equal with
        | Some w when step_rank w >= 0 -> e.T.eg_to :: e.T.eg_from
        | _ -> [])
    @ List.filter_map names ~f:(fun (n, (_, from)) ->
          if String.equal from "recorded" then Some n else None)
  in
  { vw_id = r.M.code ^ "-" ^ Canary_lang.string_of_lang lang;
    vw_project = r.M.project;
    vw_scenario = r.M.scenario;
    vw_lang = lang;
    vw_recorded_on = r.M.recorded_on;
    vw_span =
      (match stamps with
       | [] -> None
       | first :: _ -> Some (first, List.last_exn stamps));
    vw_edges = edges;
    vw_claims = claims;
    vw_badges = badges;
    vw_nodes = nodes;
    vw_unplaced = unplaced;
    vw_names = names;
    vw_dim =
      List.filter_map T.nodes ~f:(fun n ->
          if List.mem live n.T.nd_id ~equal:String.equal then None else Some n.T.nd_id) }

(** Every recorded world, once per binding language it speaks. *)
let views ?root (m : M.t) : view list =
  List.concat_map m.M.rows ~f:(fun r ->
      let langs =
        match langs_of_row r with [] -> [ Canary_lang.OCaml ] | ls -> ls
      in
      List.map langs ~f:(view_of_row ?root m r))

(* ── THE HAND-DRAWN CASES' RECORDED COUNTERPARTS ─────────────────────

   (user, 2026-09-23: keep the hand-drawn cases, and give separate
   buttons to show the recorded ones, so the running worlds can be
   compared with the proposed ones.) Each entry names a project, a
   predicate over its worlds, and the language whose chain the case
   draws; the first world the predicate admits is the counterpart. The
   wheel case has none — its project, z3, is muted — and the built case's
   is sqlite, not the llvm its text describes: no llvm world builds the
   library under a fetched, gated binding. *)

let provision_of_kind (a : Canary_artifact.assignment)
    (k : Canary_basic.artifact_kind) : Canary_store.provision option =
  List.find_map a ~f:(fun (id, (pl : Canary_artifact.placement)) ->
      if Poly.equal (Canary_artifact.kind_of id) k then
        Some pl.Canary_artifact.provision
      else None)

let counterparts :
    (string * (string * (Canary_artifact.assignment -> bool) * Canary_lang.lang))
    list =
  let is k p a = Poly.equal (provision_of_kind a k) (Some p) in
  let ocaml_binding = Canary_basic.Binding Canary_lang.OCaml in
  [ ("conf", ("zarith", is ocaml_binding Canary_artifact.Fetched, Canary_lang.OCaml));
    ( "built",
      ( "sqlite",
        (fun a ->
          is Canary_basic.Lib Canary_artifact.Built a
          && is ocaml_binding Canary_artifact.Fetched a),
        Canary_lang.OCaml ) );
    ("unified", ("torch", (fun _ -> true), Canary_lang.OCaml));
    ("none", ("sqlite", is Canary_basic.Lib Canary_artifact.Fetched, Canary_lang.Python)) ]

(** Each case with a counterpart, and the id of the view that draws it. *)
let case_views (vs : view list) : (string * string) list =
  List.filter_map counterparts ~f:(fun (key, (project, pred, lang)) ->
      Option.bind
        (List.Assoc.find Canary_registry.all_projects project ~equal:String.equal)
        ~f:(fun pr ->
          Option.bind (List.find (Canary_project_run.scenarios_of pr) ~f:pred)
            ~f:(fun a ->
              let scenario =
                Stdlib.Filename.basename
                  (Canary_project_run.scenario_dir_of ~pr_name:project a)
              in
              Option.map
                (List.find vs ~f:(fun v ->
                     String.equal v.vw_project project
                     && String.equal v.vw_scenario scenario
                     && Poly.equal v.vw_lang lang))
                ~f:(fun v -> (key, v.vw_id)))))

(* ── THE FILE ──────────────────────────────────────────────────────── *)

let json_of_view (v : view) : Yojson.Basic.t =
  let pairs kvs = `Assoc (List.map kvs ~f:(fun (k, s) -> (k, `String s))) in
  `Assoc
    ([ ("id", `String v.vw_id);
       ("project", `String v.vw_project);
       ("scenario", `String v.vw_scenario);
       ("lang", `String (Canary_lang.string_of_lang v.vw_lang));
       ("recorded_on", `List (List.map v.vw_recorded_on ~f:(fun p -> `String p))) ]
    @ (match v.vw_span with
       | None -> []
       | Some (a, b) -> [ ("span", `List [ `String a; `String b ]) ])
    @ [ ("edges", pairs v.vw_edges);
        ("claims", pairs v.vw_claims);
        ("badges", pairs v.vw_badges);
        ("nodes", pairs v.vw_nodes);
        ("unplaced", pairs v.vw_unplaced);
        ( "names",
          `Assoc
            (List.map v.vw_names ~f:(fun (n, (label, from)) ->
                 (n, `Assoc [ ("label", `String label); ("from", `String from) ]))) );
        ("dim", `List (List.map v.vw_dim ~f:(fun n -> `String n))) ])

(* the page collects every file it loads, one machine each *)
let prefix = "(window.CANARY_RUNS = window.CANARY_RUNS || []).push(\n"
let suffix = ");\n"

let payload (m : M.t) ~(generated_at : string) : string =
  let vs = views m in
  prefix
  ^ Yojson.Basic.pretty_to_string
      (`Assoc
        [ ("machine", `String (Canary_store.string_of_platform (Canary_store.platform ())));
          ("generated", `String generated_at);
          ("views", `List (List.map vs ~f:json_of_view));
          ( "cases",
            `Assoc (List.map (case_views vs) ~f:(fun (k, id) -> (k, `String id))) ) ])
  ^ suffix

let file_name_of (d : Canary_store.distro) : string =
  "overview_runs" ^ Canary_basic.platform_suffix_of d ^ ".js"

(** Every machine's file, in the order the page loads them. *)
let all_file_names = List.map [ Canary_store.Wsl; Canary_store.MacOS_local ] ~f:file_name_of

(** Where this run writes: the tracked copy beside the page, unless the
    platform is OVERRIDDEN — a [--platform] render is neither machine's
    record, the rule [Canary_matrix.write_web] states for the result
    page. *)
let target ~(hypothetical : bool) : string =
  let name = file_name_of (Canary_store.platform ()) in
  if hypothetical then "_out/canary/" ^ name else "docs/canary/" ^ name

let write (m : M.t) ~(generated_at : string) : string =
  let path = target ~hypothetical:(Canary_store.platform_is_overridden ()) in
  Canary_step_model.ensure_dir (Stdlib.Filename.dirname path);
  Stdio.Out_channel.write_all path ~data:(payload m ~generated_at);
  path
