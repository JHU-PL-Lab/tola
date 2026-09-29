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
    show nothing when opened locally (§2.7 finding 4). It is per machine
    — [_mac] beside the Linux one, named by
    [Canary_basic.platform_suffix_of] — and a [--platform] render never
    writes the tracked copy. *)

open Base
module M = Canary_matrix
module T = Canary_topology
module S = Canary_status
module SC = Canary_store_config

(* THE THREE SOURCES a value on the overview can have (2026-09-24, user:
   "all the data in diagrams … are coming from either code or logs?"):
   [Code] — a declaration or a rule in canary's own source; [Run] — a file
   a recorded run wrote; [Render] — asked of the machine rendering the
   page, which is neither, and is flagged wherever it appears. The page
   lists each value it draws under a node with its source, and says the
   kind first. *)
type source_kind = Code | Run | Render

type source = {
  src_kind : source_kind;
  src_what : string;
      (** what was read: a declaration, or the path of a file a run wrote *)
  src_at : string;  (** the function that read it *)
}

let from_code what at = { src_kind = Code; src_what = what; src_at = at }
let from_run path at = { src_kind = Run; src_what = path; src_at = at }
let from_render what at = { src_kind = Render; src_what = what; src_at = at }

let string_of_source_kind = function Code -> "code" | Run -> "run" | Render -> "render"

let json_of_source (s : source) : Yojson.Basic.t =
  `Assoc
    [ ("kind", `String (string_of_source_kind s.src_kind));
      ("what", `String s.src_what);
      ("at", `String s.src_at) ]

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
      (** per edge with a CHECKED agreement: the word its filled badge
          takes, from the outcomes of exactly those agreements *)
  vw_edge_claims : (string * (string * T.claim_state) list) list;
      (** per drawn edge: the agreements on it that apply to this chain's
          mechanism, and how each stands — what the edge's two badges
          count ({!Canary_topology.edge_claims}, 2026-09-24) *)
  vw_nodes : (string * string) list;  (** node id → sublabel *)
  vw_unplaced : (string * string) list;  (** step tag → why it has no edge *)
  vw_names : (string * (string * string)) list;
      (** node id → (what the node IS in this world, where that came
          from: [recorded] or [declared]) — phase D *)
  vw_dim : string list;
      (** nodes no realized edge touches and no evidence names *)
  vw_observed : (string * string) list;
      (** edge id → what this run RECORDED about the relation (phase E):
          the bridge record's reading of the edges around the bridge,
          including those someone else's rule establishes *)
  vw_placeholders : (string * (string * string) list) list;
      (** edge id → what a package manager did there, inside one of our
          actions, that this run does NOT record: (reason code, sentence)
          per placeholder step — [not_yet] or [out_of_reach] *)
  vw_chain : Canary_matrix.chain option;
      (** this world's chain for this language, from the record: its
          mechanism, its two sides and the cooperation joining them *)
  vw_gone : string list;
      (** the nodes and edges this chain does not have — NOT DRAWN, which
          is a different statement from dimmed: a dimmed node exists and
          nothing in the run touched it *)
  vw_candidates : string list;
      (** the placeholder claims — named, no evaluator — that apply to
          this chain *)
  vw_case : string;
      (** the package in canary this world realizes — the chain id the
          overview's §1 buttons carry ({!Canary_topology.chain_id}), which
          is how choosing a package finds its recorded worlds *)
  vw_name_sources : (string * source) list;
      (** node id → where its NAME came from: a declaration and the
          function that read it, or the inspection the run wrote — the page
          lists them under the diagram (2026-09-24) *)
  vw_place_sources : (string * source) list;
      (** node id → where its PLACEMENT line came from — the enumeration,
          a run's record, or the rendering machine *)
  vw_counts : (string * string) list;
      (** node id → how much of it the run recorded ("620 exports"), where
          its name does not already say — the result table's node cells
          (2026-09-28, design/overview.md §6.4), from the same reading as
          the name ({!Canary_matrix.reading_of_inspection}) *)
  vw_outcomes : (string * string) list;
      (** EVERY CHECKED AGREEMENT'S OUTCOME in this chain, by claim — the
          result table's check cells ({!Canary_matrix.row.checks}), which
          §2 counts. Read from the world's logged outcomes in this
          language, not through the slot columns [vw_claims] is read from,
          because the table places a check at its site whatever the world;
          [n/a] where the chain's mechanism cannot carry the claim *)
  vw_blames : (string * string) list;
      (** claim → the blame on its cell, where it has one (the cell's
          tooltip; {!Canary_matrix.blame_of}) *)
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

(** Where a step's inspection lives — the path a name read from it CITES
    (2026-09-24, user: show where each value on the diagram comes from). *)
let inspection_path ~root ~project ~scenario ~tag ~base : string =
  Printf.sprintf "%s/canary/projects/%s/%s/%s" root project
    (Canary_basic.step_dir_of_tag tag)
    (Canary_basic.filename ~variant_key:scenario ~base ~ext:"json")

let read_inspection ~root ~project ~scenario ~tag ~base : Yojson.Basic.t option =
  try Some (Yojson.Basic.from_file (inspection_path ~root ~project ~scenario ~tag ~base))
  with _ -> None

let jfield j k =
  match j with `Assoc kv -> List.Assoc.find kv k ~equal:String.equal | _ -> None

let jstr j k =
  match jfield j k with
  | Some (`String s) when not (String.is_empty s) -> Some s
  | _ -> None

let jlen j k = match jfield j k with Some (`List xs) -> Some (List.length xs) | _ -> None

let jbool j k = match jfield j k with Some (`Bool b) -> Some b | _ -> None

let jstrs j k =
  match jfield j k with
  | Some (`List xs) -> List.filter_map xs ~f:(function `String s -> Some s | _ -> None)
  | _ -> []

(* ── THE BRIDGE RECORD (2026-09-23, status.md §2.7 E) ─────────────────

   What a bridge step recorded ([Canary_bridge_driver]): what the bridge
   IS in this world and what its check answered. It names three nodes —
   the bridge, the system package it maps to, the capability file its
   check reads — and it is the only evidence canary has about the
   relations it does not perform: the depext table, the packager's file,
   pkg-config's answer. Those edges read [not_ours] in a world that
   recorded nothing and [observed] in one that did, with what was seen.
   Pure over the record, so a fixture pins every sentence. *)

let first_capability (j : Yojson.Basic.t) : Yojson.Basic.t option =
  match jfield j "capability" with Some (`List (c :: _)) -> Some c | _ -> None

let depext_version (j : Yojson.Basic.t) (pkg : string) : string option =
  match jfield j "depext_versions" with
  | Some (`Assoc kv) -> (
      match List.Assoc.find kv pkg ~equal:String.equal with
      | Some (`String v) -> Some v
      | _ -> None)
  | _ -> None

(** The nodes a bridge record names: the bridge, the capability file,
    and the system package — the one that ships the file, else the first
    the bridge maps to. *)
let bridge_names (j : Yojson.Basic.t) : (string * string) list =
  let cap = first_capability j in
  List.filter_opt
    [ Option.map (jstr j "package") ~f:(fun p -> ("bridge", p));
      Option.bind cap ~f:(fun c ->
          Option.map (jstr c "pcfile") ~f:(fun p ->
              ("cap", Stdlib.Filename.basename p)));
      Option.map
        (Option.first_some
           (Option.bind cap ~f:(fun c -> jstr c "owner"))
           (List.hd (jstrs j "depexts")))
        ~f:(fun p -> ("pkg_sys", p)) ]

(** The line under each node it names: the facts the name leaves out,
    short enough for a node box — the full paths are in the
    observations. The system package's line is the version installed; the
    capability file's is what it declares, a name and a version. *)
let bridge_sublabels (j : Yojson.Basic.t) : (string * string) list =
  let cap = first_capability j in
  let pkg_sys =
    Option.first_some
      (Option.bind cap ~f:(fun c -> jstr c "owner"))
      (List.hd (jstrs j "depexts"))
  in
  List.filter_opt
    [ Some
        ( "bridge",
          match jstr j "installed_version" with
          | Some v -> "installed " ^ v
          | None -> "not installed in this switch" );
      Option.bind pkg_sys ~f:(fun p ->
          Option.map (depext_version j p) ~f:(fun v -> ("pkg_sys", v)));
      Option.bind cap ~f:(fun c ->
          Option.map (jstr c "module") ~f:(fun m ->
              ( "cap",
                Option.value_map (jstr c "version") ~default:m ~f:(fun v ->
                    m ^ " " ^ v) ))) ]

(** What the run recorded about each relation around the bridge, by edge
    id. [conf_probe] says whether the check held — or that canary could
    not dispatch it, which is never reported as holding. *)
let bridge_observations (j : Yojson.Basic.t) : (string * string) list =
  let pkg = Option.value (jstr j "package") ~default:"the bridge" in
  let cap = first_capability j in
  let depexts = jstrs j "depexts" in
  let check = jfield j "check" in
  let argv =
    Option.value_map (jfield j "query") ~default:"its query" ~f:(fun q ->
        String.concat ~sep:" " (jstrs q "argv"))
  in
  List.filter_opt
    [ Option.map (jbool j "binding_names_bridge") ~f:(fun names ->
          let b = Option.value (jstr j "binding_package") ~default:"the binding package" in
          ( "depends",
            if names then Printf.sprintf "%s's depends names %s" b pkg
            else Printf.sprintf "%s's depends does NOT name %s" b pkg ));
      Option.map check ~f:(fun c ->
          ( "conf_probe",
            match (jbool c "dispatched", jbool c "holds") with
            | Some true, Some true -> Printf.sprintf "%s's check: %s — holds" pkg argv
            | Some true, _ ->
                Printf.sprintf "%s's check: %s — does NOT hold" pkg argv
            | _ ->
                Printf.sprintf
                  "%s's check makes no query canary can run — not dispatched" pkg ));
      (match depexts with
       | [] -> None
       | ps -> Some ("depext", Printf.sprintf "%s maps to %s" pkg (String.concat ~sep:", " ps)));
      (match
         List.filter_map depexts ~f:(fun p ->
             Option.map (depext_version j p) ~f:(fun v -> p ^ " " ^ v))
       with
       | [] -> None
       | vs -> Some ("resolve_sys", "installed here: " ^ String.concat ~sep:", " vs));
      Option.bind cap ~f:(fun c ->
          match (jstr c "pcfile", jstr c "owner") with
          | Some f, Some o -> Some ("realize_cap", Printf.sprintf "%s ships %s" o f)
          | Some f, None -> Some ("realize_cap", Printf.sprintf "no package claims %s" f)
          | None, _ -> None);
      Option.bind cap ~f:(fun c ->
          match (jstr c "module", jstr c "libdir") with
          | Some m, Some d ->
              Some
                ( "discover",
                  Printf.sprintf "pkg-config %s → %s%s" m
                    (Option.value_map (jstr c "version") ~default:"" ~f:(fun v ->
                         v ^ " in "))
                    d )
          | _ -> None) ]

(* the nodes an inspection's KIND describes, and what it calls each *)
(* WHAT AN INSPECTION NAMES. An artifact's inspection is read by
   [Canary_matrix.reading_of_inspection] — the same reading the result
   table's cells render (2026-09-28, design/overview.md §6.4 step 2), so
   this module parses no artifact kind of its own. A bridge record
   describes packages rather than an artifact, and only this page reads
   it. *)
let named_by_inspection (j : Yojson.Basic.t) : (string * string) list =
  match jstr j "kind" with
  | Some "bridge" -> bridge_names j
  | _ -> (
      match M.reading_of_inspection j with
      | Some r ->
          Option.to_list
            (Option.map (M.name_text_of_reading r) ~f:(fun n -> (r.M.rd_node, n)))
      | None -> [])

(* …and how much of it there is, for the result table's node cell *)
let counted_by_inspection (j : Yojson.Basic.t) : (string * string) list =
  match M.reading_of_inspection j with
  | Some r -> Option.to_list (Option.map (M.count_text_of_reading r) ~f:(fun c -> (r.M.rd_node, c)))
  | None -> []

let first_per_node (pairs : (string * 'a) list) : (string * 'a) list =
  List.fold pairs ~init:[] ~f:(fun acc (node, x) ->
      if List.Assoc.mem acc node ~equal:String.equal then acc else acc @ [ (node, x) ])

(* Every step's own directory holds what it and its inspections wrote.
   Two kinds of step are left out: an inspection (its parent's directory
   is read instead) and a probe of ANOTHER copy — the staged one, or a
   system package's this world does not use. A dummy is read: CPython's
   stdlib binding has no install step, and its inspection attaches to the
   dummy that holds its place. *)
let recorded_inspections ~root (r : M.row) (steps : M.world_step list) :
    (string * Yojson.Basic.t) list =
  List.concat_map steps ~f:(fun w ->
      match w.M.ws_place with
      | T.Evidence_for _ | T.Placeholder_for _
      | T.Unplaced (T.Observes_staged_copy | T.Observes_unused_system_copy) ->
          []
      | T.On _ | T.Included_for _ | T.Unplaced _ ->
          List.filter_map [ "inspect"; "inspect_stub" ] ~f:(fun base ->
              Option.map
                (read_inspection ~root ~project:r.M.project ~scenario:r.M.scenario
                   ~tag:w.M.ws_tag ~base)
                ~f:(fun j ->
                  ( inspection_path ~root ~project:r.M.project ~scenario:r.M.scenario
                      ~tag:w.M.ws_tag ~base,
                    j ))))

let recorded_names ~root (r : M.row) (steps : M.world_step list) :
    (string * (string * source)) list =
  List.concat_map (recorded_inspections ~root r steps) ~f:(fun (path, j) ->
      (* each name with the file it was read from *)
      List.map (named_by_inspection j) ~f:(fun (node, label) ->
          (node, (label, from_run path "Canary_overview_runs.named_by_inspection"))))
  |> first_per_node

let recorded_counts ~root (r : M.row) (steps : M.world_step list) : (string * string) list =
  List.concat_map (recorded_inspections ~root r steps) ~f:(fun (_, j) -> counted_by_inspection j)
  |> first_per_node

(* the bridge records this view's steps wrote: one per step that drives a
   bridge, read from that step's own directory — with its path, which the
   names and lines read from it cite *)
let bridge_records ~root (r : M.row) (steps : M.world_step list) :
    (string * Yojson.Basic.t) list =
  List.filter_map steps ~f:(fun w ->
      match w.M.ws_bridge with
      | None -> None
      | Some _ ->
          let base = Canary_bridge_driver.record_base in
          Option.map
            (read_inspection ~root ~project:r.M.project ~scenario:r.M.scenario
               ~tag:w.M.ws_tag ~base)
            ~f:(fun j ->
              ( inspection_path ~root ~project:r.M.project ~scenario:r.M.scenario
                  ~tag:w.M.ws_tag ~base,
                j )))

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

(** ⚠ A DECLARATION NAMES A NODE ONLY IN A WORLD THAT USES WHAT IT
    DECLARES (2026-09-23, user: "looks a bug"). The package gate and the
    binding row's package describe the UPSTREAM package — the one a world
    installs when it FETCHES the binding. A world that builds its binding
    here does not install it: zarith's publishes zarith-no-conf, which
    drops conf-gmp, and llvm's uses its build tree. The first cut named
    the bridge [conf-gmp] and the package [zarith] in those worlds anyway,
    because a declaration does not know which world it is read in. So the
    bridge is named only where the binding is fetched, and the package is
    the upstream one there, the package this world PUBLISHES where it
    builds and publishes one ([publishes]), and nothing otherwise. *)
let declared_names (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) (lang : Canary_lang.lang) ~(publishes : bool) :
    (string * (string * source)) list =
  let platform_pm = Canary_store.system_pm_of_platform (Canary_store.platform ()) in
  let id_of k =
    Option.map
      (List.find a ~f:(fun (id, _) -> Poly.equal (Canary_artifact.kind_of id) k))
      ~f:fst
  in
  let provider k = Option.bind (id_of k) ~f:(Canary_project_run.provenance_of pr) in
  let binding_fetched =
    List.exists a ~f:(fun (id, (pl : Canary_artifact.placement)) ->
        Poly.equal (Canary_artifact.kind_of id) (Canary_basic.Binding lang)
        && Poly.equal pl.Canary_artifact.provision Canary_artifact.Fetched)
  in
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
  (* EACH NAME WITH THE DECLARATION IT WAS READ FROM (2026-09-24): where
     there are two places a name can come from, the one that answered *)
  let code what = from_code what "Canary_overview_runs.declared_names" in
  let with_src what v = Option.map v ~f:(fun l -> (l, code what)) in
  List.filter_map ~f:(fun (node, v) -> Option.map v ~f:(fun x -> (node, x)))
    [ ( "pm_sys",
        with_src "the library row's provider is a system package: this platform's"
          (Option.map sys_pkg ~f:(fun _ -> Canary_store.string_of_pm platform_pm)) );
      ( "pkg_sys",
        with_src "the library row's provider (Sys_pkg), named for this platform"
          (Option.map sys_pkg ~f:(fun spec -> Canary_store.system_pkg_for_pm spec platform_pm))
      );
      ( "lib_sys",
        Option.first_some
          (with_src "the binding declaration's native.soname"
             (Option.bind decl ~f:(fun d -> non_empty d.Canary_binding_decl.native.soname)))
          (with_src "the declared C API's soname"
             (Option.bind native ~f:(fun n -> n.Canary_artifact.soname))) );
      ( "hdr_sys",
        let files l =
          non_empty (String.concat ~sep:", " (List.map l ~f:Stdlib.Filename.basename))
        in
        Option.first_some
          (with_src "the binding declaration's native.headers"
             (Option.bind decl ~f:(fun d -> files d.Canary_binding_decl.native.headers.files)))
          (with_src "the declared C API's headers"
             (Option.bind native ~f:(fun n ->
                  Option.bind n.Canary_artifact.headers ~f:(fun h -> files h.Canary_artifact.files))))
      );
      ("src_sys", with_src "the library source's repo record" (repo Canary_basic.Source));
      ( "bridge",
        if not binding_fetched then None
        else
          Option.first_some
            (with_src "the binding declaration's pm_gate"
               (Option.bind decl ~f:(fun d ->
                    Option.bind d.Canary_binding_decl.pm_gate ~f:bridge_of_gate)))
            (with_src "the package gate the project routes (pr_pm_gates, read by Canary_topology.join_of)"
               (List.find_map (T.bridges_of_join (T.join_of pr lang)) ~f:(fun g ->
                    match g.T.gb_bridge with
                    | Canary_bridge.Opam (Canary_bridge.Conf_package pkg) -> Some pkg
                    | Canary_bridge.Opam (Canary_bridge.Depext_field d) ->
                        Some ("depext: " ^ d)))) );
      ( "pm_lang",
        with_src "the binding row's provider (Lang_pkg): its package manager"
          (Option.map lang_pkg ~f:(fun (pm, _) -> Canary_store.string_of_pm pm)) );
      ( "pkg_lang",
        if binding_fetched then
          with_src "the binding row's provider (Lang_pkg): its package"
            (Option.map lang_pkg ~f:(fun (_, p) -> strip_gloss p))
        else if publishes then
          with_src "the wrapper package this world publishes (pr_wrapper_pkgs)"
            (List.Assoc.find pr.Canary_project_run.pr_wrapper_pkgs lang ~equal:Poly.equal)
        else None );
      ( "src_lang",
        with_src "the binding source's repo record" (repo (Canary_basic.Binding_source lang)) );
      ( "stub_lang",
        with_src "the binding declaration's coupling"
          (Option.map decl ~f:(fun d ->
               match d.Canary_binding_decl.coupling with
               | Canary_binding_decl.Stub_archive { archive; _ } ->
                   Stdlib.Filename.basename archive
               | Canary_binding_decl.Compiled_ext { product; _ } ->
                   Stdlib.Filename.basename product
               | Canary_binding_decl.Dlopen { name } -> name)) );
      ( "surf_lang",
        with_src "the binding declaration's surface_path"
          (Option.map decl ~f:(fun d -> surface_label d.Canary_binding_decl.surface_path)) ) ]

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

let view_of_row ?(root = "_out") (m : M.t) (r : M.row) (lang : Canary_lang.lang)
    : view =
  let steps = List.filter r.M.steps ~f:(fun w -> in_lang lang w.M.ws_action) in
  let word_of_tag t =
    Option.map
      (List.find steps ~f:(fun w -> String.equal w.M.ws_tag t))
      ~f:(fun w -> step_word w.M.ws_state)
  in
  (* what the world's bridge steps recorded (phase E) *)
  let records = bridge_records ~root r steps in
  let observed =
    first_per_node (List.concat_map records ~f:(fun (_, j) -> bridge_observations j))
  in
  (* what a package manager did here and nobody recorded: each placeholder
     step, on each edge it stands for *)
  let placeholders =
    let pairs =
      List.concat_map steps ~f:(fun w ->
          match (w.M.ws_place, w.M.ws_placeholder) with
          | T.Placeholder_for ids, Some ph ->
              List.map ids ~f:(fun id ->
                  ( id,
                    ( Canary_pm_action.code_of_unseen ph.Canary_pm_action.ph_unseen,
                      Canary_pm_action.describe ph ) ))
          | _ -> [])
    in
    List.filter_map T.edges ~f:(fun e ->
        match
          List.filter_map pairs ~f:(fun (id, x) ->
              if String.equal id e.T.eg_id then Some x else None)
        with
        | [] -> None
        | xs -> Some (e.T.eg_id, xs))
  in
  (* the relations a binding included with its language stands on: its
     dummy fetch marks them ({!Canary_topology.included_edges}) *)
  let included =
    List.concat_map steps ~f:(fun w ->
        match w.M.ws_place with T.Included_for ids -> ids | _ -> [])
  in
  (* EVERY edge gets a word, so the template has nothing left over: a
     realized edge its worst step's; an action edge this world does not
     realize [absent] — or [inside], where a package manager established
     the relation inside one of our actions and a placeholder says so, or
     [included], where the language's own build and install made it before
     the run; someone else's rule [not_ours] — or [observed] where this run
     recorded what that rule said here — and a claim edge [claim] *)
  let edges =
    List.map T.edges ~f:(fun e ->
        ( e.T.eg_id,
          match e.T.eg_annotation with
          | T.Info _ ->
              if List.Assoc.mem observed e.T.eg_id ~equal:String.equal then "observed"
              else "not_ours"
          | T.Agreement _ -> "claim"
          | T.Action _ -> (
              let tags =
                Option.value
                  (List.Assoc.find r.M.edges e.T.eg_id ~equal:String.equal)
                  ~default:[]
              in
              match List.filter_map tags ~f:word_of_tag with
              | [] ->
                  if List.mem included e.T.eg_id ~equal:String.equal then "included"
                  else if List.Assoc.mem placeholders e.T.eg_id ~equal:String.equal then
                    "inside"
                  else "absent"
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
  (* the chain this view draws, and what it lacks — which the page does
     not draw, and no claim of which applies *)
  let chain = List.find r.M.chains ~f:(fun c -> Poly.equal c.M.ch_lang lang) in
  let gone = Option.value_map chain ~default:[] ~f:(fun c -> c.M.ch_gone) in
  let applies slug =
    match chain with
    | None -> true
    | Some c -> List.mem c.M.ch_claims slug ~equal:String.equal
  in
  (* one claim, several columns: the matrix's own merge, worst first —
     for the claims that APPLY to this chain *)
  let claims =
    List.filter_map (List.filter r.M.claims ~f:(fun (slug, _) -> applies slug))
      ~f:(fun (slug, cols) ->
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
  (* WHAT EACH EDGE'S BADGES COUNT in this chain (2026-09-24): the
     agreements on the edge that apply to its mechanism — the list §1
     counts for that mechanism — and the filled badge's word from the
     outcomes of exactly the checked ones. A checked agreement this world
     recorded no outcome for reads [unevaluated] instead of dropping out,
     so a number never counts more than its colour was computed from *)
  let mechanism =
    match chain with
    | Some c -> c.M.ch_mechanism
    | None -> Canary_mechanism.mechanism_of_lang_exn lang
  in
  (* …and only on an edge this world REALIZES. An action edge no step
     realizes here ([absent]) carries none: the library's agreements sit
     on both of its producers, and a built world's red badge was drawn on
     the system package's edge too, which that world never fetched *)
  let edge_claims =
    List.filter_map T.edges ~f:(fun e ->
        if
          List.mem gone e.T.eg_id ~equal:String.equal
          || Poly.equal (List.Assoc.find edges e.T.eg_id ~equal:String.equal) (Some "absent")
        then None
        else
          match T.edge_claims ~mechanism ~lang e.T.eg_id with
          | [] -> None
          | xs -> Some (e.T.eg_id, List.map xs ~f:(fun (cs, st) -> (cs.T.cs_claim, st))))
  in
  (* THE RESULT TABLE'S CHECK CELLS (2026-09-28, §6.4): the row's, in this
     language ({!Canary_matrix.chain_checks}), which §2 counts *)
  let cells = Option.value (List.Assoc.find r.M.checks lang ~equal:Poly.equal) ~default:[] in
  let outcomes = List.map cells ~f:(fun (slug, c) -> (slug, c.M.chk_outcome)) in
  let blames =
    List.filter_map cells ~f:(fun (slug, c) -> Option.map c.M.chk_blame ~f:(fun b -> (slug, b)))
  in
  let badges =
    List.filter_map edge_claims ~f:(fun (e, xs) ->
        match
          List.filter_map xs ~f:(fun (slug, st) ->
              match st with
              | T.Checked ->
                  Some
                    (Option.value
                       (List.Assoc.find claims slug ~equal:String.equal)
                       ~default:"unevaluated")
              | T.Placeholder -> None)
        with
        | [] -> None
        | words -> Some (e, badge_word words))
  in
  (* the world's placements, under the node each artifact is — the setting
     columns are labelled by artifact kind, so the kind finds its column *)
  let setting kind =
    List.find_map r.M.settings ~f:(fun (label, s) ->
        if String.equal label (M.kind_label kind) then
          Option.map s ~f:(fun (s : M.setting) -> s.M.text)
        else None)
  in
  (* WHERE EACH PLACEMENT CAME FROM (2026-09-24): the world's own
     placement, from the enumeration — except the installed VERSION of a
     system package fetched with no pinned version, which the matrix asks
     of the machine rendering the page. That one is neither code nor a
     run's record, and says so *)
  let place_source kind =
    let unpinned_fetched_sys =
      match assignment_of_row r with
      | None -> false
      | Some (pr, a) ->
          List.exists a ~f:(fun (id, (pl : Canary_artifact.placement)) ->
              Poly.equal (Canary_artifact.kind_of id) kind
              && Poly.equal pl.Canary_artifact.provision Canary_artifact.Fetched
              &&
              match Canary_project_run.provenance_of pr id with
              | Some (SC.Sys_pkg spec) -> Option.is_none spec.Canary_store.version_tag
              | _ -> false)
    in
    if unpinned_fetched_sys then
      from_render
        "the package is declared, but its installed VERSION is asked of the machine \
         rendering this page — the run never recorded it (status.md §2.7 finding 2)"
        "Canary_matrix.fetched_note → sys_pkg_version"
    else
      from_code "the world's placement of this artifact: its provision and version, from the enumeration"
        "Canary_matrix.provision_choice"
  in
  let placed =
    List.filter_map
      [ ("src_sys", Canary_basic.Source); ("lib_sys", Canary_basic.Lib);
        ("src_lang", Canary_basic.Binding_source lang);
        ("mod_lang", Canary_basic.Binding lang) ]
      ~f:(fun (node, kind) ->
        Option.map (setting kind) ~f:(fun t -> (node, (t, place_source kind))))
    @ first_per_node
        (List.concat_map records ~f:(fun (path, j) ->
             List.map (bridge_sublabels j) ~f:(fun (n, t) ->
                 (n, (t, from_run path "Canary_overview_runs.bridge_sublabels")))))
  in
  let nodes = List.map placed ~f:(fun (n, (t, _)) -> (n, t)) in
  let unplaced =
    List.filter_map steps ~f:(fun w ->
        match w.M.ws_place with
        | T.Unplaced u -> Some (w.M.ws_tag, T.string_of_unplaced u)
        | T.On _ | T.Evidence_for _ | T.Placeholder_for _ | T.Included_for _ -> None)
  in
  let stamps =
    List.filter_map steps ~f:(fun w -> w.M.ws_at)
    |> List.sort ~compare:String.compare
  in
  (* what the run recorded wins over what the project declared — and each
     name keeps the source that answered *)
  let sourced_names =
    let declared =
      (* does this world publish its own binding package? ONE answer,
         the package band's — the wrapper declaration, which
         [matrix.record_carries_each_worlds_chain] holds to the steps *)
      match assignment_of_row r with
      | Some (pr, a) ->
          declared_names pr a lang ~publishes:(T.publishes_of_world ~pr ~world:a lang)
      | None -> []
    in
    first_per_node
      (List.map (recorded_names ~root r steps) ~f:(fun (n, (l, src)) ->
           (n, ((l, "recorded"), src)))
      @ List.map declared ~f:(fun (n, (l, src)) -> (n, ((l, "declared"), src))))
  in
  let names = List.map sourced_names ~f:(fun (n, (x, _)) -> (n, x)) in
  (* A NODE IS IN THIS WORLD when a realized edge touches it or the run
     recorded something about it — the hand-drawn cases hide the rest;
     here they dim, so the layout never moves *)
  let live =
    List.concat_map T.edges ~f:(fun e ->
        match List.Assoc.find edges e.T.eg_id ~equal:String.equal with
        | Some w
          when step_rank w >= 0
               || List.mem [ "observed"; "inside"; "included" ] w ~equal:String.equal ->
            e.T.eg_to :: e.T.eg_from
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
    vw_edge_claims = edge_claims;
    vw_nodes = nodes;
    vw_unplaced = unplaced;
    vw_names = names;
    vw_dim =
      List.filter_map T.nodes ~f:(fun n ->
          if List.mem live n.T.nd_id ~equal:String.equal then None else Some n.T.nd_id);
    vw_observed = observed;
    vw_placeholders = placeholders;
    vw_chain = chain;
    vw_name_sources = List.map sourced_names ~f:(fun (n, (_, s)) -> (n, s));
    vw_place_sources = List.map placed ~f:(fun (n, (_, s)) -> (n, s));
    vw_counts = recorded_counts ~root r steps;
    vw_outcomes = outcomes;
    vw_blames = blames;
    vw_case =
      (match chain with
       | Some c ->
           T.chain_id ~project:r.M.project ~lang ~lang_side:c.M.ch_lang_side
             ~native_side:c.M.ch_native_side
       | None -> "");
    vw_gone = gone;
    vw_candidates =
      List.filter_map T.claim_sites ~f:(fun cs ->
          if (not (T.implemented cs)) && applies cs.T.cs_claim then Some cs.T.cs_claim
          else None)
      |> List.fold ~init:[] ~f:(fun acc c ->
             if List.mem acc c ~equal:String.equal then acc else acc @ [ c ]) }

(** Every recorded world, once per binding language it speaks — the
    matrix's rule, so the views are the chains §2 counts. *)
let views ?root (m : M.t) : view list =
  List.concat_map m.M.rows ~f:(fun r ->
      List.map (M.langs_of_steps r.M.steps) ~f:(view_of_row ?root m r))

(* ── THE HAND-DRAWN CASES' RECORDED COUNTERPARTS ─────────────────────

   (user, 2026-09-23: keep the hand-drawn cases, and give separate
   buttons to show the recorded ones, so the running worlds can be
   compared with the proposed ones.) Each entry names a project, a
   predicate over its worlds, and the language whose chain the case
   draws; the first world the predicate admits is the counterpart. The
   wheel case has none — its project, z3, is muted — and the built case's
   is sqlite, not the llvm its text describes: no llvm world builds the
   library under a fetched, gated binding. It is sqlite's INSTALLED world
   (2026-09-23): built here and staged, as the drawing has both — the
   built-only world has no staged copy, which the package band now says
   ([Canary_topology.band_hidden]) and the drawing does not.

   THE COMPARISON LEFT THE PAGE on 2026-09-24 (user: §1 draws the generic
   chain and the concrete ones, so §2's drawings and §2.1's recorded
   copies of them went, their notes merged into §1). The hand-drawn cases
   stay as DATA — the oracle the pins hold the derivations to — and this
   mapping is how those pins find the world each case stands for. *)

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
          is Canary_basic.Lib Canary_artifact.Installed a
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

(** Each edge's agreements as the page reads them, [[slug, state], …] —
    one encoder for a recorded view and for §1's mechanisms, so the two
    are counted alike. *)
let json_of_edge_claims (xs : (string * (string * T.claim_state) list) list) :
    Yojson.Basic.t =
  `Assoc
    (List.map xs ~f:(fun (e, cl) ->
         ( e,
           `List
             (List.map cl ~f:(fun (slug, st) ->
                  `List [ `String slug; `String (T.string_of_claim_state st) ])) )))

let json_of_view (v : view) : Yojson.Basic.t =
  let pairs kvs = `Assoc (List.map kvs ~f:(fun (k, s) -> (k, `String s))) in
  `Assoc
    ([ ("id", `String v.vw_id);
       ("case", `String v.vw_case);
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
        (* what each drawn edge's two badges count here *)
        ("edge_claims", json_of_edge_claims v.vw_edge_claims);
        ("nodes", pairs v.vw_nodes);
        ("unplaced", pairs v.vw_unplaced);
        ( "names",
          `Assoc
            (List.map v.vw_names ~f:(fun (n, (label, from)) ->
                 (n, `Assoc [ ("label", `String label); ("from", `String from) ]))) );
        ("dim", `List (List.map v.vw_dim ~f:(fun n -> `String n)));
        (* where each name and each placement line came from *)
        ( "name_sources",
          `Assoc (List.map v.vw_name_sources ~f:(fun (n, s) -> (n, json_of_source s))) );
        ( "place_sources",
          `Assoc (List.map v.vw_place_sources ~f:(fun (n, s) -> (n, json_of_source s))) );
        ("gone", `List (List.map v.vw_gone ~f:(fun n -> `String n)));
        ("candidates", `List (List.map v.vw_candidates ~f:(fun c -> `String c)));
        (* the result table's node counts and check outcomes (§1.2) *)
        ("counts", pairs v.vw_counts);
        ("outcomes", pairs v.vw_outcomes);
        ("blames", pairs v.vw_blames);
        ("observed", pairs v.vw_observed);
        ( "chain",
          match v.vw_chain with
          | None -> `Null
          | Some c ->
              `Assoc
                [ ("mechanism", `String (Canary_mechanism.string_of_mechanism c.M.ch_mechanism));
                  ("lang_side", `String c.M.ch_lang_side);
                  ("native_side", `String c.M.ch_native_side);
                  ("cooperation", `String (T.code_of_coop c.M.ch_coop));
                  ("character", `String c.M.ch_character) ] );
        ( "placeholders",
          `Assoc
            (List.map v.vw_placeholders ~f:(fun (e, xs) ->
                 ( e,
                   `List
                     (List.map xs ~f:(fun (code, text) ->
                          `Assoc [ ("unseen", `String code); ("text", `String text) ]))
                 ))) ) ])

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
          ("views", `List (List.map vs ~f:json_of_view)) ])
  ^ suffix

let file_name_of (d : Canary_store.distro) : string =
  "overview_runs" ^ Canary_basic.platform_suffix_of d ^ ".js"

(** Every machine's file, in the order the page loads them. *)
let all_file_names = List.map [ Canary_store.Wsl; Canary_store.MacOS_local ] ~f:file_name_of

(** Where this run writes: the tracked copy beside the page, unless the
    platform is OVERRIDDEN — a [--platform] render is neither machine's
    record (design/platform.md, "A hypothetical render is not a record":
    first stated for the result page, and this file's alone since that
    page retired on 2026-09-28). *)
let target ~(hypothetical : bool) : string =
  let name = file_name_of (Canary_store.platform ()) in
  if hypothetical then "_out/canary/" ^ name else "docs/canary/" ^ name

let write (m : M.t) ~(generated_at : string) : string =
  let path = target ~hypothetical:(Canary_store.platform_is_overridden ()) in
  Canary_step_model.ensure_dir (Stdlib.Filename.dirname path);
  Stdio.Out_channel.write_all path ~data:(payload m ~generated_at);
  path
