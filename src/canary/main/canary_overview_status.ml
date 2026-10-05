(** The page's front matter, where the project stands. Two kinds of rows:
    those computed when the page is made, from the code and the runs
    files, and those recorded in [canary/overview/status.json] (a value,
    the date it was read and how to read it again), which change only when
    someone flushes them by following each row's how. [text] prints both
    ([canary overview --status]). *)

open Base

let esc = Canary_overview_assets.esc

(* ── computed now ── *)

(** Each computed row: what, its value now, and the command that shows it. *)
let live ?(tests = []) () : (string * string * string) list =
  let module T = Canary_topology in
  let module A = Canary_agreement in
  let dir = Stdlib.Filename.dirname Canary_overview_assets.docs_path in
  let machines = Canary_overview_runs.recorded_machines ~dir () in
  let missing =
    List.filter Canary_overview_runs.all_file_names ~f:(fun f ->
        not (Stdlib.Sys.file_exists (Stdlib.Filename.concat dir f)))
  in
  let field v k =
    match List.Assoc.find v k ~equal:String.equal with Some (`String s) -> s | _ -> ""
  in
  let projects_run =
    List.concat_map machines ~f:(fun (_, vs) -> List.map vs ~f:(fun v -> field v "project"))
    |> List.dedup_and_sort ~compare:String.compare
  in
  let runs =
    String.concat ~sep:"; "
      (List.map machines ~f:(fun (m, vs) ->
           let worlds =
             List.map vs ~f:(fun v -> (field v "project", field v "scenario"))
             |> List.dedup_and_sort ~compare:Poly.compare
           in
           Printf.sprintf "%s: %d worlds, %d chains" m (List.length worlds) (List.length vs))
      @ List.map missing ~f:(fun f -> "no " ^ f))
  in
  let registry = A.agreement_registry in
  let evaluated =
    List.count registry ~f:(fun r ->
        match A.status_of_row r with A.Evaluated | A.Partly -> true | _ -> false)
  in
  let decided =
    Canary_agreement_overview.decided_slugs (Canary_overview_runs.recorded_chains ~dir ())
  in
  let landed = List.count registry ~f:(fun r -> List.mem decided r.A.ag_slug ~equal:String.equal) in
  let irs =
    List.map Canary_overview_flow.passes ~f:snd |> List.dedup_and_sort ~compare:String.compare
  in
  let muted = Canary_registry.muted () in
  [ ( "Projects",
      Printf.sprintf "%d in the registry%s; %d with recorded runs"
        (List.length Canary_registry.all_specs)
        (if List.is_empty muted then ""
         else Printf.sprintf " (muted: %s)" (String.concat ~sep:", " muted))
        (List.length projects_run),
      "canary spec-check @all" );
    ("Recorded runs", runs, "make view on each machine; canary overview --json");
    ( "Agreements",
      Printf.sprintf "%d registered: %d with an evaluator, %d landed (decided by a recorded run)"
        (List.length registry) evaluated landed,
      "canary checks --landing" );
    ( "Candidates",
      Printf.sprintf "%d, so %d claims are placed on the model" (List.length A.proposed_agreements)
        (List.length T.claim_sites),
      "canary checks --firing" );
    ( "The model",
      Printf.sprintf
        "%d layers, %d nodes, %d edges; %d cooperation kinds, %d package managers with \
         drivers, %d binding mechanisms"
        (List.length T.all_components) (List.length T.nodes) (List.length T.edges)
        (List.length T.coop_catalogue) (List.length Canary_pm_solo.table)
        (List.length Canary_mechanism.mechanism_catalogue),
      "canary overview --flow, and §3" );
    ( "The pipeline",
      Printf.sprintf "%d passes over %d IRs" (List.length Canary_overview_flow.passes)
        (List.length irs),
      "canary emit <project> --stage N" );
    ( "Model tests",
      Printf.sprintf "%d, each with the claim it holds (§0.4)"
        (List.sum (module Int) tests ~f:(fun f -> List.length f.Canary_overview_tests.tf_tests)),
      "canary project-test" ) ]

(* ── recorded ── *)

type recorded = { rc_what : string; rc_value : string; rc_as_of : string; rc_how : string }

type track = { tr_track : string; tr_judged : string; tr_judged_on : string; tr_now : string }

type data = {
  d_flushed : string;
  d_recorded : recorded list;
  d_tracks : track list;
  d_through_line : string * string;  (** as of, and the text *)
}

(** [canary/overview/status.json], as last flushed. *)
let data () : data =
  let j = Yojson.Basic.from_string (Canary_overview_assets.read "status.json") in
  let member k = function
    | `Assoc kv -> List.Assoc.find kv k ~equal:String.equal
    | _ -> None
  in
  let str k v = match member k v with Some (`String s) -> s | _ -> "" in
  let list k = match member k j with Some (`List l) -> l | _ -> [] in
  { d_flushed = str "flushed" j;
    d_recorded =
      List.map (list "recorded") ~f:(fun v ->
          { rc_what = str "what" v; rc_value = str "value" v; rc_as_of = str "as_of" v;
            rc_how = str "how" v });
    d_tracks =
      List.map (list "tracks") ~f:(fun v ->
          { tr_track = str "track" v; tr_judged = str "judged" v;
            tr_judged_on = str "judged_on" v; tr_now = str "now" v });
    d_through_line =
      (match member "through_line" j with
       | Some tl -> (str "as_of" tl, str "text" tl)
       | None -> ("", "")) }

(* ── the page ── *)

let table (head : string list) (rows : string list list) : string =
  {|<table class="keytbl status"><thead><tr>|}
  ^ String.concat (List.map head ~f:(fun h -> "<th>" ^ esc h ^ "</th>"))
  ^ "</tr></thead><tbody>"
  ^ String.concat
      (List.map rows ~f:(fun r ->
           "<tr>" ^ String.concat (List.map r ~f:(fun c -> "<td>" ^ c ^ "</td>")) ^ "</tr>"))
  ^ "</tbody></table>"

let date (s : string) = {|<span class="date">|} ^ esc s ^ "</span>"

let live_html ?tests () =
  table [ "what"; "now"; "shown by" ]
    (List.map (live ?tests ()) ~f:(fun (w, v, how) ->
         [ esc w; esc v; "<code>" ^ esc how ^ "</code>" ]))

let recorded_html () =
  let d = data () in
  table [ "what"; "value"; "as of"; "how to read it again" ]
    (List.map d.d_recorded ~f:(fun r -> [ esc r.rc_what; esc r.rc_value; date r.rc_as_of; esc r.rc_how ]))

let tracks_html () =
  let d = data () in
  let as_of, text = d.d_through_line in
  table [ "track"; "judged"; "on"; "where it stands now" ]
    (List.map d.d_tracks ~f:(fun t ->
         [ esc t.tr_track; esc t.tr_judged; date t.tr_judged_on; esc t.tr_now ]))
  ^ Printf.sprintf "<p><b>The through-line</b> (%s). %s</p>" (esc as_of) (esc text)

(* ── the terminal ── *)

(** All of it, for [canary overview --status]. *)
let text ?tests () : string =
  let d = data () in
  let as_of, through = d.d_through_line in
  String.concat ~sep:"\n"
    ([ "Where the project stands"; "  computed now, from the code and the runs files:" ]
    @ List.map (live ?tests ()) ~f:(fun (w, v, how) -> Printf.sprintf "    %s: %s  [%s]" w v how)
    @ [ Printf.sprintf "  recorded, flushed %s (to flush a row, follow its how):" d.d_flushed ]
    @ List.map d.d_recorded ~f:(fun r ->
          Printf.sprintf "    %s: %s  (as of %s; how: %s)" r.rc_what r.rc_value r.rc_as_of r.rc_how)
    @ [ "  the tracks, as judged:" ]
    @ List.map d.d_tracks ~f:(fun t ->
          Printf.sprintf "    %s: %s (%s); now: %s" t.tr_track t.tr_judged t.tr_judged_on t.tr_now)
    @ [ Printf.sprintf "  the through-line (%s): %s" as_of through ])
  ^ "\n"
