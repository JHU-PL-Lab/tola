(** §0 of the overview page: the outline, the terms the page uses, and how
    the page is made — a figure of the path from canary's code and its
    runs to the page, marking what the harness holds and what agents do
    not read, and a table of the same path for each subject canary
    models. The page's sections, with the template slots each is made of
    and the code behind it, are listed here too. [text] prints it all
    ([canary overview --flow]). *)

open Base

let esc = Canary_overview_assets.esc

(* ── the page's sections ── *)

type section = {
  sc_num : string;
  sc_title : string;  (** as its heading reads *)
  sc_about : string;  (** a line for the outline; top-level sections only *)
  sc_anchor : string;  (** its heading's id *)
  sc_slots : string list;  (** the template slots it is made of *)
  sc_code : string list;  (** the modules behind it *)
}

(** In the order the page has them. *)
let sections : section list =
  let s ?(about = "") num title anchor slots code =
    { sc_num = num; sc_title = title; sc_about = about; sc_anchor = anchor; sc_slots = slots;
      sc_code = code }
  in
  [ s "§0" "Outline, and how this page is made" "outline" [ "outline" ]
      [ "Canary_overview_flow" ]
      ~about:"the sections, the terms, and the path from canary's code and its runs to each section";
    s "§0.1" "Terms" "terms" [ "terms" ] [ "Canary_overview_flow" ];
    s "§0.2" "How this page is made" "flow" [ "flow_figure"; "flow_key" ]
      [ "Canary_overview_flow"; "Canary_overview_looks" ];
    s "§0.3" "Each subject, layer by layer" "subjects" [ "flow_table" ]
      [ "Canary_overview_flow" ];
    s "§0.4" "The tests" "tests" [ "tests_table"; "tests_lists" ]
      [ "Canary_overview_tests"; "Canary_tests" ];
    s "§1" "A chain, layer by layer" "layers"
      [ "missing_steps"; "chain_key"; "join_panel" ]
      [ "Canary_overview_diagram"; "Canary_overview_looks"; "Canary_overview_panel";
        "Canary_overview_cases"; "Canary_overview_join"; "Canary_overview_draw";
        "Canary_overview_runs" ]
      ~about:"what canary models between two package managers, with a recorded run drawn on it";
    s "§1.1" "What each node is" "nodes" [ "node_legend" ]
      [ "Canary_overview_panel"; "Canary_topology" ];
    s "§1.2" "The results, one row per chain" "results"
      [ "results_key"; "results_table"; "results_columns" ]
      [ "Canary_frames"; "Canary_overview_results"; "Canary_overview_runs" ];
    s "§2" "The agreements" "overview" [ "agreement_overview" ]
      [ "Canary_agreement_overview" ]
      ~about:"where each rule ran, where it is checked, and what the runs decided";
    s "§2.1" "Where they sit on the chain" "sittings" []
      [ "Canary_agreement_overview"; "Canary_topology" ];
    s "§2.2" "Every edge, and the claims on it" "census"
      [ "sites"; "sites_checked"; "sites_named"; "sites_multi"; "claim_sites_table";
        "bare_count"; "bare_edges" ]
      [ "Canary_overview_tables"; "Canary_topology" ];
    s "§3" "The model: package managers, mechanisms, cooperations" "tables" []
      [ "Canary_overview_tables" ]
      ~about:"the pieces a chain is made of, and the chains canary runs";
    s "§3.1" "Each package manager on its own" "pm-solo" [ "pm_solo_table" ]
      [ "Canary_overview_tables"; "Canary_pm_solo" ];
    s "§3.2" "Binding mechanisms" "mechanisms" [ "binding_table" ]
      [ "Canary_overview_tables"; "Canary_mechanism" ];
    s "§3.3" "How two package managers cooperate" "cooperation"
      [ "coop_table"; "topology_notes" ]
      [ "Canary_overview_tables"; "Canary_topology" ];
    s "§3.4" "The chains canary runs" "chains" [ "chains_table" ]
      [ "Canary_overview_tables"; "Canary_overview_join" ] ]

(** The template slots that belong to the page as a whole. *)
let page_slots = [ "css"; "agreements_css"; "generated_at"; "scripts" ]

let section_of (num : string) : section option =
  List.find sections ~f:(fun s -> String.equal s.sc_num num)

let number (s : section) = Option.value (String.chop_prefix s.sc_num ~prefix:"§") ~default:s.sc_num
let is_top (s : section) = not (String.mem (number s) '.')

(** A section's heading, as the page writes it. *)
let heading (s : section) = number s ^ (if is_top s then ". " else " ") ^ s.sc_title

(** A section's number, as a link to its heading. *)
let link (num : string) : string =
  match section_of num with
  | Some s -> Printf.sprintf {|<a href="#%s">%s</a>|} s.sc_anchor (esc num)
  | None -> esc num

(** The outline: each section, its subsections under it. *)
let outline () : string =
  let item s = Printf.sprintf {|<a href="#%s">%s</a>|} s.sc_anchor (esc (heading s)) in
  let under t s = String.is_prefix (number s) ~prefix:(number t ^ ".") in
  {|<ul class="outline">|}
  ^ String.concat
      (List.map (List.filter sections ~f:is_top) ~f:(fun t ->
           let subs = List.filter sections ~f:(under t) in
           "<li>" ^ item t
           ^ (if String.is_empty t.sc_about then "" else " — " ^ esc t.sc_about)
           ^ (if List.is_empty subs then ""
              else "<ul>" ^ String.concat (List.map subs ~f:(fun s -> "<li>" ^ item s ^ "</li>")) ^ "</ul>")
           ^ "</li>"))
  ^ "</ul>"
  ^ Canary_overview_exhibits.list_html ()

(* ── the terms ── *)

let terms : (string * string) list =
  [ ( "side",
      "the system side — the native library and its package manager — and the language \
       side — the binding and its package manager" );
    ("layer", "package manager, package, artifact, program: §1 draws them top to bottom");
    ( "world",
      "one choice of where each of a project's artifacts comes from — fetched, built or \
       installed — and at which version" );
    ("chain", "one world in one binding language: what §1 draws, and a row of §1.2");
    ("action", "a step canary runs; each edge of §1 is named by the family of actions that realizes it");
    ( "agreement",
      "a claim canary checks between artifacts; a candidate is a claim named but not yet \
       checked, and a claim's site is the edges it sits on" );
    ("binding mechanism", "how a language binds the native library: cstubs, cext, ctypes …");
    ("cooperation", "how the two package managers are joined: through a bridge, a gate, or nothing");
    ("bridge", "package content made for two package managers to cooperate, such as opam's conf-* packages");
    ( "capability file",
      "what a package says it offers — a .pc or META file — owned by the package that ships it" );
    ( "frame",
      "a column group of §1.2 and §2: one action as §1 draws it — what it consumes, its \
       pieces, what it produces, and the checks on each" );
    ( "test",
      "a check that holds one claim about what canary's code computes, for a run or for this \
       page, and fails when the claim stops holding; §0.4 lists those canary project-test runs" ) ]

let terms_html () : string =
  {|<dl class="terms">|}
  ^ String.concat
      (List.map terms ~f:(fun (t, d) -> Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (esc t) (esc d)))
  ^ "</dl>"

(* ── what a run writes, named by the code that writes it ── *)

let root = "_out"
let project = "‹project›"
let projects_dir = root ^ "/canary/projects/"

let in_projects (path : string) : string =
  Option.value (String.chop_prefix path ~prefix:projects_dir) ~default:path

let log_file = in_projects (Canary_status.log_path ~root ~project)
let manifest_files = in_projects (Canary_manifest.path ~root ~project ~scenario:"‹world›")
let inspection_files = project ^ "/‹step›/inspect*.json"
let diagram_files = project ^ "/-run/diagrams/*.mmd"
let docs_dir = Stdlib.Filename.dirname Canary_overview_assets.docs_path

let runs_files =
  List.map Canary_overview_runs.all_file_names ~f:(fun f -> docs_dir ^ "/" ^ f)

(* ── each subject canary models, layer by layer ── *)

type layer = {
  ly_holds : string;
  ly_from : string list;  (** the modules that hold it, or the files a run writes it to *)
  ly_shown : (string * string list) list;  (** what shows it, and in which sections *)
}

type subject = { sj_name : string; sj_code : layer; sj_run : layer }

let subjects : subject list =
  let layer holds from shown = { ly_holds = holds; ly_from = from; ly_shown = shown } in
  [ { sj_name = "actions";
      sj_code =
        layer "the action catalogue, in families" [ "Canary_action"; "Canary_action_family" ]
          [ ("edges", [ "§1" ]); ("columns", [ "§1.2"; "§2" ]) ];
      sj_run =
        layer "each step's state" [ log_file ]
          [ ("edge states", [ "§1" ]); ("piece cells", [ "§1.2" ]) ] };
    { sj_name = "agreements";
      sj_code =
        layer "the registry: each claim, and where it sits"
          [ "Canary_agreement"; "Canary_topology" ]
          [ ("badges", [ "§1" ]); ("check columns", [ "§1.2" ]); ("rows", [ "§2" ]);
            ("sites", [ "§2.1"; "§2.2" ]) ];
      sj_run =
        layer "each check's outcome" [ log_file ]
          [ ("badge colours", [ "§1" ]); ("check cells", [ "§1.2" ]);
            ("decided, blame", [ "§2" ]) ] };
    { sj_name = "package managers";
      sj_code =
        layer "drivers, bridges, binding mechanisms, cooperation kinds"
          [ "Canary_pm_solo"; "Canary_bridge"; "Canary_mechanism"; "Canary_topology" ]
          [ ("choices", [ "§1" ]); ("tables", [ "§3.1"; "§3.2"; "§3.3" ]) ];
      sj_run =
        layer "placeholders for what they do out of sight; bridge records"
          [ log_file; inspection_files ]
          [ ("inside marks, the bridge's record", [ "§1" ]) ] };
    { sj_name = "packages";
      sj_code =
        layer "each project's declarations" [ "Canary_registry" ]
          [ ("declared names", [ "§1" ]); ("chains", [ "§3.4" ]) ];
      sj_run =
        layer "what each step found, and where" [ inspection_files; manifest_files ]
          [ ("recorded names", [ "§1" ]); ("artifact cells", [ "§1.2" ]) ] } ]

(* ── the figure ── *)

type kind = Code | Hand | Step | File | Sections

type line =
  | Main of string
  | Sub of string
  | Pass of string * string  (** a pass, and the IR it hands on *)
  | Link of string * string  (** a section's number, and the words *)

type box = {
  bx_id : string;
  bx_name : string;  (** what [text] calls it *)
  bx_kind : kind;
  bx_x : int;
  bx_y : int;
  bx_w : int;
  bx_h : int;
  bx_lines : line list;
  bx_title : string;  (** the modules or files it stands for *)
  bx_held : string list;  (** the tests, or make targets, that hold it *)
  bx_agents : string;  (** what agents query instead of reading it whole; "" when they read it *)
}

(** Boxes joined by one bracket, which an arrow leaves from. *)
type group = { gr_id : string; gr_name : string; gr_boxes : string list }

type arrow = { ar_from : string; ar_to : string; ar_note : string }

let canvas_w = 1000
let canvas_h = 856
let left_x = 20
let left_w = 170
let mid_x = 300
let mid_w = 330
let right_x = 750
let right_w = 230

let passes =
  [ ("1 declare", "spec"); ("2 analyse", "analysis"); ("3 enumerate", "worlds");
    ("4 select", "worlds"); ("5 order", "worlds"); ("6 realize", "steps") ]

(** What holds each subject's code. *)
let code_held = function
  | "actions" ->
      [ "action.execution_plan_topo_and_edges"; "action.close_deps_deploy_mismatch";
        "action.node_of_assignment_chain" ]
  | "agreements" ->
      [ "agreements.registry_complete"; "agreements.fixtures_execute";
        "agreements.action_path_reports_outcomes" ]
  | "package managers" ->
      [ "mechanism.catalogue_total_and_consistent"; "overview.tables_list_what_canary_covers";
        "steps.placeholders_stand_for_what_pms_do" ]
  | "packages" ->
      [ "registry.entries_enumerate"; "spec_check.every_project_reports";
        "spec_check.pair_counts_points" ]
  | _ -> []

(** The written-by-hand inputs of the page: id, words, what they stand
    for, what holds them. *)
let page_inputs =
  [ ( "graph",
      "the chain's graph",
      "Canary_topology: its nodes, edges and claim sites",
      [ "topology.graph_matches_the_registry"; "topology.every_step_has_a_place";
        "overview.package_band_is_one_cooperation" ] );
    ( "looks",
      "looks, places, cases",
      "Canary_overview_looks · Canary_overview_diagram · Canary_overview_cases",
      [ "overview.visual_vocabulary_is_one_list"; "overview.layout_rules_hold";
        "overview.edge_marks_clear_the_boxes" ] );
    ( "files",
      "page files",
      "canary/overview/: the page's prose, styles and scripts",
      [ "overview.scripts_parse"; "overview.template_slots_are_filled";
        "overview.flow_is_the_page" ] ) ]

let boxes : box list =
  let box ?(title = "") ?(agents = "") id name kind x y w h lines held =
    { bx_id = id; bx_name = name; bx_kind = kind; bx_x = x; bx_y = y; bx_w = w; bx_h = h;
      bx_lines = lines; bx_title = title; bx_held = held; bx_agents = agents }
  in
  let base = Stdlib.Filename.basename in
  List.mapi subjects ~f:(fun i s ->
      box ("code:" ^ s.sj_name) s.sj_name Code left_x (50 + (42 * i)) left_w 34
        [ Main s.sj_name ] (code_held s.sj_name)
        ~title:(String.concat ~sep:" · " s.sj_code.ly_from))
  @ List.mapi page_inputs ~f:(fun i (id, words, title, held) ->
        box ("page:" ^ id) words Hand left_x (590 + (42 * i)) left_w 34 [ Main words ] held
          ~title)
  @ [ box "passes" "the six passes" Step mid_x 46 mid_w 168
        (List.map passes ~f:(fun (p, ir) -> Pass (p, ir)))
        [ "analysis.touches_joins_actions_to_declarations"; "select.is_a_subset_of_stage2";
          "run_order.groups_by_store_state" ]
        ~title:"Canary_pipeline; canary emit ‹project› --stage N prints one pass";
      box "ci" "CI YAML" File right_x 166 right_w 44 [ Main "CI YAML"; Sub "canary ci" ]
        [ "gh.derived_expectation_polarity" ] ~title:".github/workflows/canary_*.yml";
      box "run" "run" Step mid_x 254 mid_w 52
        [ Main "run: each step does its action"; Main "and checks its agreements" ]
        [ "steps.dep_dirs_correspond_to_deps"; "strict.acceptance_policy"; "switch.selection" ]
        ~title:"Canary_local_runner.run_graph";
      box "diagrams" "diagrams" File right_x 258 right_w 44 [ Main "diagrams"; Sub "muted" ] []
        ~title:
          (projects_dir ^ diagram_files
         ^ "; their connectivity check runs only with CANARY_DIAGRAM_CONN=1");
      box "out" "a run's files" File mid_x 346 mid_w 40
        [ Main (String.concat ~sep:" · " [ base log_file; "manifests"; "inspections" ]) ]
        [ "manifest.records_what_a_run_realized"; "overview.one_reader_per_inspection";
          "make canary-agreement-roundtrip" ]
        ~title:
          (String.concat ~sep:" · "
             (List.map [ log_file; manifest_files; inspection_files ] ~f:(fun f ->
                  projects_dir ^ f)));
      box "record" "the record" Step mid_x 452 mid_w 52
        [ Main "the record"; Sub "canary overview --json" ]
        [ "matrix.record_export_is_the_matrix"; "matrix.record_carries_every_step";
          "matrix.record_joins_edges_and_claims" ]
        ~title:"Canary_matrix.matrix_of";
      box "runs" (base (List.hd_exn runs_files)) File right_x 454 right_w 48
        [ Main (base (List.hd_exn runs_files)); Sub "one per machine" ]
        [ "overview.recorded_runs_are_an_overlay"; "overview.badges_colour_from_the_cells";
          "overview.every_drawn_line_has_a_source" ]
        ~title:(String.concat ~sep:" · " runs_files ^ ", written by Canary_overview_runs")
        ~agents:"canary overview --json";
      box "html" (base Canary_overview_assets.docs_path) File 330 605 270 46
        [ Main (base Canary_overview_assets.docs_path) ]
        [ "overview.template_slots_are_filled"; "overview.agreement_counts_are_the_tables";
          "overview.sections_numbered_in_order" ]
        ~title:
          (Canary_overview_assets.docs_path
         ^ ": canary/overview/page.html, filled by Canary_overview_page.render")
        ~agents:"canary overview --flow";
      box "sections" "the page's sections" Sections mid_x 712 mid_w 126
        [ Link ("§1", "§1 the chain, layer by layer"); Link ("§1.2", "§1.2 the results' columns");
          Link ("§2", "§2 the agreements"); Link ("§2.2", "§2.2 every edge's claims");
          Link ("§3", "§3 the model's tables") ]
        [ "overview.flow_is_the_page" ];
      box "run_sections" "a run's sections" Sections right_x 712 right_w 58
        [ Link ("§1", "§1 a chain's run"); Link ("§1.2", "§1.2 the results' rows") ]
        [ "overview.results_table_is_the_column_model"; "overview.recorded_views_are_named" ];
      box "exhibits" "exhibits" File left_x 770 260 46
        [ Main "each figure and table, on its own"; Sub "fig-*.svg · tab-*.html" ]
        [ "overview.exhibits_are_exported" ]
        ~title:
          (Canary_overview_exhibits.export_dir
         ^ ": for a manuscript to embed, written by Canary_overview_export") ]

let groups : group list =
  [ { gr_id = "code"; gr_name = "the code";
      gr_boxes = List.map subjects ~f:(fun s -> "code:" ^ s.sj_name) };
    { gr_id = "page"; gr_name = "the page's own";
      gr_boxes = List.map page_inputs ~f:(fun (id, _, _, _) -> "page:" ^ id) } ]

let arrows : arrow list =
  let a ?(note = "") from to_ = { ar_from = from; ar_to = to_; ar_note = note } in
  [ a "code" "passes"; a "passes" "run"; a "passes" "ci"; a "run" "diagrams"; a "run" "out";
    a "out" "record"; a "record" "runs" ~note:"a view per chain";
    a "record" "html" ~note:"§2's counts"; a "code" "page" ~note:"and draws the page";
    a "page" "html"; a "page" "exhibits"; a "html" "sections"; a "runs" "run_sections" ]

(** The stage names beside the figure. *)
let lanes : (int * int * string) list =
  [ (left_x, 34, "in the code"); (mid_x, 34, "canary action ‹project›");
    (mid_x + mid_w + 14, 371, "in " ^ root ^ "/"); (mid_x, 440, "make view");
    (left_x, 578, "the page") ]

let box_by_id id = List.find boxes ~f:(fun b -> String.equal b.bx_id id)
let group_by_id id = List.find groups ~f:(fun g -> String.equal g.gr_id id)
let mid_y b = b.bx_y + (b.bx_h / 2)
let group_boxes g = List.filter_map g.gr_boxes ~f:box_by_id

let bracket_x g =
  match group_boxes g with b :: _ -> b.bx_x + b.bx_w + 20 | [] -> 0

(** A group's first and last box centres. *)
let group_span g =
  match group_boxes g with
  | [] -> None
  | bs -> Some (mid_y (List.hd_exn bs), mid_y (List.last_exn bs))

(** An arrow's two ends, straight along one axis; [None] when its ends do
    not face each other. *)
let route (a : arrow) : ((int * int) * (int * int)) option =
  match (group_by_id a.ar_from, group_by_id a.ar_to, box_by_id a.ar_from, box_by_id a.ar_to) with
  | Some g, Some h, _, _ -> (
      match (group_span g, group_span h) with
      | Some (_, g_last), Some (h_first, _) when bracket_x g = bracket_x h && g_last < h_first ->
          Some ((bracket_x g, g_last), (bracket_x g, h_first))
      | _ -> None)
  | Some g, None, _, Some b -> (
      (* level with the target's centre, which lies along the bracket, or
         straight down from the bracket's end into a box below *)
      match group_span g with
      | Some (first, last) ->
          let y = mid_y b and x = bracket_x g in
          if first <= y && y <= last && x < b.bx_x then Some ((x, y), (b.bx_x, y))
          else if last < b.bx_y && b.bx_x < x && x < b.bx_x + b.bx_w then
            Some ((x, last), (x, b.bx_y))
          else None
      | None -> None)
  | None, None, Some s, Some t ->
      let ox0 = max s.bx_x t.bx_x and ox1 = min (s.bx_x + s.bx_w) (t.bx_x + t.bx_w) in
      let oy0 = max s.bx_y t.bx_y and oy1 = min (s.bx_y + s.bx_h) (t.bx_y + t.bx_h) in
      if ox0 < ox1 && s.bx_y + s.bx_h <= t.bx_y then
        Some (((ox0 + ox1) / 2, s.bx_y + s.bx_h), ((ox0 + ox1) / 2, t.bx_y))
      else if oy0 < oy1 && s.bx_x + s.bx_w <= t.bx_x then
        Some ((s.bx_x + s.bx_w, (oy0 + oy1) / 2), (t.bx_x, (oy0 + oy1) / 2))
      else None
  | _ -> None

let is_bus (a : arrow) =
  Option.is_some (group_by_id a.ar_from) && Option.is_some (group_by_id a.ar_to)

let arrow_svg (a : arrow) : string =
  match route a with
  | None -> ""
  | Some ((x0, y0), (x1, y1)) ->
      let horizontal = y0 = y1 in
      (* the line stops where the head begins *)
      let lx, ly = if horizontal then (x1 - 9, y1) else (x1, y1 - 9) in
      let head =
        if horizontal then Printf.sprintf "M%d %dL%d %dL%d %dZ" x1 y1 (x1 - 9) (y1 - 5) (x1 - 9) (y1 + 5)
        else Printf.sprintf "M%d %dL%d %dL%d %dZ" x1 y1 (x1 - 5) (y1 - 9) (x1 + 5) (y1 - 9)
      in
      let note =
        if String.is_empty a.ar_note then ""
        else if horizontal then
          Printf.sprintf {|<text class="fnote" x="%d" y="%d" text-anchor="middle">%s</text>|}
            ((x0 + x1) / 2) (y0 - 8) (esc a.ar_note)
        else if is_bus a then
          Printf.sprintf {|<text class="fnote" x="%d" y="%d" text-anchor="end">%s</text>|}
            (x0 - 10) ((y0 + y1) / 2) (esc a.ar_note)
        else
          Printf.sprintf {|<text class="fnote" x="%d" y="%d">%s</text>|} (x0 + 8)
            (((y0 + y1) / 2) + 4) (esc a.ar_note)
      in
      Printf.sprintf {|<path class="fline" d="M%d %dL%d %d"/><path class="fhead" d="%s"/>%s|} x0
        y0 lx ly head note

let bracket_svg (g : group) : string =
  match group_span g with
  | None -> ""
  | Some (first, last) ->
      let x = bracket_x g in
      String.concat
        (Printf.sprintf {|<path class="fline" d="M%d %dV%d"/>|} x first last
        :: List.map (group_boxes g) ~f:(fun b ->
               Printf.sprintf {|<path class="fline" d="M%d %dH%d"/>|} (b.bx_x + b.bx_w) (mid_y b) x))

let line_height = function Main _ -> 18 | Sub _ -> 16 | Pass _ -> 24 | Link _ -> 22
let line_rise = function Main _ -> 13 | Sub _ -> 11 | Pass _ -> 17 | Link _ -> 16

(** The tests' mark, top left: filled where tests hold the box, and then
    a link to §0.4, which lists them. *)
let held_svg (b : box) : string =
  let cls, says =
    if List.is_empty b.bx_held then ("unheld", "held by no test")
    else ("held", "held by " ^ String.concat ~sep:", " b.bx_held)
  in
  let dot =
    Printf.sprintf {|<circle class="fdot %s" cx="%d" cy="%d" r="4.5"><title>%s</title></circle>|}
      cls (b.bx_x + 10) (b.bx_y + 10) (esc says)
  in
  if List.is_empty b.bx_held then dot else {|<a href="#tests">|} ^ dot ^ "</a>"

(** The agents' mark, bottom right: a struck AI where agents do not read
    the box whole. *)
let agents_svg (b : box) : string =
  if String.is_empty b.bx_agents then ""
  else
    let x = b.bx_x + b.bx_w - 24 and y = b.bx_y + b.bx_h - 8 in
    Printf.sprintf
      {|<g class="fagent"><title>agents do not read this whole; they query %s</title><text x="%d" y="%d">AI</text><path d="M%d %dL%d %d"/></g>|}
      (esc b.bx_agents) x y (x - 2) (y - 1) (x + 15) (y - 9)

let box_svg (b : box) : string =
  let x, y, w, h = (b.bx_x, b.bx_y, b.bx_w, b.bx_h) in
  let cls =
    match b.bx_kind with
    | Code -> "fbox"
    | Hand -> "fbox hand"
    | Step -> "fbox step"
    | File -> "fbox file"
    | Sections -> "fbox secs"
  in
  let shape =
    match b.bx_kind with
    | File ->
        let f = 10 in
        Printf.sprintf {|<path class="fshape" d="M%d %dH%dL%d %dV%dH%dZ"/><path class="ffold" d="M%d %dV%dH%d"/>|}
          x y (x + w - f) (x + w) (y + f) (y + h) x (x + w - f) y (y + f) (x + w)
    | _ -> Printf.sprintf {|<rect x="%d" y="%d" width="%d" height="%d" rx="6"/>|} x y w h
  in
  let total = List.sum (module Int) b.bx_lines ~f:line_height in
  let top = y + ((h - total) / 2) in
  let _, lines =
    List.fold b.bx_lines ~init:(top, []) ~f:(fun (at, acc) l ->
        let base = at + line_rise l in
        let svg =
          match l with
          | Main s ->
              Printf.sprintf {|<text x="%d" y="%d" text-anchor="middle">%s</text>|} (x + (w / 2)) base
                (esc s)
          | Sub s ->
              Printf.sprintf {|<text class="fsub" x="%d" y="%d" text-anchor="middle">%s</text>|}
                (x + (w / 2)) base (esc s)
          | Pass (p, ir) ->
              Printf.sprintf {|<text x="%d" y="%d">%s</text><text class="fsub" x="%d" y="%d">→ %s</text>|}
                (x + 24) base (esc p) (x + 156) base (esc ir)
          | Link (num, words) -> (
              match section_of num with
              | Some s ->
                  Printf.sprintf
                    {|<a href="#%s"><title>%s</title><text class="flink" x="%d" y="%d">%s</text></a>|}
                    s.sc_anchor
                    (esc (String.concat ~sep:" · " s.sc_code))
                    (x + 22) base (esc words)
              | None -> Printf.sprintf {|<text x="%d" y="%d">%s</text>|} (x + 22) base (esc words))
        in
        (at + line_height l, svg :: acc))
  in
  let title = if String.is_empty b.bx_title then "" else "<title>" ^ esc b.bx_title ^ "</title>" in
  Printf.sprintf {|<g class="%s">%s%s%s%s%s</g>|} cls title shape (String.concat (List.rev lines))
    (held_svg b) (agents_svg b)

(** The figure's drawing. *)
let svg () : string =
  Printf.sprintf
    {|<svg class="flow" viewBox="0 0 %d %d" role="img" aria-label="How this page is made: from canary's code and its runs to this page">%s%s%s%s</svg>|}
    canvas_w canvas_h
    (String.concat (List.map groups ~f:bracket_svg))
    (String.concat (List.map arrows ~f:arrow_svg))
    (String.concat (List.map boxes ~f:box_svg))
    (String.concat
       (List.map lanes ~f:(fun (x, y, t) ->
            Printf.sprintf {|<text class="flane" x="%d" y="%d">%s</text>|} x y (esc t))))

(** The figure: its drawing, captioned. *)
let figure () : string = Canary_overview_exhibits.figure "fig-flow" (svg ())

(* ── the table ── *)

(** What shows a layer, each with links to its sections. *)
let shown_html (shown : (string * string list) list) : string =
  String.concat ~sep:"; "
    (List.map shown ~f:(fun (what, secs) ->
         esc what ^ " " ^ String.concat ~sep:", " (List.map secs ~f:link)))

(** The subjects, layer by layer, as HTML. *)
let table () : string =
  let from l = Printf.sprintf {|<div class="from">%s</div>|} (esc (String.concat ~sep:" · " l)) in
  let row s =
    Printf.sprintf "<tr><th>%s</th><td>%s%s</td><td>%s</td><td>%s%s</td><td>%s</td></tr>"
      (esc s.sj_name) (esc s.sj_code.ly_holds) (from s.sj_code.ly_from)
      (shown_html s.sj_code.ly_shown) (esc s.sj_run.ly_holds) (from s.sj_run.ly_from)
      (shown_html s.sj_run.ly_shown)
  in
  Canary_overview_exhibits.table ~cls:"flowtab" "tab-subjects"
  ^ {|<tr><th></th><th>code layer: what canary knows</th><th>shown in</th><th>running layer: what a run records</th><th>shown in</th></tr>|}
  ^ String.concat ~sep:"\n" (List.map subjects ~f:row)
  ^ "</table>"

(* ── the terminal ── *)

let name_of (id : string) : string =
  match (group_by_id id, box_by_id id) with
  | Some g, _ ->
      Printf.sprintf "%s (%s)" g.gr_name
        (String.concat ~sep:", " (List.map (group_boxes g) ~f:(fun b -> b.bx_name)))
  | None, Some b -> b.bx_name
  | None, None -> id

let words_of_line = function
  | Main s | Sub s -> s
  | Pass (p, ir) -> p ^ " → " ^ ir
  | Link (_, w) -> w

(** §0, and the page's sections, as text. *)
let text () : string =
  let b = Buffer.create 4096 in
  let add s = Buffer.add_string b s in
  add ("§0 of " ^ Canary_overview_assets.docs_path ^ ": outline, terms, and how the page is made\n\n");
  add "The sections\n";
  List.iter sections ~f:(fun s ->
      let indent = if is_top s then "  " else "    " in
      add
        (Printf.sprintf "%s%s  #%s\n%s  slots: %s\n%s  code: %s\n" indent (heading s) s.sc_anchor
           indent
           (if List.is_empty s.sc_slots then "-" else String.concat ~sep:", " s.sc_slots)
           indent (String.concat ~sep:", " s.sc_code)));
  add (Printf.sprintf "  the page as a whole\n    slots: %s\n" (String.concat ~sep:", " page_slots));
  add "\nThe terms\n";
  List.iter terms ~f:(fun (t, d) -> add (Printf.sprintf "  %s: %s\n" t d));
  add "\nThe figure\n";
  List.iter boxes ~f:(fun bx ->
      let words = List.map bx.bx_lines ~f:words_of_line in
      let words =
        match words with w :: rest when String.equal w bx.bx_name -> rest | _ -> words
      in
      add
        (Printf.sprintf "  %s%s%s\n    held by: %s%s\n" bx.bx_name
           (if List.is_empty words then "" else " — " ^ String.concat ~sep:" · " words)
           (if String.is_empty bx.bx_title then "" else "  [" ^ bx.bx_title ^ "]")
           (if List.is_empty bx.bx_held then "no test" else String.concat ~sep:", " bx.bx_held)
           (if String.is_empty bx.bx_agents then ""
            else "\n    agents do not read it whole; they query " ^ bx.bx_agents)));
  add "  arrows:\n";
  List.iter arrows ~f:(fun a ->
      add
        (Printf.sprintf "    %s → %s%s\n" (name_of a.ar_from) (name_of a.ar_to)
           (if String.is_empty a.ar_note then "" else "  (" ^ a.ar_note ^ ")")));
  add "\nEach subject, layer by layer\n";
  let shown l =
    String.concat ~sep:"; "
      (List.map l ~f:(fun (what, secs) -> what ^ " " ^ String.concat ~sep:", " secs))
  in
  List.iter subjects ~f:(fun s ->
      add (Printf.sprintf "  %s\n" s.sj_name);
      List.iter [ ("code layer", s.sj_code); ("running layer", s.sj_run) ] ~f:(fun (name, ly) ->
          add
            (Printf.sprintf "    %s: %s  [%s]\n      shown in: %s\n" name ly.ly_holds
               (String.concat ~sep:" · " ly.ly_from) (shown ly.ly_shown))));
  Buffer.contents b
