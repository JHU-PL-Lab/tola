open Base

(* ── The result table (2026-08-17, user) ──
   A cross-project verdict matrix: ROWS = project × scenario (the
   ENUMERATED worlds — a stable shape, never-run scenarios show all
   [·]), COLUMNS = actions (the union across the registry in
   catalogue order). Cells carry the last-run verdict from the shared
   actions.log (via {!Canary_status.project_matrix} — the only
   per-scenario run record). The future extension: pre/post-check
   columns ("each checks") appended to the action set.

   Rendered in the cmd (text/md/json) and as the web page
   [docs/canary/projects/matrix.html]. Pure read — no execution. *)

(** One matrix cell: the verdict mark (✓/✗/xfail[cN]/·/⊘ — the
    {!Canary_status} vocabulary). The cell is the empty string when
    the action is NOT part of the scenario's chain (distinct from [·]
    = in the chain, never run). *)
type cell = { mark : string }

type row = {
  project : string;
  scenario : string;
  cells : (string * cell option) list;
      (** per column tag in column order; [None] = not in the chain *)
}

type t = { columns : string list; rows : row list }

let mark_of_run ?(run : (string * (string * string option)) list = [])
    (tag : string) : string =
  match List.Assoc.find run tag ~equal:String.equal with
  | Some (event, detail) -> Canary_status.mark event detail
  | None -> "·"

(** The scenario's run verdicts keyed by tag ([] when the project has
    no actions.log or the scenario never ran). *)
let run_of_scenario ~scenario
    (runs : (string * (string * (string * string option)) list) list) :
    (string * (string * string option)) list =
  match List.Assoc.find runs scenario ~equal:String.equal with
  | Some v -> v
  | None -> []

(** The actions ONE scenario's steps carry (the {!covered_actions_of}
    per-scenario derivation — derive_steps on the scenario's runner
    spec; the pattern's sig chain omits install/publish steps, so the
    honest chain comes from the step list). *)
let actions_of (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) : Canary_basic.action list =
  let spec = pr.Canary_project_run.pr_runner_spec a ~workspace:"_out/tmp" in
  let steps =
    Canary_step_builder.derive_steps ~root:"_out" ~project:pr.pr_name
      ~langs:Canary_lang.[ OCaml; Python ] spec
  in
  List.map steps ~f:(fun (s : Canary_step_model.step) -> s.action)
  |> Stdlib.List.sort_uniq Stdlib.compare

(** Build the matrix over a project list (the bin injects the
    registry). Columns = the sorted union of every project's covered
    actions (the action variant's declaration order); rows = every
    enumerated scenario in registry order. *)
let matrix_of (projects : (string * Canary_project_run.project_run) list) :
    t =
  let root = "_out" in
  let columns =
    List.concat_map projects ~f:(fun (_, pr) ->
        Canary_project_run.covered_actions_of pr)
    |> Stdlib.List.sort_uniq Stdlib.compare
    |> List.map ~f:Canary_basic.string_of_action
  in
  let rows =
    List.concat_map projects ~f:(fun (project, pr) ->
        let runs = Canary_status.project_matrix ~root ~project in
        List.map (Canary_project_run.scenarios_of pr) ~f:(fun a ->
            let chain_tags =
              List.map (actions_of pr a) ~f:Canary_basic.string_of_action
            in
            let scenario =
              Stdlib.Filename.basename
                (Canary_project_run.scenario_dir_of ~pr_name:project a)
            in
            let run = run_of_scenario ~scenario runs in
            { project;
              scenario;
              cells =
                List.map columns ~f:(fun tag ->
                    if List.mem chain_tags tag ~equal:String.equal then
                      (tag, Some { mark = mark_of_run ~run tag })
                    else (tag, None)) }))
  in
  { columns; rows }

(* ── text renderer ── *)

(** Per-project grouped sections; columns with no chain presence in
    the group are elided (the honest blank is invisible, not a glyph). *)
let pp_text (m : t) : unit =
  let groups =
    List.group m.rows ~break:(fun a b ->
        not (String.equal a.project b.project))
  in
  let width = 14 in
  List.iter groups ~f:(fun group ->
      (match group with
       | [] -> ()
       | (r : row) :: _ ->
           (* a column is in the group when any row's cell is non-None *)
           let used =
             List.filter m.columns ~f:(fun tag ->
                 List.exists group ~f:(fun (rr : row) ->
                     match
                       List.Assoc.find rr.cells tag ~equal:String.equal
                     with
                     | Some (Some _) -> true
                     | _ -> false))
           in
           let pad s =
             if String.length s >= width then s ^ " "
             else s ^ String.make (width - String.length s) ' '
           in
           Fmt.pr "@.%s — %d scenario(s)@." r.project (List.length group);
           Fmt.pr "  %s%s@." (pad "scenario")
             (String.concat ~sep:"" (List.map used ~f:pad));
           List.iter group ~f:(fun (rr : row) ->
               let cells =
                 List.map used ~f:(fun tag ->
                     match
                       List.Assoc.find rr.cells tag ~equal:String.equal
                     with
                     | Some (Some c) -> pad c.mark
                     | Some None -> pad ""
                     | None -> pad "")
               in
               Fmt.pr "  %s%s@." (pad rr.scenario)
                 (String.concat ~sep:"" cells))));
  let total = List.length m.rows in
  Fmt.pr "@.legend: ✓ done · not run ⊘ blocked xfail[cN] expected failure (cN confirming contracts) ✗ failed@.";
  Fmt.pr "%d scenario(s) across %d project(s)@." total
    (List.length (List.dedup_and_sort ~compare:String.compare (List.map m.rows ~f:(fun r -> r.project))))

(* ── markdown renderer (GH-renderable) ── *)

let pp_md (m : t) : unit =
  List.iter (List.group m.rows ~break:(fun a b ->
      not (String.equal a.project b.project))) ~f:(fun group ->
      match group with
      | [] -> ()
      | (r : row) :: _ ->
          let used =
            List.filter m.columns ~f:(fun tag ->
                List.exists group ~f:(fun (rr : row) ->
                    match
                      List.Assoc.find rr.cells tag ~equal:String.equal
                    with
                    | Some (Some _) -> true
                    | _ -> false))
          in
          Fmt.pr "### %s@." r.project;
          Fmt.pr "| scenario | %s |@."
            (String.concat ~sep:" | " used);
          Fmt.pr "| --- | %s |@."
            (String.concat ~sep:" | " (List.map used ~f:(fun _ -> "---")));
          List.iter group ~f:(fun (rr : row) ->
              let cells =
                List.map used ~f:(fun tag ->
                    match
                      List.Assoc.find rr.cells tag ~equal:String.equal
                    with
                    | Some (Some c) -> c.mark
                    | Some None -> " "
                    | None -> " ")
              in
              Fmt.pr "| %s | %s |@." rr.scenario
                (String.concat ~sep:" | " cells));
          Fmt.pr "@.")

(* ── JSON ── *)

let to_json (m : t) : Yojson.Basic.t =
  `Assoc
    [ ( "columns",
        `List (List.map m.columns ~f:(fun c -> `String c)) );
      ( "rows",
        `List
          (List.map m.rows ~f:(fun (r : row) ->
               `Assoc
                 [ ("project", `String r.project);
                   ("scenario", `String r.scenario);
                   ( "cells",
                     `Assoc
                       (List.filter_map r.cells ~f:(fun (tag, c) ->
                            match c with
                            | Some c -> Some (tag, `String c.mark)
                            | None -> None)) ) ])) )
    ]

(* ── HTML (the web page) ── *)

(** Self-contained page: the full union-column table, colored cells,
    inside a horizontal scroll container. The styling mirrors
    {!Canary_html}'s badge tones without importing its machinery. *)
let render_html (m : t) ~(generated_at : string) : string =
  let esc s =
    s
    |> String.substr_replace_all ~pattern:"&" ~with_:"&amp;"
    |> String.substr_replace_all ~pattern:"<" ~with_:"&lt;"
    |> String.substr_replace_all ~pattern:">" ~with_:"&gt;"
  in
  let cell_cls mark =
    match mark with
    | "" -> "blank"
    | "·" -> "notrun"
    | "⊘" -> "blocked"
    | "✗" -> "fail"
    | s when String.is_prefix s ~prefix:"xfail" -> "xfail"
    | _ -> "ok"
  in
  let header =
    "<th>project</th><th>scenario</th>"
    ^ String.concat ~sep:""
        (List.map m.columns ~f:(fun c -> "<th>" ^ esc c ^ "</th>"))
  in
  let body =
    String.concat ~sep:""
      (List.map m.rows ~f:(fun (r : row) ->
           let cells =
             String.concat ~sep:""
               (List.map m.columns ~f:(fun tag ->
                    match
                      List.Assoc.find r.cells tag ~equal:String.equal
                    with
                    | Some (Some c) ->
                        Printf.sprintf "<td class=\"%s\" title=\"%s\">%s</td>"
                          (cell_cls c.mark) (esc tag) (esc c.mark)
                    | _ -> "<td class=\"blank\"></td>"))
           in
           Printf.sprintf "<tr><td>%s</td><td class=\"scenario\">%s</td>%s</tr>"
             (esc r.project) (esc r.scenario) cells))
  in
  Printf.sprintf
    {|<!doctype html>
<html><head><meta charset="utf-8"><title>canary result matrix</title>
<style>
body { font-family: system-ui, sans-serif; margin: 2rem; color: #24292f; }
h1 { font-size: 1.4rem; } .meta { color: #6a737d; font-size: .85rem; margin-bottom: 1rem; }
.wrap { overflow-x: auto; border: 1px solid #d0d7de; border-radius: 6px; }
table { border-collapse: collapse; font-size: .82rem; }
th, td { padding: 4px 8px; border-bottom: 1px solid #eaeef2; white-space: nowrap; text-align: left; }
th { background: #f6f8fa; position: sticky; top: 0; }
td.scenario { font-family: ui-monospace, monospace; font-size: .78rem; }
td.ok { background: #dafbe1; } td.xfail { background: #fff8c5; }
td.fail { background: #ffebe9; font-weight: bold; }
td.notrun { color: #8c959f; } td.blocked { color: #57606a; background: #f6f8fa; }
td.blank { background: #f6f8fa; }
</style></head><body>
<h1>canary result matrix</h1>
<div class="meta">generated %s — rows = project × scenario; columns = actions (pre/post-check columns: future)</div>
<div class="wrap"><table><thead><tr>%s</tr></thead><tbody>%s</tbody></table></div>
</body></html>|}
    (esc generated_at) header body

(* The web file locations (the docs copy is the GH Pages view). *)
let web_path ~projects_root = projects_root ^ "/matrix.html"

let docs_path = "docs/canary/projects/matrix.html"

let write_web ~projects_root (m : t) ~(generated_at : string) : unit =
  let html = render_html m ~generated_at in
  List.iter [ web_path ~projects_root; docs_path ] ~f:(fun path ->
      let oc = Stdlib.open_out path in
      Stdlib.output_string oc html;
      Stdlib.close_out oc);
  Fmt.pr "Wrote %s and %s (%d rows)@." (web_path ~projects_root)
    docs_path (List.length m.rows)
