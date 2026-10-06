(** The components alone, without their nodes: each side's package manager
    over the artifacts it delivers, with the joins between the sides in the
    middle column, the cooperation between the package managers above and
    the binding between the artifacts below. Drawn on its own; Figure 2's
    nodes, grouped the same way, are {!Canary_overview_diagram.diagram}
    [~by_component:true]. *)

open Base
module T = Canary_topology
module D = Canary_overview_diagram

let esc = Canary_overview_assets.esc
let width = 960
let height = 340
let box_w = 260
let box_h = 86

(** Each component's place: its column (the system side, the joins, the
    language side) and its row (management, artifacts). The program, which
    uses them, is not drawn. *)
let cells : (T.component * (int * int)) list =
  [ (T.Pm_sys, (0, 0)); (T.Pm_coop, (1, 0)); (T.Pm_lang, (2, 0));
    (T.Art_sys, (0, 1)); (T.Binding, (1, 1)); (T.Art_lang, (2, 1)) ]

(** What each component is, in two short lines. *)
let gloss = function
  | T.Pm_sys -> ("the system's package manager:", "its management part")
  | T.Pm_lang -> ("the language's package manager:", "its management part")
  | T.Pm_coop -> ("the cooperation between", "the two package managers")
  | T.Art_sys -> ("system artifacts, and the tools", "that build and inspect them")
  | T.Art_lang -> ("language artifacts and their tools:", "compilers, interpreters, inspectors")
  | T.Binding -> ("the binding mechanism through which", "a language and a system cooperate")
  | T.Program -> ("the program that uses them", "")

let x_of col = 30 + (col * 320)
let y_of row = 60 + (row * 170)
let mid row = y_of row + (box_h / 2)

let box ((c, (col, row)) : T.component * (int * int)) : string =
  let x = x_of col and y = y_of row in
  let l1, l2 = gloss c in
  let cls =
    String.concat ~sep:" "
      ([ "cnode"; (if row = 0 then "cmanage" else "cart") ] @ if col = 1 then [ "cjoin" ] else [])
  in
  Printf.sprintf
    {|<g class="%s"><rect x="%d" y="%d" width="%d" height="%d" rx="10"/>%s<text class="cgloss" x="%d" y="%d">%s</text><text class="cgloss" x="%d" y="%d">%s</text></g>|}
    cls x y box_w box_h
    (D.component_name ~x:(x + 14) ~y:(y + 28) c)
    (x + 14) (y + 54) (esc l1) (x + 14) (y + 70) (esc l2)

let svg () : string =
  let link x0 x1 y =
    Printf.sprintf {|<line class="clink" x1="%d" y1="%d" x2="%d" y2="%d"/>|} x0 y x1 y
  in
  (* each join meets the two sides on its row; the sides never meet *)
  let joins =
    List.concat_map [ 0; 1 ] ~f:(fun row ->
        [ link (x_of 0 + box_w) (x_of 1) (mid row); link (x_of 1 + box_w) (x_of 2) (mid row) ])
  in
  let provides col =
    let x = x_of col + (box_w / 2) in
    Printf.sprintf
      {|<line class="clink" x1="%d" y1="%d" x2="%d" y2="%d" marker-end="url(#ca)"/><text class="clabel" x="%d" y="%d">provides</text>|}
      x (y_of 0 + box_h) x (y_of 1 - 2) (x + 8)
      (((y_of 0 + box_h + y_of 1) / 2) + 4)
  in
  let caption col text =
    Printf.sprintf {|<text class="sidecap" x="%d" y="34">%s</text>|} (x_of col + (box_w / 2)) text
  in
  let row_label row text =
    Printf.sprintf {|<text class="sidecap" x="14" y="%d" transform="rotate(-90 14 %d)">%s</text>|}
      (mid row) (mid row) text
  in
  Printf.sprintf
    {|<svg viewBox="0 0 %d %d" class="diagram comps" role="img"><defs><marker id="ca" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z"/></marker></defs>%s%s%s%s%s</svg>|}
    width height
    (String.concat [ caption 0 "SYSTEM SIDE"; caption 1 "THE JOINS"; caption 2 "LANGUAGE SIDE" ])
    (String.concat [ row_label 0 "MANAGEMENT"; row_label 1 "ARTIFACTS" ])
    (String.concat joins)
    (String.concat [ provides 0; provides 2 ])
    (String.concat (List.map cells ~f:box))
