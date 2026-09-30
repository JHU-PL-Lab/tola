(** The overview page, [canary overview]: [canary/overview/page.html] filled
    from the modules that draw each part — §0 ({!Canary_overview_flow});
    §1's diagram ({!Canary_overview_diagram}), its looks and places
    ({!Canary_overview_looks}) and its panel ({!Canary_overview_panel}); §2
    ({!Canary_agreement_overview}) with §2.2, and §3
    ({!Canary_overview_tables}).
    §1.2 and a chain's recorded run are laid out by the page's scripts from
    the runs files ({!Canary_overview_runs}), which the page loads and does
    not embed. *)

open Base
module T = Canary_topology

let esc = Canary_overview_assets.esc

(** The page's stylesheet, [canary/overview/page.css]. *)
let css () = Canary_overview_assets.read "page.css"

(** §1's script, [canary/overview/page.js]: it keeps the chain chosen,
    looks each answer up in the page's data and the runs files, and
    applies it. *)
let script () = Canary_overview_assets.script "page.js"

(* ── §1.2, the result table: a row per chain and machine, the frames of
   {!Canary_frames} as its columns, every cell a word a view carries ── *)

let layer_word : T.layer -> string = function
  | T.L_pm -> "pm"
  | T.L_package -> "pkg"
  | T.L_artifact -> "art"
  | T.L_program -> "prog"

(** The column model as the table's script reads it: each node's label and
    layer, and each frame's columns — a piece with the layer it makes, a
    check with the layer of its site's product — and what each blame word
    means. *)
let frames_json () : string =
  let module Fr = Canary_frames in
  let layer_of_node n =
    Option.value_map (T.node_by_id n) ~default:"art" ~f:(fun nd -> layer_word nd.T.nd_layer)
  in
  let layer_of_edge id =
    Option.value_map (List.find T.edges ~f:(fun e -> String.equal e.T.eg_id id)) ~default:"art"
      ~f:(fun e -> layer_of_node e.T.eg_to)
  in
  let strs l = `List (List.map l ~f:(fun s -> `String s)) in
  let column = function
    | Fr.Node n -> `Assoc [ ("k", `String "n"); ("id", `String n) ]
    | Fr.Piece { edges; label } ->
        `Assoc
          [ ("k", `String "p"); ("label", `String label); ("edges", strs edges);
            ("layer", `String (layer_of_edge (List.hd_exn edges))) ]
    | Fr.Check { slug; code; site; stage } ->
        `Assoc
          [ ("k", `String "c"); ("slug", `String slug); ("code", `String code);
            ("site", `String site);
            ("stage", `String (Canary_agreement_common.string_of_stage stage));
            ("layer", `String (layer_of_edge site)) ]
  in
  `Assoc
    [ ( "nodes",
        `Assoc
          (List.map T.nodes ~f:(fun nd ->
               ( nd.T.nd_id,
                 `Assoc
                   [ ("label", `String nd.T.nd_label); ("layer", `String (layer_word nd.T.nd_layer)) ] ))) );
      ( "frames",
        `List
          (List.map Fr.frames ~f:(fun fr ->
               `Assoc
                 [ ("side", `String (Fr.string_of_side fr.Fr.fr_side));
                   ("side_label", `String (Fr.label_of_side fr.Fr.fr_side));
                   ("label", `String fr.Fr.fr_label);
                   ("cols", `List (List.map fr.Fr.fr_columns ~f:column)) ])) );
      ( "blames",
        `Assoc (List.map Canary_matrix.blame_gloss ~f:(fun (w, g) -> (w, `String g))) );
      ( "outcomes",
        `Assoc
          (List.map Canary_matrix.outcome_marks ~f:(fun o ->
               ( o.Canary_matrix.om_label,
                 `List [ `String o.Canary_matrix.om_mark; `String o.Canary_matrix.om_look ] )))
      ) ]
  |> Yojson.Basic.to_string
  |> String.substr_replace_all ~pattern:"</" ~with_:"<\\/"

(** §1.2's stylesheet, [canary/overview/results.css]. *)
let results_css () = Canary_overview_assets.read "results.css"

(** §1.2's script, [canary/overview/results.js]: it lays out the words
    {!Canary_overview_runs} computed, under the column model above. *)
let results_script () = Canary_overview_assets.script "results.js"

(** One script tag per machine's runs file, loaded before the scripts
    that draw from them; a missing file is a failed tag and nothing more. *)
let runs_script () =
  String.concat
    (List.map Canary_overview_runs.all_file_names ~f:(fun f ->
         Printf.sprintf {|<script src="%s"></script>
|} f))

(* ── the page ── *)

(** The page: [canary/overview/page.html] with its slots filled. *)
let render (projects : (string * Canary_project_run.project_run) list)
    ~(overview : string) ~(generated_at : string) : string =
  let module P = Canary_overview_panel in
  let module Tb = Canary_overview_tables in
  let bare = T.bare_edges () in
  let join = Canary_overview_join.of_projects projects in
  let sites f = Int.to_string (List.count T.claim_sites ~f) in
  Canary_overview_assets.fill "page.html"
    [ ("css", css () ^ "\n" ^ results_css ());
      ("agreements_css", Canary_agreement_overview.css ());
      ("outline", Canary_overview_flow.outline ());
      ("terms", Canary_overview_flow.terms_html ());
      ("missing_steps", P.missing_steps_note ());
      ("chain_key", Canary_overview_looks.key_html Canary_overview_looks.Chain_key);
      ("join_panel", P.join_panel join);
      ("node_legend", P.node_legend ());
      ("frames_json", frames_json ());
      ("agreement_overview", overview);
      ("sites", Int.to_string (List.length T.claim_sites));
      ("sites_checked", sites T.implemented);
      ("sites_named", sites (fun p -> not (T.implemented p)));
      ("sites_multi", sites (fun p -> List.length p.T.cs_edges > 1));
      ("claim_sites_table", Tb.claim_sites_table ());
      ("bare_count", Int.to_string (List.length bare));
      ("bare_edges", esc (String.concat ~sep:", " (List.map bare ~f:(fun e -> e.T.eg_id))));
      ("pm_solo_table", Tb.pm_solo_table projects);
      ("binding_table", Tb.binding_table projects);
      ("coop_table", Tb.coop_table projects);
      ("topology_notes", Tb.topology_notes projects);
      ("chains_table", Tb.chains_table join);
      ("flow_figure", Canary_overview_flow.figure ());
      ("flow_key", Canary_overview_looks.key_html Canary_overview_looks.Flow_key);
      ("flow_table", Canary_overview_flow.table ());
      ("generated_at", esc generated_at);
      (* the runs files load before the scripts that draw them *)
      ("scripts", runs_script () ^ script () ^ results_script ()) ]

let docs_path = Canary_overview_assets.docs_path

(** The retired result pages' addresses under [docs/canary/projects/]:
    each holds a pointer to §1.2, written with the page. *)
let pointer_dir = "docs/canary/projects"

let pointer_files = [ "matrix.html"; "matrix_mac.html"; "index.html" ]

let pointer_html =
  {|<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta http-equiv="refresh" content="0; url=../overview.html#results">
<title>canary results</title></head><body>
<p>The result table is §1.2 of <a href="../overview.html#results">the overview page</a>.</p>
</body></html>
|}

let write (projects : (string * Canary_project_run.project_run) list)
    ~(overview : string) ~(generated_at : string) : unit =
  let html = render projects ~overview ~generated_at in
  Stdio.Out_channel.write_all docs_path ~data:html;
  Canary_step_model.ensure_dir pointer_dir;
  List.iter pointer_files ~f:(fun f ->
      Stdio.Out_channel.write_all (pointer_dir ^ "/" ^ f) ~data:pointer_html)
