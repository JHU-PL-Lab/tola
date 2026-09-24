(** [Canary_overview_page] — the OVERVIEW page, `canary overview`
    (2026-09-22; renamed from the "model" page 2026-09-23, user).

    A separate page from `matrix.html`, deliberately. That one is a
    RECORD: per project, per scenario, what a run decided. This one is
    GENERAL MECHANISM — what chains can exist, what joins them, where a
    claim could sit — with no project, no version and no verdict on it.
    The multi-PM model's own §14 says not to put verdicts in the
    methodology tables, and a reader scrolling from "what happened here"
    into "what can exist anywhere" without a page break will read the
    second as the first.

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

(* column centres, then per-node y. The artifact band stacks four nodes
   per side; everything else is one node per band per side. *)
let layout : (string * pos) list =
  [ ("pm_sys", { px = 150; py = 62 });
    ("pm_lang", { px = 1070; py = 62 });
    ("pkg_sys", { px = 150; py = 200 });
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
    ("cap", { px = 390; py = 275 });
    ("bridge", { px = 720; py = 200 });
    ("pkg_lang", { px = 1070; py = 200 });
    ("src_sys", { px = 150; py = 392 });
    ("hdr_sys", { px = 150; py = 466 });
    ("lib_sys", { px = 150; py = 550 });
    ("staged_sys", { px = 150; py = 624 });
    ("src_lang", { px = 1070; py = 392 });
    ("stub_lang", { px = 1070; py = 466 });
    ("mod_lang", { px = 1070; py = 550 });
    ("surf_lang", { px = 1070; py = 624 });
    (* the two consumers sit under the side whose resolution they use:
       the artifact-linked one names paths, the package-linked one names
       a package *)
    ("consumer_artifact", { px = 390; py = 762 });
    ("consumer_package", { px = 840; py = 762 }) ]

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

(* ── svg primitives ──────────────────────────────────────────────── *)

let esc (s : string) : string =
  String.concat_map s ~f:(function
    | '&' -> "&amp;"
    | '<' -> "&lt;"
    | '>' -> "&gt;"
    | '"' -> "&quot;"
    | c -> String.of_char c)

let band ~y ~h ~label ~cls =
  Printf.sprintf
    {|<rect class="band %s" x="8" y="%d" width="%d" height="%d" rx="10"/>
<text class="bandlabel" x="20" y="%d">%s</text>|}
    cls y (canvas_w - 16) h (y + 20) (esc label)

(** Nodes are drawn AFTER edges so the boxes mask the lines that run
    under them — which is what lets every edge be a straight centre-to-
    centre segment instead of a routed path. *)
let node_svg ?(extra = "") ?(case_slot = false) ~(live : bool) ~(label : string)
    ~(sub : string option) (n : T.node) =
  let p = pos_of n.T.nd_id in
  let x = p.px - (box_w / 2) and y = p.py - (box_h / 2) in
  let decl = T.declaration_at n.T.nd_id in
  let cls =
    Printf.sprintf "node %s%s%s%s"
      (T.string_of_layer n.T.nd_layer)
      (if live then "" else " dim")
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
          (x + box_w - 10) (y + 10) (x + box_w - 10) (y + 14)
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
      cls (esc n.T.nd_id) (esc n.T.nd_gloss) x y box_w box_h p.px
      (if Option.is_some sub then p.py - 2 else p.py + 5)
      (if case_slot then
         Printf.sprintf {| data-y0="%d" data-y1="%d" data-y2="%d"|} (p.py + 5) (p.py - 2)
           (p.py - 7)
       else "")
      (esc label) badge
  in
  let subline =
    match sub with
    | None -> ""
    | Some s ->
        Printf.sprintf {|<text class="nsub" x="%d" y="%d">%s</text>|} p.px
          (p.py + 14) (esc s)
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
  main ^ subline ^ slot ^ "</g>"

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
   node to show not-implemented yet"). An edge whose claims are ALL
   candidates — named, with no evaluator — gets a hollow, dashed badge,
   so a claim that is known and not implemented no longer looks like one
   that runs. *)
(* A PLACEHOLDER SLOT (2026-09-23): on the recorded template only, every
   edge carries a hidden marker the overlay shows where a placeholder step
   stands — a package manager did something there, inside one of our
   actions, that the run does not record. Left of the midpoint, so it
   never sits on the claim badge. *)
let edge_svg ?(extra = "") ~(live : bool) ~(claims : int) ?(candidate_only = false)
    ?(ph_slot = false) (e : T.edge) =
  let dst = pos_of e.eg_to in
  let cls =
    Printf.sprintf "edge%s%s%s%s"
      (if e.T.eg_diagonal then " diag" else "")
      (if live then "" else " dim")
      (if claims = 0 then " bare" else "")
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
           let mx = (src.px + dst.px) / 2 and my = (src.py + dst.py) / 2 in
           let badge =
             if claims = 0 then ""
             else
               let cand = if candidate_only then " cand" else "" in
               Printf.sprintf
                 {|<circle class="cbadge%s" cx="%d" cy="%d" r="9"/><text class="cnum%s" x="%d" y="%d">%d</text>|}
                 cand (mx + 46) my cand (mx + 46) (my + 4) claims
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

(** THE one layout. [rename] substitutes a concrete label for a node,
    [dead] greys an edge that this case does not have, and [classes] adds
    classes to an element by id — the join's handle, which draws every
    element once and lets the stylesheet hide it. *)
let diagram ?(rename = fun (_ : string) -> None)
    ?(sublabel = fun (_ : string) -> None) ?(dead = fun (_ : string) -> false)
    ?(hide = fun (_ : string) -> false) ?(ph_slots = false) ?(case_slots = false)
    ?(classes = fun (_ : string) -> ([] : string list)) () : string =
  let extra id = String.concat (List.map (classes id) ~f:(fun c -> " " ^ c)) in
  let bands =
    String.concat
      [ band ~y:30 ~h:70 ~label:"PM LAYER — who resolves and installs"
          ~cls:"pm";
        band ~y:140 ~h:170
          ~label:"PACKAGE LAYER — symbolic claims, and the bridge between them"
          ~cls:"package";
        band ~y:350 ~h:320
          ~label:"ARTIFACT LAYER — what is actually on disk" ~cls:"artifact";
        band ~y:710 ~h:74 ~label:"PROGRAM — the only band where anything runs"
          ~cls:"program" ]
  in
  (* AN EDGE GOES WHEN EITHER END GOES. Hiding only the node left the
     concrete cases drawing every edge to a fallback coordinate — the
     wheel case hid nine nodes and still drew twenty-two segments, most
     of them converging on a point where nothing was. A hidden endpoint
     is not a styling choice; the relation does not exist in that case. *)
  let gone id = hide id in
  let es =
    String.concat
      (List.map T.edges ~f:(fun e ->
           if
             hide e.T.eg_id || gone e.T.eg_to
             || List.exists e.T.eg_from ~f:gone
           then ""
           else
             let sites = T.claim_sites_on e.T.eg_id in
             edge_svg ~extra:(extra e.T.eg_id) ~live:(not (dead e.T.eg_id))
               ~claims:(List.length sites)
               ~candidate_only:
                 ((not (List.is_empty sites))
                 && List.for_all sites ~f:(fun p -> not p.T.cs_implemented))
               ~ph_slot:ph_slots e))
  in
  let ns =
    String.concat
      (List.map T.nodes ~f:(fun n ->
           if hide n.T.nd_id then ""
           else
             let label =
               match rename n.T.nd_id with
               | Some l -> l
               | None -> n.T.nd_label
             in
             node_svg ~extra:(extra n.T.nd_id) ~case_slot:case_slots ~live:true ~label
               ~sub:(sublabel n.T.nd_id) n))
  in
  Printf.sprintf
    {|<svg viewBox="0 0 %d %d" class="diagram" role="img">
<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7"
 markerHeight="7" orient="auto-start-reverse">
<path d="M 0 0 L 10 5 L 0 10 z"/></marker></defs>
%s%s%s</svg>|}
    canvas_w canvas_h bands es ns

(* ── the page ─────────────────────────────────────────────────────── *)

let css =
  {|:root{--bg:#fbfaf8;--fg:#1d1c1a;--mut:#6a665f;--line:#d9d4cb;
--pm:#e8eef6;--pkg:#f3ecdf;--art:#e9f1e9;--prog:#f6e8e8;--warn:#b4451f;
--card:#fff;--acc:#2b5f8a;--ok:#2f7d3a;--bad:#c0262d;--xf:#b07a12}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
--bg:#161514;--fg:#eceae6;--mut:#a09a91;--line:#35322e;
--pm:#1d2530;--pkg:#2a2519;--art:#1a241b;--prog:#2b1d1d;--card:#1f1e1c;
--acc:#7fb0dc;--warn:#e0805a;--ok:#7cc488;--bad:#f07f84;--xf:#e8bf5c}}
:root[data-theme="dark"]{--bg:#161514;--fg:#eceae6;--mut:#a09a91;--line:#35322e;
--pm:#1d2530;--pkg:#2a2519;--art:#1a241b;--prog:#2b1d1d;--card:#1f1e1c;
--acc:#7fb0dc;--warn:#e0805a;--ok:#7cc488;--bad:#f07f84;--xf:#e8bf5c}
*{box-sizing:border-box}
body{background:var(--bg);color:var(--fg);margin:0;padding:0 16px 80px;
font:15px/1.6 ui-serif,Georgia,serif;-webkit-text-size-adjust:100%}
main{max-width:1180px;margin:0 auto}
h1{font-size:1.75rem;line-height:1.25;margin:2rem 0 .4rem}
h2{font-size:1.25rem;margin:2.6rem 0 .6rem;padding-top:.8rem;
border-top:1px solid var(--line)}
h3{font-size:1.02rem;margin:1.6rem 0 .4rem}
p,li{max-width:74ch}
code,.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.88em}
.lede{color:var(--mut);font-size:1.02rem}
.note{border-left:3px solid var(--acc);padding:.5rem 0 .5rem .9rem;
margin:1.1rem 0;background:var(--card)}
.warn{border-left-color:var(--warn)}
.warn strong{color:var(--warn)}
table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.9rem}
th,td{border:1px solid var(--line);padding:.4rem .55rem;text-align:left;
vertical-align:top}
th{background:var(--card);font-weight:600}
td.n{color:var(--mut)}
.diagram{width:100%;height:auto;margin:1rem 0;background:var(--card);
border:1px solid var(--line);border-radius:10px}
.band{fill:var(--card);stroke:var(--line);stroke-width:1}
.band.pm{fill:var(--pm)}.band.package{fill:var(--pkg)}
.band.artifact{fill:var(--art)}.band.program{fill:var(--prog)}
.bandlabel{font:600 12px ui-monospace,monospace;fill:var(--mut)}
.node rect{fill:var(--card);stroke:var(--fg);stroke-width:1.3}
.node.oracle rect{stroke-dasharray:5 3;stroke:var(--acc)}
.node .nlabel{font:600 13px ui-sans-serif,system-ui,sans-serif;
fill:var(--fg);text-anchor:middle}
.node .nsub{font:11px ui-monospace,monospace;fill:var(--mut);
text-anchor:middle}
.node.dim{opacity:.32}
.edge line{stroke:var(--fg);stroke-width:1.4;opacity:.72}
.edge.diag line{stroke-dasharray:6 4;stroke:var(--acc);stroke-width:1.6}
.edge.bare line{stroke:var(--warn);stroke-width:2;opacity:.95}
.edge path{fill:none;stroke:var(--fg);stroke-width:1.4;opacity:.72}
.edge .elabel{font:11px ui-monospace,monospace;fill:var(--mut);
text-anchor:middle}
.edge.bare .elabel{fill:var(--warn);font-weight:700}
.edge .elabel.info{font-style:italic}
.edge .elabel.claim{fill:var(--acc);font-weight:700}
.clm{color:var(--acc)}
.rec .edge line,.rec .edge path{stroke-dasharray:none}
.rec .edge.st-ran line,.rec .edge.st-ran path{stroke:var(--ok);stroke-width:2.6;opacity:1}
.rec .edge.st-warm line,.rec .edge.st-warm path{stroke:var(--ok);stroke-width:2.6;
opacity:.9;stroke-dasharray:7 3}
.rec .edge.st-xfail line,.rec .edge.st-xfail path{stroke:var(--xf);stroke-width:2.6;opacity:1}
.rec .edge.st-fail line,.rec .edge.st-fail path{stroke:var(--bad);stroke-width:3.2;opacity:1}
.rec .edge.st-blocked line,.rec .edge.st-blocked path{stroke:var(--bad);stroke-width:2.4;
opacity:1;stroke-dasharray:5 3}
.rec .edge.st-unrecorded line,.rec .edge.st-unrecorded path{stroke:var(--mut);
stroke-width:2;opacity:1;stroke-dasharray:1 4}
.rec .edge.st-absent{opacity:.14}
.rec .edge.st-not_ours{opacity:.5}
.rec .edge.st-not_ours line{stroke:var(--mut);stroke-width:1.4;stroke-dasharray:2 5}
.rec .edge.st-observed line{stroke:var(--acc);stroke-width:2;stroke-dasharray:2 3;opacity:1}
.rec .edge.st-inside line,.rec .edge.st-inside path{stroke:var(--mut);stroke-width:1.8;
stroke-dasharray:1 4;opacity:.9}
.phm{display:none}.phm.on{display:inline}
.phm rect{fill:var(--card);stroke:var(--mut);stroke-width:1.4;stroke-dasharray:2 2}
.phm text{font:700 11px ui-monospace,monospace;fill:var(--mut);text-anchor:middle}
.phm.not_yet rect{stroke:var(--acc)}.phm.not_yet text{fill:var(--acc)}
.rec .edge.st-claim line{stroke:var(--acc);stroke-width:1.6;stroke-dasharray:4 4}
.rec .edge.cl-violated .cbadge{fill:var(--bad)}
.rec .edge.cl-holds .cbadge{fill:var(--ok)}
.rec .edge.cl-partial .cbadge{fill:var(--xf)}
.rec .edge.cl-undecided .cbadge,.rec .edge.cl-unevaluated .cbadge{fill:var(--mut)}
.rec .node .nsub{fill:var(--fg)}
.rec .gone{display:none}
.rec .node.named-decl .nlabel{font-style:italic}
table.cmp{font-size:.85rem;max-width:780px}
.widetable{overflow-x:auto;max-width:100%}
table.cov{font-size:.82rem;min-width:900px}
table.cov td{vertical-align:top}
table.cmp tr.agree td{color:var(--mut)}
table.cmp tr.differ td{background:color-mix(in srgb,var(--xf) 14%,transparent)}
table.cmp .from{font:11px ui-monospace,monospace;color:var(--mut)}
.sw.ok{border-top:3px solid var(--ok)}.sw.okw{border-top:3px dashed var(--ok)}
.sw.xf{border-top:3px solid var(--xf)}.sw.bad{border-top:3px solid var(--bad)}
.sw.un{border-top:2px dotted var(--mut)}.sw.ab{border-top:2px solid var(--line)}
.sw.no{border-top:2px dashed var(--mut);opacity:.6}
.sw.ob{border-top:2px dotted var(--acc)}
.o-violated{color:var(--bad);font-weight:700}.o-holds{color:var(--ok)}
.o-undecided,.o-unevaluated{color:var(--mut)}
select{font:13px ui-sans-serif,system-ui,sans-serif;max-width:100%;
padding:.3rem .4rem;border:1px solid var(--line);border-radius:6px;
background:var(--card);color:var(--fg)}
.selbar button:disabled{opacity:.45;cursor:not-allowed}
ul.unpl{margin:.2rem 0 0;padding-left:1.2rem;font-size:.88rem;color:var(--mut)}
.edge.dim{opacity:.18}
.cbadge{fill:var(--acc);opacity:.9}
.node.declared rect{stroke-dasharray:none}
.declmark circle{fill:var(--card);stroke:var(--acc);stroke-width:1.4}
.declmark text{font:11px ui-sans-serif,sans-serif;fill:var(--acc);
text-anchor:middle}
.cnum{font:700 11px ui-sans-serif,sans-serif;fill:#fff;text-anchor:middle}
.cbadge.cand{fill:var(--card);stroke:var(--acc);stroke-width:1.6;stroke-dasharray:3 2;opacity:1}
.cnum.cand{fill:var(--acc)}
.key{display:flex;flex-wrap:wrap;gap:1.1rem;font-size:.85rem;
color:var(--mut);margin:.4rem 0 1.4rem}
.key span{display:flex;align-items:center;gap:.4rem}
.sw{width:26px;height:0;border-top:2px solid var(--fg);display:inline-block}
.sw.d{border-top:2px dashed var(--acc)}
.sw.b{border-top:3px solid var(--warn)}
.foot{color:var(--mut);font-size:.84rem;margin-top:3rem;
border-top:1px solid var(--line);padding-top:1rem}
a{color:var(--acc)}
.selbar{display:flex;flex-wrap:wrap;gap:.5rem;margin:1rem 0 .3rem}
.selbar button{font:600 13px ui-sans-serif,system-ui,sans-serif;
padding:.42rem .8rem;border:1px solid var(--line);border-radius:999px;
background:var(--card);color:var(--fg);cursor:pointer}
.selbar button.on{background:var(--acc);color:#fff;border-color:var(--acc)}
.selbar button:hover{border-color:var(--acc)}
.selbar .bl{opacity:.65;font-weight:400;font-size:.85em}
.selbar .barlabel{font:600 11px ui-monospace,monospace;color:var(--mut);
align-self:center;min-width:12.5em;text-transform:uppercase;letter-spacing:.04em}
.join .jrow{margin:.3rem 0;align-items:center}
.join .gone{display:none}
.join .edge.jdead{opacity:.18}
.join .node .ncase{font:italic 11.5px ui-monospace,SFMono-Regular,Menlo,monospace;
fill:var(--acc);text-anchor:middle}
.join .node .ncase.rec-name{font-style:normal}
.join .node .ncase.term{fill:var(--mut)}
.join .node .nplace{font:10px ui-monospace,SFMono-Regular,Menlo,monospace;
fill:var(--mut);text-anchor:middle}
.join .node.related rect{stroke:var(--acc);stroke-width:3}
.nm-rec{font:12px ui-monospace,monospace;color:var(--acc)}
.nm-decl{font:italic 12px ui-monospace,monospace;color:var(--acc)}
.cgroup{display:inline-flex;flex-wrap:wrap;gap:.3rem;align-items:center;margin-right:.55rem}
.cproj{font:600 12px ui-sans-serif,system-ui,sans-serif;color:var(--mut)}
.cgroup button{font-size:12px;padding:.24rem .55rem}
.selbar button.hint{border:2px dashed var(--acc)}
section.case>p{color:var(--mut);font-size:.92rem;margin:.4rem 0 0}
.mechnote{color:var(--mut);font-size:.9rem;margin:.3rem 0 0}
.edet{font:12px ui-monospace,monospace;color:var(--mut);min-height:2.4em;
margin:.2rem 0 1.4rem;padding:.45rem .6rem;border:1px dashed var(--line);
border-radius:6px;background:var(--card)}
.edet.lit{border-style:solid;border-color:var(--acc);color:var(--fg)}
#rechead{white-space:pre-line}
svg .edge{cursor:default}
svg .edge:hover line,svg .edge:hover path{stroke-width:3;opacity:1}
tr.bare td{background:color-mix(in srgb,var(--warn) 9%,transparent)}
@media(max-width:700px){body{font-size:14px}h1{font-size:1.4rem}
table{font-size:.8rem}}|}

let claim_sites_table () =
  let row (e : T.edge) =
    let ps = T.claim_sites_on e.T.eg_id in
    let impl = List.count ps ~f:(fun p -> p.T.cs_implemented) in
    let cand = List.length ps - impl in
    let names =
      if List.is_empty ps then
        "<em>nothing — this relation is recovered by no claim</em>"
      else
        String.concat ~sep:", "
          (List.map ps ~f:(fun p ->
               Printf.sprintf "<code>%s</code>%s" (esc p.T.cs_claim)
                 (if p.T.cs_implemented then "" else "<sup>?</sup>")))
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
     runs</th><th>impl / cand</th><th>claims</th></tr></thead><tbody>%s</tbody></table>"
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
<div id="jrec" hidden>
<div class="key reckey">
<span><i class="sw ok"></i> ran</span>
<span><i class="sw okw"></i> warm — an earlier run's verdict</span>
<span><i class="sw xf"></i> expected failure confirmed</span>
<span><i class="sw bad"></i> failed (dashed: blocked)</span>
<span><i class="sw un"></i> in the chain, never logged</span>
<span><i class="sw ab"></i> not realized in this world</span>
<span><i class="sw no"></i> someone else's rule — nothing recorded</span>
<span><i class="sw ob"></i> someone else's rule — recorded by this run</span>
<span><i class="sw un"></i> happened inside a package manager's action — unseen</span>
<span><svg width="26" height="18" viewBox="0 0 26 18"><g class="phm on not_yet"><rect x="2" y="1" width="22" height="16" rx="3"/><text x="13" y="13">…</text></g></svg>
a placeholder — not recorded yet (grey: out of reach)</span>
<span><span class="nm-rec">name</span> recorded by the run · <span class="nm-decl">name</span> declared by the project</span>
<span>a dimmed node: in the chain, and nothing in this run touched it</span>
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
    (diagram ~classes ~case_slots:true ~ph_slots:true ())
    m_notes k_notes pm_notes c_notes runs0
    (match unbanded with
     | [] -> ""
     | us ->
         Printf.sprintf
           {|<p class="mechnote">No cooperation button: %s. Their packages are among the concrete ones, drawn with what canary cannot read left in (§4.3).</p>|}
           (esc (String.concat ~sep:"; " us)))
    data

let script =
  {|<script>
(function(){
// THE CHAIN, CHOSEN (§1). Five choices — the two package managers, the
// mechanism, the cooperation — or a package in canary, which sets the
// other four, names the nodes, and draws its recorded run where a machine
// recorded one. Every set a choice draws is in #joindata
// (canary_overview_join.ml), every recorded word in the per-machine
// overview_runs.js (canary_overview_runs.ml); this keeps the state, looks
// them up and applies them.
var jbox=document.getElementById('join'), J=null;
try{ J=JSON.parse(document.getElementById('joindata').textContent); }catch(e){}
if(jbox&&J){
  var S={m:J.default.m, k:J.default.k, ps:null, pl:J.default.pl, c:null, v:null, hl:null};
  var jesc=function(s){ var d=document.createElement('span'); d.textContent=s; return d.innerHTML; };
  var caseOf=function(id){
    for(var i=0;i<J.cases.length;i++) if(J.cases[i].id===id) return J.cases[i];
    return null; };
  // every machine's recorded worlds, by the package each realizes
  var VIEWS={}, BYCASE={};
  (window.CANARY_RUNS||[]).forEach(function(r){
    (r.views||[]).forEach(function(w){
      w.key=w.id+'@'+r.machine; w.machine=r.machine; VIEWS[w.key]=w;
      (BYCASE[w['case']]=BYCASE[w['case']]||[]).push(w); }); });
  var STATES=['ran','warm','xfail','fail','blocked','unrecorded','absent','inside','not_ours','observed','claim'],
      OUTS=['violated','holds','partial','undecided','unevaluated'];
  // a line longer than its box is squeezed to fit rather than cut: every
  // character stays readable on hover-zoom, and none spills onto an edge
  var fit=function(t, w){ if(!t) return;
    t.removeAttribute('textLength'); t.removeAttribute('lengthAdjust');
    try{ if(t.textContent&&t.getComputedTextLength()>w){
      t.setAttribute('textLength', w); t.setAttribute('lengthAdjust','spacingAndGlyphs'); } }catch(e){} };
  var list=function(id, head, items){ var el=document.getElementById(id); if(!el) return;
    el.innerHTML=items.length?'<p class="mechnote"><strong>'+head+'</strong></p><ul class="unpl">'
      +items.join('')+'</ul>':''; };
  var key=function(){ return S.k+'|'+(S.ps||'*')+'|'+(S.pl||'*'); };
  // the band for the choice — or, where no chain has it, the nearest one
  // some chain has: the native side's package manager is let go first,
  // then the language side's; [drop] names what was let go
  var nearest=function(){
    var tries=[[S.ps,S.pl],[null,S.pl],[S.ps,null],[null,null]];
    for(var i=0;i<tries.length;i++){
      var ps=tries[i][0], pl=tries[i][1], b=J.bands[S.k+'|'+(ps||'*')+'|'+(pl||'*')];
      if(b) return {band:b, drop:[S.ps&&!ps?S.ps:null, S.pl&&!pl?S.pl:null].filter(Boolean),
                    kept:[ps,pl].filter(Boolean)};
    }
    return {band:null, drop:[], kept:[]};
  };
  var draw=function(){
    var c=S.c&&caseOf(S.c), v=c&&S.v?VIEWS[S.v]:null, near=c?null:nearest(),
        band=c||(near&&near.band)||{gone:[],dead:[]},
        gone=v?(v.gone||[]):((J.mechanisms[S.m]||{}).gone||[]).concat(band.gone||[]),
        dead=v?[]:(band.dead||[]), names={},
        related=(!c&&S.hl&&J.related[S.hl])||[];
    // a package names every node its project declares; a package manager
    // chosen alone names its own node; a recorded run's own names win, and
    // say they are recorded
    if(c) names=c.names; else { if(S.ps) names.pm_sys=S.ps; if(S.pl) names.pm_lang=S.pl; }
    var named=function(id){
      if(v&&v.names&&v.names[id]) return v.names[id];
      return names[id]?{label:names[id], from:'declared'}:null; };
    // THE PACKAGE MANAGERS' TERMS for the package layer's two in-between
    // nodes, wherever no name is known: the capability file the native
    // side's package manager ships (§4.1), and the kinds of bridge the
    // chains join through (§4.3) — or, where no chain has the choice,
    // those the language side's package manager defines
    var terms={}, pt=J.pm_terms[(c?c.ps:S.ps)||J.sys_pm],
        br=c?(c.bridge||[]):((near&&near.band&&near.band.bridge)||[]);
    if(pt&&pt.cap) terms.cap=pt.cap;
    if(!br.length&&!c&&S.pl&&J.pm_terms[S.pl]) br=J.pm_terms[S.pl].bridges||[];
    if(br.length) terms.bridge=br.join(' · ');
    jbox.classList.toggle('rec', !!v);
    jbox.querySelectorAll('[data-edge]').forEach(function(g){
      var e=g.getAttribute('data-edge'), t=g.querySelector('title'), mk=g.querySelector('.phm');
      g.classList.toggle('gone', gone.indexOf(e)>=0);
      g.classList.toggle('jdead', dead.indexOf(e)>=0);
      STATES.forEach(function(s){ g.classList.remove('st-'+s); });
      OUTS.forEach(function(o){ g.classList.remove('cl-'+o); });
      if(t&&g.dataset.gtitle===undefined) g.dataset.gtitle=t.textContent;
      var obs=v&&(v.observed||{})[e], ph=v&&(v.placeholders||{})[e];
      if(v){ g.classList.add('st-'+(v.edges[e]||'absent'));
        if(v.badges[e]) g.classList.add('cl-'+v.badges[e]); }
      // the edge's own description, plus what this run recorded there
      if(t) t.textContent=g.dataset.gtitle+(obs?' — recorded here: '+obs:'');
      // the placeholder marker: where a package manager did something
      // inside our action that this run does not record
      if(mk){ mk.classList.toggle('on', !!ph);
        mk.classList.toggle('not_yet', !!ph && ph.some(function(x){ return x.unseen==='not_yet'; }));
        var mt=mk.querySelector('title');
        if(mt) mt.textContent=ph?ph.map(function(x){ return x.text; }).join('\n'):''; } });
    jbox.querySelectorAll('[data-node]').forEach(function(g){
      var id=g.getAttribute('data-node'), l=g.querySelector('.nlabel'),
          s=g.querySelector('.ncase'), pe=g.querySelector('.nplace'), n=named(id),
          term=n?'':(terms[id]||''), line=n?n.label:term,
          place=v&&v.nodes?(v.nodes[id]||''):'';
      g.classList.toggle('gone', gone.indexOf(id)>=0);
      g.classList.toggle('dim', !!v && (v.dim||[]).indexOf(id)>=0);
      // the package nodes the last clicked button is about
      g.classList.toggle('related', related.indexOf(id)>=0);
      if(s){ s.textContent=line;
        s.classList.toggle('rec-name', !!n && n.from==='recorded');
        s.classList.toggle('term', !!term);
        s.setAttribute('y', place?s.dataset.y2:s.dataset.y1); }
      if(pe) pe.textContent=place;
      fit(s, 196); fit(pe, 196);
      if(l&&l.dataset.y0) l.setAttribute('y', place?l.dataset.y2:(line?l.dataset.y1:l.dataset.y0)); });
    var ids=J.runs[S.m+'|'+key()]||[];
    jbox.querySelectorAll('button[data-g]').forEach(function(b){
      var g=b.dataset.g, val=b.dataset.v;
      b.classList.toggle('on', g==='c' ? S.c===val : S[g]===val);
      // the packages the choice picks out, while none is chosen
      if(g==='c') b.classList.toggle('hint', !c && ids.indexOf(val)>=0); });
    // a cooperation says what it is whether or not a package is chosen;
    // its band's note only while none is
    jbox.querySelectorAll('.jnote').forEach(function(p){
      var d=p.dataset;
      p.hidden=!((d.jm&&d.jm===S.m)||(d.jk&&d.jk===S.k)||(d.jkb&&!c&&d.jkb===S.k)
                ||(d.jc&&d.jc===S.c)||(d.jpm&&(d.jpm===S.ps||d.jpm===S.pl))); });
    // how many chains the cooperation's band was drawn from, as narrowed
    if(!c&&band.n) jbox.querySelectorAll('.jcount').forEach(function(x){ x.textContent=band.n; });
    var runs=document.getElementById('jruns'), miss=document.getElementById('jmiss');
    if(runs){
      var seen={}, who=[];
      ids.forEach(function(id){ var x=caseOf(id), w=x?x.project+' ('+x.lang+')':id;
        if(!seen[w]){ seen[w]=1; who.push(w); } });
      runs.innerHTML=who.length?'<strong>Canary runs this chain:</strong> '+jesc(who.sort().join(', '))+' (§4.4).'
        :'No chain canary runs has this choice.'; }
    if(miss){
      var k=J.kinds[S.k]||{}, why='';
      if(!c&&k.unbanded) why='⚠ '+jesc(k.label||S.k)+' has no band of its own: '+jesc(k.unbanded)+'.';
      else if(!c&&near&&near.drop.length)
        why='Canary runs no '+jesc(k.label||S.k)+' chain with '+jesc(near.drop.join(' or '))
          +' — the band is drawn from its chains'
          +(near.kept.length?' with '+jesc(near.kept.join(' and ')):'')+'.';
      miss.innerHTML=why; miss.hidden=!why; }
    // THE RECORDED RUN (merged from the retired §2.1): which world is
    // drawn, and everything it recorded or could not
    var worlds=c?(BYCASE[c.id]||[]):[], bar=document.getElementById('jrecbar'),
        sel=document.getElementById('jworld'), norec=document.getElementById('jnorec'),
        recd=document.getElementById('jrec');
    if(bar) bar.hidden=!v;
    if(recd) recd.hidden=!v;
    if(norec) norec.hidden=!(c&&!worlds.length);
    if(sel){ sel.innerHTML='';
      worlds.forEach(function(w){ var o=document.createElement('option'); o.value=w.key;
        o.textContent=w.scenario+' ('+w.machine+')'; o.selected=(w.key===S.v); sel.appendChild(o); }); }
    if(!v) return;
    var head=document.getElementById('jrechead');
    if(head) head.textContent=v.project+' — '+v.lang+' — '+v.scenario+' — recorded on '
      +(v.recorded_on.length?v.recorded_on.join(', '):'(no platform logged)')
      +(v.span?' — '+v.span[0]+' … '+v.span[1]:' — nothing recorded yet')
      +(v.chain?'\nchain: '+v.chain.mechanism+' · '+v.chain.lang_side+' ↔ '
        +v.chain.native_side+' · '+v.chain.character:'');
    var ob=v.observed||{};
    list('jrecobserved','What this run recorded around the bridge:',
      Object.keys(ob).map(function(e){ return '<li><code>'+jesc(e)+'</code> — '+jesc(ob[e])+'</li>'; }));
    var phs=v.placeholders||{}, byText={}, order=[];
    Object.keys(phs).forEach(function(e){ phs[e].forEach(function(x){
      if(!byText[x.text]){ byText[x.text]={unseen:x.unseen, edges:[]}; order.push(x.text); }
      byText[x.text].edges.push(e); }); });
    list('jrecph','What the package managers did here that this run does not record:',
      order.map(function(tx){ var p=byText[tx];
        return '<li><b>'+(p.unseen==='not_yet'?'not recorded yet':'out of reach')+'</b> — '
          +jesc(tx)+' <span class="from">('+p.edges.map(function(e){ return '<code>'+jesc(e)+'</code>'; }).join(', ')
          +')</span></li>'; }));
    var cl=Object.keys(v.claims||{}), cand=v.candidates||[], ce=document.getElementById('jrecclaims');
    if(ce) ce.innerHTML=(cl.length
      ?'<p class="mechnote"><strong>Claims the graph places, in this world:</strong> '
        +cl.map(function(x){ return '<code>'+jesc(x)+'</code> <span class="o-'+v.claims[x]+'">'
          +jesc(v.claims[x])+'</span>'; }).join(' · ')+'</p>':'')
      // a placeholder claim applies only where its edge exists in this chain
      +(cand.length?'<p class="mechnote"><strong>Placeholder claims that apply to this chain</strong> — named, no evaluator: '
        +cand.map(function(x){ return '<code>'+jesc(x)+'</code>'; }).join(' · ')+'</p>':'');
    var up=Object.keys(v.unplaced||{});
    list('jrecunplaced','Steps of this world with no edge on the page:',
      up.map(function(tg){ return '<li><code>'+jesc(tg)+'</code> — '+jesc(v.unplaced[tg])+'</li>'; }));
  };
  var pick=function(g,val){
    if(g==='m'){ S.m=val; var d=(J.mechanisms[val]||{}).pms||[]; if(d.length===1) S.pl=d[0]; }
    else if(g==='ps'){ S.ps=(S.ps===val?null:val); }
    else if(g==='pl'){ S.pl=(S.pl===val?null:val); }
    else if(g==='k'){ S.k=val; S.c=null; }
    else if(g==='c'){ var x=caseOf(val); if(x){ S.c=val; S.m=x.m; S.k=x.k; S.ps=x.ps; S.pl=x.pl;
      var ws=BYCASE[val]||[]; S.v=ws.length?ws[0].key:null; } }
    // the package nodes a non-package button is about; a package names
    // its own nodes instead, and a package manager clicked off lights none
    S.hl=(g==='c'||(g==='ps'&&!S.ps)||(g==='pl'&&!S.pl))?null:g+'|'+val;
    // a package stays chosen only while every choice agrees with it
    var c=S.c&&caseOf(S.c);
    if(c&&(c.m!==S.m||c.k!==S.k||c.ps!==S.ps||c.pl!==S.pl)) S.c=null;
    if(!S.c) S.v=null;
    draw();
  };
  jbox.addEventListener('click',function(e){
    var b=e.target.closest('button[data-g]'); if(b) pick(b.dataset.g,b.dataset.v); });
  var wsel=document.getElementById('jworld');
  if(wsel) wsel.addEventListener('change',function(){ S.v=wsel.value; draw(); });
  // #chain=<id> — §4.4's rows link here; #rec=<world> — one recorded world
  var h=/#chain=([^&]+)/.exec(location.hash), r=/#rec=([^&]+)/.exec(location.hash),
      want=h?decodeURIComponent(h[1]):null, world=r?decodeURIComponent(r[1]):null;
  var go=function(id,w){ if(caseOf(id)){ pick('c',id); if(w&&VIEWS[w]){ S.v=w; draw(); }
    jbox.scrollIntoView(); } };
  if(world&&VIEWS[world]) go(VIEWS[world]['case'],world);
  else if(want&&caseOf(want)) go(want);
  else draw();
  document.querySelectorAll('a[href^="#chain="]').forEach(function(a){
    a.addEventListener('click',function(e){ e.preventDefault();
      go(decodeURIComponent(a.getAttribute('href').slice(7))); }); });
}
// hovering an edge fills the detail strip. The SVG <title> is still
// there for keyboard and for people who hover slowly, but a strip that
// stays put is readable while comparing two edges.
var strip=document.getElementById('edet');
if(strip){
  document.querySelectorAll('svg .edge').forEach(function(g){
    g.addEventListener('mouseenter',function(){
      var t=g.querySelector('title');
      strip.textContent = t ? t.textContent : '';
      strip.classList.add('lit');
    });
    g.addEventListener('mouseleave',function(){ strip.classList.remove('lit'); });
  });
}
})();
</script>|}

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
<p class="lede">General mechanism — no project, no version, no verdict in
the page itself. What ran and what it decided is the
<a href="projects/matrix.html">result matrix</a>; this page is what
<em>can</em> exist, which is a different question. The one exception is a
package's recorded run, which §1 draws when you choose that package, from
a separate per-machine file.</p>

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
is the only thing relating its two ends. The badge on an edge counts the
claims that sit there. Hover an edge for what it establishes.</p>
<p class="mechnote"><strong>Not yet every step.</strong> %s</p>
<div class="key">
<span><code>fetch_lib</code> our action · <em>pkg-config</em> someone
else's · <b class="clm">prs</b> a claim</span>
<span><i class="sw"></i> within a layer, or down one</span>
<span><i class="sw d"></i> diagonal — crosses layers (discovery)</span>
<span><i class="sw b"></i> no claim recovers this relation</span>
<span>◇ the experiment declares something here</span>
<span>? = candidate, no evaluator</span>
<span><svg width="20" height="20" viewBox="0 0 20 20"><circle class="cbadge cand" cx="10" cy="10" r="7"/></svg>
every claim here is a placeholder — named, not implemented</span>
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

<h2 id="overview">2. The agreement overview</h2>
<p>Every agreement, where its rule RAN and where it is CHECKED, over the
same action columns the result matrix uses — of which it is the
template, so an empty column there can be looked up here. It lives on
this page because it describes the <em>shape</em> of the checking rather
than one machine's record.</p>
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
· <a href="projects/matrix.html">result matrix</a></div>
%s</main></body></html>|}
    css Canary_matrix.overview_css
    (* §1 the chain — the missing steps COUNTED from the catalogue, the
       chain chosen from its parts — and §1.1 its legend *)
    (missing_steps_note ()) (join_panel join) (node_legend ())
    (* §2 the agreement overview. The hand-drawn cases that were §2 and
       their recorded copies that were §2.1 went on 2026-09-24 — §1 draws
       every chain and its recorded run; their notes are §1's (user) *)
    overview
    (* §3 the census — the total is COUNTED: it was a literal
       "Twenty-five" and went stale the day a candidate was added *)
    (List.length T.claim_sites)
    (List.count T.claim_sites ~f:(fun p -> p.T.cs_implemented))
    (List.count T.claim_sites ~f:(fun p -> not p.T.cs_implemented))
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
    (* the recorded runs' files load BEFORE the script that draws them *)
    (esc generated_at) (runs_script () ^ script)

let docs_path = "docs/canary/overview.html"

let write (projects : (string * Canary_project_run.project_run) list)
    ~(overview : string) ~(generated_at : string) : unit =
  let html = render projects ~overview ~generated_at in
  Stdio.Out_channel.write_all docs_path ~data:html
