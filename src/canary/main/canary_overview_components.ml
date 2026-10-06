(** The components alone, without their nodes. Down each side, the
    package manager's management part manages the packages, and the
    packages provide the artifacts. Between the sides, the cooperation
    joins the packages, the managers taking part only through them, and
    the binding mechanism joins the artifacts; the two joins relate.
    Drawn on its own; Figure 2 draws the components' boxes around its
    nodes while their buttons are on ({!Canary_overview_diagram.diagram}
    [~boxes]), a manager's box holding the packages it manages. *)

open Base
module T = Canary_topology
module D = Canary_overview_diagram

let esc = Canary_overview_assets.esc
let width = 960
let height = 476
let box_w = 260
let box_h = 86

(** A box of the figure: a component, or a side's packages. *)
type cell = Component of T.component | Packages of T.side

(** Each box's place: its column (the system side, the joins, the language
    side) and its row (management, packages, artifacts). The cooperation
    sits with the packages it joins, the binding mechanism with the
    artifacts. The program, which uses them, is not drawn. *)
let cells : (cell * (int * int)) list =
  [ (Component T.Pm_sys, (0, 0)); (Component T.Pm_lang, (2, 0));
    (Packages T.S_sys, (0, 1)); (Component T.Pm_coop, (1, 1)); (Packages T.S_lang, (2, 1));
    (Component T.Art_sys, (0, 2)); (Component T.Binding, (1, 2)); (Component T.Art_lang, (2, 2)) ]

(** How two boxes relate: a manager manages its packages, which provide its
    artifacts; a join joins a side's box; a manager takes part in the
    cooperation only through its packages; the two joins relate, neither
    requiring the other. *)
type link = Manages | Provides | Joins | Takes_part | Relates

let links : (cell * cell * link) list =
  [ (Component T.Pm_sys, Packages T.S_sys, Manages);
    (Component T.Pm_lang, Packages T.S_lang, Manages);
    (Packages T.S_sys, Component T.Art_sys, Provides);
    (Packages T.S_lang, Component T.Art_lang, Provides);
    (Packages T.S_sys, Component T.Pm_coop, Joins);
    (Component T.Pm_coop, Packages T.S_lang, Joins);
    (Component T.Art_sys, Component T.Binding, Joins);
    (Component T.Binding, Component T.Art_lang, Joins);
    (Component T.Pm_sys, Component T.Pm_coop, Takes_part);
    (Component T.Pm_lang, Component T.Pm_coop, Takes_part);
    (Component T.Pm_coop, Component T.Binding, Relates) ]

(** What each component is, in two short lines. *)
let gloss = function
  | T.Pm_sys -> ("the system's package manager:", "its management part")
  | T.Pm_lang -> ("the language's package manager:", "its management part")
  | T.Pm_coop -> ("the cooperation between", "the two package managers")
  | T.Art_sys -> ("system artifacts, and the tools", "that build and inspect them")
  | T.Art_lang -> ("language artifacts and their tools:", "compilers, interpreters, inspectors")
  | T.Binding -> ("the binding mechanism through which", "a language and a system cooperate")
  | T.Program -> ("the program that uses them", "")

let cell_name = function
  | Component c -> T.component_name_parts c
  | Packages T.S_sys -> ("P", "sys")
  | Packages T.S_lang -> ("P", "lang")

let cell_gloss = function
  | Component c -> gloss c
  | Packages T.S_sys -> ("the system's packages: metadata,", "content, the capability file")
  | Packages T.S_lang -> ("the language's packages: metadata,", "content, the bridge")

let x_of col = 30 + (col * 320)
let y_of row = 60 + (row * 150)
let mid row = y_of row + (box_h / 2)
let place c = List.Assoc.find_exn cells c ~equal:Poly.equal

let box ((c, (col, row)) : cell * (int * int)) : string =
  let x = x_of col and y = y_of row in
  let l1, l2 = cell_gloss c in
  let tone = match row with 0 -> "cmanage" | 1 -> "cpkg" | _ -> "cart" in
  let cls = String.concat ~sep:" " ([ "cnode"; tone ] @ if col = 1 then [ "cjoin" ] else []) in
  Printf.sprintf
    {|<g class="%s"><rect x="%d" y="%d" width="%d" height="%d" rx="10"/>%s<text class="cgloss" x="%d" y="%d">%s</text><text class="cgloss" x="%d" y="%d">%s</text></g>|}
    cls x y box_w box_h
    (D.typeset_name ~x:(x + 14) ~y:(y + 28) (cell_name c))
    (x + 14) (y + 54) (esc l1) (x + 14) (y + 70) (esc l2)

(** A link between its boxes' facing edges: down a column from the upper
    box to the lower, along a row between their sides, or across from a
    manager's inner bottom corner to the cooperation's top. A direct link
    is solid, an indirect one dotted; managing and providing point down,
    and relating points both ways. *)
let link_svg ((a, b, kind) : cell * cell * link) : string =
  let (ca, ra), (cb, rb) = (place a, place b) in
  let cls = match kind with Takes_part | Relates -> "cdot" | Manages | Provides | Joins -> "clink" in
  let line ?(heads = "") x1 y1 x2 y2 =
    Printf.sprintf {|<line class="%s" x1="%d" y1="%d" x2="%d" y2="%d"%s/>|} cls x1 y1 x2 y2 heads
  in
  if ca = cb then
    let top, bottom = (Int.min ra rb, Int.max ra rb) in
    let x = x_of ca + (box_w / 2) and y1 = y_of top + box_h and y2 = y_of bottom - 2 in
    let labelled heads ~from text =
      line ~heads x from x y2
      ^ Printf.sprintf {|<text class="clabel" x="%d" y="%d">%s</text>|} (x + 8)
          (((y1 + y2) / 2) + 4) text
    in
    match kind with
    | Manages -> labelled {| marker-end="url(#ca)"|} ~from:y1 "manages"
    | Provides -> labelled {| marker-end="url(#ca)"|} ~from:y1 "provides"
    | Relates -> labelled {| marker-start="url(#ca)" marker-end="url(#ca)"|} ~from:(y1 + 2) "relates"
    | Joins | Takes_part -> line x y1 x y2
  else if ra = rb then
    let left, right = (Int.min ca cb, Int.max ca cb) in
    line (x_of left + box_w) (mid ra) (x_of right) (mid ra)
  else
    let (uc, ur), (lc, lr) = if ra < rb then ((ca, ra), (cb, rb)) else ((cb, rb), (ca, ra)) in
    let x1, x2 =
      if uc < lc then (x_of uc + box_w, x_of lc + 40) else (x_of uc, x_of lc + box_w - 40)
    in
    line x1 (y_of ur + box_h) x2 (y_of lr)

let svg () : string =
  let caption col text =
    Printf.sprintf {|<text class="sidecap" x="%d" y="34">%s</text>|} (x_of col + (box_w / 2)) text
  in
  let row_label row text =
    Printf.sprintf {|<text class="sidecap" x="14" y="%d" transform="rotate(-90 14 %d)">%s</text>|}
      (mid row) (mid row) text
  in
  Printf.sprintf
    {|<svg viewBox="0 0 %d %d" class="diagram comps" role="img"><defs><marker id="ca" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z"/></marker></defs>%s%s%s%s</svg>|}
    width height
    (String.concat [ caption 0 "SYSTEM SIDE"; caption 1 "THE JOINS"; caption 2 "LANGUAGE SIDE" ])
    (String.concat [ row_label 0 "MANAGEMENT"; row_label 1 "PACKAGES"; row_label 2 "ARTIFACTS" ])
    (String.concat (List.map links ~f:link_svg))
    (String.concat (List.map cells ~f:box))
