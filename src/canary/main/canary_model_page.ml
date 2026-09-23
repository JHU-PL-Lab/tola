(** [Canary_model_page] — the METHODOLOGY page (2026-09-22).

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
    ("bridge", { px = 610; py = 176 });
    ("cap", { px = 610; py = 268 });
    ("pkg_lang", { px = 1070; py = 212 });
    ("src_sys", { px = 150; py = 392 });
    ("hdr_sys", { px = 150; py = 466 });
    ("lib_sys", { px = 150; py = 550 });
    ("staged_sys", { px = 150; py = 624 });
    ("src_lang", { px = 1070; py = 392 });
    ("stub_lang", { px = 1070; py = 466 });
    ("mod_lang", { px = 1070; py = 550 });
    ("surf_lang", { px = 1070; py = 624 });
    ("app", { px = 610; py = 762 });
    ("decl", { px = 610; py = 466 }) ]

let pos_of id =
  match List.Assoc.find layout id ~equal:String.equal with
  | Some p -> p
  | None -> { px = 610; py = 440 }

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
  let cls =
    Printf.sprintf "node %s%s"
      (T.string_of_layer n.T.nd_layer)
      (if live then "" else " dim")
  in
  let main =
    Printf.sprintf
      {|<g class="%s"><title>%s</title>
<rect x="%d" y="%d" width="%d" height="%d" rx="7"/>
<text class="nlabel" x="%d" y="%d">%s</text>|}
      cls (esc n.T.nd_gloss) x y box_w box_h p.px
      (if Option.is_some sub then p.py - 2 else p.py + 5)
      (esc label)
  in
  let subline =
    match sub with
    | None -> ""
    | Some s ->
        Printf.sprintf {|<text class="nsub" x="%d" y="%d">%s</text>|} p.px
          (p.py + 14) (esc s)
  in
  main ^ subline ^ "</g>"

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
             {|<g class="%s"><title>%s</title><path d="M %d %d a 30 26 0 1 1 22 0"/></g>|}
             cls
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
           Printf.sprintf
             {|<g class="%s"><title>%s — %s</title>
<line x1="%d" y1="%d" x2="%d" y2="%d" marker-end="url(#a)"/>
<text class="elabel" x="%d" y="%d">%s</text>%s</g>|}
             cls
             (esc (Option.value e.T.eg_action ~default:"(nothing we run)"))
             (esc e.T.eg_says) src.px src.py dst.px dst.py mx (my - 7)
             (esc (Option.value e.T.eg_action ~default:"·"))
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
               ~claims:(List.length (T.placements_on e.T.eg_id))
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
--card:#fff;--acc:#2b5f8a}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
--bg:#161514;--fg:#eceae6;--mut:#a09a91;--line:#35322e;
--pm:#1d2530;--pkg:#2a2519;--art:#1a241b;--prog:#2b1d1d;--card:#1f1e1c;
--acc:#7fb0dc;--warn:#e0805a}}
:root[data-theme="dark"]{--bg:#161514;--fg:#eceae6;--mut:#a09a91;--line:#35322e;
--pm:#1d2530;--pkg:#2a2519;--art:#1a241b;--prog:#2b1d1d;--card:#1f1e1c;
--acc:#7fb0dc;--warn:#e0805a}
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
.edge.dim{opacity:.18}
.cbadge{fill:var(--acc);opacity:.9}
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
@media(max-width:700px){body{font-size:14px}h1{font-size:1.4rem}
table{font-size:.8rem}}|}

let placements_table () =
  let row (e : T.edge) =
    let ps = T.placements_on e.T.eg_id in
    let impl = List.count ps ~f:(fun p -> p.T.pl_implemented) in
    let cand = List.length ps - impl in
    let names =
      if List.is_empty ps then
        "<em>nothing — this relation is recovered by no claim</em>"
      else
        String.concat ~sep:", "
          (List.map ps ~f:(fun p ->
               Printf.sprintf "<code>%s</code>%s" (esc p.T.pl_claim)
                 (if p.T.pl_implemented then "" else "<sup>?</sup>")))
    in
    Printf.sprintf
      "<tr%s><td><code>%s</code></td><td class=\"n\">%s</td><td>%s</td><td \
       class=\"n\">%d / %d</td><td>%s</td></tr>"
      (if List.is_empty ps then " class=\"bare\"" else "")
      (esc e.T.eg_id)
      (esc (Option.value e.T.eg_action ~default:"— we run nothing —"))
      (esc e.T.eg_tool) impl cand names
  in
  Printf.sprintf
    "<table><thead><tr><th>edge</th><th>our action</th><th>whose rule \
     runs</th><th>impl / cand</th><th>claims</th></tr></thead><tbody>%s</tbody></table>"
    (String.concat (List.map T.edges ~f:row))

let topology_table (projects : (string * Canary_project_run.project_run) list) =
  let rows = T.topologies projects in
  let row ((t : T.t), (insts : T.instance list)) =
    let realized =
      List.map insts ~f:(fun i -> i.T.in_project)
      |> List.dedup_and_sort ~compare:String.compare
    in
    Printf.sprintf
      "<tr><td class=\"mono\">%s</td><td class=\"mono\">%s</td><td \
       class=\"mono\">%s</td><td>%s</td><td class=\"n\">%s</td></tr>"
      (esc (T.string_of_supplier t.T.tp_sys))
      (esc (T.short_of_join t.T.tp_join))
      (esc (T.string_of_supplier t.T.tp_lang))
      (esc (T.character t))
      (esc (String.concat ~sep:", " realized))
  in
  Printf.sprintf
    "<table><thead><tr><th>native side</th><th>bridge</th><th>language \
     side</th><th>character</th><th>we realize it in</th></tr></thead><tbody>%s</tbody></table>"
    (String.concat (List.map rows ~f:row))

let render (projects : (string * Canary_project_run.project_run) list)
    ~(generated_at : string) : string =
  let bare = T.bare_edges () in
  let assoc l = fun id -> List.Assoc.find l id ~equal:String.equal in
  (* CASE 1 — the conf-* shape, and the shape of every opam binding over
     a system library. Both bridges present. *)
  let case_conf =
    diagram
      ~rename:
        (assoc
           [ ("pm_sys", "apt"); ("pkg_sys", "libgmp-dev");
             ("bridge", "conf-gmp"); ("cap", "gmp.pc"); ("pm_lang", "opam");
             ("pkg_lang", "zarith"); ("lib_sys", "libgmp.so.10");
             ("hdr_sys", "gmp.h"); ("src_lang", "Zarith.git");
             ("stub_lang", "zarith_stubs.a"); ("mod_lang", "zarith.cmxa");
             ("surf_lang", "zarith.mli"); ("app", "zarith_example") ])
      ~sublabel:
        (assoc
           [ ("bridge", "presence only — bounds no version");
             ("cap", "declared by nobody; read by the conf predicate") ])
      ~hide:(fun id -> List.mem [ "src_sys"; "staged_sys" ] id ~equal:String.equal)
      ()
  in
  (* CASE 2 — the bad practice: the wheel carries the library. The whole
     system side and both bridges vanish. *)
  let case_wheel =
    diagram
      ~rename:
        (assoc
           [ ("pm_lang", "pip"); ("pkg_lang", "z3-solver (wheel)");
             ("lib_sys", "libz3.so — INSIDE the wheel");
             ("mod_lang", "z3/*.py + native ext"); ("surf_lang", "z3.__all__");
             ("app", "python -c 'import z3'") ])
      ~sublabel:
        (assoc
           [ ("lib_sys", "no system package, no bridge, no discovery");
             ("pkg_lang", "one package supplies both sides") ])
      ~hide:(fun id ->
        List.mem
          [ "pm_sys"; "pkg_sys"; "bridge"; "cap"; "src_sys"; "staged_sys";
            "hdr_sys"; "src_lang"; "stub_lang" ]
          id ~equal:String.equal)
      ()
  in
  (* CASE 3 — the world builds its own library, and the bridge STILL
     gates. The finding that fell out of the derivation. *)
  let case_built =
    diagram
      ~rename:
        (assoc
           [ ("src_sys", "llvm-project @ ref"); ("lib_sys", "libLLVM.so (built)");
             ("staged_sys", "install prefix"); ("pm_sys", "apt — not used here");
             ("pkg_sys", "llvm-19-dev — not used here");
             ("bridge", "conf-llvm-shared {= 19}"); ("cap", "llvm-config");
             ("pm_lang", "opam"); ("pkg_lang", "llvm.19-shared");
             ("mod_lang", "llvm.cmxa"); ("app", "llvm_example") ])
      ~sublabel:
        (assoc
           [ ("bridge", "still runs — against the SYSTEM, not this build");
             ("pkg_sys", "the gate validates this, the world uses that") ])
      ~dead:(fun id ->
        List.mem [ "resolve_sys"; "realize_sys"; "realize_hdr"; "realize_cap" ]
          id ~equal:String.equal)
      ()
  in
  Printf.sprintf
    {|<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Cooperation Model</title>
<style>%s</style></head><body><main>

<h1>How two package ecosystems are joined</h1>
<p class="lede">General mechanism only — no project, no version, no verdict.
What ran and what it decided is the
<a href="projects/matrix.html">result matrix</a>; this page is what
<em>can</em> exist, which is a different question and does not belong on
the same scroll.</p>

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

<h2>1. The generic chain, with every step</h2>
<p>Nodes are what exists; edges are relations some real tool establishes,
labelled with the action of ours that realizes them. An edge labelled
<code>·</code> is a relation that really happens and that we run nothing
at. The badge on an edge counts the claims that sit there.</p>
<div class="key">
<span><i class="sw"></i> within a layer, or down one</span>
<span><i class="sw d"></i> diagonal — crosses layers (discovery)</span>
<span><i class="sw b"></i> no claim recovers this relation</span>
<span>? = candidate, no evaluator</span>
</div>
%s

<div class="note warn"><strong>One edge runs both ways.</strong>
<code>binding package</code> ↔ <code>language module</code> is an
<em>install</em> when the binding is fetched and a <em>pack</em> when it
is built here. Those are different actions establishing different
relations, and which one applies is a fact about the world, not about the
project. Both are drawn; in any given world exactly one is live.</div>

<div class="note warn"><strong>Two nodes the three-layer picture does not
have.</strong> The <em>declaration</em> — four of our implemented claims
compare an artifact against the experiment's own spec, which is not a
layer but an oracle attached to whatever node it speaks about. And the
<em>source</em>, which the layered model has only inside its
package-rewrite cases, never in the base picture.</div>

<h2>2. Where every claim sits, and the edges where none do</h2>
<p>Twenty-five claims — %d implemented, %d candidates — placed on the
edges above. A placement is a <em>set</em> of edges rather than one, so
an end-to-end claim spanning several has somewhere to go; none does
yet.</p>
%s

<div class="note warn"><strong>%d edges carry no claim at all</strong>
(%s). Every one is a relation a real tool establishes and from which we
recover nothing. They are not obscure: they are the package layer and
the cooperation between the two ecosystems. Almost everything we have
sits on the two edges where a compiler or a linker ran.</div>

<div class="note"><strong>The network analogy, and where it breaks.</strong>
Two hosts in a network stack implement the <em>same protocol</em> at each
layer, so both a per-layer invariant and an end-to-end invariant have a
stated contract to check against. Here the horizontal relation at the
package layer is a bridge somebody wrote, or nothing — not a protocol,
and not symmetric between the two sides. A bridge may carry identity
while dropping version, which in network terms is a layer that forwards
the address and silently discards the checksum. That asymmetry is why the
end-to-end invariants are the ones we do not have.</div>

<h2>3. Cooperation topologies</h2>
<p>One row per distinct shape, derived from what each project declares —
never from a table anyone maintains by hand. The last column is a fact
about us and not part of the row.</p>
%s

<h2>4. Concrete cases</h2>
<p>The same graph with its nodes named. Hidden nodes do not exist in that
case; greyed edges exist and do not fire.</p>

<h3>4.1 A binding over a system library — the <code>conf-*</code> shape</h3>
<p>Both bridges present. The symbolic path runs
<code>binding → conf → depext → system package</code>; the artifact path
runs <code>conf predicate → capability query → the library on disk</code>.
They can land on different libraries, and nothing today compares them.</p>
%s

<h3>4.2 The library inside the wheel</h3>
<p>The consumer package carries the native artifact. The system PM, the
system package and <em>both</em> bridges disappear — there is no
cooperation left, which is a different statement from having no bridge.
Every claim that compared two ecosystems has nothing to compare.</p>
%s

<h3>4.3 The world builds its own library — and the bridge still gates</h3>
<p>The native side is built here, so the system package is not used. The
binding package's <code>conf-llvm-shared {= "19"}</code> constraint is
still in its depends, and opam still evaluates it — against the system,
which this world is not using. The gate passes or fails on evidence
unrelated to the artifacts under test.</p>
%s

<div class="foot">Generated %s from the project declarations — nodes,
edges and claim placements live in <code>canary_topology.ml</code>;
nothing on this page is hand-maintained. ·
<a href="projects/matrix.html">result matrix</a></div>
</main></body></html>|}
    css (diagram ())
    (List.count T.placements ~f:(fun p -> p.T.pl_implemented))
    (List.count T.placements ~f:(fun p -> not p.T.pl_implemented))
    (placements_table ()) (List.length bare)
    (esc
       (String.concat ~sep:", " (List.map bare ~f:(fun e -> e.T.eg_id))))
    (topology_table projects)
    case_conf case_wheel case_built (esc generated_at)

let docs_path = "docs/canary/model.html"

let write (projects : (string * Canary_project_run.project_run) list)
    ~(generated_at : string) : unit =
  let html = render projects ~generated_at in
  Stdio.Out_channel.write_all docs_path ~data:html
