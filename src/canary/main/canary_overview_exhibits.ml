(** The overview page's figures and tables, in page order: each one's id
    (its anchor on the page, and the name to give anything exported from
    it) and its title. A number follows from the order, one counter per
    kind, so adding an exhibit renumbers the ones after it and never its
    id. *)

open Base

let esc = Canary_overview_assets.esc

type kind = Figure | Table

type exhibit = { ex_id : string; ex_kind : kind; ex_title : string }

let exhibits : exhibit list =
  let f id title = { ex_id = id; ex_kind = Figure; ex_title = title } in
  let t id title = { ex_id = id; ex_kind = Table; ex_title = title } in
  [ f "fig-flow" "How this page is made: from canary's code and a run to each section";
    t "tab-subjects" "Each subject's code layer and running layer, and where the page shows them";
    t "tab-tests" "The tests: each test file, its tests, and the boxes of Figure 1 they hold";
    f "fig-chain"
      "A chain, layer by layer: package managers, packages, artifacts and programs, with the \
       actions between them";
    t "tab-lines" "Where the lines under the node labels come from";
    f "fig-components"
      "The components: down each side a package manager, its packages and its artifacts, and \
       the joins between the sides";
    t "tab-nodes" "What each node is";
    t "tab-results" "The results: one row per chain and machine, the frames as columns";
    t "tab-layers"
      "The agreements by layer: the part of the chain each reads in each layer, and the object \
       formats it applies to";
    t "tab-outcomes" "What a log records, what a check cell shows, and the blame it can carry";
    t "tab-agreements"
      "The agreements over the frames: where each rule ran, where it is checked, and what the \
       runs decided";
    t "tab-census" "Every edge of the chain, and the claims on it";
    t "tab-pm" "Each package manager on its own";
    t "tab-mechanisms" "Binding mechanisms, and the claims checked for each";
    t "tab-cooperation" "How two package managers cooperate";
    t "tab-chains" "The chains canary runs" ]

(** Where [canary overview] writes each exhibit on its own, beside the
    manuscript that embeds them. *)
let export_dir = "doc/canary/research/exhibits"

let find (id : string) : exhibit =
  match List.find exhibits ~f:(fun e -> String.equal e.ex_id id) with
  | Some e -> e
  | None -> failwith ("no exhibit " ^ id)

let number (e : exhibit) : int =
  let same = List.filter exhibits ~f:(fun x -> Poly.equal x.ex_kind e.ex_kind) in
  match List.findi same ~f:(fun _ x -> String.equal x.ex_id e.ex_id) with
  | Some (i, _) -> i + 1
  | None -> 0

let label (e : exhibit) : string =
  (match e.ex_kind with Figure -> "Figure " | Table -> "Table ") ^ Int.to_string (number e)

(** The file the export writes the exhibit to. *)
let file_name (e : exhibit) : string =
  e.ex_id ^ match e.ex_kind with Figure -> ".svg" | Table -> ".html"

(** What a caption says: its label, its title, and the file to embed. *)
let caption_text (e : exhibit) : string =
  Printf.sprintf {|<b>%s.</b> %s <code class="exfile" title="%s">%s</code>|} (esc (label e))
    (esc e.ex_title)
    (esc (export_dir ^ "/" ^ file_name e))
    (esc (file_name e))

(** A table's opening tag, with its id and its caption. *)
let table ?cls (id : string) : string =
  Printf.sprintf {|<table%s id="%s"><caption>%s</caption>|}
    (match cls with Some c -> Printf.sprintf {| class="%s"|} c | None -> "")
    id
    (caption_text (find id))

(** The table exhibit [id] as [html] carries it, without its caption. *)
let bare_table (id : string) (html : string) : string option =
  let opening =
    Option.bind (String.substr_index html ~pattern:(Printf.sprintf {| id="%s">|} id)) ~f:(fun p ->
        List.last
          (List.filter (String.substr_index_all html ~may_overlap:false ~pattern:"<table")
             ~f:(fun i -> i < p)))
  in
  Option.bind opening ~f:(fun s ->
      Option.map (String.substr_index html ~pos:s ~pattern:"</table>") ~f:(fun e ->
          let t = String.sub html ~pos:s ~len:(e + String.length "</table>" - s) in
          match
            (String.substr_index t ~pattern:"<caption>", String.substr_index t ~pattern:"</caption>")
          with
          | Some a, Some b -> String.prefix t a ^ String.drop_prefix t (b + String.length "</caption>")
          | _ -> t))

(** A diagram, as the figure it is. *)
let figure (id : string) (svg : string) : string =
  Printf.sprintf {|<figure class="exhibit" id="%s">%s<figcaption>%s</figcaption></figure>|} id svg
    (caption_text (find id))

(** Every exhibit, numbered and linked, for §0. *)
let list_html () : string =
  let count k = List.count exhibits ~f:(fun e -> Poly.equal e.ex_kind k) in
  Printf.sprintf
    {|<details class="exlist"><summary>The %d figures and %d tables</summary><ul>%s</ul></details>|}
    (count Figure) (count Table)
    (String.concat
       (List.map exhibits ~f:(fun e ->
            Printf.sprintf {|<li><a href="#%s">%s</a></li>|} e.ex_id (caption_text e))))
