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
    ("pkg_sys", { px = 150; py = 212 });
    (* THE TWO BRIDGES SIT WITH THEIR OWNERS (user, 2026-09-22). Both
       were centred, which drew them as neutral machinery between the
       ecosystems. They are not neutral and they are not co-owned: a
       capability file ships INSIDE the native package and is written by
       whoever packaged it, while a bridge package belongs to the
       language ecosystem and is written by one of its maintainers.
       Different authors, different release cycles — which is the whole
       reason the symbolic path and the artifact path can disagree. A
       layout that hid the ownership hid the motive. *)
    ("cap", { px = 390; py = 252 });
    ("bridge", { px = 840; py = 190 });
    ("pkg_lang", { px = 1070; py = 212 });
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
let node_svg ~(live : bool) ~(label : string) ~(sub : string option)
    (n : T.node) =
  let p = pos_of n.T.nd_id in
  let x = p.px - (box_w / 2) and y = p.py - (box_h / 2) in
  let decl = T.declaration_at n.T.nd_id in
  let cls =
    Printf.sprintf "node %s%s%s"
      (T.string_of_layer n.T.nd_layer)
      (if live then "" else " dim")
      (if Option.is_some decl then " declared" else "")
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
  (* [data-node] is the handle a recorded run's overlay finds the node by *)
  let main =
    Printf.sprintf
      {|<g class="%s" data-node="%s"><title>%s</title>
<rect x="%d" y="%d" width="%d" height="%d" rx="7"/>
<text class="nlabel" x="%d" y="%d">%s</text>%s|}
      cls (esc n.T.nd_id) (esc n.T.nd_gloss) x y box_w box_h p.px
      (if Option.is_some sub then p.py - 2 else p.py + 5)
      (esc label) badge
  in
  let subline =
    match sub with
    | None -> ""
    | Some s ->
        Printf.sprintf {|<text class="nsub" x="%d" y="%d">%s</text>|} p.px
          (p.py + 14) (esc s)
  in
  main ^ subline ^ "</g>"

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

let edge_svg ~(live : bool) ~(claims : int) (e : T.edge) =
  let dst = pos_of e.eg_to in
  let cls =
    Printf.sprintf "edge%s%s%s"
      (if e.T.eg_diagonal then " diag" else "")
      (if live then "" else " dim")
      (if claims = 0 then " bare" else "")
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
               Printf.sprintf
                 {|<circle class="cbadge" cx="%d" cy="%d" r="9"/><text class="cnum" x="%d" y="%d">%d</text>|}
                 (mx + 46) my (mx + 46) (my + 4) claims
           in
           (* an inline style, because the stylesheet's text-anchor would
              beat a presentation attribute *)
           let anchor =
             if List.mem label_starts_at_midpoint e.T.eg_id ~equal:String.equal
             then {| style="text-anchor:start"|}
             else ""
           in
           Printf.sprintf
             {|<g class="%s" data-edge="%s"><title>%s — %s</title>
<line x1="%d" y1="%d" x2="%d" y2="%d" marker-end="url(#a)"/>
<text class="%s" x="%d" y="%d"%s>%s</text>%s</g>|}
             cls (esc e.T.eg_id)
             (esc (annotation_title e.T.eg_annotation))
             (esc e.T.eg_says) src.px src.py dst.px dst.py
             (annotation_class e.T.eg_annotation) mx (my - 7) anchor
             (esc (annotation_label e.T.eg_annotation))
             badge))

(** THE one layout. [rename] substitutes a concrete label for a node,
    [dead] greys an edge that this case does not have. *)
let diagram ?(rename = fun (_ : string) -> None)
    ?(sublabel = fun (_ : string) -> None) ?(dead = fun (_ : string) -> false)
    ?(hide = fun (_ : string) -> false) () : string =
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
             edge_svg ~live:(not (dead e.T.eg_id))
               ~claims:(List.length (T.claim_sites_on e.T.eg_id))
               e))
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
             node_svg ~live:true ~label ~sub:(sublabel n.T.nd_id) n))
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
.rec .edge.st-claim line{stroke:var(--acc);stroke-width:1.6;stroke-dasharray:4 4}
.rec .edge.cl-violated .cbadge{fill:var(--bad)}
.rec .edge.cl-holds .cbadge{fill:var(--ok)}
.rec .edge.cl-partial .cbadge{fill:var(--xf)}
.rec .edge.cl-undecided .cbadge,.rec .edge.cl-unevaluated .cbadge{fill:var(--mut)}
.rec .node .nsub{fill:var(--fg)}
.sw.ok{border-top:3px solid var(--ok)}.sw.okw{border-top:3px dashed var(--ok)}
.sw.xf{border-top:3px solid var(--xf)}.sw.bad{border-top:3px solid var(--bad)}
.sw.un{border-top:2px dotted var(--mut)}.sw.ab{border-top:2px solid var(--line)}
.sw.no{border-top:2px dashed var(--mut);opacity:.6}
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
section.case>p{color:var(--mut);font-size:.92rem;margin:.4rem 0 0}
.mechnote{color:var(--mut);font-size:.9rem;margin:.3rem 0 0}
.edet{font:12px ui-monospace,monospace;color:var(--mut);min-height:2.4em;
margin:.2rem 0 1.4rem;padding:.45rem .6rem;border:1px dashed var(--line);
border-radius:6px;background:var(--card)}
.edet.lit{border-style:solid;border-color:var(--acc);color:var(--fg)}
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
let topology_table (projects : (string * Canary_project_run.project_run) list) =
  let rows =
    T.topologies projects
    |> List.sort ~compare:(fun ((a : T.t), _) ((b : T.t), _) ->
           match
             String.compare
               (T.string_of_supplier a.T.tp_lang)
               (T.string_of_supplier b.T.tp_lang)
           with
           | 0 -> (
               match
                 String.compare
                   (T.short_of_join a.T.tp_join)
                   (T.short_of_join b.T.tp_join)
               with
               | 0 ->
                   String.compare
                     (T.string_of_supplier a.T.tp_sys)
                     (T.string_of_supplier b.T.tp_sys)
               | c -> c)
           | c -> c)
  in
  let row ((t : T.t), (insts : T.instance list)) =
    let cases =
      List.map insts ~f:(fun i -> i.T.in_project)
      |> List.dedup_and_sort ~compare:String.compare
    in
    Printf.sprintf
      "<tr><td class=\"mono\">%s</td><td class=\"mono\">%s</td><td \
       class=\"mono\">%s</td><td>%s</td><td class=\"n\">%s</td></tr>"
      (esc (T.string_of_supplier t.T.tp_lang))
      (esc (T.short_of_join t.T.tp_join))
      (esc (T.string_of_supplier t.T.tp_sys))
      (esc (T.character t))
      (esc (String.concat ~sep:", " cases))
  in
  Printf.sprintf
    "<table><thead><tr><th>language side</th><th>bridge</th><th>native \
     side</th><th>character</th><th>case</th></tr></thead><tbody>%s</tbody></table>"
    (String.concat (List.map rows ~f:row))

(** The two things the deleted `checks --topology` said that the table
    does not (2026-09-23): which rows are wrong for a known reason, and
    why no capability bridge appears. Both computed — the second was a
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
    if T.no_capability_bridge_declared projects then
      "<div class=\"note warn\"><strong>No capability bridge appears in any \
       row, because no project declares one.</strong> The projects declare \
       <code>Headers</code>, <code>Runtime_lib</code> and \
       <code>Link_lib</code> as their C API's components and none declares \
       a <code>Pc_file</code>. That is an absence of DECLARATION, not of \
       the bridge: pkg-config is demonstrably in use — the conf packages' \
       build predicates run it, and canary's own library locator does.</div>"
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

(** The artifact band, once per binding mechanism. Each is a row of the
    binding table instantiated — which is the point: the whole chain is
    the JOIN of one of these with one cooperation topology. *)
let mechanism_panels () =
  let one (v : T.artifact_variant) =
    let m = Canary_mechanism.string_of_mechanism v.T.av_mechanism in
    let hidden id = List.mem v.T.av_hidden id ~equal:String.equal in
    Printf.sprintf
      {|<section class="mech" id="mech-%s"><p class="mechnote">%s%s</p>%s</section>|}
      (esc m)
      (if v.T.av_wired then ""
       else "<b>Not wired — no live project binds through it.</b> ")
      (esc v.T.av_note)
      (diagram ~hide:hidden ())
  in
  let buttons =
    String.concat
      (List.map (T.artifact_variants ()) ~f:(fun v ->
           let m = Canary_mechanism.string_of_mechanism v.T.av_mechanism in
           Printf.sprintf
             {|<button data-m="%s">%s <span class="bl">%s</span></button>|}
             (esc m) (esc m)
             (esc (Canary_lang.string_of_lang v.T.av_lang))))
  in
  Printf.sprintf {|<div class="selbar" data-group="mech">%s</div>%s|} buttons
    (String.concat (List.map (T.artifact_variants ()) ~f:one))

(** A concrete case: the same graph, named, with what it does not have
    removed. Selected rather than stacked, for the same reason the
    mechanisms are — three diagrams down a page are compared by
    scrolling, which is the one thing that makes them hard to compare. *)
type case = {
  ca_key : string;
  ca_title : string;
  ca_blurb : string;
  ca_rename : string -> string option;
  ca_sub : string -> string option;
  ca_hide : string -> bool;
  ca_dead : string -> bool;
}

let case_panels (cases : case list) =
  let buttons =
    String.concat
      (List.map cases ~f:(fun c ->
           Printf.sprintf {|<button data-m="%s">%s</button>|} (esc c.ca_key)
             (esc c.ca_title)))
  in
  let panels =
    String.concat
      (List.map cases ~f:(fun c ->
           Printf.sprintf {|<section class="case" id="case-%s"><p>%s</p>%s</section>|}
             (esc c.ca_key) c.ca_blurb
             (diagram ~rename:c.ca_rename ~sublabel:c.ca_sub ~hide:c.ca_hide
                ~dead:c.ca_dead ())))
  in
  Printf.sprintf {|<div class="selbar" data-group="case">%s</div>%s|} buttons
    panels

(** THE SAME CASES, AS RECORDED (2026-09-23, status.md §2.7 phase C; user:
    keep the hand-drawn cases, and give separate buttons to show the
    running ones, so the two can be compared). A recorded world is drawn
    on ONE template — the generic diagram, every node given an empty
    sublabel to fill — by the script below, from the per-machine file
    [Canary_overview_runs] writes. This page holds no run state: a button
    exists for each case that has a counterpart, and whether the counterpart
    has been recorded is the file's to say. *)
let recorded_section (cases : case list) =
  let buttons =
    String.concat
      (List.filter_map cases ~f:(fun c ->
           if List.Assoc.mem Canary_overview_runs.counterparts c.ca_key
                ~equal:String.equal
           then
             Some
               (Printf.sprintf {|<button data-rec-case="%s">%s</button>|}
                  (esc c.ca_key) (esc c.ca_title))
           else None))
  in
  Printf.sprintf
    {|<div id="recwrap"><h3 id="recorded">2.1 The same cases, as recorded</h3>
<p>The cases above are drawn by hand: what we expect. Each button below
draws a <em>recorded</em> world with that case's shape on the same layout,
so the two can be compared by switching. An edge is coloured by what the
steps realizing it did in the last recorded run, a claim badge by the
outcomes of the claims placed there, and the world's placements sit under
the node names. An edge this world realizes no step of is faint; an edge
someone else's rule establishes is dotted, because nothing is recorded
there yet. The wheel case has no counterpart while z3 is muted.</p>
<div class="selbar recbar">%s</div>
<p><label>any recorded world: <select id="recsel"></select></label></p>
<p id="rechead" class="edet">no recorded runs loaded — <code>canary
overview</code> writes them to <code>overview_runs.js</code> beside this
page</p>
<div id="rec" class="rec">%s</div>
<div class="key reckey">
<span><i class="sw ok"></i> ran</span>
<span><i class="sw okw"></i> warm — an earlier run's verdict</span>
<span><i class="sw xf"></i> expected failure confirmed</span>
<span><i class="sw bad"></i> failed (dashed: blocked)</span>
<span><i class="sw un"></i> in the chain, never logged</span>
<span><i class="sw ab"></i> not in this world</span>
<span><i class="sw no"></i> someone else's rule — nothing recorded</span>
</div>
<div id="recclaims"></div>
<div id="recunplaced"></div></div>|}
    buttons
    (diagram ~sublabel:(fun _ -> Some "") ())

let script =
  {|<script>
(function(){
// ONE selector for both bars. The mechanism bar swaps the artifact band
// (a binding-table row); the case bar swaps the whole chain (a concrete
// instance). Panels are pre-rendered rather than re-laid-out, so nothing
// shifts underfoot when you switch.
document.querySelectorAll('[data-group]').forEach(function(bar){
  var g=bar.dataset.group;
  var show=function(k){
    document.querySelectorAll('section.'+g).forEach(function(s){
      s.hidden = s.id !== g+'-'+k; });
    bar.querySelectorAll('button').forEach(function(b){
      b.classList.toggle('on', b.dataset.m===k); });
  };
  bar.addEventListener('click',function(e){
    var b=e.target.closest('button'); if(b) show(b.dataset.m); });
  var first=bar.querySelector('button');
  if(first) show(first.dataset.m);
});
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

(** THE OVERLAY'S SCRIPT (2026-09-23). It loads every machine's record —
    a missing file is a failed script tag and nothing more — and applies a
    view's words to the template: a state class on each edge, an outcome
    class on each badge, the placements as node sublabels. It decides
    nothing; every word it applies was computed in [Canary_overview_runs].
    [#rec=<view>] in the URL selects a view, so a world can be linked. *)
let runs_script () =
  String.concat
    (List.map Canary_overview_runs.all_file_names ~f:(fun f ->
         Printf.sprintf {|<script src="%s"></script>
|} f))
  ^ {|<script>
(function(){
var runs=window.CANARY_RUNS||[], views=[], byId={}, cases={};
runs.forEach(function(r){
  (r.views||[]).forEach(function(v){
    v.key=v.id+'@'+r.machine; v.machine=r.machine; views.push(v); byId[v.key]=v; });
  Object.keys(r.cases||{}).forEach(function(k){
    if(!cases[k]) cases[k]=r.cases[k]+'@'+r.machine; });
});
var sel=document.getElementById('recsel'), head=document.getElementById('rechead'),
    rec=document.getElementById('rec');
if(!sel||!rec) return;
document.querySelectorAll('.recbar button').forEach(function(b){
  if(!cases[b.dataset.recCase]){ b.disabled=true; b.title='no recorded world for this case'; }
});
if(!views.length) return;
views.forEach(function(v){
  var o=document.createElement('option'); o.value=v.key;
  o.textContent=v.project+' · '+v.lang+' · '+v.scenario+' ('+v.machine+')';
  sel.appendChild(o); });
var STATES=['ran','warm','xfail','fail','blocked','unrecorded','absent','not_ours','claim'],
    OUTS=['violated','holds','partial','undecided','unevaluated'];
function esc(s){ var d=document.createElement('span'); d.textContent=s; return d.innerHTML; }
function show(key){
  var v=byId[key]; if(!v) return;
  sel.value=key;
  rec.querySelectorAll('[data-edge]').forEach(function(g){
    var e=g.getAttribute('data-edge');
    STATES.forEach(function(s){ g.classList.remove('st-'+s); });
    OUTS.forEach(function(o){ g.classList.remove('cl-'+o); });
    g.classList.add('st-'+(v.edges[e]||'absent'));
    if(v.badges[e]) g.classList.add('cl-'+v.badges[e]);
  });
  rec.querySelectorAll('[data-node]').forEach(function(g){
    var t=g.querySelector('.nsub'); if(t) t.textContent=v.nodes[g.getAttribute('data-node')]||'';
  });
  head.textContent=v.project+' — '+v.lang+' — '+v.scenario+' — recorded on '
    +(v.recorded_on.length?v.recorded_on.join(', '):'(no platform logged)')
    +(v.span?' — '+v.span[0]+' … '+v.span[1]:' — nothing recorded yet');
  var cl=Object.keys(v.claims);
  document.getElementById('recclaims').innerHTML=cl.length
    ?'<p class="mechnote"><strong>Claims the graph places, in this world:</strong> '
      +cl.map(function(c){ return '<code>'+esc(c)+'</code> <span class="o-'+v.claims[c]+'">'
        +esc(v.claims[c])+'</span>'; }).join(' · ')+'</p>'
    :'';
  var up=Object.keys(v.unplaced);
  document.getElementById('recunplaced').innerHTML=up.length
    ?'<p class="mechnote"><strong>Steps of this world with no edge on the page:</strong></p><ul class="unpl">'
      +up.map(function(t){ return '<li><code>'+esc(t)+'</code> — '+esc(v.unplaced[t])+'</li>'; }).join('')+'</ul>'
    :'';
  document.querySelectorAll('.recbar button').forEach(function(b){
    b.classList.toggle('on', cases[b.dataset.recCase]===key); });
  try{ history.replaceState(null,'','#rec='+encodeURIComponent(key)); }catch(e){}
}
sel.addEventListener('change',function(){ show(sel.value); });
document.querySelectorAll('.recbar button').forEach(function(b){
  b.addEventListener('click',function(){ var k=cases[b.dataset.recCase]; if(k) show(k); });
});
var m=/#rec=([^&]+)/.exec(location.hash), want=m?decodeURIComponent(m[1]):null;
show(want&&byId[want]?want:(cases.conf||views[0].key));
// a link that names a world lands on it
if(want&&byId[want]){ var h=document.getElementById('recorded'); if(h) h.scrollIntoView(); }
})();
</script>|}

let render (projects : (string * Canary_project_run.project_run) list)
    ~(overview : string) ~(generated_at : string) : string =
  let bare = T.bare_edges () in
  let assoc l = fun id -> List.Assoc.find l id ~equal:String.equal in
  let hides ids id = List.mem ids id ~equal:String.equal in
  let cases =
    [ { ca_key = "conf"; ca_title = "conf-* over a system library";
        ca_blurb =
          "Both bridges present, and each sits with its author. The \
           SYMBOLIC path runs <code>binding → conf → depext → system \
           package</code>; the ARTIFACT path runs <code>conf predicate → \
           capability query → the library on disk</code>. They can land \
           on different libraries, and nothing today compares them.";
        ca_rename =
          assoc
            [ ("pm_sys", "apt"); ("pkg_sys", "libgmp-dev");
              ("bridge", "conf-gmp"); ("cap", "gmp.pc"); ("pm_lang", "opam");
              ("pkg_lang", "zarith"); ("lib_sys", "libgmp.so.10");
              ("hdr_sys", "gmp.h"); ("src_lang", "Zarith.git");
              ("stub_lang", "zarith_stubs.a"); ("mod_lang", "zarith.cmxa");
              ("surf_lang", "zarith.mli");
              ("consumer_artifact", "zarith_example (paths)");
              ("consumer_package", "zarith_example (-package zarith)") ];
        ca_sub =
          assoc
            [ ("bridge", "an opam package — written by an opam maintainer");
              ("cap", "inside libgmp-dev — written by the Debian packager") ];
        ca_hide = hides [ "src_sys"; "staged_sys" ]; ca_dead = (fun _ -> false)
      };
      { ca_key = "wheel"; ca_title = "the library inside the wheel";
        ca_blurb =
          "The consumer package carries the native artifact. The system \
           PM, the system package and <em>both</em> bridges disappear — \
           there is no cooperation left, which is a different statement \
           from having no bridge. Every claim that compared two \
           ecosystems has nothing to compare.";
        ca_rename =
          assoc
            [ ("pm_lang", "pip"); ("pkg_lang", "z3-solver (wheel)");
              ("lib_sys", "libz3.so — INSIDE the wheel");
              ("mod_lang", "z3/*.py + native ext");
              ("surf_lang", "z3.__all__");
              ("consumer_package", "python -c 'import z3'") ];
        ca_sub =
          assoc
            [ ("lib_sys", "no system package, no bridge, no discovery");
              ("pkg_lang", "one package supplies both sides") ];
        ca_hide =
          hides
            [ "pm_sys"; "pkg_sys"; "bridge"; "cap"; "src_sys"; "staged_sys";
              "hdr_sys"; "src_lang"; "stub_lang" ];
        ca_dead = (fun _ -> false) };
      { ca_key = "built"; ca_title = "built here — and the bridge still gates";
        ca_blurb =
          "The native side is built here, so the system package is not \
           used. The binding package's <code>conf-llvm-shared {= \
           \"19\"}</code> constraint is still in its depends and opam \
           still evaluates it — against the system, which this world is \
           not using. The gate passes or fails on evidence unrelated to \
           the artifacts under test.";
        ca_rename =
          assoc
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
        ca_sub =
          assoc
            [ ("bridge", "still runs — against the SYSTEM, not this build");
              ("pkg_sys", "the gate validates this, the world uses that") ];
        ca_hide = (fun _ -> false);
        ca_dead =
          hides [ "resolve_sys"; "realize_sys"; "realize_hdr"; "realize_cap" ]
      };
      { ca_key = "unified"; ca_title = "one package universe";
        ca_blurb =
          "Both sides come from the same package manager, so there is no \
           second ecosystem to bridge to — the constraint travels as an \
           ordinary dependency in one namespace. This is torch: the \
           library arrives through opam as an upstream binary, named \
           directly by a depext bound rather than through a conf hop.";
        ca_rename =
          assoc
            [ ("pm_lang", "opam"); ("pkg_lang", "torch");
              ("bridge", "depext: libtorch >=2.1.0 <2.2.0");
              ("lib_sys", "libtorch.so (opam binary)");
              ("hdr_sys", "torch/*.h"); ("src_lang", "ocaml-torch.git");
              ("stub_lang", "libtorch_core_stubs.a");
              ("mod_lang", "torch.cmxa"); ("surf_lang", "torch.mli");
              ("consumer_artifact", "torch_example (paths)");
              ("consumer_package", "torch_example (-package torch)") ];
        ca_sub =
          assoc
            [ ("bridge",
               "metadata inside the consumer — not a package of its own");
              ("pkg_lang", "same PM on both sides") ];
        ca_hide = hides [ "pm_sys"; "pkg_sys"; "cap"; "src_sys"; "staged_sys" ];
        ca_dead = (fun _ -> false) };
      { ca_key = "none"; ca_title = "no package manager between them";
        ca_blurb =
          "The binding and the library were joined by whoever built the \
           interpreter, outside any package manager we can observe. \
           CPython's stdlib <code>sqlite3</code> is the case. The \
           coupling is entirely real — the extension records a NEEDED on \
           libsqlite3 and the loader resolves it — but there is no \
           declaration anywhere to check it against. <em>No gate</em> and \
           <em>no gate mechanism</em> are different situations.";
        ca_rename =
          assoc
            [ ("pm_sys", "apt"); ("pkg_sys", "libsqlite3-0");
              ("lib_sys", "libsqlite3.so.0"); ("hdr_sys", "sqlite3.h");
              ("pm_lang", "(the interpreter build)");
              ("pkg_lang", "CPython stdlib");
              ("stub_lang", "_sqlite3.cpython-*.so");
              ("mod_lang", "sqlite3/__init__.py");
              ("surf_lang", "dir(sqlite3)");
              ("consumer_package", "python -c 'import sqlite3'") ];
        ca_sub =
          assoc
            [ ("pkg_lang", "chosen at interpreter build time, not here");
              ("lib_sys", "the loader picks it; nothing declared which") ];
        ca_hide =
          hides [ "bridge"; "cap"; "src_sys"; "staged_sys"; "src_lang" ];
        ca_dead = (fun _ -> false) } ]
  in
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
<em>can</em> exist, which is a different question. The one exception is
§2.1, which draws a recorded run over the same layout for comparison,
from a separate per-machine file.</p>

<div class="note"><strong>A bridge is a thing, not a relation.</strong>
It is concrete, separate package content whose purpose is package-manager
cooperation. It lives in neither the pure native side nor the pure
language side — which is exactly why a binding-level view cannot see it,
and why this page exists. It is also <em>optional</em>: two ecosystems may
cooperate through a bridge, or through nothing but the artifacts, and a
language package that links whatever the system installed is not thereby
broken.</div>

<div class="note"><strong>There are usually two bridges, not one.</strong>
A <code>conf-*</code> package carries package <em>identity</em> plus the
depext mapping. A <code>.pc</code> file carries <em>capability</em> — a
name, a version, cflags, libs. They are written by different people, and
they can disagree. Cargo's <code>*-sys</code> topology has only the
second, which is what makes it artifact-centric rather than
bridgeless.</div>

<h2>1. The generic chain</h2>
<p>Nodes are what exists. An edge points from components to a component
and carries one annotation. Most carry the <strong>action</strong> of ours
that realizes the relation. Where we run nothing, an edge carries
<em>information</em> in italics: whatever does establish the relation, and
in time what a run recorded about it. One edge carries a
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
</div>

<div class="note"><strong>The artifact band is one binding mechanism.</strong>
As first drawn it was the C-shim shape — headers, a compiled stub, a
language module. A <code>ctypes</code> binding compiles nothing and has
no stub node at all; its library is opened by name at import, so two of
these edges do not merely go quiet, they do not exist. So the whole
diagram is a <em>join</em>: one artifact-layer row (a binding mechanism)
with one package-and-PM row (a cooperation topology). Neither table
alone draws a chain; the pair does. Switch the band below.</div>
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

<h2 id="cases">2. Concrete cases</h2>
<p>The general shape above, instantiated: the same graph with its nodes
named. A node that is absent does not exist in that case; a greyed edge
exists and does not fire. Switch between them rather than scrolling —
chains laid end to end are compared by memory, which is the one thing
that makes them hard to compare. Each case is a row of the topology
table in §5.</p>
%s

<h2 id="overview">3. The agreement overview</h2>
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

<h2 id="census">4. Where every claim sits, and the edges where none do</h2>
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

<h2 id="topologies">5. Cooperation topologies</h2>
<p>One row per distinct shape, derived from what each project declares —
never from a table anyone maintains by hand. The last column is a fact
about us and not part of the row.</p>
%s
%s

<div class="foot">Generated %s. <strong>What is derived and what is not</strong>,
since the page is meant to trade the second for the first over time:
the cooperation topologies are derived from each project's declared
provisions, gates and C-API components; the mechanism variants from the mechanism
catalogue; the agreement overview from the registry and recorded runs.
The nodes, the edges, which edge each claim sits on, and the labels of
the concrete cases are <em>hand-written lists</em> in
<code>canary_topology.ml</code> and here — placeholders, checked by pins
against the registry but not yet computed from the action catalogue.
Each edge's annotation is typed, though: an action family the catalogue
has, a registered or candidate claim, or information; and which of the
catalogue's actions have no edge is computed.
The diagrams are SVG emitted from that data, with one hand-placed
coordinate per node. The recorded worlds of §2.1 are not in this page:
they are read from <code>overview_runs.js</code> (one per machine), which
<code>canary overview</code> computes from the run record — each edge's
state from the steps placed on it, each badge from its claims' outcomes.
· <a href="projects/matrix.html">result matrix</a></div>
%s</main></body></html>|}
    css Canary_matrix.overview_css
    (* §1 the chain — the missing steps COUNTED from the catalogue — and
       §1.1 its legend *)
    (missing_steps_note ()) (mechanism_panels ()) (node_legend ())
    (* §2 the cases — moved up so the general shape is followed at once by
       its instances (user, 2026-09-23) — and §2.1, the same cases as
       recorded, for comparison *)
    (case_panels cases ^ recorded_section cases)
    (* §3 the agreement overview *)
    overview
    (* §4 the census — the total is COUNTED: it was a literal
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
    (* §5 the topologies *)
    (topology_table projects) (topology_notes projects)
    (esc generated_at) (script ^ runs_script ())

let docs_path = "docs/canary/overview.html"

let write (projects : (string * Canary_project_run.project_run) list)
    ~(overview : string) ~(generated_at : string) : unit =
  let html = render projects ~overview ~generated_at in
  Stdio.Out_channel.write_all docs_path ~data:html
