(** §1.2's result table: its columns ([Canary_frames]), its header, and
    each recorded row's cells. A row's cells are computed here, once, when
    a machine writes its runs file, and filed by column; the page's script
    and the export only lay them out under today's columns. *)

open Base
module T = Canary_topology
module Fr = Canary_frames
module M = Canary_matrix

let esc = Canary_overview_assets.esc

let layer_word : T.layer -> string = function
  | T.L_pm -> "pm"
  | T.L_package -> "pkg"
  | T.L_artifact -> "art"
  | T.L_program -> "prog"

let node_layer n =
  Option.value_map (T.node_by_id n) ~default:"art" ~f:(fun nd -> layer_word nd.T.nd_layer)

let node_label n = Option.value_map (T.node_by_id n) ~default:n ~f:(fun nd -> nd.T.nd_label)

let edge_layer id =
  Option.value_map
    (List.find T.edges ~f:(fun e -> String.equal e.T.eg_id id))
    ~default:"art"
    ~f:(fun e -> node_layer e.T.eg_to)

(* ── the columns ── *)

(** The key a column's cells are filed under: its frame, then what it
    shows. *)
let key_of (fr : Fr.frame) (c : Fr.column) : string =
  fr.Fr.fr_label ^ "|"
  ^
  match c with
  | Fr.Node n -> "n|" ^ n
  | Fr.Piece { label; _ } -> "p|" ^ label
  | Fr.Check { slug; site; stage; _ } ->
      String.concat ~sep:"|" [ "c"; slug; Canary_agreement_common.string_of_stage stage; site ]

(** Every column, in order, with its frame and its key. *)
let columns : (Fr.frame * Fr.column * string) list =
  List.concat_map Fr.frames ~f:(fun fr ->
      List.map fr.Fr.fr_columns ~f:(fun c -> (fr, c, key_of fr c)))

let keys () = List.map columns ~f:(fun (_, _, k) -> k)

(** The header: the sides, the frames, and each column. *)
let thead () : string =
  let rec sides = function
    | [] -> []
    | (fr : Fr.frame) :: _ as frs ->
        let same, rest =
          List.split_while frs ~f:(fun f -> Poly.equal f.Fr.fr_side fr.Fr.fr_side)
        in
        ( Fr.label_of_side fr.Fr.fr_side,
          List.sum (module Int) same ~f:(fun f -> List.length f.Fr.fr_columns) )
        :: sides rest
  in
  let h1 =
    {|<tr><th class="rt-lab" rowspan="3">chain · machine</th>|}
    ^ String.concat
        (List.map (sides Fr.frames) ~f:(fun (label, span) ->
             Printf.sprintf {|<th class="rt-side" colspan="%d">%s</th>|} span (esc label)))
    ^ "</tr>"
  in
  let h2 =
    "<tr>"
    ^ String.concat
        (List.map Fr.frames ~f:(fun fr ->
             Printf.sprintf {|<th class="rt-fr" colspan="%d">%s</th>|}
               (List.length fr.Fr.fr_columns) (esc fr.Fr.fr_label)))
    ^ "</tr>"
  in
  let h3 =
    "<tr>"
    ^ String.concat
        (List.map columns ~f:(fun (_, c, _) ->
             match c with
             | Fr.Node n ->
                 Printf.sprintf {|<th class="rt-%s" title="%s">%s</th>|} (node_layer n) (esc n)
                   (esc (node_label n))
             | Fr.Piece { edges; label } ->
                 Printf.sprintf {|<th class="rt-hp rt-u-%s" title="%s">%s</th>|}
                   (edge_layer (List.hd_exn edges))
                   (esc (String.concat ~sep:", " edges))
                   (esc label)
             | Fr.Check { slug; code; site; stage } ->
                 let stage = Canary_agreement_common.string_of_stage stage in
                 Printf.sprintf {|<th class="rt-hc rt-u-%s" title="%s">%s%s</th>|} (edge_layer site)
                   (esc (slug ^ " — " ^ stage ^ ", at " ^ site))
                   (if String.equal stage "pre" then "›" else "»")
                   (esc code)))
    ^ "</tr>"
  in
  "<thead>" ^ h1 ^ h2 ^ h3 ^ "</thead>"

(* ── the marks ── *)

(** What a piece shows for its step's state. *)
type step_mark = { sm_state : string; sm_mark : string; sm_look : string; sm_means : string }

let step_marks : step_mark list =
  let s state mark look means = { sm_state = state; sm_mark = mark; sm_look = look; sm_means = means } in
  [ s "ran" "✓" "rt-ok" "ran"; s "warm" "✓" "rt-warm" "warm"; s "fail" "✗" "rt-bad" "failed";
    s "xfail" "xf" "rt-xf" "expected failure"; s "blocked" "⊘" "rt-bad" "blocked";
    s "unrecorded" "·" "rt-dim" "not recorded"; s "absent" "—" "rt-dim" "not in this run";
    s "inside" "⌂" "rt-dim" "inside a package manager's action";
    s "included" "∈" "rt-dim" "included with the language";
    s "observed" "~" "rt-dim" "someone else's relation";
    s "not_ours" "~" "rt-dim" "someone else's relation" ]

let mark_of_step (st : string) : string * string =
  match List.find step_marks ~f:(fun m -> String.equal m.sm_state st) with
  | Some m -> (m.sm_mark, m.sm_look)
  | None -> ("?", "rt-dim")

let mark_of_outcome (o : string) : string * string =
  match List.find M.outcome_marks ~f:(fun m -> String.equal m.M.om_label o) with
  | Some m -> (m.M.om_mark, m.M.om_look)
  | None -> (o, "rt-dim")

(** The key under the table: each piece mark and what it means; a check
    cell's marks are its outcomes', in the outcomes table. *)
let legend () : string =
  let entries =
    List.fold step_marks ~init:[] ~f:(fun acc m ->
        let e = (m.sm_mark, m.sm_look, m.sm_means) in
        if List.mem acc e ~equal:Poly.equal then acc else acc @ [ e ])
  in
  String.concat ~sep:" · "
    (List.map entries ~f:(fun (mark, look, means) ->
         Printf.sprintf {|<span class="%s">%s</span> %s|} look (esc mark) (esc means)))
  ^ Printf.sprintf
      {| · a check cell shows its outcome's mark (<a href="#tab-outcomes">%s</a>) · <i>italic</i> declared, not recorded|}
      (esc (Canary_overview_exhibits.label (Canary_overview_exhibits.find "tab-outcomes")))

(* ── a recorded row ── *)

(** What a recorded world gives its row's cells. *)
type facts = {
  f_edges : (string * string) list;  (** edge → its state *)
  f_gone : string list;  (** nodes and edges this chain does not have *)
  f_names : (string * (string * string)) list;  (** node → (name, recorded | declared) *)
  f_nodes : (string * string) list;  (** node → its placement *)
  f_counts : (string * string) list;  (** node → how much of it was recorded *)
  f_outcomes : (string * string) list;  (** claim → outcome *)
  f_blames : (string * string) list;  (** claim → blame *)
}

(** A row's cells, filed by column key. A frame is in the chain when a step
    realized one of its pieces; a node's first cell shows it and a later
    one is where it is consumed; a piece shows its first recorded edge. *)
let cells (f : facts) : (string * string) list =
  let find l k = List.Assoc.find l k ~equal:String.equal in
  let gone x = List.mem f.f_gone x ~equal:String.equal in
  let recorded e =
    match find f.f_edges e with
    | Some st -> (not (String.equal st "absent")) && not (gone e)
    | None -> false
  in
  let on (fr : Fr.frame) =
    List.exists fr.Fr.fr_columns ~f:(function
      | Fr.Piece { edges; _ } -> List.exists edges ~f:recorded
      | _ -> false)
  in
  let shown = ref [] in
  List.map columns ~f:(fun (fr, c, key) ->
      let here = on fr in
      let td =
        match c with
        | Fr.Node n ->
            let cls = "rt-" ^ node_layer n in
            if (not here) || gone n then Printf.sprintf {|<td class="%s rt-off"></td>|} cls
            else
              let label, from = Option.value (find f.f_names n) ~default:("", "") in
              let place = Option.value (find f.f_nodes n) ~default:"" in
              let full =
                String.concat ~sep:" — "
                  (List.filter [ label; place ] ~f:(fun t -> not (String.is_empty t)))
              in
              if List.mem !shown n ~equal:String.equal then
                Printf.sprintf {|<td class="%s rt-rep" title="%s">%s</td>|} cls (esc full) (esc label)
              else begin
                shown := n :: !shown;
                Printf.sprintf {|<td class="%s%s" title="%s">%s%s</td>|} cls
                  (if String.equal from "declared" then " rt-decl" else "")
                  (esc full)
                  (esc (if String.is_empty label then place else label))
                  (match find f.f_counts n with
                   | Some x when not (String.is_empty x) ->
                       {| <span class="rt-x">|} ^ esc x ^ "</span>"
                   | _ -> "")
              end
        | Fr.Piece { edges; _ } ->
            if not here then {|<td class="rt-off"></td>|}
            else
              let st =
                Option.value ~default:"absent"
                  (List.find_map edges ~f:(fun e ->
                       match find f.f_edges e with
                       | Some s when not (String.equal s "absent") -> Some s
                       | _ -> None))
              in
              let mark, look = mark_of_step st in
              Printf.sprintf {|<td class="rt-p %s" title="%s">%s</td>|} look
                (esc (String.concat ~sep:", " edges ^ ": " ^ st))
                (esc mark)
        | Fr.Check { slug; _ } ->
            if not here then {|<td class="rt-off"></td>|}
            else
              let o = find f.f_outcomes slug in
              let mark, look =
                match o with Some o -> mark_of_outcome o | None -> ("·", "rt-dim")
              in
              let blame =
                match find f.f_blames slug with
                | Some b ->
                    Printf.sprintf " — blame: %s (%s)" b
                      (Option.value (List.Assoc.find M.blame_gloss b ~equal:String.equal) ~default:"")
                | None -> ""
              in
              Printf.sprintf {|<td class="rt-c %s" title="%s">%s</td>|} look
                (esc
                   (slug ^ ": "
                   ^ Option.value o ~default:"not evaluated in any recorded run"
                   ^ blame))
                (esc mark)
      in
      (key, td))

(** As [encodeURIComponent] spells a URL's component. *)
let uri_component (s : string) : string =
  String.concat_map s ~f:(fun c ->
      if Char.is_alphanum c || String.mem "-_.!~*'()" c then String.of_char c
      else Printf.sprintf "%%%02X" (Char.to_int c))

(** A recorded row: the key it sorts by, its opening — its id, and the
    chain and machine it names, linking to the chain drawn in §1 — and its
    cells. *)
type row = { rw_sort : string; rw_head : string; rw_cells : (string * string) list }

let row ~(machine : string) ~(project : string) ~(id : string) (f : facts) : row =
  let key = id ^ "@" ^ machine in
  { rw_sort = String.concat ~sep:"|" [ project; id; machine ];
    rw_head =
      Printf.sprintf
        {|<tr id="row-%s"><th class="rt-lab"><a href="#rec=%s" data-key="%s"><b>%s</b> %s</a> <span class="rt-m">@%s</span></th>|}
        (esc key) (uri_component key) (esc key) (esc project) (esc id) (esc machine);
    rw_cells = cells f }

let json_of_row (r : row) : Yojson.Basic.t =
  `Assoc
    [ ("sort", `String r.rw_sort);
      ("head", `String r.rw_head);
      ("cells", `Assoc (List.map r.rw_cells ~f:(fun (k, td) -> (k, `String td)))) ]

let row_of_json (j : Yojson.Basic.t) : row option =
  let get k = match j with `Assoc kv -> List.Assoc.find kv k ~equal:String.equal | _ -> None in
  match (get "sort", get "head", get "cells") with
  | Some (`String s), Some (`String h), Some (`Assoc cs) ->
      Some
        { rw_sort = s;
          rw_head = h;
          rw_cells = List.filter_map cs ~f:(function k, `String td -> Some (k, td) | _ -> None) }
  | _ -> None

(* ── the table ── *)

(** A cell for a column the row's runs file was written before. *)
let missing = {|<td class="rt-off" title="recorded before this column existed"></td>|}

(** The rows, sorted, each laid out over today's columns. *)
let tbody_rows (rows : row list) : string =
  List.sort rows ~compare:(fun a b -> String.compare a.rw_sort b.rw_sort)
  |> List.map ~f:(fun r ->
         r.rw_head
         ^ String.concat
             (List.map columns ~f:(fun (_, _, k) ->
                  Option.value (List.Assoc.find r.rw_cells k ~equal:String.equal) ~default:missing))
         ^ "</tr>")
  |> String.concat

(** The table, captioned: its header, and the rows given — none on the
    page, whose script lays them out from the runs files. *)
let table ?(rows = []) () : string =
  Canary_overview_exhibits.table ~cls:"rt" "tab-results"
  ^ thead () ^ {|<tbody id="rtbody">|} ^ tbody_rows rows ^ "</tbody></table>"

(** What the page's script lays the rows out by: the column keys in order,
    and the cell for a column a row predates. *)
let columns_json () : string =
  Yojson.Basic.to_string
    (`Assoc
      [ ("keys", `List (List.map (keys ()) ~f:(fun k -> `String k))); ("missing", `String missing) ])
  |> String.substr_replace_all ~pattern:"</" ~with_:"<\\/"
