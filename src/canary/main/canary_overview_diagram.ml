(** §1's diagram: the layered graph of {!Canary_topology} drawn as SVG on
    one hand-placed layout. Every chain is this drawing with its nodes
    named and its edges styled by the page's script; none is drawn twice.
    The rules the layout keeps are {!Canary_overview_looks.layout_rules}. *)

open Base
module T = Canary_topology

let esc = Canary_overview_assets.esc

(* ── the layout: explicit coordinates for a small, fixed graph ── *)

let canvas_w = 1220
let canvas_h = 900
let box_w = 208
let box_h = 46

type pos = { px : int; py : int }

(** The two sources sit beside their package's column, clear of its edges
    (a source is not package content), in narrower boxes. *)
let side_nodes = [ "src_sys"; "src_lang" ]
let side_box_w = 150

let box_w_of (id : string) : int =
  if List.mem side_nodes id ~equal:String.equal then side_box_w else box_w

(** Each node's centre. A package's column holds what it ships, top to
    bottom; the capability file sits a level below the native package, off
    its lower right; the bridge sits on the package row, nearer the binding
    package; each consumer under the side whose resolution it uses. *)
let layout : (string * pos) list =
  [ ("pm_sys", { px = 230; py = 62 });
    ("pm_lang", { px = 990; py = 62 });
    ("pkg_sys", { px = 230; py = 200 });
    ("cap", { px = 470; py = 275 });
    ("bridge", { px = 670; py = 200 });
    ("pkg_lang", { px = 990; py = 200 });
    ("src_sys", { px = 91; py = 392 });
    ("hdr_sys", { px = 230; py = 482 });
    ("lib_sys", { px = 230; py = 566 });
    ("staged_sys", { px = 230; py = 640 });
    ("src_lang", { px = 1129; py = 392 });
    ("stub_lang", { px = 990; py = 482 });
    ("mod_lang", { px = 990; py = 566 });
    ("surf_lang", { px = 990; py = 640 });
    ("consumer_artifact", { px = 410; py = 762 });
    ("consumer_package", { px = 750; py = 762 }) ]

let pos_of id =
  match List.Assoc.find layout id ~equal:String.equal with
  | Some p -> p
  | None -> { px = 610; py = 440 }

(** Each component's container on this layout, a polygon around the nodes
    {!Canary_topology.node_components} puts in it. The system PM's turns a
    corner to take in the capability file, off the native package's lower
    right; the program's nodes stay in their band. *)
let containers : (T.component * (int * int) list) list =
  let rect x0 y0 x1 y1 = [ (x0, y0); (x1, y0); (x1, y1); (x0, y1) ] in
  [ (T.Pm_sys, [ (114, 28); (346, 28); (346, 242); (586, 242); (586, 310); (114, 310) ]);
    (T.Pm_coop, rect 554 166 786 232);
    (T.Pm_lang, rect 874 28 1106 236);
    (T.Art_sys, rect 10 356 346 676);
    (T.Binding, rect 874 356 1212 518);
    (T.Art_lang, rect 874 530 1106 676) ]

(** Edges whose label starts at the midpoint instead of centring on it:
    they leave the native column at a shallow angle, and a centred label
    would run under a box. *)
let label_starts_at_midpoint = [ "realize_cap"; "discover" ]

(** Where an edge's label and badges sit, as a percentage of the way from
    tail to head — 50 unless listed, placed so no mark falls under a box
    or on another edge's marks ([overview.edge_marks_clear_the_boxes]). *)
let label_at =
  [ ("build_lib", 80); ("run", 60); ("run_packaged", 75); ("install_lang", 20);
    ("install_surf", 30) ]

let anchor_of (e : T.edge) ~(src : pos) ~(dst : pos) : int * int =
  let pct =
    Option.value (List.Assoc.find label_at e.T.eg_id ~equal:String.equal) ~default:50
  in
  (src.px + ((dst.px - src.px) * pct / 100), src.py + ((dst.py - src.py) * pct / 100))

(* ── svg primitives ── *)

(** The four bands: top, height, label, class. *)
let bands_def : (int * int * string * string) list =
  [ (30, 70, "PM LAYER — who resolves and installs", "pm");
    (140, 170, "PACKAGE LAYER — symbolic claims, and the bridge between them", "package");
    (350, 320, "ARTIFACT LAYER — what is actually on disk", "artifact");
    (710, 74, "PROGRAM — the only band where anything runs", "program") ]

let band_rect ~y ~h ~cls =
  Printf.sprintf {|<rect class="band %s" x="8" y="%d" width="%d" height="%d" rx="10"/>|}
    cls y (canvas_w - 16) h

(** A band's label, centred on its top and drawn over the edges, with a
    halo. *)
let band_label ~y ~label =
  Printf.sprintf {|<text class="bandlabel" x="%d" y="%d">%s</text>|} (canvas_w / 2) (y + 20)
    (esc label)

(** A monospace line squeezed to [w] where it would overrun it: a glyph's
    advance is about 0.6 of the font's size. The page's script measures
    and squeezes again. *)
let squeeze ~(size : float) ~(w : int) (s : string) : string =
  let chars = String.count s ~f:(fun c -> Char.to_int c land 0xC0 <> 0x80) in
  if Float.(of_int chars * 0.6 * size > of_int w) then
    Printf.sprintf {| textLength="%d" lengthAdjust="spacingAndGlyphs"|} w
  else ""

(** A component's name, its subscript set lower and smaller. *)
let component_name ~x ~y (c : T.component) : string =
  let base, sub = T.component_name_parts c in
  Printf.sprintf {|<text class="cname" x="%d" y="%d">%s%s</text>|} x y (esc base)
    (if String.is_empty sub then ""
     else Printf.sprintf {|<tspan class="csub" dy="4">%s</tspan>|} (esc sub))

(** A container's outline, drawn under the edges. *)
let container_outline ((_, pts) : T.component * (int * int) list) : string =
  Printf.sprintf {|<polygon class="cbox" points="%s"/>|}
    (String.concat ~sep:" " (List.map pts ~f:(fun (x, y) -> Printf.sprintf "%d,%d" x y)))

(** A container's name on a tab across its top edge, drawn over everything. *)
let container_tab ((c, pts) : T.component * (int * int) list) : string =
  let x0, y0 = List.hd_exn pts in
  let base, sub = T.component_name_parts c in
  let w = (String.length base * 9) + (String.length sub * 7) + 14 in
  Printf.sprintf {|<rect class="ctab" x="%d" y="%d" width="%d" height="20" rx="4"/>%s|}
    (x0 + 10) (y0 - 10) w
    (component_name ~x:(x0 + 17) ~y:(y0 + 5) c)

(** A node. Nodes are drawn after the edges, so the boxes mask the lines
    that run under them and every edge can be a straight segment. A
    declaration is a ◇ badge on the node it is about. [data-node] is the
    handle the page's script finds the node by; a case slot holds the
    lines a chosen chain writes under the label — [line], with its
    classes, and a recorded run's [place] under it. *)
let node_svg ?(extra = "") ?(case_slot = false) ?line ?place (n : T.node) =
  let p = pos_of n.T.nd_id in
  let w = box_w_of n.T.nd_id in
  let x = p.px - (w / 2) and y = p.py - (box_h / 2) in
  let decl = T.declaration_at n.T.nd_id in
  let cls =
    Printf.sprintf "node %s%s%s"
      (T.string_of_layer n.T.nd_layer)
      (if Option.is_some decl then " declared" else "")
      extra
  in
  let badge =
    match decl with
    | None -> ""
    | Some what ->
        Printf.sprintf
          {|<g class="declmark"><title>DECLARED by the experiment: %s</title>
<circle cx="%d" cy="%d" r="8"/><text x="%d" y="%d">◇</text></g>|}
          (esc what)
          (x + w - 10) (y + 10) (x + w - 10) (y + 14)
  in
  let placed = Option.is_some place and lined = Option.is_some line in
  let main =
    Printf.sprintf
      {|<g class="%s" data-node="%s"><title>%s</title>
<rect x="%d" y="%d" width="%d" height="%d" rx="7"/>
<text class="nlabel" x="%d" y="%d"%s>%s</text>%s|}
      cls (esc n.T.nd_id) (esc n.T.nd_gloss) x y w box_h p.px
      (if placed then p.py - 7 else if lined then p.py - 2 else p.py + 5)
      (if case_slot then
         Printf.sprintf {| data-y0="%d" data-y1="%d" data-y2="%d"|} (p.py + 5) (p.py - 2)
           (p.py - 7)
       else "")
      (esc n.T.nd_label) badge
  in
  (* the name, and under it the run's placement: a third line *)
  let slot =
    if case_slot then
      let text, classes = Option.value line ~default:("", []) in
      let place = Option.value place ~default:"" in
      Printf.sprintf
        {|<text class="%s" x="%d" y="%d" data-y1="%d" data-y2="%d"%s>%s</text><text class="nplace" x="%d" y="%d"%s>%s</text>|}
        (String.concat ~sep:" " ("ncase" :: classes))
        p.px
        (if placed then p.py + 7 else p.py + 14)
        (p.py + 14) (p.py + 7)
        (squeeze ~size:11.5 ~w:(w - 12) text)
        (esc text) p.px (p.py + 19)
        (squeeze ~size:10. ~w:(w - 12) place)
        (esc place)
    else ""
  in
  main ^ slot ^ "</g>"

(** What an edge's label says: an action by its family's name, a claim by
    its code, information (someone else's rule) in italics. *)
let annotation_label = function
  | T.Action f -> Canary_action_family.to_string f
  | T.Agreement slug -> Canary_agreement_common.short_code_of_slug slug
  | T.Info s -> s

let annotation_class = function
  | T.Action _ -> "elabel"
  | T.Agreement _ -> "elabel claim"
  | T.Info _ -> "elabel info"

let annotation_title = function
  | T.Action f -> "our action " ^ Canary_action_family.to_string f
  | T.Agreement slug -> "the claim " ^ slug
  | T.Info s -> s ^ " (we run nothing here)"

(** An edge. An edge with agreements placed on it carries two badges: a
    filled one counting those canary checks for the chain drawn, a hollow
    one those only named; the page's script recounts both per chain. An
    edge with none placed is bare. [ph_slot] adds the hidden placeholder
    marker a recorded run shows where a package manager did something the
    run does not record; [marker] shows it, with its classes and what it
    stands for. *)
let edge_svg ?(extra = "") ~(counts : int * int) ?(ph_slot = false) ?marker (e : T.edge) =
  let dst = pos_of e.eg_to in
  let placed = not (List.is_empty (T.claim_sites_on e.T.eg_id)) in
  let cls =
    Printf.sprintf "edge%s%s%s"
      (if e.T.eg_diagonal then " diag" else "")
      (if placed then "" else " bare")
      extra
  in
  String.concat
    (List.map e.T.eg_from ~f:(fun from_id ->
         let src = pos_of from_id in
         if String.equal from_id e.T.eg_to then
           (* a self edge: probe_lib reads the artifact it stands on *)
           Printf.sprintf
             {|<g class="%s" data-edge="%s"><title>%s</title><path d="M %d %d a 30 26 0 1 1 22 0"/></g>|}
             cls (esc e.T.eg_id)
             (esc (e.T.eg_says))
             (src.px - 46) (src.py - 10)
         else
           let mx, my = anchor_of e ~src ~dst in
           let badge =
             if not placed then ""
             else
               (* the hollow badge sits beside the filled one, or in its
                  place when nothing here is checked *)
               let checked, named = counts in
               let none n = if n = 0 then " none" else "" in
               let x1 = mx + 46 and x2 = mx + 67 in
               let hx = if checked > 0 then x2 else x1 in
               Printf.sprintf
                 {|<circle class="cbadge chk%s" cx="%d" cy="%d" r="9"/><text class="cnum chk%s" x="%d" y="%d">%d</text><circle class="cbadge cand%s" cx="%d" cy="%d" r="9" data-x1="%d" data-x2="%d"/><text class="cnum cand%s" x="%d" y="%d" data-x1="%d" data-x2="%d">%d</text>|}
                 (none checked) x1 my (none checked) x1 (my + 4) checked (none named) hx my x1
                 x2 (none named) hx (my + 4) x1 x2 named
           in
           (* an inline style: the stylesheet's text-anchor would beat a
              presentation attribute *)
           let anchor =
             if List.mem label_starts_at_midpoint e.T.eg_id ~equal:String.equal
             then {| style="text-anchor:start"|}
             else ""
           in
           let slot =
             if not ph_slot then ""
             else
               (* hidden by class: SVG does not honour [hidden] *)
               let classes, says = Option.value marker ~default:([], "") in
               Printf.sprintf
                 {|<g class="%s"><title>%s</title><rect x="%d" y="%d" width="22" height="16" rx="3"/><text x="%d" y="%d">…</text></g>|}
                 (String.concat ~sep:" " ("phm" :: classes))
                 (esc says) (mx - 57) (my - 8) (mx - 46) (my + 4)
           in
           Printf.sprintf
             {|<g class="%s" data-edge="%s"><title>%s — %s</title>
<line x1="%d" y1="%d" x2="%d" y2="%d" marker-end="url(#a)"/>
<text class="%s" x="%d" y="%d"%s>%s</text>%s%s</g>|}
             cls (esc e.T.eg_id)
             (esc (annotation_title e.T.eg_annotation))
             (esc e.T.eg_says) src.px src.py dst.px dst.py
             (annotation_class e.T.eg_annotation) mx (my - 7) anchor
             (esc (annotation_label e.T.eg_annotation))
             badge slot))

(** The one layout: every node and edge drawn once. [classes] adds classes
    to an element by id, which the page's script and stylesheet use to
    hide, grey or outline it; [counts] is what an edge's two badges count;
    [lines], [places] and [markers] are what a chosen chain writes under a
    node and a recorded run marks on an edge. A caption names each side
    over its column. *)
let diagram ?(by_component = false) ?(ph_slots = false) ?(case_slots = false)
    ?(classes = fun (_ : string) -> ([] : string list))
    ?(counts =
      fun id ->
        let ps = T.claim_sites_on id in
        let checked = List.count ps ~f:T.implemented in
        (checked, List.length ps - checked))
    ?(lines = fun (_ : string) -> (None : (string * string list) option))
    ?(places = fun (_ : string) -> (None : string option))
    ?(markers = fun (_ : string) -> (None : (string list * string) option)) () : string =
  let extra id = String.concat (List.map (classes id) ~f:(fun c -> " " ^ c)) in
  let bands =
    String.concat (List.map bands_def ~f:(fun (y, h, _, cls) -> band_rect ~y ~h ~cls))
  in
  (* drawn by component, the containers name the regions and the bands
     only shade the layers *)
  let band_labels =
    if by_component then ""
    else String.concat (List.map bands_def ~f:(fun (y, _, label, _) -> band_label ~y ~label))
  in
  let outlines =
    if by_component then String.concat (List.map containers ~f:container_outline) else ""
  in
  let tabs = if by_component then String.concat (List.map containers ~f:container_tab) else "" in
  let captions =
    Printf.sprintf
      {|<text class="sidecap" x="%d" y="20">SYSTEM SIDE</text><text class="sidecap" x="%d" y="20">LANGUAGE SIDE</text>|}
      (pos_of "pkg_sys").px (pos_of "pkg_lang").px
  in
  let es =
    String.concat
      (List.map T.edges ~f:(fun e ->
           edge_svg ~extra:(extra e.T.eg_id) ~counts:(counts e.T.eg_id) ~ph_slot:ph_slots
             ?marker:(markers e.T.eg_id) e))
  in
  let ns =
    String.concat
      (List.map T.nodes ~f:(fun n ->
           node_svg ~extra:(extra n.T.nd_id) ~case_slot:case_slots ?line:(lines n.T.nd_id)
             ?place:(places n.T.nd_id) n))
  in
  Printf.sprintf
    {|<svg viewBox="0 0 %d %d" class="diagram" role="img">
<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7"
 markerHeight="7" orient="auto-start-reverse">
<path d="M 0 0 L 10 5 L 0 10 z"/></marker></defs>
%s%s%s%s%s%s%s</svg>|}
    canvas_w canvas_h bands captions outlines es band_labels ns tabs
