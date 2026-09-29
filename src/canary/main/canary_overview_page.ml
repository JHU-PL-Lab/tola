(** [Canary_overview_page] — the OVERVIEW page, `canary overview`
    (2026-09-22; renamed from the "model" page 2026-09-23, user).

    It began as a separate page from the result matrix, deliberately.
    That one was a RECORD: per project, per scenario, what a run decided.
    This one was GENERAL MECHANISM — what chains can exist, what joins
    them, where a claim could sit — with no project, no version and no
    verdict on it. The multi-PM model's own §14 says not to put verdicts
    in the methodology tables, and a reader scrolling from "what happened
    here" into "what can exist anywhere" without a page break will read
    the second as the first.

    ONE PAGE since 2026-09-28 (user; design/overview.md §6.4). §1's
    recorded runs had already crossed that line — each drawn over the
    generic chain and marked as a run — so the result table joined them
    as §1.2, and the matrix's own page retired. What keeps record and
    mechanism apart now is the marking rather than the page break: a run
    is drawn over the chain as a run, and the table of runs is a section
    of its own.

    The generic diagram and every concrete case come from ONE layout
    function over {!Canary_topology.nodes} and {!Canary_topology.edges}.
    A concrete case is the same graph with its nodes renamed and its
    inapplicable edges greyed — never a second drawing, which would be
    free to disagree with the first. *)

open Base
module T = Canary_topology

(* ── layout ───────────────────────────────────────────────────────────

   Explicit coordinates rather than a solver: the graph is fixed and
   small, and a hand-placed layout that reads well beats a computed one
   that has to be re-read every time it shifts. *)

let canvas_w = 1220
let canvas_h = 900
let box_w = 208
let box_h = 46

type pos = { px : int; py : int }

(* THE SOURCES SIT BESIDE THEIR PACKAGE'S COLUMN, NOT IN IT (user,
   2026-09-24: "the source is not in the package which usually contains
   the library or module … move the naitve source … to the left … The
   same for binding source, which we move it to the right. Both source are
   still in the same height"). A package's column is what it ships — the
   native package its headers and library, the binding package its module
   and surface — and the edges from a package to its content run straight
   down it. Drawn in that column, a source sat on those edges and read as
   package content. It sits outside now, on the source row, and feeds only
   its build edges. Its box is narrower so the column's edges pass clear
   of it; the names drawn under a source are short (a repository, a ref).

   The headers stay in the column: the native package ships them
   ([realize_hdr]), and in a built chain the build edge reaches them from
   the source beside it. *)
let side_nodes = [ "src_sys"; "src_lang" ]
let side_box_w = 150

let box_w_of (id : string) : int =
  if List.mem side_nodes id ~equal:String.equal then side_box_w else box_w

(* column centres, then per-node y. The artifact band stacks three nodes
   per column under each package, with the source beside the column on
   the row above; everything else is one node per band per side. The two
   columns sit in from the canvas edges to leave the sources their room,
   and the artifact rows sit 16px lower than they did, so the two build
   edges that fan out of the native source have space for their labels. *)
let layout : (string * pos) list =
  [ ("pm_sys", { px = 230; py = 62 });
    ("pm_lang", { px = 990; py = 62 });
    ("pkg_sys", { px = 230; py = 200 });
    (* THE TWO IN-BETWEEN NODES SIT WITH THEIR OWNERS (user, 2026-09-22).
       Both were centred, which drew them as neutral machinery between
       the ecosystems. They are not neutral and they are not co-owned: a
       capability file ships INSIDE the native package and is written by
       whoever packaged it, while a bridge package belongs to the language
       ecosystem and is written by one of its maintainers. Different
       authors, different release cycles — which is the whole reason the
       symbolic path and the artifact path can disagree. A layout that hid
       the ownership hid the motive.

       AND THE DIAGRAM IS LAYERED (user, 2026-09-24: "if they are on the
       same abstraction layers, they can stay on the same horizontal
       line"). The two are NOT on the same layer, though both are extra to
       a package's standard content (user, the same day): a BRIDGE PACKAGE
       IS A PACKAGE — conf-gmp is an opam package — so it sits on the
       package row with the two packages it joins, right of centre, with
       the language ecosystem that writes it; a CAPABILITY FILE IS CONTENT
       inside a package — gmp.pc ships in libgmp-dev — so it sits a level
       below, off the native package's lower-right. Setting the two on one
       row, tried first, drew a file as a peer of a package. The bridge's
       edges to both packages run level and long enough to keep their
       labels and badges in view (on 2026-09-23 a 22px [depends] edge hid
       the bridge's placeholder claims under the two boxes). *)
    ("cap", { px = 470; py = 275 });
    (* the bridge sits near the binding package, on the language side
       (user, 2026-09-24: "the bridge package should be near to the
       binding_package, since it belongs to the language PM's side") — as
       near as its [depends] edge still has room for its label and badge *)
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
    (* the two consumers sit under the side whose resolution they use:
       the artifact-linked one names paths, the package-linked one names
       a package — far enough left that the edge from the binding package
       clears the column under it *)
    ("consumer_artifact", { px = 410; py = 762 });
    ("consumer_package", { px = 750; py = 762 }) ]

let pos_of id =
  match List.Assoc.find layout id ~equal:String.equal with
  | Some p -> p
  | None -> { px = 610; py = 440 }

(* TWO LABELS START AT THEIR EDGE'S MIDPOINT INSTEAD OF CENTRING ON IT
   (2026-09-23). Both edges leave the native column at a shallow angle,
   so the midpoint sits against a node box, and the box — drawn over the
   edges — clipped the label once it was longer than the dot it replaced
   ("packager" read "ckager"). Placed by hand, like the coordinates
   above: starting every label was tried and put a line through
   "conf predicate". *)
let label_starts_at_midpoint = [ "realize_cap"; "discover" ]

(* WHERE AN EDGE'S LABEL AND BADGES SIT, as a percentage of the way from
   its tail to its head — the midpoint unless listed (2026-09-24). At the
   midpoint [build_lib]'s label and badges fell behind the headers box, as
   its edge fans out of the source beside the column; the package-linked
   probe's label was cut by the stub box and the artifact-linked probe's by
   the staged copy. Three edges run down the binding package's column on
   one line — [install_lang] and [pack] join the same two nodes in
   opposite directions, so their midpoints coincide — and their marks are
   spaced along it. Pinned by overview.edge_marks_clear_the_boxes. *)
let label_at =
  [ ("build_lib", 80); ("run", 60); ("run_packaged", 75); ("install_lang", 20);
    ("install_surf", 30) ]

let anchor_of (e : T.edge) ~(src : pos) ~(dst : pos) : int * int =
  let pct =
    Option.value (List.Assoc.find label_at e.T.eg_id ~equal:String.equal) ~default:50
  in
  (src.px + ((dst.px - src.px) * pct / 100), src.py + ((dst.py - src.py) * pct / 100))

(* ── svg primitives ──────────────────────────────────────────────── *)

let esc (s : string) : string =
  String.concat_map s ~f:(function
    | '&' -> "&amp;"
    | '<' -> "&lt;"
    | '>' -> "&gt;"
    | '"' -> "&quot;"
    | c -> String.of_char c)

(* THE FOUR BANDS: top, height, label, class. *)
let bands_def : (int * int * string * string) list =
  [ (30, 70, "PM LAYER — who resolves and installs", "pm");
    (140, 170, "PACKAGE LAYER — symbolic claims, and the bridge between them", "package");
    (350, 320, "ARTIFACT LAYER — what is actually on disk", "artifact");
    (710, 74, "PROGRAM — the only band where anything runs", "program") ]

let band_rect ~y ~h ~cls =
  Printf.sprintf {|<rect class="band %s" x="8" y="%d" width="%d" height="%d" rx="10"/>|}
    cls y (canvas_w - 16) h

(* A BAND'S LABEL IS CENTRED, AND DRAWN OVER THE EDGES (2026-09-24). At
   the top-left it sat where the native column starts: the PM band's was
   hidden behind the system PM, the artifact band's under the native
   source once that moved to the corner, and a [fetch_lib] label ran
   through it. The middle of each band's top is clear of every node; an
   edge may still cross it, so the label is drawn after the edges, with a
   halo, and before the nodes. *)
let band_label ~y ~label =
  Printf.sprintf {|<text class="bandlabel" x="%d" y="%d">%s</text>|} (canvas_w / 2) (y + 20)
    (esc label)

(* ── THE LAYOUT'S RULES (2026-09-27) ──────────────────────────────────

   THE RULES THE LAYOUT KEEPS, IN WORDS A REDRAW CAN CARRY (user,
   2026-09-27: "a collection of my human words or learned rules … Those
   are a bit higher than the code-hint, so that if we switch to another
   GUI framework e.g. mermaid, we are still aware of the rules on how to
   migrate them"). The coordinates in [layout] are one drawing of these
   rules. A redraw in another framework would place things differently,
   and must keep every rule here.

   Each rule says itself, says why, and says how it is checked: over the
   nodes' places and boxes, which any rendering can report, so a future
   drawing is held to the same list; or, where the rule is about what is
   drawn rather than where, by the pin that checks it. The looks — colour,
   dash, what the keys say — are the visual vocabulary's
   ([visual_hints]); these are the places. Held by
   overview.layout_rules_hold. *)

(** A drawing's places: each node's centre and box. *)
type layout_view = { lv_at : string -> pos; lv_w : string -> int; lv_h : int }

type layout_check =
  | Places of (layout_view -> bool)  (** held over any drawing's places *)
  | Pinned_by of string  (** held over this drawing by that pin *)

type layout_rule = { lr_says : string; lr_why : string; lr_check : layout_check }

let this_layout = { lv_at = pos_of; lv_w = box_w_of; lv_h = box_h }

let layout_rules : layout_rule list =
  let x v n = (v.lv_at n).px and y v n = (v.lv_at n).py in
  let side s = List.filter_map T.nodes ~f:(fun n -> Option.some_if (Poly.equal n.T.nd_side s) n.T.nd_id) in
  let one_line v f ns =
    match ns with [] -> true | n :: rest -> List.for_all rest ~f:(fun m -> f v m = f v n)
  in
  let rule says why check = { lr_says = says; lr_why = why; lr_check = check } in
  [ rule
      "The system side is on the left and the language side on the right: every node on \
       the system side lies left of every node on the language side."
      "The two package managers' worlds meet in the middle, and every edge that crosses \
       between them is a cooperation. Each node's side is data (Canary_topology.nd_side). \
       (user, 2026-09-24)"
      (Places
         (fun v ->
           List.for_all (side T.S_sys) ~f:(fun a ->
               List.for_all (side T.S_lang) ~f:(fun b -> x v a < x v b))));
    rule
      "Layers stack from the top: package managers, packages, artifacts, programs. Each \
       node sits inside its layer's band."
      "The chain runs from who resolves, through what is claimed, to what is on disk and \
       what runs."
      (Places
         (fun v ->
           List.for_all T.nodes ~f:(fun n ->
               List.exists bands_def ~f:(fun (top, h, _, cls) ->
                   String.equal cls (T.string_of_layer n.T.nd_layer)
                   && top < y v n.T.nd_id && y v n.T.nd_id < top + h))));
    rule
      "A package and what it ships form one vertical line: its package manager above it, \
       its content straight below it — native package, headers, library; binding package, \
       stub, module, surface. On the native line the staged copy sits under the library \
       it copies."
      "user, 2026-09-27: \"vertical line for a package and package content\""
      (Places
         (fun v ->
           one_line v x [ "pm_sys"; "pkg_sys"; "hdr_sys"; "lib_sys"; "staged_sys" ]
           && one_line v x [ "pm_lang"; "pkg_lang"; "stub_lang"; "mod_lang"; "surf_lang" ]));
    rule "Every package sits at the same height, the bridge package among them."
      "A bridge package is a package: conf-gmp is an opam package, as libgmp-dev is an apt \
       one. (user, 2026-09-24)"
      (Places (fun v -> one_line v y [ "pkg_sys"; "bridge"; "pkg_lang" ]));
    rule
      "Nodes of one kind on the two sides share a row: the two package managers, the two \
       sources, headers and stub, library and module, staged copy and surface, the two \
       consumers."
      "user, 2026-09-24: \"if they are on the same abstraction layers, they can stay on \
       the same horizontal line\""
      (Places
         (fun v ->
           List.for_all
             [ [ "pm_sys"; "pm_lang" ]; [ "src_sys"; "src_lang" ]; [ "hdr_sys"; "stub_lang" ];
               [ "lib_sys"; "mod_lang" ]; [ "staged_sys"; "surf_lang" ];
               [ "consumer_artifact"; "consumer_package" ] ]
             ~f:(one_line v y)));
    rule
      "A source is not package content, so it sits beside its package's line, clear of \
       it: the native source to the upper left of the headers, the binding source to the \
       upper right of the stub."
      "user, 2026-09-24: \"the source is not in the package which usually contains the \
       library or module\" — drawn on the package's line, it sat on the package's edges \
       and read as its content."
      (Places
         (fun v ->
           (2 * x v "src_sys") + v.lv_w "src_sys" < 2 * x v "pkg_sys"
           && (2 * x v "src_lang") - v.lv_w "src_lang" > 2 * x v "pkg_lang"
           && y v "pkg_sys" < y v "src_sys" && y v "src_sys" < y v "hdr_sys"
           && y v "pkg_lang" < y v "src_lang" && y v "src_lang" < y v "stub_lang"));
    rule
      "The capability file is content inside the native package: it sits a level below \
       it, off its lower right."
      "gmp.pc ships in libgmp-dev and is written by its packager — not a package, and not \
       the bridge's. (user, 2026-09-22 and 2026-09-24)"
      (Places (fun v -> x v "cap" > x v "pkg_sys" && y v "cap" > y v "pkg_sys"));
    rule
      "The bridge package belongs to the language side: it sits between the two packages, \
       nearer the binding package."
      "user, 2026-09-24: \"the bridge package should be near to the binding_package, since \
       it belongs to the language PM's side\""
      (Places
         (fun v ->
           x v "pkg_sys" < x v "bridge" && x v "bridge" < x v "pkg_lang"
           && x v "pkg_lang" - x v "bridge" < x v "bridge" - x v "pkg_sys"));
    rule
      "The two consumers sit under the side whose resolution they use: the artifact-linked \
       one, which names paths, toward the system side; the package-linked one, which names \
       a package, toward the language side."
      "Which side resolved a program's inputs is the difference between the two probes."
      (Places (fun v -> x v "consumer_artifact" < x v "consumer_package"));
    rule "The two sides are named over their columns."
      "user, 2026-09-24: a hint for \"the left part and right part for the system and \
       language division\". A dividing line was not drawn: every edge crossing it is a \
       cooperation, and one would carry its label on the line."
      (Pinned_by "overview.visual_vocabulary_is_one_list");
    rule "No two boxes overlap."
      "A box drawn over another hides a node."
      (Places
         (fun v ->
           List.for_all T.nodes ~f:(fun a ->
               List.for_all T.nodes ~f:(fun b ->
                   String.equal a.T.nd_id b.T.nd_id
                   || 2 * abs (x v a.T.nd_id - x v b.T.nd_id)
                      >= v.lv_w a.T.nd_id + v.lv_w b.T.nd_id
                   || abs (y v a.T.nd_id - y v b.T.nd_id) >= v.lv_h))));
    rule
      "Nothing drawn hides anything else: no edge runs under a source it does not join, and \
       no label or badge lies under a box, another edge's marks or a band's title."
      "A mark under a box is lost, and a package's edge under a source drew the source as \
       package content. (2026-09-24)"
      (Pinned_by "overview.edge_marks_clear_the_boxes");
    rule
      "One diagram: every chain is drawn on the same layout and switched from the panel, \
       never drawn a second time beside it."
      "Laid end to end, chains are compared by memory. (user, 2026-09-24, when §2's \
       drawings were merged into §1)"
      (Pinned_by "overview.chain_choices_draw_one_chain") ]

(** Nodes are drawn AFTER edges so the boxes mask the lines that run
    under them — which is what lets every edge be a straight centre-to-
    centre segment instead of a routed path. *)
let node_svg ?(extra = "") ?(case_slot = false) (n : T.node) =
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
  (* THE DECLARATION IS A BADGE, NOT A BOX. It used to be a node with a
     position, and the position was arbitrary — nothing produces it and
     it takes part in no action. As a mark on the artifacts the spec
     speaks about, it is where a reader looks for it. *)
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
  (* [data-node] is the handle a recorded run's overlay finds the node by.
     A CASE SLOT (the §1 join) is an empty second line a concrete chain
     fills with what its project declares the node is; the label carries
     both of its heights, so it sits centred while the slot is empty *)
  let main =
    Printf.sprintf
      {|<g class="%s" data-node="%s"><title>%s</title>
<rect x="%d" y="%d" width="%d" height="%d" rx="7"/>
<text class="nlabel" x="%d" y="%d"%s>%s</text>%s|}
      cls (esc n.T.nd_id) (esc n.T.nd_gloss) x y w box_h p.px (p.py + 5)
      (if case_slot then
         Printf.sprintf {| data-y0="%d" data-y1="%d" data-y2="%d"|} (p.py + 5) (p.py - 2)
           (p.py - 7)
       else "")
      (esc n.T.nd_label) badge
  in
  (* the name, and under it — while a recorded run is drawn — where the run
     placed the artifact: a third line, so the label and the name move up *)
  let slot =
    if case_slot then
      Printf.sprintf
        {|<text class="ncase" x="%d" y="%d" data-y1="%d" data-y2="%d"></text><text class="nplace" x="%d" y="%d"></text>|}
        p.px (p.py + 14) (p.py + 14) (p.py + 7) p.px (p.py + 19)
    else ""
  in
  main ^ slot ^ "</g>"

(* WHAT AN EDGE SAYS, per kind of annotation (2026-09-23): an action by
   its family's name; a claim by its code, the way every table on this
   page names one; information in italics, because it names someone
   else's rule rather than ours. The tooltip spells each out. *)
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

(* A PLACEHOLDER IS DRAWN AS ONE (2026-09-23, user: "we can use special
   node to show not-implemented yet"): an agreement that is named and has
   no evaluator is counted by a hollow, dashed badge, so it no longer
   looks like one that runs.

   TWO BADGES, NOT ONE NUMBER (2026-09-24, user, on the numbers on the
   edges). One number counted every agreement placed on the edge — for
   every mechanism, checked or only named — and a recorded run coloured it
   from fewer. Now a filled badge counts the agreements canary CHECKS on
   this relation for the chain drawn, a hollow one those only NAMED, and
   the script recounts both per drawing from [Canary_topology.edge_claims]
   lists. An edge with no agreement placed on it has no slots: it is bare
   whatever is chosen.

   A PLACEHOLDER SLOT (2026-09-23): on the recorded template only, every
   edge carries a hidden marker the overlay shows where a placeholder step
   stands — a package manager did something there, inside one of our
   actions, that the run does not record. Left of the midpoint, so it
   never sits on the badges. *)
let edge_svg ?(extra = "") ~(counts : int * int) ?(ph_slot = false) (e : T.edge) =
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
           (* an inline style, because the stylesheet's text-anchor would
              beat a presentation attribute *)
           let anchor =
             if List.mem label_starts_at_midpoint e.T.eg_id ~equal:String.equal
             then {| style="text-anchor:start"|}
             else ""
           in
           let slot =
             if not ph_slot then ""
             else
               (* hidden by CLASS, not by the [hidden] attribute: SVG does
                  not honour [hidden], and the first cut drew a marker on
                  every edge *)
               Printf.sprintf
                 {|<g class="phm"><title></title><rect x="%d" y="%d" width="22" height="16" rx="3"/><text x="%d" y="%d">…</text></g>|}
                 (mx - 57) (my - 8) (mx - 46) (my + 4)
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

(** THE one layout: every node and edge drawn once. [classes] adds
    classes to an element by id — the join's handle, which lets the
    stylesheet hide, grey or outline it per choice; [counts] is what an
    edge's two badges count before the script recounts them.

    The parameters that renamed, sub-labelled, greyed or hid elements for
    the hand-drawn cases went with those drawings (2026-09-24): nothing
    passed them, and the styles they switched on were the vocabulary's
    dead entries. *)
let diagram ?(ph_slots = false) ?(case_slots = false)
    ?(classes = fun (_ : string) -> ([] : string list))
    ?(counts =
      fun id ->
        let ps = T.claim_sites_on id in
        let checked = List.count ps ~f:T.implemented in
        (checked, List.length ps - checked)) () : string =
  let extra id = String.concat (List.map (classes id) ~f:(fun c -> " " ^ c)) in
  let bands =
    String.concat (List.map bands_def ~f:(fun (y, h, _, cls) -> band_rect ~y ~h ~cls))
  in
  let band_labels =
    String.concat (List.map bands_def ~f:(fun (y, _, label, _) -> band_label ~y ~label))
  in
  (* THE TWO SIDES (user, 2026-09-24: "some visual hints so that we can see
     the left part and right part for the system and language division").
     A caption over each column, in the margin above the bands: the side
     a column belongs to is the side of the package manager at its top.
     A dividing line was tried on paper and not drawn: every edge that
     crosses it is a cooperation between the two sides, and the bridge's
     own check to the capability file would carry its label on it. *)
  let captions =
    Printf.sprintf
      {|<text class="sidecap" x="%d" y="20">SYSTEM SIDE</text><text class="sidecap" x="%d" y="20">LANGUAGE SIDE</text>|}
      (pos_of "pkg_sys").px (pos_of "pkg_lang").px
  in
  let es =
    String.concat
      (List.map T.edges ~f:(fun e ->
           edge_svg ~extra:(extra e.T.eg_id) ~counts:(counts e.T.eg_id) ~ph_slot:ph_slots e))
  in
  let ns =
    String.concat
      (List.map T.nodes ~f:(fun n ->
           node_svg ~extra:(extra n.T.nd_id) ~case_slot:case_slots n))
  in
  Printf.sprintf
    {|<svg viewBox="0 0 %d %d" class="diagram" role="img">
<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7"
 markerHeight="7" orient="auto-start-reverse">
<path d="M 0 0 L 10 5 L 0 10 z"/></marker></defs>
%s%s%s%s%s</svg>|}
    canvas_w canvas_h bands captions es band_labels ns

(* ── the page ─────────────────────────────────────────────────────── *)

(** The page's stylesheet, [canary/overview/page.css]. *)
let css () = Canary_overview_assets.read "page.css"

(* ── THE VISUAL VOCABULARY (2026-09-24) ─────────────────────────────────

   EVERY VISUAL HINT §1 USES, IN ONE LIST (user, 2026-09-24: "shall we
   keep all our visual hints in a place, so we can always check for them
   all and you won't be forget the old ones, and we can detect if there
   are conflicts"). A hint is a look the stylesheet gives one kind of
   element, in the drawings where it can show, and what that look tells
   the reader. Each names the stylesheet rules that give it its look, the
   sample and the words a key shows for it, and which key shows them.

   Both keys — the chain's, above the diagram, and a recorded run's,
   under it — are rendered from this list, so a hint is explained there,
   on the drawing itself, or (for the few that only switch something off)
   with a reason here. overview.visual_vocabulary_is_one_list holds the
   rest: every §1 rule of the stylesheet belongs to exactly one hint or
   to the base look; every hint's rules exist and its classes are applied
   by the page; no key sample stands for two meanings; and no two hints
   that can show on one kind of element at once look alike.

   Its first run found what the eye had missed: a recorded run drew "in
   the chain, never logged" and "happened inside a package manager's
   action" in the same grey dots, under the same key sample, and the key
   gave "failed" and "blocked" one sample. It also found six rules nothing
   applied any more — leftovers of the hand-drawn cases — which went. *)

type vh_element =
  | Frame  (** the bands and the side captions *)
  | Node  (** a node's box *)
  | Name  (** a line under a node's label *)
  | Edge  (** an edge's line *)
  | Edge_label
  | Badge
  | Marker  (** a mark on an edge or a node: placeholder, declaration *)
  | Button  (** a button of the panel *)

(** Where a hint can show: in every drawing, only while no recorded run is
    drawn, or only while one is. *)
type vh_mode = Always | Generic | Recorded

type vh_key =
  | Chain_key  (** the key above the diagram *)
  | Run_key  (** the recorded run's key *)
  | Drawn of string list  (** the drawing says it itself, in these words *)
  | No_key of string  (** it only switches something off; why that needs no key *)

type visual_hint = {
  vh_id : string;
  vh_element : vh_element;
  vh_classes : string list;  (** the classes that carry it *)
  vh_rules : string list;  (** its stylesheet rules, selectors as written *)
  vh_mode : vh_mode;
  vh_group : string option;
      (** hints of one group never share an element: an edge has one state *)
  vh_sample : string;  (** the key's sample, as markup *)
  vh_says : string;  (** the key's words *)
  vh_key : vh_key;
}

(** The rules that are the base look every hint modifies — not hints. *)
let vocabulary_base : string list =
  [ ".band"; ".node rect"; ".node .nlabel";
    (* a recorded run's state takes the line: the generic dashes go *)
    ".rec .edge line,.rec .edge path"; ".phm"; ".selbar button";
    ".selbar button:disabled"; ".selbar button:hover"; "svg .edge" ]

let visual_hints : visual_hint list =
  let hint ?group ?(sample = "") ?(says = "") id element classes rules mode key =
    { vh_id = id; vh_element = element; vh_classes = classes; vh_rules = rules;
      vh_mode = mode; vh_group = group; vh_sample = sample; vh_says = says; vh_key = key }
  in
  let sw c = Printf.sprintf {|<i class="sw%s"></i>|} (if String.is_empty c then "" else " " ^ c) in
  let badge_svg inner =
    Printf.sprintf {|<svg width="20" height="20" viewBox="0 0 20 20">%s</svg>|} inner
  in
  let phm_svg cls =
    Printf.sprintf
      {|<svg width="26" height="18" viewBox="0 0 26 18"><g class="phm %s"><rect x="2" y="1" width="22" height="16" rx="3"/><text x="13" y="13">…</text></g></svg>|}
      cls
  in
  let outcome cls =
    badge_svg (Printf.sprintf {|<g class="edge %s"><circle class="cbadge chk" cx="10" cy="10" r="7"/></g>|} cls)
  in
  let state ?(rules = []) cls sample says =
    hint ~group:"state" ~sample ~says ("state." ^ cls) Edge [ "st-" ^ cls ]
      (if List.is_empty rules then
         [ Printf.sprintf ".rec .edge.st-%s line,.rec .edge.st-%s path" cls cls ]
       else rules)
      Recorded Run_key
  in
  [ (* ── the frame ── *)
    hint "bands" Frame [ "pm"; "package"; "artifact"; "program" ]
      [ ".band.pm"; ".band.package"; ".band.artifact"; ".band.program"; ".bandlabel" ]
      Always
      (Drawn (List.map bands_def ~f:(fun (_, _, title, _) -> title)));
    hint "sides" Frame [ "sidecap" ] [ ".sidecap" ] Always
      (Drawn [ "SYSTEM SIDE"; "LANGUAGE SIDE" ]);
    (* ── the panel ── *)
    hint "button.chosen" Button [ "on" ] [ ".selbar button.on" ] Always Chain_key
      ~sample:{|<span class="kbtn on">opam</span>|} ~says:"a choice made";
    hint "button.picked" Button [ "hint" ] [ ".selbar button.hint" ] Generic Chain_key
      ~sample:{|<span class="kbtn hint">zarith</span>|}
      ~says:"a package in canary the current choice picks out";
    (* ── edges, in every drawing ── *)
    hint "label.action" Edge_label [ "elabel" ] [ ".edge .elabel" ] Always Chain_key
      ~sample:"<code>fetch_lib</code>" ~says:"our action";
    hint "label.info" Edge_label [ "info" ] [ ".edge .elabel.info" ] Always Chain_key
      ~sample:"<em>pkg-config</em>" ~says:"someone else's rule — we run nothing there";
    hint "label.claim" Edge_label [ "claim" ] [ ".edge .elabel.claim" ] Always Chain_key
      ~sample:{|<b class="clm">prs</b>|} ~says:"a claim of ours is all that relates the two ends";
    hint "edge.plain" Edge [ "edge" ] [ ".edge line"; ".edge path" ] Always Chain_key
      ~sample:(sw "") ~says:"within a layer, or down one";
    hint "edge.diagonal" Edge [ "diag" ] [ ".edge.diag line" ] Generic Chain_key
      ~sample:(sw "d") ~says:"diagonal — crosses layers (discovery)";
    hint "edge.bare" Edge [ "bare" ] [ ".edge.bare line"; ".edge.bare .elabel" ] Generic Chain_key
      ~sample:(sw "b") ~says:"no claim recovers this relation";
    hint "edge.greyed" Edge [ "jdead" ]
      [ ".join .edge.jdead"; ".join .edge.jdead .cbadge,.join .edge.jdead .cnum" ]
      Generic Chain_key ~sample:(sw "gr")
      ~says:"greyed — in these chains the relation exists and does not fire";
    hint "hover" Edge [] [ "svg .edge:hover line,svg .edge:hover path" ] Always
      (No_key
         "the edge under the pointer thickens and its description shows under the \
          diagram; the prose above the key says so");
    (* ── badges ── *)
    hint "badge.checked" Badge [ "chk" ] [ ".cbadge"; ".cnum" ] Always Chain_key
      ~sample:(badge_svg {|<circle class="cbadge chk" cx="10" cy="10" r="7"/>|})
      ~says:"agreements canary checks here, for the chain drawn";
    hint "badge.named" Badge [ "cand" ] [ ".cbadge.cand"; ".cnum.cand" ] Always Chain_key
      ~sample:(badge_svg {|<circle class="cbadge cand" cx="10" cy="10" r="7"/>|})
      ~says:"agreements only named — no evaluator yet";
    hint "badge.empty" Badge [ "none" ] [ ".cbadge.none,.cnum.none" ] Always
      (No_key "a badge with nothing to count is not drawn");
    (* ── nodes and the lines under them ── *)
    hint "node.declared" Marker [ "declmark" ] [ ".declmark circle"; ".declmark text" ] Always
      Chain_key ~sample:"◇" ~says:"the experiment declares something here";
    hint "node.related" Node [ "related" ] [ ".join .node.related rect" ] Generic Chain_key
      ~sample:
        {|<svg width="26" height="16" viewBox="0 0 26 16"><g class="node related"><rect x="2" y="2" width="22" height="12" rx="3"/></g></svg>|}
      ~says:"outlined — a package node the last button clicked is about";
    hint "node.gone" Node [ "gone" ] [ ".join .gone"; ".rec .gone" ] Always
      (No_key
         "not drawn at all: a node or edge the chain does not have is absent, which the \
          prose says is the statement");
    hint "name.declared" Name [ "ncase" ] [ ".join .node .ncase" ] Always Chain_key ~group:"name"
      ~sample:{|<span class="nm-decl">name</span>|} ~says:"a name the project declares";
    hint "name.term" Name [ "term" ] [ ".join .node .ncase.term" ] Always Chain_key ~group:"name"
      ~sample:{|<span class="nm-term">.pc file</span>|}
      ~says:"a package manager's term, where no name is known";
    (* ── a recorded run ── *)
    hint "name.recorded" Name [ "rec-name" ] [ ".join .node .ncase.rec-name" ] Recorded Run_key
      ~group:"name" ~sample:{|<span class="nm-rec">name</span>|} ~says:"a name the run recorded";
    hint "name.placed" Name [ "nplace" ] [ ".join .node .nplace" ] Recorded Run_key
      ~sample:{|<span class="nm-place">F 1.14</span>|}
      ~says:"the third line: where the run placed the artifact";
    hint "node.untouched" Node [ "dim" ] [ ".node.dim" ] Recorded Run_key
      ~sample:
        {|<svg width="26" height="16" viewBox="0 0 26 16"><g class="node dim"><rect x="2" y="2" width="22" height="12" rx="3"/></g></svg>|}
      ~says:"dimmed — in the chain, and nothing in this run touched it";
    state "ran" (sw "ok") "ran";
    state "warm" (sw "okw") "warm — an earlier run's verdict";
    state "xfail" (sw "xf") "expected failure confirmed";
    state "fail" (sw "bad") "failed";
    state "blocked" (sw "bl") "blocked — something it needs failed first";
    state "unrecorded" (sw "un") "in the chain, never logged";
    state "absent" ~rules:[ ".rec .edge.st-absent" ] (sw "ab") "not realized in this world";
    state "not_ours" ~rules:[ ".rec .edge.st-not_ours"; ".rec .edge.st-not_ours line" ] (sw "no")
      "someone else's rule — nothing recorded";
    state "observed" ~rules:[ ".rec .edge.st-observed line" ] (sw "ob")
      "someone else's rule — recorded by this run";
    state "inside"
      {|<svg width="26" height="6" viewBox="0 0 26 6"><line class="swl in" x1="0" y1="3" x2="26" y2="3"/></svg>|}
      "happened inside a package manager's action — unseen";
    state "included" (sw "ic")
      "included with the language — made by its own build and install, before the run";
    state "claim" ~rules:[ ".rec .edge.st-claim line" ] (sw "cl")
      "a claim of ours — only the claim relates the two ends";
    hint "outcome.violated" Badge [ "cl-violated" ] [ ".rec .edge.cl-violated .cbadge.chk" ]
      Recorded Run_key ~group:"outcome" ~sample:(outcome "cl-violated")
      ~says:"an agreement here is violated";
    hint "outcome.holds" Badge [ "cl-holds" ] [ ".rec .edge.cl-holds .cbadge.chk" ] Recorded
      Run_key ~group:"outcome" ~sample:(outcome "cl-holds") ~says:"every agreement here holds";
    hint "outcome.partial" Badge [ "cl-partial" ] [ ".rec .edge.cl-partial .cbadge.chk" ]
      Recorded Run_key ~group:"outcome" ~sample:(outcome "cl-partial")
      ~says:"some hold, the rest have no verdict";
    hint "outcome.none" Badge [ "cl-undecided"; "cl-unevaluated" ]
      [ ".rec .edge.cl-undecided .cbadge.chk,.rec .edge.cl-unevaluated .cbadge.chk" ] Recorded
      Run_key ~group:"outcome" ~sample:(outcome "cl-undecided") ~says:"no verdict yet";
    hint "placeholder.out_of_reach" Marker [ "on" ] [ ".phm.on"; ".phm rect"; ".phm text" ]
      Recorded Run_key ~sample:(phm_svg "on")
      ~says:"a package manager did something here that this run cannot record";
    hint "placeholder.not_yet" Marker [ "not_yet" ] [ ".phm.not_yet rect"; ".phm.not_yet text" ]
      Recorded Run_key ~sample:(phm_svg "on not_yet")
      ~says:"a package manager did something here that this run does not record yet" ]

(** One key, rendered from the vocabulary: a sample and its words per
    hint, in the list's order. *)
let key_html (k : vh_key) : string =
  String.concat ~sep:"\n"
    (List.filter_map visual_hints ~f:(fun h ->
         if Poly.equal h.vh_key k then
           Some (Printf.sprintf "<span>%s %s</span>" h.vh_sample (esc h.vh_says))
         else None))

let claim_sites_table () =
  let row (e : T.edge) =
    let ps = T.claim_sites_on e.T.eg_id in
    let impl = List.count ps ~f:T.implemented in
    let cand = List.length ps - impl in
    let names =
      if List.is_empty ps then
        "<em>nothing — this relation is recovered by no claim</em>"
      else
        String.concat ~sep:", "
          (List.map ps ~f:(fun p ->
               Printf.sprintf "<code>%s</code>%s" (esc p.T.cs_claim)
                 (if T.implemented p then "" else "<sup>?</sup>")))
    in
    let annotation =
      match e.T.eg_annotation with
      | T.Action f ->
          Printf.sprintf "<code>%s</code>"
            (esc (Canary_action_family.to_string f))
      | T.Agreement slug -> Printf.sprintf "claim <code>%s</code>" (esc slug)
      | T.Info s -> Printf.sprintf "<em>%s</em> — we run nothing" (esc s)
    in
    Printf.sprintf
      "<tr%s><td><code>%s</code></td><td class=\"n\">%s</td><td>%s</td><td \
       class=\"n\">%d / %d</td><td>%s</td></tr>"
      (if List.is_empty ps then " class=\"bare\"" else "")
      (esc e.T.eg_id) annotation (esc e.T.eg_tool) impl cand names
  in
  Printf.sprintf
    "<table><thead><tr><th>edge</th><th>annotation</th><th>whose rule \
     runs</th><th>impl / cand</th><th>claims (<sup>?</sup> = no evaluator)</th></tr></thead><tbody>%s</tbody></table>"
    (String.concat (List.map T.edges ~f:row))

(* THE STEPS THE PAGE CANNOT PLACE, from the catalogue (2026-09-23,
   status.md §2.6 step 1). This was a sentence naming two of them — the
   source fetches — while eight more had no edge either. The source
   sentence survives only while a source fetch is still on the list. *)
let missing_steps_note () =
  let missing = T.families_without_edge () in
  let is_source f =
    Canary_action_family.(
      equal f Fetch_source || equal f Fetch_binding_source)
  in
  match missing with
  | [] -> "Every action family in the catalogue has an edge."
  | _ ->
      Printf.sprintf
        "%d of the catalogue's %d action families have no edge here: %s — \
         computed from the action catalogue, not listed by hand.%s"
        (List.length missing)
        (List.length (Canary_action_family.of_catalogue ()))
        (String.concat ~sep:", "
           (List.map missing ~f:(fun f ->
                "<code>" ^ esc (Canary_action_family.to_string f) ^ "</code>")))
        (if List.exists missing ~f:is_source then
           " The source fetches leave both source nodes with no producer, \
            and adding them is a decision rather than a drawing fix: canary \
            treats a repository as a provider beside the system and \
            language packages, which would put it in the package layer."
         else "")

(** LANGUAGE SIDE FIRST (user, 2026-09-22), so the rows group by it.
    The language PM is what a reader arrives with — they are holding an
    opam package and asking what it rests on — and sorting by the native
    side scattered the opam rows through the table. *)
(* ── §5: WHAT CANARY COVERS — THREE TABLES, AND THE CHAINS THEY COMPOSE
   (2026-09-23, user: "the whole chain needs two rows (two pm) from the
   PM-solo table, and one binding table … derive a table in the overview
   page is also interesting and more illustrative").

   Every cell below is computed from canary's own code: the package
   managers' drivers and [Canary_pm_solo], the mechanism catalogue, the
   bridge model, [Canary_topology]'s cooperation kinds, and the projects'
   declarations. The layered-model draft's tables were the reference the
   prose columns were written against; unlike them, these list only what
   canary covers. It replaced the per-shape topology table, whose rows
   are now the chains of §5.4. *)

(* a table that may be wider than the page scrolls on its own *)
let wide (html : string) = {|<div class="widetable">|} ^ html ^ "</div>"

let cells (xs : string list) =
  "<tr>" ^ String.concat (List.map xs ~f:(fun x -> "<td>" ^ x ^ "</td>")) ^ "</tr>"

let heads (xs : string list) =
  "<thead><tr>"
  ^ String.concat (List.map xs ~f:(fun x -> "<th>" ^ x ^ "</th>"))
  ^ "</tr></thead>"

(** Which projects fetch through [pm], read from the providers their
    artifact tables name. A system package names both platforms' packages,
    so it counts for apt and for brew. *)
let pm_users (projects : (string * Canary_project_run.project_run) list)
    (pm : Canary_store.package_manager) : string list =
  List.filter_map projects ~f:(fun (name, pr) ->
      let uses =
        List.exists pr.Canary_project_run.pr_artifacts ~f:(fun row ->
            match Canary_project_spec.provider_of_row row with
            | Some (Canary_store_config.Sys_pkg _) ->
                List.mem [ Canary_store.Apt; Canary_store.Brew ] pm ~equal:Poly.equal
            | Some (Canary_store_config.Lang_pkg { pm = p; _ }) -> Poly.equal p pm
            | _ -> false)
      in
      if uses then Some name else None)

let pm_solo_table projects =
  let row (r : Canary_pm_solo.row) =
    let pm = r.Canary_pm_solo.ps_pm in
    let unseen =
      Canary_pm_action.inside_install pm ~of_binding:true
      |> List.map ~f:(fun p ->
             Printf.sprintf "%s <span class=\"from\">%s</span>"
               (esc p.Canary_pm_action.ph_key)
               (match p.Canary_pm_action.ph_unseen with
                | Canary_pm_action.Not_yet _ -> "not yet"
                | Canary_pm_action.Out_of_reach _ -> "out of reach"))
    in
    let dash = function [] -> "—" | xs -> String.concat ~sep:"<br>" xs in
    cells
      [ Printf.sprintf "<b>%s</b><br><span class=\"from\">%s</span>"
          (esc (Canary_store.string_of_pm pm))
          (esc (Canary_pm_solo.scope_of pm));
        esc (Canary_pm_solo.store_of pm);
        esc r.Canary_pm_solo.ps_package;
        esc r.Canary_pm_solo.ps_versions;
        esc r.Canary_pm_solo.ps_ships;
        (* the terms §1 writes under "capability file" and "bridge package" *)
        Printf.sprintf "<b>%s</b>" (esc r.Canary_pm_solo.ps_capability);
        dash (List.map (Canary_bridge.kinds_of_pm pm) ~f:esc);
        dash unseen;
        (match pm_users projects pm with [] -> "—" | us -> esc (String.concat ~sep:", " us)) ]
  in
  wide
    (Printf.sprintf "<table class=\"cov\">%s<tbody>%s</tbody></table>"
       (heads
          [ "package manager"; "store"; "what a package is"; "its versions";
            "what it ships for others to read"; "its capability file";
            "bridges it defines"; "inside an install, unseen"; "used by" ])
       (String.concat (List.map Canary_pm_solo.table ~f:row)))

(** Which projects bind through [m], per pass 2 — the mechanism each
    declared binding language resolves to. *)
let mechanism_users (projects : (string * Canary_project_run.project_run) list)
    (m : Canary_mechanism.mechanism) : string list =
  List.filter_map projects ~f:(fun (name, pr) ->
      let an = Canary_pipeline.analysed_of pr in
      if
        List.exists (T.binding_langs pr) ~f:(fun lang ->
            Poly.equal (Canary_project_analysis.mechanism_for an lang) m)
      then Some name
      else None)

let binding_table projects =
  let yes b = if b then "yes" else "no" in
  let row (i : Canary_mechanism.mechanism_info) =
    let m = i.Canary_mechanism.mi_mechanism in
    cells
      [ Printf.sprintf "<b>%s</b>" (esc (Canary_mechanism.string_of_mechanism m));
        esc (Canary_lang.string_of_lang i.Canary_mechanism.mi_lang);
        esc
          (match i.Canary_mechanism.mi_discipline with
           | Canary_mechanism.Static_c_abi -> "static C ABI"
           | Canary_mechanism.Dynamic_ffi -> "dynamic FFI");
        esc i.Canary_mechanism.mi_lib_coupling;
        yes i.Canary_mechanism.mi_compiles_a_stub;
        yes i.Canary_mechanism.mi_consumer_records_needed;
        yes i.Canary_mechanism.mi_exposes_typed_stub;
        (match mechanism_users projects m with
         | [] -> "— <span class=\"from\">not wired</span>"
         | us -> esc (String.concat ~sep:", " us)) ]
  in
  wide
    (Printf.sprintf "<table class=\"cov\">%s<tbody>%s</tbody></table>"
       (heads
          [ "mechanism"; "language"; "discipline"; "how the library is bound";
            "a compiled stub?"; "does the consumer record its NEEDED?";
            "a typed boundary?"; "used by" ])
       (String.concat
          (List.map ~f:row
             (* grouped by language, as §1's buttons are (user, 2026-09-24) *)
             (Canary_overview_join.by_language
                (fun (i : Canary_mechanism.mechanism_info) -> i.Canary_mechanism.mi_lang)
                Canary_mechanism.mechanism_catalogue))))

(* the instances of one cooperation kind, and the two package managers
   (or local suppliers) each joins *)
let coop_groups projects =
  (* per WORLD (2026-09-23): a world that builds its binding does not go
     through the package gate its project declares *)
  let insts = List.concat_map projects ~f:T.topologies_of_worlds in
  List.filter_map T.coop_catalogue ~f:(fun info ->
      match
        List.filter insts ~f:(fun ((t : T.t), _) ->
            Poly.equal (T.coop_of t) info.T.co_kind)
      with
      | [] -> None
      | xs -> Some (info, xs))

let coop_table projects =
  let groups = coop_groups projects in
  let row ((info : T.coop_info), (xs : (T.t * T.instance) list)) =
    let pairs =
      List.map xs ~f:(fun ((t : T.t), _) ->
          T.string_of_supplier t.T.tp_lang ^ " ↔ " ^ T.string_of_supplier t.T.tp_sys)
      |> List.dedup_and_sort ~compare:String.compare
    in
    let who =
      List.map xs ~f:(fun ((t : T.t), (i : T.instance)) ->
          let bridge =
            match T.bridges_of_join t.T.tp_join with
            | [] -> ""
            | bs -> " (" ^ String.concat ~sep:" + " (List.map bs ~f:T.string_of_gated) ^ ")"
          in
          (* a binding the world does not take from a package manager says
             so: that is why no gate applies to it *)
          let side =
            match t.T.tp_lang with
            | T.By_pm _ -> ""
            | s -> " (binding " ^ T.string_of_supplier s ^ ")"
          in
          i.T.in_project ^ bridge ^ side)
      |> List.dedup_and_sort ~compare:String.compare
    in
    (* the kinds of bridge its chains join through — the term §1 writes
       under "bridge package" for this cooperation *)
    let bridge_kinds =
      List.concat_map xs ~f:(fun ((t : T.t), _) ->
          List.map (T.bridges_of_join t.T.tp_join) ~f:(fun g ->
              Canary_bridge.kind_term g.T.gb_bridge))
      |> List.dedup_and_sort ~compare:String.compare
    in
    cells
      [ Printf.sprintf "<b>%s</b><br><span class=\"from\">draft: %s</span>"
          (esc info.T.co_name) (esc info.T.co_draft);
        esc (String.concat ~sep:", " pairs);
        (match bridge_kinds with
         | [] -> "—"
         | ks -> Printf.sprintf "<b>%s</b>" (esc (String.concat ~sep:" · " ks)));
        esc info.T.co_package_join;
        esc info.T.co_artifact_join;
        esc info.T.co_versions;
        esc info.T.co_recorded;
        esc (String.concat ~sep:", " who) ]
  in
  let covered = List.map groups ~f:(fun (i, _) -> i.T.co_kind) in
  let uncovered =
    List.filter T.coop_catalogue ~f:(fun i ->
        not (List.mem covered i.T.co_kind ~equal:Poly.equal))
  in
  wide
    (Printf.sprintf "<table class=\"cov\">%s<tbody>%s</tbody></table>"
       (heads
          [ "cooperation"; "the two sides"; "its bridge"; "how the packages are joined";
            "what meets the artifacts"; "how a version constraint travels";
            "what canary records"; "instances" ])
       (String.concat (List.map groups ~f:row)))
  ^ Printf.sprintf
      "<p class=\"mechnote\">Classified but instantiated by no project yet: %s.</p>"
      (esc
         (String.concat ~sep:"; "
            (List.map uncovered ~f:(fun i -> i.T.co_name))))

(** The chains: one per (project, binding language, the two sides) — a
    binding mechanism between two sides, joined by a cooperation. The SAME
    list §1's concrete buttons are ([Canary_overview_join.cases_of]), and
    each row links to its chain drawn there. *)
let chains_table (j : Canary_overview_join.t) =
  let module J = Canary_overview_join in
  wide
    (Printf.sprintf "<table class=\"cov\">%s<tbody>%s</tbody></table>"
       (heads
          [ "project"; "language"; "binding (§5.2)"; "language side (§5.1)";
            "native side (§5.1)"; "cooperation (§5.3)" ])
       (String.concat
          (List.map j.J.jn_cases ~f:(fun c ->
               cells
                 [ Printf.sprintf {|<a href="#chain=%s">%s</a>|} (esc c.J.cs_id)
                     (esc c.J.cs_project);
                   esc (Canary_lang.string_of_lang c.J.cs_lang);
                   esc (Canary_mechanism.string_of_mechanism c.J.cs_mechanism);
                   esc (T.string_of_supplier c.J.cs_topology.T.tp_lang);
                   esc (T.string_of_supplier c.J.cs_topology.T.tp_sys);
                   esc (T.character c.J.cs_topology) ]))))

(** The two things the deleted `checks --topology` said that the table
    does not (2026-09-23): which rows are wrong for a known reason, and
    why no capability file appears. Both computed — the second was a
    hand-written sentence in the terminal view, and is now a question
    asked of every project's declared C API. *)
let topology_notes (projects : (string * Canary_project_run.project_run) list) =
  let unreachable =
    T.unreachable_gates (T.topologies projects)
    |> List.map ~f:(fun i ->
           Printf.sprintf "%s/%s" i.T.in_project
             (Canary_lang.string_of_lang i.T.in_lang))
    |> List.dedup_and_sort ~compare:String.compare
  in
  let gates =
    if List.is_empty unreachable then ""
    else
      Printf.sprintf
        "<div class=\"note warn\"><strong>%d bindings sit in a wrong row, \
         for a known reason</strong> (%s). Each declares a conf package, \
         but on the opam-binding template's own record: the template leaves \
         <code>pr_binding_decls</code> empty, so the gate never reaches this \
         derivation and the row reads <code>⚠ UNDECLARED</code>. That is \
         <code>project/issues.md</code> §2 — a mechanism declared in two \
         places, one of them read — at its second consumer.</div>"
        (List.length unreachable)
        (esc (String.concat ~sep:", " unreachable))
  in
  let cap =
    if T.no_capability_file_declared projects then
      "<div class=\"note warn\"><strong>No row is capability-mediated, \
       because no project declares a capability file.</strong> The \
       projects declare <code>Headers</code>, <code>Runtime_lib</code> and \
       <code>Link_lib</code> as their C API's components and none declares \
       a <code>Pc_file</code>. That is an absence of DECLARATION, not of \
       the file: pkg-config is demonstrably in use — the conf packages' \
       checks read it, and canary's own library locator does. A capability \
       file is not a bridge; where a row says <em>artifact validation</em>, \
       that is the bridge's own check.</div>"
    else ""
  in
  gates ^ cap

(** The node legend. It exists because a reader asked what a "capability
    file" and a "staged copy" were — the glosses were already on the
    nodes as SVG tooltips, which is exactly where a reader who is
    scrolling will not find them. A tooltip is a reminder, not an
    explanation. *)
let node_legend () =
  let row (n : T.node) =
    Printf.sprintf
      "<tr><td><b>%s</b></td><td class=\"n\">%s</td><td>%s</td></tr>"
      (esc n.T.nd_label)
      (esc (T.string_of_layer n.T.nd_layer))
      (esc n.T.nd_gloss)
  in
  Printf.sprintf
    "<table><thead><tr><th>node</th><th>layer</th><th>what it \
     is</th></tr></thead><tbody>%s</tbody></table>"
    (String.concat (List.map T.nodes ~f:row))

(* ── THE HAND-DRAWN CASES: notes and an oracle, no longer drawings ─────

   Five cooperations were drawn by hand as §2 (2026-09-22), and §2.1 drew
   each one's recorded counterpart beside it (2026-09-23), so what the
   derivations drew could be compared with what was expected. §1 now draws
   every chain canary runs, named from declarations and overlaid with its
   recorded run, so the drawings went (user, 2026-09-24: "shall we remove
   the diagrams in ss2 and ss 2.1 … please merged them into the ss 1's
   diagram rather than just deleting them"). What stays:
   - each case's prose, shown in §1 with the cooperation it illustrates;
   - its names, the nodes it leaves out and the edges it greys — the
     ORACLE the pins still hold the derivations to
     ([overview.package_band_is_one_cooperation],
     [overview.recorded_views_are_named]). *)

(** One hand-drawn case. *)
type case = {
  ca_key : string;
  ca_coop : T.coop;
      (** the cooperation it illustrates — held to its counterpart
          world's by [overview.package_band_is_one_cooperation] *)
  ca_title : string;
  ca_blurb : string;
  ca_names : (string * string) list;  (** node id → what the case calls it *)
  ca_subs : (string * string) list;  (** node id → what the case says about it *)
  ca_hidden : string list;  (** nodes that do not exist in the case *)
  ca_dead : string list;  (** edges that exist and do not fire *)
}

let hand_cases : case list =
  [ { ca_key = "conf"; ca_coop = T.Co_conf; ca_title = "conf-* over a system library";
      ca_blurb =
        "Both bridges present, and each sits with its author. The \
         SYMBOLIC path runs <code>binding → conf → depext → system \
         package</code>; the ARTIFACT path runs <code>conf predicate → \
         capability query → the library on disk</code>. They can land \
         on different libraries, and nothing today compares them.";
      ca_names =
        [ ("pm_sys", "apt"); ("pkg_sys", "libgmp-dev");
          ("bridge", "conf-gmp"); ("cap", "gmp.pc"); ("pm_lang", "opam");
          ("pkg_lang", "zarith"); ("lib_sys", "libgmp.so.10");
          ("hdr_sys", "gmp.h"); ("src_lang", "Zarith.git");
          ("stub_lang", "zarith_stubs.a"); ("mod_lang", "zarith.cmxa");
          ("surf_lang", "zarith.mli");
          ("consumer_artifact", "zarith_example (paths)");
          ("consumer_package", "zarith_example (-package zarith)") ];
      ca_subs =
        [ ("bridge", "an opam package — written by an opam maintainer");
          ("cap", "inside libgmp-dev — written by the Debian packager") ];
      ca_hidden = [ "src_sys"; "staged_sys" ]; ca_dead = [] };
    { ca_key = "wheel"; ca_coop = T.Co_absorbed; ca_title = "the library inside the wheel";
      ca_blurb =
        "The consumer package carries the native artifact. The system \
         PM, the system package and <em>both</em> bridges disappear — \
         there is no cooperation left, which is a different statement \
         from having no bridge. Every claim that compared two \
         ecosystems has nothing to compare.";
      ca_names =
        [ ("pm_lang", "pip"); ("pkg_lang", "z3-solver (wheel)");
          ("lib_sys", "libz3.so — INSIDE the wheel");
          ("mod_lang", "z3/*.py + native ext");
          ("surf_lang", "z3.__all__");
          ("consumer_package", "python -c 'import z3'") ];
      ca_subs =
        [ ("lib_sys", "no system package, no bridge, no discovery");
          ("pkg_lang", "one package supplies both sides") ];
      ca_hidden =
        [ "pm_sys"; "pkg_sys"; "bridge"; "cap"; "src_sys"; "staged_sys";
          "hdr_sys"; "src_lang"; "stub_lang" ];
      ca_dead = [] };
    { ca_key = "built"; ca_coop = T.Co_gated_local;
      ca_title = "built here — and the bridge still gates";
      ca_blurb =
        "The native side is built here, so the system package is not \
         used. The binding package's <code>conf-llvm-shared {= \
         \"19\"}</code> constraint is still in its depends and opam \
         still evaluates it — against the system, which this world is \
         not using. The gate passes or fails on evidence unrelated to \
         the artifacts under test.";
      ca_names =
        [ ("src_sys", "llvm-project @ ref");
          ("lib_sys", "libLLVM.so (built)");
          ("staged_sys", "install prefix");
          ("pm_sys", "apt — not used here");
          ("pkg_sys", "llvm-19-dev — not used here");
          ("bridge", "conf-llvm-shared {= 19}"); ("cap", "llvm-config");
          ("pm_lang", "opam"); ("pkg_lang", "llvm.19-shared");
          ("mod_lang", "llvm.cmxa");
          ("consumer_artifact", "llvm_example (build tree)");
          ("consumer_package", "llvm_example (-package llvm)") ];
      ca_subs =
        [ ("bridge", "still runs — against the SYSTEM, not this build");
          ("pkg_sys", "the gate validates this, the world uses that") ];
      ca_hidden = [];
      ca_dead = [ "resolve_sys"; "realize_sys"; "realize_hdr"; "realize_cap" ] };
    { ca_key = "unified"; ca_coop = T.Co_unified; ca_title = "one package universe";
      ca_blurb =
        "Both sides come from the same package manager, so there is no \
         second ecosystem to bridge to — the constraint travels as an \
         ordinary dependency in one namespace. This is torch: the \
         library arrives through opam as an upstream binary, named \
         directly by a depext bound rather than through a conf hop.";
      ca_names =
        [ ("pm_lang", "opam"); ("pkg_lang", "torch");
          ("bridge", "depext: libtorch >=2.1.0 <2.2.0");
          ("lib_sys", "libtorch.so (opam binary)");
          ("hdr_sys", "torch/*.h"); ("src_lang", "ocaml-torch.git");
          ("stub_lang", "libtorch_core_stubs.a");
          ("mod_lang", "torch.cmxa"); ("surf_lang", "torch.mli");
          ("consumer_artifact", "torch_example (paths)");
          ("consumer_package", "torch_example (-package torch)") ];
      ca_subs =
        [ ("bridge", "metadata inside the consumer — not a package of its own");
          ("pkg_lang", "same PM on both sides") ];
      ca_hidden = [ "pm_sys"; "pkg_sys"; "cap"; "src_sys"; "staged_sys" ];
      ca_dead = [] };
    { ca_key = "none"; ca_coop = T.Co_no_pm; ca_title = "no package manager between them";
      ca_blurb =
        "The binding and the library were joined by whoever built the \
         interpreter, outside any package manager we can observe. \
         CPython's stdlib <code>sqlite3</code> is the case. The \
         coupling is entirely real — the extension records a NEEDED on \
         libsqlite3 and the loader resolves it — but there is no \
         declaration anywhere to check it against. <em>No gate</em> and \
         <em>no gate mechanism</em> are different situations.";
      ca_names =
        [ ("pm_sys", "apt"); ("pkg_sys", "libsqlite3-0");
          ("lib_sys", "libsqlite3.so.0"); ("hdr_sys", "sqlite3.h");
          ("pm_lang", "(the interpreter build)");
          ("pkg_lang", "CPython stdlib");
          ("stub_lang", "_sqlite3.cpython-*.so");
          ("mod_lang", "sqlite3/__init__.py");
          ("surf_lang", "dir(sqlite3)");
          ("consumer_package", "python -c 'import sqlite3'") ];
      ca_subs =
        [ ("pkg_lang", "chosen at interpreter build time, not here");
          ("lib_sys", "the loader picks it; nothing declared which") ];
      ca_hidden = [ "bridge"; "cap"; "src_sys"; "staged_sys"; "src_lang" ];
      ca_dead = [] } ]

(* ── THE CHAIN, CHOSEN (2026-09-23, status.md §2.7; user: draw the
   package-manager part per cooperation, the way the artifact part is
   drawn per mechanism — and, 2026-09-24, "can we also make the pm itself
   as the choice? … all are shown as buttons in one place") ──────────────

   ONE diagram and one panel of buttons: the native side's package
   manager, the language side's, the binding mechanism (the artifact
   band, a row of §5.2), the cooperation (the package band, a row of
   §5.3) — or a concrete chain canary runs (a row of §5.4), which fixes
   the other four and names the nodes under their generic labels. A
   mechanism also chooses the package manager that ships its language's
   bindings. Every set a choice draws comes from [Canary_overview_join],
   as the JSON the script reads; the script keeps the state, looks the
   sets up and applies them. The page opens drawn in the default choice,
   so it reads right before any script runs.

   It replaced five pre-rendered panels, one per mechanism, and then two
   bars driven by a generated stylesheet — which could not narrow a
   cooperation by package manager, and so drew absorbed with a binding
   source that no wheel has. *)

(** The chains the ids name, as a reader reads them: project and language,
    once each. *)
let runs_label (j : Canary_overview_join.t) (ids : string list) : string =
  List.filter_map ids ~f:(fun id ->
      List.find_map j.Canary_overview_join.jn_cases ~f:(fun c ->
          if String.equal c.Canary_overview_join.cs_id id then
            Some
              (c.Canary_overview_join.cs_project ^ " ("
              ^ Canary_lang.string_of_lang c.Canary_overview_join.cs_lang
              ^ ")")
          else None))
  |> List.dedup_and_sort ~compare:String.compare
  |> String.concat ~sep:", "

(** The panel and the one diagram it draws. *)
let join_panel (j : Canary_overview_join.t) =
  let module J = Canary_overview_join in
  let m0, k0, pl0 = J.default_choice j in
  let gone0, dead0 = J.default_drawing j in
  let classes id =
    (if List.mem gone0 id ~equal:String.equal then [ "gone" ] else [])
    @ if List.mem dead0 id ~equal:String.equal then [ "jdead" ] else []
  in
  let hidden_unless lit = if lit then "" else " hidden" in
  let button ~g ~v ?(title = "") ~lit label =
    Printf.sprintf {|<button data-g="%s" data-v="%s"%s%s>%s</button>|} g (esc v)
      (if String.is_empty title then "" else Printf.sprintf {| title="%s"|} (esc title))
      (if lit then {| class="on"|} else "")
      label
  in
  let row label body =
    Printf.sprintf {|<div class="selbar jrow"><span class="barlabel">%s</span>%s</div>|}
      label body
  in
  let pm_buttons side g =
    String.concat
      (List.map (J.pms side) ~f:(fun pm ->
           let v = Canary_store.string_of_pm pm in
           let lit = String.equal g "pl" && Poly.equal pl0 (Some v) in
           button ~g ~v ~title:(Canary_pm_solo.scope_of pm) ~lit (esc v)))
  in
  let m_buttons =
    String.concat
      (List.map (J.variants ()) ~f:(fun v ->
           let m = Canary_mechanism.string_of_mechanism v.T.av_mechanism in
           button ~g:"m" ~v:m ~lit:(String.equal m m0)
             (Printf.sprintf {|%s <span class="bl">%s</span>|} (esc m)
                (esc (Canary_lang.string_of_lang v.T.av_lang)))))
  in
  let k_buttons =
    String.concat
      (List.map j.J.jn_kinds ~f:(fun b ->
           let info = T.info_of_coop b.T.cb_kind in
           let k = T.code_of_coop b.T.cb_kind in
           button ~g:"k" ~v:k ~title:info.T.co_name ~lit:(String.equal k k0)
             (Printf.sprintf {|%s <span class="bl">%s</span>|} (esc info.T.co_label)
                (esc (J.pm_label j b.T.cb_kind)))))
  in
  (* the concrete chains, grouped by project in §4.4's order *)
  let projects_in_order =
    List.fold j.J.jn_cases ~init:[] ~f:(fun acc c ->
        if List.mem acc c.J.cs_project ~equal:String.equal then acc
        else acc @ [ c.J.cs_project ])
  in
  let c_buttons =
    String.concat
      (List.map projects_in_order ~f:(fun p ->
           Printf.sprintf {|<span class="cgroup"><span class="cproj">%s</span>%s</span>|}
             (esc p)
             (String.concat
                (List.filter_map j.J.jn_cases ~f:(fun c ->
                     if not (String.equal c.J.cs_project p) then None
                     else
                       Some
                         (button ~g:"c" ~v:c.J.cs_id ~title:(T.character c.J.cs_topology)
                            ~lit:false
                            (Printf.sprintf {|%s <span class="bl">%s ↔ %s</span>|}
                               (esc (Canary_lang.string_of_lang c.J.cs_lang))
                               (esc (T.string_of_supplier c.J.cs_topology.T.tp_lang))
                               (esc (T.string_of_supplier c.J.cs_topology.T.tp_sys)))))))))
  in
  let sides k =
    List.filter_map j.J.jn_instances ~f:(fun i ->
        if Poly.equal (T.coop_of i.T.bi_topology) k then
          Some
            (T.string_of_supplier i.T.bi_topology.T.tp_lang
            ^ " ↔ "
            ^ T.string_of_supplier i.T.bi_topology.T.tp_sys)
        else None)
    |> List.dedup_and_sort ~compare:String.compare
  in
  let m_notes =
    String.concat
      (List.map (J.variants ()) ~f:(fun v ->
           let m = Canary_mechanism.string_of_mechanism v.T.av_mechanism in
           Printf.sprintf {|<p class="mechnote jnote" data-jm="%s"%s><b>%s</b> — %s%s</p>|}
             (esc m) (hidden_unless (String.equal m m0)) (esc m)
             (if v.T.av_wired then ""
              else "<b>Not wired — no live project binds through it.</b> ")
             (esc v.T.av_note)))
  in
  (* THE HAND-DRAWN CASE A COOPERATION WAS ILLUSTRATED BY — its prose, and
     what it said about single nodes, merged here from the retired §2 *)
  let hand_note k =
    match List.find hand_cases ~f:(fun c -> Poly.equal c.ca_coop k) with
    | None -> ""
    | Some c ->
        Printf.sprintf {|<br><b>%s.</b> %s%s|} (esc c.ca_title) c.ca_blurb
          (String.concat
             (List.map c.ca_subs ~f:(fun (n, s) ->
                  Printf.sprintf " <i>%s</i>: %s."
                    (esc
                       (Option.value_map (T.node_by_id n) ~default:n ~f:(fun nd ->
                            nd.T.nd_label)))
                    (esc s))))
  in
  (* a cooperation's note says what it is whether or not a concrete
     package is chosen; its band's note only while none is *)
  let k_notes =
    String.concat
      (List.map j.J.jn_kinds ~f:(fun b ->
           let info = T.info_of_coop b.T.cb_kind in
           let k = T.code_of_coop b.T.cb_kind in
           Printf.sprintf
             {|<p class="mechnote jnote" data-jk="%s"%s><b>%s</b> — %s.%s</p><p class="mechnote jnote" data-jkb="%s"%s>Its two sides: %s. Drawn from <span class="jcount">%d</span> of its chains (one per world and binding language) — those with the chosen package managers: a node is left out only when none of them has it.</p>|}
             (esc k) (hidden_unless (String.equal k k0)) (esc info.T.co_name)
             (esc info.T.co_package_join) (hand_note b.T.cb_kind) (esc k)
             (hidden_unless (String.equal k k0))
             (esc (String.concat ~sep:", " (sides b.T.cb_kind)))
             b.T.cb_worlds))
  in
  let pm_notes =
    String.concat
      (List.map Canary_pm_solo.table ~f:(fun r ->
           let v = Canary_store.string_of_pm r.Canary_pm_solo.ps_pm in
           Printf.sprintf {|<p class="mechnote jnote" data-jpm="%s"%s><b>%s</b> — %s.</p>|}
             (esc v) (hidden_unless (Poly.equal pl0 (Some v))) (esc v)
             (esc r.Canary_pm_solo.ps_package)))
  in
  let c_notes =
    String.concat
      (List.map j.J.jn_cases ~f:(fun c ->
           Printf.sprintf
             {|<p class="mechnote jnote" data-jc="%s" hidden><b>%s</b> (%s) — %s ↔ %s: %s. Under each generic label, what %s declares the node is, in italics — or, upright, what a recorded run of it found; the chain is drawn from its %d world%s.</p>|}
             (esc c.J.cs_id) (esc c.J.cs_project)
             (esc (Canary_lang.string_of_lang c.J.cs_lang))
             (esc (T.string_of_supplier c.J.cs_topology.T.tp_lang))
             (esc (T.string_of_supplier c.J.cs_topology.T.tp_sys))
             (esc (T.character c.J.cs_topology))
             (esc c.J.cs_project) c.J.cs_band.T.cb_worlds
             (if c.J.cs_band.T.cb_worlds = 1 then "" else "s")))
  in
  let runs0 =
    match
      List.Assoc.find j.J.jn_runs
        (m0 ^ "|" ^ k0 ^ "|*|" ^ Option.value pl0 ~default:"*")
        ~equal:String.equal
    with
    | None | Some [] -> "No chain canary runs has this choice."
    | Some ids ->
        "<strong>Canary runs this chain:</strong> " ^ esc (runs_label j ids) ^ " (§4.4)."
  in
  (* the covered kinds with no band of their own, said rather than
     dropped — their chains are among the concrete ones *)
  let unbanded =
    List.filter_map T.coop_catalogue ~f:(fun i ->
        Option.bind (T.no_band_because i.T.co_kind) ~f:(fun why ->
            match
              List.filter_map j.J.jn_cases ~f:(fun c ->
                  if Poly.equal (T.coop_of c.J.cs_topology) i.T.co_kind then
                    Some c.J.cs_project
                  else None)
              |> List.dedup_and_sort ~compare:String.compare
            with
            | [] -> None
            | ps ->
                Some
                  (Printf.sprintf "%s (%s) — %s" i.T.co_name (String.concat ~sep:", " ps)
                     why)))
  in
  let data =
    String.substr_replace_all
      (Yojson.Basic.to_string (J.json j))
      ~pattern:"</" ~with_:"<\\/"
  in
  Printf.sprintf
    {|<div class="join" id="join">
%s%s%s%s%s
<div id="jrecbar" hidden><p class="mechnote"><label>recorded world:
<select id="jworld"></select></label></p><p id="jrechead" class="edet"></p></div>
<p class="mechnote" id="jnorec" hidden>No run of this package is recorded on
this machine — <code>canary overview</code> writes what each machine ran to
<code>overview_runs.js</code> beside this page.</p>
%s%s%s%s%s
<p class="mechnote" id="jruns">%s</p>
<p class="mechnote" id="jmiss" hidden></p>%s
<details class="jprov" id="jprov"><summary id="jprovsum">Where the lines under the node labels come from</summary>
<table class="cmp"><thead><tr><th>node</th><th>line</th><th>shown</th><th>source — and the code that read it</th></tr></thead>
<tbody id="jprovbody"></tbody></table>
<p class="mechnote">Every line written under a node label, with where it was read:
<span class="src code">code</span> a declaration or a rule in canary's source;
<span class="src run">run</span> a file a recorded run wrote;
<span class="src render">render</span> asked of the machine rendering this page —
neither, and flagged wherever it appears. Each is computed with its value in
<code>Canary_overview_runs</code> and <code>Canary_overview_join</code>; the
page only looks it up. Only these lines are traced so far; what is not yet —
a recorded run's edge states and badges, the band rules, the script's own
rules and §1.2's cells — is listed in <code>doc/canary/design/overview.md</code> §4.</p></details>
%s
<div id="jrec" hidden>
<div class="key reckey">
%s
</div>
<div id="jrecobserved"></div>
<div id="jrecph"></div>
<div id="jrecclaims"></div>
<div id="jrecunplaced"></div></div>
<script type="application/json" id="joindata">%s</script></div>|}
    (row "native-side PM" (pm_buttons J.Native "ps"))
    (row "language-side PM" (pm_buttons J.Language "pl"))
    (row "binding mechanism" m_buttons)
    (row "cooperation" k_buttons)
    (row "package in canary" c_buttons)
    (diagram ~classes ~case_slots:true ~ph_slots:true
       ~counts:(fun id ->
         (* the default drawing's badges, as the script would count them *)
         let claims =
           Option.value ~default:[]
             (Option.bind
                (List.find (J.variants ()) ~f:(fun v ->
                     String.equal (Canary_mechanism.string_of_mechanism v.T.av_mechanism) m0))
                ~f:(fun v -> List.Assoc.find (J.mechanism_claims v) id ~equal:String.equal))
         in
         let checked = List.count claims ~f:(fun (_, st) -> Poly.equal st T.Checked) in
         (checked, List.length claims - checked))
       ())
    m_notes k_notes pm_notes c_notes runs0
    (match unbanded with
     | [] -> ""
     | us ->
         Printf.sprintf
           {|<p class="mechnote">No cooperation button: %s. Their packages are among the concrete ones, drawn with what canary cannot read left in (§4.3).</p>|}
           (esc (String.concat ~sep:"; " us)))
    (* the layout's rules, as a redraw must keep them *)
    (Printf.sprintf
       {|<details class="jprov" id="jrules"><summary>How this diagram is laid out — %d rules a redraw in any framework must keep</summary><ol class="lrules">%s</ol><p class="mechnote">Each is held against these places by <code>overview.layout_rules_hold</code>, or by the pin it names; the looks are the keys'.</p></details>|}
       (List.length layout_rules)
       (String.concat
          (List.map layout_rules ~f:(fun r ->
               Printf.sprintf "<li><strong>%s</strong> <span class=\"lwhy\">%s</span></li>"
                 (esc r.lr_says) (esc r.lr_why)))))
    (* the recorded run's key, from the vocabulary *)
    (key_html Run_key)
    data

(** §1's script, [canary/overview/page.js]: it keeps the chain chosen,
    looks each answer up in the page's data and the runs files, and
    applies it. *)
let script () = Canary_overview_assets.script "page.js"

(* ── §1.2 THE RESULT TABLE (2026-09-28, design/overview.md §6.4) ─────

   The result matrix joins this page (user: one page; prototype A for its
   columns). A row is a CHAIN — one world in one language, the key §1
   draws — on one machine; the columns are [Canary_frames]'s, the same
   header §2 will use. The page computes nothing: the header is the
   column model, embedded here, and every cell is a word a view in the
   runs files already carries ([Canary_overview_runs]: edge states, node
   names and counts, claim outcomes). The script only lays them out. *)

let layer_word : T.layer -> string = function
  | T.L_pm -> "pm"
  | T.L_package -> "pkg"
  | T.L_artifact -> "art"
  | T.L_program -> "prog"

(** The column model as the table's script reads it: each node's label and
    layer, and each frame's columns — a piece with the layer it makes, a
    check with the layer of its site's product. *)
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
      (* what each blame word on a check cell means, for its tooltip *)
      ( "blames",
        `Assoc (List.map Canary_matrix.blame_gloss ~f:(fun (w, g) -> (w, `String g)))
      ) ]
  |> Yojson.Basic.to_string
  |> String.substr_replace_all ~pattern:"</" ~with_:"<\\/"

let results_section () : string =
  Printf.sprintf
    {|<h3 id="results">1.2 The results, one row per chain</h3>
<p>Every chain canary runs, on each machine that recorded it: a world in one
language, the key §1 draws. The columns are §1's actions as frames — what an
action consumes, the checks on that input, its pieces, what it produces, the
checks on that — by side, then flow (<code>canary checks --frames</code>). An
artifact appears again, in grey, where it is consumed; a frame the chain does
not have is hatched. A row's name draws it in §1, and a drawn run links back to
its row.</p>
<p class="rt-key"><span class="rt-ok">✓</span> ran · <span class="rt-warm">✓</span> warm ·
<span class="rt-bad">✗</span> failed or violated · <span class="rt-xf">xf</span> expected
failure · ⊘ blocked · · not recorded · — not in this run · ⌂ inside a package
manager's action · ∈ included with the language · ~ someone else's relation · <span class="rt-gap">no-evid no-decl
no-ref none</span> a check that could not decide · n/a the mechanism cannot carry
it · <i>italic</i> declared, not recorded</p>
<div class="rt-wrap"><table class="rt" id="rtable"></table></div>
<p class="mechnote" id="rtnone" hidden>No run is recorded on this page yet —
<code>canary overview</code> writes each machine's runs to
<code>overview_runs.js</code> beside it.</p>
<script type="application/json" id="framesdata">%s</script>|}
    (frames_json ())

(** §1.2's stylesheet, [canary/overview/results.css]. *)
let results_css () = Canary_overview_assets.read "results.css"

(** §1.2's script, [canary/overview/results.js]: it lays out the words
    [Canary_overview_runs] computed, under the column model above. *)
let results_script () = Canary_overview_assets.script "results.js"

(** THE RECORDED RUNS' FILES (2026-09-23): one script tag per machine,
    loaded BEFORE the page's script, which draws a package's recorded run
    from them. A missing file is a failed script tag and nothing more. The
    page holds no run state; every recorded word was computed in
    [Canary_overview_runs]. *)
let runs_script () =
  String.concat
    (List.map Canary_overview_runs.all_file_names ~f:(fun f ->
         Printf.sprintf {|<script src="%s"></script>
|} f))

let render (projects : (string * Canary_project_run.project_run) list)
    ~(overview : string) ~(generated_at : string) : string =
  let bare = T.bare_edges () in
  (* §1's choices and §5.4's chains: computed once, one list for both *)
  let join = Canary_overview_join.of_projects projects in
  Printf.sprintf
    {|<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Canary Overview</title>
<style>%s
%s</style></head><body><main>

<h1>How two package ecosystems are joined</h1>
<p class="lede">The chain two package ecosystems form, drawn from canary's
code (§1); what every chain canary runs recorded, laid out on it
(<a href="#results">§1.2</a>); and the agreements that check it (§2). What
a run recorded is read from a separate file per machine, never embedded in
the page.</p>

<div class="note"><strong>A bridge is a thing, not a relation.</strong>
It is concrete, separate package content whose purpose is package-manager
cooperation. It lives in neither the pure native side nor the pure
language side — which is exactly why a binding-level view cannot see it,
and why this page exists. It is also <em>optional</em>: two ecosystems may
cooperate through a bridge, or through nothing but the artifacts, and a
language package that links whatever the system installed is not thereby
broken.</div>

<div class="note"><strong>A capability file is not a bridge.</strong>
A <code>conf-*</code> package carries package <em>identity</em> plus the
depext mapping, and a check. A <code>.pc</code> file carries
<em>capability</em> — a name, a version, cflags, libs — and belongs to the
package that ships it, as a META file belongs to its OCaml package. They
are written by different people and they can disagree, which is why the
file is a source of claims; but what validates the symbolic path against
the artifacts is the bridge's own check, which reads the file. Each
package manager defines its own kinds of bridge. Cargo's
<code>*-sys</code> topology has no bridge and a capability file, which is
what makes it artifact-centric rather than bridgeless.</div>

<h2>1. The generic chain</h2>
<p>Nodes are what exists. An edge points from components to a component
and carries one annotation. Most carry the <strong>action</strong> of ours
that realizes the relation. Where we run nothing, an edge carries
<em>information</em> in italics: whatever does establish the relation — and,
while a package's recorded run is drawn, what that run recorded about it.
One edge carries a
<strong class="clm">claim</strong>, by its code, because a claim of ours
is the only thing relating its two ends. A claim is an agreement: a row of
§2, or a candidate one not yet in the registry. An edge's badges count the
agreements placed on it that apply to the chain drawn — filled for those
canary checks, hollow for those only named so far — so they change with
the mechanism, and in a recorded run the filled one takes the colour of
those agreements' outcomes. An agreement placed on several edges is
counted on each. Hover an edge for what it establishes and which
agreements its badges count.</p>
<p class="mechnote"><strong>Not yet every step.</strong> %s</p>
<div class="key">
%s
</div>

<div class="note"><strong>The artifact band is one binding mechanism.</strong>
As first drawn it was the C-shim shape — headers, a compiled stub, a
language module. A <code>ctypes</code> binding compiles nothing and has
no stub node at all; its library is opened by name at import, so two of
these edges do not merely go quiet, they do not exist. So the whole
diagram is a <em>join</em>: one artifact-layer row (a binding mechanism,
§4.2) with one package-and-PM row (a cooperation, §4.3), between two
package managers (§4.1). No one table draws a chain; together they do.
Pick below: a package manager for each side, a binding mechanism (the
artifact band) and a cooperation (the package band) — or a package in
canary, one of the chains canary runs (§4.4), which picks all four and
writes under each generic label what its project declares the node is.
A mechanism also picks the package manager that ships its language's
bindings, and any button but a package's outlines the package nodes it
is about. A cooperation's band is drawn from the chains that realize it,
narrowed to the chosen package managers, so a node that is absent does
not exist in any of them; a greyed edge exists and does not fire. The
line under the diagram says which projects canary runs the choice for.
The chains are switched rather than stacked: laid end to end, they are
compared by memory, which is the one thing that makes them hard to
compare.</div>
<div class="note"><strong>A package's recorded run is drawn on the same
layout.</strong> Choosing a package also draws the last run of it that a
machine recorded, if one did — the recorded world can be switched where
the package has several. An edge is then coloured by what the steps
realizing it did, a claim badge by the outcomes of the claims placed
there, and a node the run did not touch is dimmed. An edge someone else's
rule establishes is dotted: grey where nothing is recorded, in the accent
colour where the run recorded what that rule said — which is what a bridge
step does: it runs the bridge's own check in its world and records the
mapping, the capability file and pkg-config's answer. A name under a node
is upright where the run recorded it and italic where only the project
declares it, and a third line gives where the run placed the artifact.
What the world's chain does not have at all is not drawn, and a claim
sitting only there does not apply: a bridge's claims apply only where
there is a bridge. The key and what the run recorded are under the
diagram.</div>
%s
<p id="edet" class="edet">hover an edge</p>

<div class="note warn"><strong>One edge runs both ways.</strong>
<code>binding package</code> ↔ <code>language module</code> is an
<em>install</em> when the binding is fetched and a <em>pack</em> when it
is built here. Those are different actions establishing different
relations, and which one applies is a fact about the world, not about the
project. Both are drawn; in any given world exactly one is live.</div>

<div class="note warn"><strong>There are two consumer programs, not
one.</strong> The <em>artifact-linked</em> one is handed the language
module and the native library by path — every input named explicitly. It
answers <em>is the code right</em>. The <em>package-linked</em> one names
only the binding package and lets the package manager resolve the rest.
It answers <em>is the recipe right</em>, which fails differently: an
install can omit a file the consumer needs, a META can be wrong, a conf
chain can fail to resolve, and none of that is visible to the first
probe. <strong>They should be the same program</strong> — that is what
makes the pair informative rather than merely two tests, and the edge
between them is a claim nothing else in this graph can make.
<br><br><strong>The linking lift</strong> is the method that derives the
second from the first: same source, same expected result, only the
resolution changes — from inputs named by path to a package named by
the consumer. It should be universal, computed from the binding
mechanism plus a project's static facts (what the package is called,
what the consumer imports). Where a project must customize it, the
customization comes in two kinds that must not be confused: telling the
lift a <em>name</em> it cannot derive is static information, while
supplying a <em>resolution</em> the package failed to provide — an
environment variable pointing at the native library — is the package
admitting its recipe is insufficient, and is recorded as a finding.</div>

<div class="note"><strong>The declaration is a badge, not a node.</strong>
It used to be drawn as a box, and its position was arbitrary — nothing in
the chain produces it, it takes part in no action, and no tool ever
enforced it. It is the <em>experiment's own statement</em> about one
artifact, so it is now a ◇ on the two nodes that carry one; hover for
what is declared there. Those two account for all four
declaration-facing claims. It also explains why they behave differently:
such a claim cannot fail because two tools disagreed — it fails because
the world differs from what we <em>said</em> it would be, which is a
defect in the spec as often as in the software.</div>

<div class="note warn"><strong>One node the three-layer picture does not
have:</strong> the <em>source</em>, which the layered model carries only
inside its package-rewrite cases, never in the base picture.</div>

<h3>1.1 What each node is</h3>
%s

%s

<h2 id="overview">2. The agreement overview</h2>
<p>Every agreement, where its rule RAN and where it is CHECKED, over the
same frames as §1.2's result table — of which it is the template, so an
empty column there can be looked up here, and ◆ marks the column each
claim fills.</p>
<div class="note warn"><strong>Two of its columns are not
mechanism.</strong> <code>decided</code> and <code>blame</code> are
counted from recorded runs, per agreement, so this section alone depends
on run state — unlike everything else here. Splitting the table at that
seam would have shown one row's halves on two pages, which is worse.</div>
%s

<h2 id="census">3. Where every claim sits, and the edges where none do</h2>
<p>%d claims — %d implemented, %d candidates — placed on the edges of §1.
A <em>claim site</em> is a set of edges rather than one, and %d already
span several: the library's declaration-facing claims sit on both edges
that can produce a library, and <code>package_resolution_suffices</code>
runs end to end from the language PM to the package-linked program.</p>
%s

<div class="note warn"><strong>%d edges carry no claim at all</strong>
(%s). Every one is a relation a real tool establishes and from which we
recover nothing. Most are the package layer and the cooperation between
the two ecosystems; almost everything we have sits on the two edges
where a compiler or a linker ran.</div>

<div class="note"><strong>The network analogy, and where it breaks.</strong>
Two hosts in a network stack implement the <em>same protocol</em> at each
layer, so both a per-layer invariant and an end-to-end invariant have a
stated contract to check against. Here the horizontal relation at the
package layer is a bridge somebody wrote, or nothing — not a protocol,
and not symmetric between the two sides. A bridge may carry identity
while dropping version, which in network terms is a layer that forwards
the address and silently discards the checksum. That asymmetry is why the
end-to-end invariants are the ones we do not have.</div>

<h2 id="tables">4. What canary covers: three tables, and the chains they compose</h2>
<p>A chain is one binding mechanism (§4.2) between two package managers
(two rows of §4.1), joined by their cooperation (§4.3); §4.4 lists the
chains canary runs. Every cell is computed from canary's own code — the
package managers' drivers, the mechanism catalogue, the bridge model, the
cooperation kinds and the projects' declarations — so a table lists only
what canary covers. The layered-model draft's tables were the reference
for the columns; they also cover ecosystems canary does not reach yet
(RPM, Cargo, Cabal, RubyGems, Conda, Nix).</p>
<h3>4.1 Each package manager on its own</h3>
%s
<h3>4.2 Binding mechanisms</h3>
%s
<h3>4.3 How two package managers cooperate</h3>
%s
%s
<h3>4.4 The chains canary runs</h3>
<p>One row per distinct chain among a project's worlds: its binding
language, where each side comes from, and so which cooperation joins
them. A project appears more than once when its worlds differ — a world
that builds its binding does not go through the package gate its project
declares, so a chain is a fact about the world, not the project. These
are §1's packages in canary, and each project links to its chain drawn
there.</p>
%s

<div class="foot">Generated %s. <strong>What is derived and what is not</strong>,
since the page is meant to trade the second for the first over time:
the tables of §4 are computed from canary's code — the package managers'
drivers, the mechanism catalogue, the bridge model, the cooperation kinds
and each project's declared provisions, gates and C-API components —
though their prose columns (what a package is, how a join travels) are
written in <code>canary_pm_solo.ml</code> and
<code>canary_topology.ml</code>; §1's artifact band comes from the
mechanism catalogue, and its package band from the worlds of each
cooperation kind, by one rule per node in <code>canary_topology.ml</code>;
the agreement overview from the registry and recorded runs.
The nodes, the edges and which edge each claim sits on are
<em>hand-written lists</em> in <code>canary_topology.ml</code> —
placeholders, checked by pins against the registry but not yet computed
from the action catalogue — and so are the five cases §1's cooperation
notes quote, which this page used to draw by hand and which the pins
still hold the derivations to. Each edge's annotation is typed, though:
an action family the catalogue has, a registered or candidate claim, or
information; and which of the catalogue's actions have no edge is
computed. The diagram is SVG emitted from that data, with one
hand-placed coordinate per node. A package's recorded run is not in this
page: it is read from <code>overview_runs.js</code> (one per machine),
which <code>canary overview</code> computes from the run record — each
edge's state from the steps placed on it, each badge from its claims'
outcomes, and the edges around a bridge from what a bridge step recorded
(one bridge so far: conf-gmp, on zarith).
· <a href="#results">the results (§1.2)</a></div>
%s</main></body></html>|}
    (css () ^ "\n" ^ results_css ()) (Canary_matrix.overview_css ())
    (* §1 the chain — the missing steps COUNTED from the catalogue, the
       chain chosen from its parts — §1.1 its legend, and §1.2 every
       recorded chain in the result table *)
    (missing_steps_note ()) (key_html Chain_key) (join_panel join) (node_legend ())
    (results_section ())
    (* §2 the agreement overview. The hand-drawn cases that were §2 and
       their recorded copies that were §2.1 went on 2026-09-24 — §1 draws
       every chain and its recorded run; their notes are §1's (user) *)
    overview
    (* §3 the census — the total is COUNTED: it was a literal
       "Twenty-five" and went stale the day a candidate was added *)
    (List.length T.claim_sites)
    (* implemented = the registry's answer, not a flag (2026-09-24) *)
    (List.count T.claim_sites ~f:T.implemented)
    (List.count T.claim_sites ~f:(fun p -> not (T.implemented p)))
    (* counted, like the total above: a literal "Three" was written here
       in the same edit that removed the stale "Twenty-five", and it was
       wrong on arrival — five sites span several edges *)
    (List.count T.claim_sites ~f:(fun p -> List.length p.T.cs_edges > 1))
    (claim_sites_table ()) (List.length bare)
    (esc
       (String.concat ~sep:", " (List.map bare ~f:(fun e -> e.T.eg_id))))
    (* §4 the tables *)
    (pm_solo_table projects) (binding_table projects) (coop_table projects)
    (topology_notes projects) (chains_table join)
    (* the recorded runs' files load BEFORE the scripts that draw them *)
    (esc generated_at) (runs_script () ^ script () ^ results_script ())

let docs_path = "docs/canary/overview.html"

(** THE RESULT PAGES' OLD ADDRESSES (2026-09-28, user: one page, and the
    per-run pages retire — design/overview.md §6.4 step 5). The result
    matrix is §1.2 of this page now, and nothing is copied into
    [docs/canary/projects/] any more; what stays there is a line at each
    address a link may still use — [matrix.html], the macOS copy's
    [matrix_mac.html] and the run index [index.html] — that lands on
    §1.2. Written with the page because they point at it. The same bytes
    on every machine, so, unlike the runs file, a [--platform] render may
    write them. *)
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
