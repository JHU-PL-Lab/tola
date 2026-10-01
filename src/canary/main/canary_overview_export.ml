(** The page's figures and tables as files of their own, for a manuscript
    to embed: each named by its id, without the page's caption and
    number. A figure is a standalone SVG carrying the page's light-theme
    styles; a table is an HTML fragment, styled by whatever embeds it.
    Made by the generators that make the page, beside the page rather
    than from it. *)

open Base
module E = Canary_overview_exhibits

(** Where the files go: beside the manuscript, or under [_out/] when this
    machine renders another platform's view. *)
let dir () =
  if Canary_store.platform_is_overridden () then "_out/canary/exhibits" else E.export_dir

(** The exhibits the export does not make, and why. *)
let not_exported : (string * string) list = []

(** The exhibits a choice of chain draws. *)
let drawn_by_choice = [ "fig-chain"; "tab-lines" ]

(* ── the page's styles, for a drawing on its own ── *)

(** The stylesheet's top-level rules, as selector and declarations; an
    at-rule's block (dark mode, narrow screens) is left out. *)
let rules (css : string) : (string * string) list =
  let n = String.length css in
  let rec close i depth =
    if i >= n then n
    else
      match css.[i] with
      | '{' -> close (i + 1) (depth + 1)
      | '}' -> if depth = 1 then i + 1 else close (i + 1) (depth - 1)
      | _ -> close (i + 1) depth
  in
  let rec go i acc =
    match String.index_from css i '{' with
    | None -> List.rev acc
    | Some o ->
        let sel = String.strip (String.sub css ~pos:i ~len:(o - i)) in
        let e = close o 0 in
        let body = String.strip (String.sub css ~pos:(o + 1) ~len:(max 0 (e - o - 2))) in
        go e (if String.is_prefix sel ~prefix:"@" then acc else (sel, body) :: acc)
  in
  go 0 []

let ident c = Char.is_alphanum c || Char.equal c '-' || Char.equal c '_'

(** Does the selector [sel] name the class [c]? *)
let has_class (sel : string) (c : string) : bool =
  let pat = "." ^ c in
  List.exists (String.substr_index_all sel ~may_overlap:false ~pattern:pat) ~f:(fun i ->
      let k = i + String.length pat in
      k >= String.length sel || not (ident sel.[k]))

(** The classes [svg] uses. *)
let classes_of (svg : string) : string list =
  String.substr_index_all svg ~may_overlap:false ~pattern:{|class="|}
  |> List.concat_map ~f:(fun i ->
         let s = i + String.length {|class="|} in
         match String.index_from svg s '"' with
         | Some e -> String.split (String.sub svg ~pos:s ~len:(e - s)) ~on:' '
         | None -> [])
  |> List.filter ~f:(fun c -> not (String.is_empty c))
  |> List.dedup_and_sort ~compare:String.compare

(** [svg] as a file of its own: its namespace and size, and the rules of
    the page's light theme that reach it. [scope] joins the root's
    classes where the page scopes a rule to the drawing's container. *)
let standalone ?(scope = "") (svg : string) : string =
  let tag_end = Option.value (String.index svg '>') ~default:0 in
  let attrs = String.sub svg ~pos:4 ~len:(tag_end - 4) in
  let attrs =
    if String.is_empty scope then attrs
    else String.substr_replace_first attrs ~pattern:{|class="|} ~with_:({|class="|} ^ scope ^ " ")
  in
  let w, h =
    match String.substr_index attrs ~pattern:{|viewBox="|} with
    | Some i -> (
        let s = i + String.length {|viewBox="|} in
        let e = Option.value (String.index_from attrs s '"') ~default:s in
        match String.split (String.sub attrs ~pos:s ~len:(e - s)) ~on:' ' with
        | [ _; _; w; h ] -> (w, h)
        | _ -> ("100%", "100%"))
    | None -> ("100%", "100%")
  in
  let opening =
    Printf.sprintf {|<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s"%s>|} w h attrs
  in
  let rest = String.drop_prefix svg (tag_end + 1) in
  let css = rules (Canary_overview_assets.read "page.css") in
  let used = classes_of (opening ^ rest) in
  let rule (sel, body) = sel ^ "{" ^ body ^ "}" in
  (* the page's text, which the drawing's own rules refine *)
  let text =
    List.filter_map css ~f:(fun (sel, body) ->
        if String.equal sel "body" then
          Some
            (":root{"
            ^ String.concat ~sep:";"
                (List.filter
                   (List.map (String.split body ~on:';') ~f:String.strip)
                   ~f:(fun d -> String.is_prefix d ~prefix:"font" || String.is_prefix d ~prefix:"color"))
            ^ "}")
        else None)
  in
  let style =
    List.map (List.filter css ~f:(fun (sel, _) -> String.equal sel ":root")) ~f:rule
    @ text
    @ List.map (List.filter css ~f:(fun (sel, _) -> List.exists used ~f:(has_class sel))) ~f:rule
    (* the drawing is the whole file: none of the page's margins or frame *)
    @ [ "svg:root{width:auto;height:auto;max-width:none;margin:0;padding:0;border:0;border-radius:0}" ]
  in
  opening ^ "<style><![CDATA[" ^ String.concat ~sep:"\n" style ^ "]]></style>" ^ rest

(* ── the files ── *)

(** Every exhibit the export writes, in page order: its file name and its
    content. [overview] is §2, which holds three of the tables. With a
    [choice], only the exhibits it draws, drawn for it from [views]. *)
let files ?choice ?(views = []) ?(tests = [])
    (projects : (string * Canary_project_run.project_run) list) ~(overview : string) :
    (string * string) list =
  let module Tb = Canary_overview_tables in
  let module Dr = Canary_overview_draw in
  let join = Canary_overview_join.of_projects projects in
  let d = Dr.drawing join ~views (Option.value choice ~default:(Dr.opening join)) in
  let figure = function
    | "fig-flow" -> Some (standalone (Canary_overview_flow.svg ()))
    | "fig-chain" ->
        Some
          (standalone
             ~scope:(if Option.is_some d.Dr.dr_view then "join rec" else "join")
             (Dr.svg d))
    | _ -> None
  in
  let table_source = function
    | "tab-subjects" -> Some (Canary_overview_flow.table ())
    | "tab-tests" -> Some (Canary_overview_tests.table tests)
    | "tab-lines" -> Some (Dr.lines_table d)
    (* every machine's rows, from the runs files the page loads *)
    | "tab-results" ->
        Some (Canary_overview_results.table ~rows:(Canary_overview_runs.recorded_rows ()) ())
    | "tab-nodes" -> Some (Canary_overview_panel.node_legend ())
    | "tab-outcomes" | "tab-agreements" | "tab-sittings" -> Some overview
    | "tab-census" -> Some (Tb.claim_sites_table ())
    | "tab-pm" -> Some (Tb.pm_solo_table projects)
    | "tab-mechanisms" -> Some (Tb.binding_table projects)
    | "tab-cooperation" -> Some (Tb.coop_table projects)
    | "tab-chains" -> Some (Tb.chains_table join)
    | _ -> None
  in
  let wanted e =
    Option.is_none choice || List.mem drawn_by_choice e.E.ex_id ~equal:String.equal
  in
  List.filter_map (List.filter E.exhibits ~f:wanted) ~f:(fun e ->
      match e.E.ex_kind with
      | E.Figure -> Option.map (figure e.E.ex_id) ~f:(fun c -> (E.file_name e, c))
      | E.Table ->
          Option.map
            (Option.bind (table_source e.E.ex_id) ~f:(E.bare_table e.E.ex_id))
            ~f:(fun c -> (E.file_name e, c ^ "\n")))

(** Write the exhibits into [dir]; the directory written. *)
let write ?dir:(d = dir ()) ?choice ?views ?tests
    (projects : (string * Canary_project_run.project_run) list) ~(overview : string) : string =
  let rec mkdir_p p =
    if not (Stdlib.Sys.file_exists p) then begin
      mkdir_p (Stdlib.Filename.dirname p);
      Stdlib.Sys.mkdir p 0o755
    end
  in
  mkdir_p d;
  List.iter (files ?choice ?views ?tests projects ~overview) ~f:(fun (name, content) ->
      Stdlib.Out_channel.with_open_bin (Stdlib.Filename.concat d name) (fun oc ->
          Stdlib.Out_channel.output_string oc content));
  d
