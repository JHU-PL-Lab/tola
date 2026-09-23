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

let view_of_row (m : M.t) (r : M.row) (lang : Canary_lang.lang) : view =
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
    vw_unplaced = unplaced }

(** Every recorded world, once per binding language it speaks. *)
let views (m : M.t) : view list =
  List.concat_map m.M.rows ~f:(fun r ->
      let langs =
        match langs_of_row r with [] -> [ Canary_lang.OCaml ] | ls -> ls
      in
      List.map langs ~f:(view_of_row m r))

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
        ("unplaced", pairs v.vw_unplaced) ])

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
