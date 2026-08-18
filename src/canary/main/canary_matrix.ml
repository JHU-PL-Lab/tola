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
    {!Canary_status} vocabulary) plus the PROVISION CHOICE of the
    action's primary artifact in this scenario (e.g. [B:d] = built
    @dev, [F:4.16.0] = fetched at a pinned version — the information
    the long scenario names carried, now living in the cell). The
    cell is [None] when the action is NOT part of the scenario's
    chain (distinct from [·] = in the chain, never run). *)
type cell = { mark : string; provision : string }

type row = {
  project : string;
  scenario : string;
      (** the full scenario id — the cmd views' label and the web
          tooltip (the web replaces the long name with ref+platform) *)
  ref_label : string;
      (** the source repo's ref (e.g. "pre-10549", "release-1.14" —
          the declared [ref_]; the source pin id when no repo record
          is declared) *)
  ref_url : string option;
      (** the remote link to the exact commit/tree, when the repo has
          a Git remote *)
  platform : string;
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

(* ── the web row's identity: repo ref + platform (2026-08-17, user's
   web refinement) ──
   The long scenario names duplicate the action columns (the
   provision×channel encoding IS the chain). The web view replaces the
   scenario column with the information the actions DON'T show: the
   repo ref (linked to the remote commit/tree) and the platform. *)

(** The scenario's source repo record: the source artifact's provider
    ([Repo_axes]/[Repo] family), matched by the source placement's
    pinned version id — the generic read of the per-repo identity (the
    project-local [*_source_for_assignment] dispatches use the same
    data). *)
let source_repo_of (pr : Canary_project_run.project_run)
    (a : Canary_artifact.assignment) :
    Canary_artifact_source.source_repo option =
  let src_id =
    (Canary_enumerate.version_of a Canary_artifact.a_source).Canary_basic.id
  in
  let repos =
    match
      Canary_project_run.provenance_of pr Canary_artifact.a_source
    with
    | Some (Canary_store_config.Repo r) -> [ r ]
    | Some (Canary_store_config.Repo_axes rs) -> rs
    | _ -> []
  in
  List.find repos ~f:(fun (r : Canary_artifact_source.source_repo) ->
      String.equal r.Canary_artifact_source.version.Canary_basic.id src_id)

(** A 7+ char all-hex ref is a commit SHA; anything else (tags,
    branches) is a tree. *)
let is_sha (ref_ : string) : bool =
  String.length ref_ >= 7
  && String.for_all ref_ ~f:(fun c ->
         Char.(c >= '0' && c <= '9') || Char.(c >= 'a' && c <= 'f'))

(** The remote link to the exact commit/tree, when the repo has a Git
    remote. The canonical URL strips a trailing [.git]. *)
let ref_url_of (r : Canary_artifact_source.source_repo) : string option =
  match r.Canary_artifact_source.remote with
  | Some (Canary_artifact_source.Git url) ->
      let base =
        Option.value
          (String.chop_suffix url ~suffix:".git")
          ~default:url
      in
      Some
        (base ^ "/" ^ (if is_sha r.Canary_artifact_source.ref_ then "commit"
                       else "tree")
        ^ "/" ^ r.Canary_artifact_source.ref_)
  | Some _ | None -> None

(** The platform label (universal today — one distro per machine; the
    macOS CI column is the future value). *)
let platform_label () : string =
  match Canary_basic.detect_distro () with
  | Canary_store.Wsl -> "wsl_ubuntu"
  | Canary_store.MacOS_local -> "macos_local"

(* ── the cell's provision choice ── *)

(** The action's PRIMARY artifact for a provision read: the one it
    PRODUCES (build/fetch/publish); a probe shows its consumer — the
    binding of its lang first (the consumer-of-interest), else the
    first. *)
let action_artifact (act : Canary_basic.action)
    (a : Canary_artifact.assignment) : Canary_artifact.artifact_id option =
  let pick (ks : Canary_basic.artifact_kind list) :
      Canary_basic.artifact_kind option =
    match ks with
    | [] -> None
    | _ -> (
        match
          List.find ks ~f:(function Canary_basic.Binding _ -> true | _ -> false)
        with
        | Some k -> Some k
        | None -> Some (List.hd_exn ks))
  in
  let kind =
    match Canary_action.produces_of_action act with
    | [] -> pick (Canary_action.consumes_of_action act)
    | ks -> pick ks
  in
  Option.bind kind ~f:(fun k ->
      let lang =
        match act with
        | Canary_basic.Build_binding l | Canary_basic.Probe_binding l
        | Canary_basic.Fetch (Canary_basic.Binding l)
        | Canary_basic.Publish (Canary_basic.Binding l) -> Some l
        | Canary_basic.Build_app { lang = l; _ }
        | Canary_basic.Probe_app { lang = l; _ } -> Some l
        | _ -> None
      in
      List.find_map a ~f:(fun (id, _) ->
          if
            Canary_basic.equal_artifact_kind
              (Canary_artifact.kind_of id)
              k
            && (match (lang, id.Canary_artifact.kind) with
                | Some l, Canary_basic.Binding l' -> Poly.equal l l'
                | None, _ -> true
                | _ -> false)
          then Some id
          else None))

(** The provision CHOICE string for one artifact in the scenario:
    [F] fetched (with the pinned version when one exists — the binding
    pin is identity), [B:d]/[B:s] built @dev/@stable, [V:d]/[V:s]
    vendored. Empty when absent/unknown. *)
let provision_choice (a : Canary_artifact.assignment)
    (id : Canary_artifact.artifact_id) : string =
  match Canary_enumerate.placement_of a id with
  | None -> ""
  | Some (pl : Canary_artifact.placement) ->
      let ch =
        match pl.Canary_artifact.version.Canary_basic.channel with
        | Canary_basic.Stable -> ":s"
        | Canary_basic.Dev -> ":d"
      in
      (match pl.Canary_artifact.provision with
       | Canary_artifact.Fetched ->
           (* the SOURCE's pin repeats the ref column — keep it bare;
              a binding's pin (e.g. 4.16.0) IS identity-bearing info
              the ref column doesn't show *)
           let pin = pl.Canary_artifact.version.Canary_basic.id in
           if Canary_artifact.equal_artifact_id id Canary_artifact.a_source
              || String.is_empty pin
           then "F"
           else "F:" ^ pin
       | Canary_artifact.Built -> "B" ^ ch
       | Canary_artifact.Vendored -> "V" ^ ch
       | Canary_artifact.Absent -> "")

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
        let platform = platform_label () in
        List.map (Canary_project_run.scenarios_of pr) ~f:(fun a ->
            let chain_acts = actions_of pr a in
            let chain_tags =
              List.map chain_acts ~f:Canary_basic.string_of_action
            in
            let scenario =
              Stdlib.Filename.basename
                (Canary_project_run.scenario_dir_of ~pr_name:project a)
            in
            let run = run_of_scenario ~scenario runs in
            let repo = source_repo_of pr a in
            let src_id =
              (Canary_enumerate.version_of a Canary_artifact.a_source)
                .Canary_basic.id
            in
            let ref_label =
              match repo with
              | Some r -> r.Canary_artifact_source.ref_
              | None ->
                  (if String.is_empty src_id then "(ambient)" else src_id)
            in
            let ref_url = Option.bind repo ~f:ref_url_of in
            { project;
              scenario;
              ref_label;
              ref_url;
              platform;
              cells =
                List.map columns ~f:(fun tag ->
                    if List.mem chain_tags tag ~equal:String.equal then
                      (* the cell's provision choice: the action's
                         primary artifact in THIS scenario (the same
                         action may appear twice — Probe_lib over two
                         locations — one provision either way) *)
                      let provision =
                        match
                          List.find chain_acts ~f:(fun act ->
                              String.equal
                                (Canary_basic.string_of_action act)
                                tag)
                        with
                        | Some act -> (
                            match action_artifact act a with
                            | Some id -> provision_choice a id
                            | None -> "")
                        | None -> ""
                      in
                      (tag, Some { mark = mark_of_run ~run tag; provision })
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

(** Self-contained page: the full union-column table — project | ref
    (linked to the remote commit/tree) | platform | actions — colored
    cells showing the provision choice + the verdict. The long
    scenario ids live in the cell tooltips. The styling mirrors
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
    "<th>project</th><th>ref</th><th>platform</th>"
    ^ String.concat ~sep:""
        (List.map m.columns ~f:(fun c -> "<th>" ^ esc c ^ "</th>"))
  in
  let body =
    String.concat ~sep:""
      (List.map m.rows ~f:(fun (r : row) ->
           let ref_cell =
             match r.ref_url with
             | Some url ->
                 Printf.sprintf "<a href=\"%s\" title=\"%s\">%s</a>"
                   (esc url) (esc r.scenario) (esc r.ref_label)
             | None ->
                 Printf.sprintf "<span title=\"%s\">%s</span>"
                   (esc r.scenario) (esc r.ref_label)
           in
           let cells =
             String.concat ~sep:""
               (List.map m.columns ~f:(fun tag ->
                    match
                      List.Assoc.find r.cells tag ~equal:String.equal
                    with
                    | Some (Some c) ->
                        Printf.sprintf
                          "<td class=\"%s\" title=\"%s · %s\"><span class=\"prov\">%s</span><span class=\"mk\">%s</span></td>"
                          (cell_cls c.mark) (esc r.scenario) (esc tag)
                          (esc c.provision) (esc c.mark)
                    | _ -> "<td class=\"blank\"></td>"))
           in
           Printf.sprintf
             "<tr><td>%s</td><td class=\"ref\">%s</td><td class=\"platform\">%s</td>%s</tr>"
             (esc r.project) ref_cell (esc r.platform) cells))
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
td.ref { font-family: ui-monospace, monospace; font-size: .78rem; }
td.ref a { color: #0969da; text-decoration: none; }
td.ref a:hover { text-decoration: underline; }
td.platform { color: #57606a; font-size: .75rem; }
td .prov { color: #57606a; font-family: ui-monospace, monospace; font-size: .7rem; margin-right: 5px; }
td .mk { font-weight: 600; }
td.ok { background: #dafbe1; } td.xfail { background: #fff8c5; }
td.fail { background: #ffebe9; } td.fail .mk { font-weight: 800; }
td.notrun { color: #8c959f; } td.blocked { color: #57606a; background: #f6f8fa; }
td.blank { background: #f6f8fa; }
</style></head><body>
<h1>canary result matrix</h1>
<div class="meta">generated %s — rows = project × scenario; columns = actions, cells = provision choice + verdict (hover a cell for the full scenario id). Pre/post-check columns: future.</div>
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
