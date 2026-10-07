(** The two checked lists that hold §1's drawing: [layout_rules], where
    things are placed, and [visual_hints], how they look. The page renders
    its keys and its layout notes from them, and tests hold them to the
    drawing and the stylesheet. *)

open Base
module T = Canary_topology
module D = Canary_overview_diagram

let esc = Canary_overview_assets.esc

(* ── the layout's rules ── *)

(** A drawing's places: each node's centre and box. *)
type layout_view = { lv_at : string -> D.pos; lv_w : string -> int; lv_h : int }

type layout_check =
  | Places of (layout_view -> bool)  (** held over any drawing's places *)
  | Tested_by of string  (** held over this drawing by that test *)

(** A rule the layout keeps, in words a redraw in another framework can
    carry, and how it is checked ([overview.layout_rules_hold]). The
    coordinates in {!Canary_overview_diagram.layout} are one drawing of
    these rules. *)
type layout_rule = { lr_says : string; lr_why : string; lr_check : layout_check }

let this_layout = { lv_at = D.pos_of; lv_w = D.box_w_of; lv_h = D.box_h }

let layout_rules : layout_rule list =
  let x v n = (v.lv_at n).D.px and y v n = (v.lv_at n).D.py in
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
               List.exists D.bands_def ~f:(fun (top, h, _, cls) ->
                   String.equal cls (T.string_of_layer n.T.nd_layer)
                   && top < y v n.T.nd_id && y v n.T.nd_id < top + h))));
    rule
      "A package and what it ships form one vertical line: its package manager above it, \
       its payload below it — native package, headers, library, with the staged copy under \
       the library it copies; binding package, stub, module, surface."
      "user, 2026-09-27: \"vertical line for a package and package content\""
      (Places
         (fun v ->
           one_line v x [ "pm_sys"; "pkg_sys"; "hdr_sys"; "lib_sys"; "staged_sys" ]
           && one_line v x [ "pm_lang"; "pkg_lang"; "stub_lang"; "mod_lang"; "surf_lang" ]));
    rule
      "One step below each package sits its side's cooperation node: the capability file \
       under the native package, the bridge under the binding package."
      "Each side's packaging forms one regular box under its package manager's: the \
       bridge is an opam package like any other, the capability file is part of the native \
       package's packaging, and the cooperation spans the two. (user, 2026-10-06; until \
       then the bridge sat on the packages' row)"
      (Places (fun v -> y v "cap" > y v "pkg_sys" && y v "bridge" > y v "pkg_lang"));
    rule
      "Nodes of one kind on the two sides share a row: the two package managers, the two \
       packages, the capability file and the bridge, the two sources, headers and stub, \
       library and module, staged copy and surface, the two consumers."
      "user, 2026-09-24: \"if they are on the same abstraction layers, they can stay on \
       the same horizontal line\""
      (Places
         (fun v ->
           List.for_all
             [ [ "pm_sys"; "pm_lang" ]; [ "pkg_sys"; "pkg_lang" ]; [ "cap"; "bridge" ];
               [ "src_sys"; "src_lang" ]; [ "hdr_sys"; "stub_lang" ]; [ "lib_sys"; "mod_lang" ];
               [ "staged_sys"; "surf_lang" ]; [ "consumer_artifact"; "consumer_package" ] ]
             ~f:(one_line v y)));
    rule
      "Four pairs are one equal step apart: native package and capability file, binding \
       package and bridge, native source and headers, binding source and stub."
      "user, 2026-10-06: the same vertical distance for each, so the components' boxes are \
       regular and line up."
      (Places
         (fun v ->
           let d = y v "cap" - y v "pkg_sys" in
           d > 0
           && y v "bridge" - y v "pkg_lang" = d
           && y v "hdr_sys" - y v "src_sys" = d
           && y v "stub_lang" - y v "src_lang" = d));
    rule
      "A source is in no package, so it sits beside its package's line, clear of \
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
      "The capability file is part of the native package's packaging: it sits a level \
       below the package, off its lower right."
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
      (Tested_by "overview.visual_vocabulary_is_one_list");
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
       part of the package. (2026-09-24)"
      (Tested_by "overview.edge_marks_clear_the_boxes");
    rule
      "One diagram: every chain is drawn on the same layout and switched from the panel, \
       never drawn a second time beside it; the components' boxes are switched on it too."
      "Laid end to end, chains are compared by memory. (user, 2026-09-24, when §2's \
       drawings were merged into §1; the boxes, 2026-10-06)"
      (Tested_by "overview.chain_choices_draw_one_chain") ]

(* ── the visual vocabulary ── *)

type vh_element =
  | Frame  (** the bands, the side captions and the components' boxes *)
  | Node  (** a node's box *)
  | Name  (** a line under a node's label *)
  | Edge  (** an edge's line *)
  | Edge_label
  | Badge
  | Marker  (** a mark on an edge or a node: placeholder, declaration *)
  | Button  (** a button of the panel *)
  | Flow_box  (** a box of §0.2's figure *)
  | Flow_mark  (** a mark on a box of §0.2's figure: the tests', the agents' *)

(** Where a hint can show: in every drawing, only while no recorded run is
    drawn, or only while one is. *)
type vh_mode = Always | Generic | Recorded

type vh_key =
  | Chain_key  (** the key above the diagram *)
  | Run_key  (** the recorded run's key *)
  | Flow_key  (** the key under §0.2's figure *)
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
    ".selbar button:disabled"; ".selbar button:hover"; "svg .edge";
    (* §0.2's figure: a box is canary's code or a step it runs *)
    ".flow"; ".flow text"; ".flow .fsub"; ".flow .flane"; ".flow .fnote";
    ".fbox rect,.fbox .fshape"; ".fline"; ".fhead"; ".flow .flink"; ".flow a:hover .flink";
    ".fdot" ]

(** The visual vocabulary: every look §1 uses, one entry each — the element
    it styles, its stylesheet rules, the key that explains it and the words
    it says. Both keys are rendered from this list;
    [overview.visual_vocabulary_is_one_list] holds it to the stylesheet. *)
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
      (Drawn (List.map D.bands_def ~f:(fun (_, _, title, _) -> title)));
    hint "sides" Frame [ "sidecap" ] [ ".sidecap" ] Always
      (Drawn [ "SYSTEM SIDE"; "LANGUAGE SIDE" ]);
    hint "components" Frame
      [ "cbx"; "cbox"; "ctab"; "cname"; "csub"; "shown" ]
      [ ".cbox"; ".ctab"; ".cname"; ".csub"; ".cbx:not(.shown)" ]
      Always Chain_key
      ~sample:
        {|<svg width="30" height="18" viewBox="0 0 30 18"><rect class="cbox" x="2" y="3" width="26" height="12"/></svg>|}
      ~says:"a component's box, while its button is on";
    hint "side.box" Frame [ "sbox" ] [ ".sbox" ] Always Chain_key
      ~sample:
        {|<svg width="30" height="18" viewBox="0 0 30 18"><rect class="sbox" x="2" y="3" width="26" height="12"/></svg>|}
      ~says:"a whole side, from its package manager to its artifacts, while its button is on";
    hint "source.patch" Frame [ "srcbox" ] [] Always Chain_key
      ~sample:
        {|<svg width="30" height="18" viewBox="0 0 30 18"><rect class="band pm" x="2" y="2" width="26" height="14" rx="4"/></svg>|}
      ~says:"a source repository: fetched, not built, so in no component's box";
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
    hint "edge.filtered" Edge [ "filtered" ] [ ".edge.filtered" ] Always
      (No_key
         "an arrow the arrows row leaves out is not drawn, with its label and badges; the row \
          says which arrows show");
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
      ~says:"a package manager did something here that this run does not record yet";
    hint "flow.file" Flow_box [ "file"; "ffold" ] [ ".fbox .ffold" ] Always Flow_key
      ~sample:
        {|<svg width="30" height="18" viewBox="0 0 30 18"><g class="fbox file"><path class="fshape" d="M1 1H21L29 9V17H1Z"/><path class="ffold" d="M21 1V9H29"/></g></svg>|}
      ~says:"a file";
    hint "flow.hand" Flow_box [ "hand" ] [ ".fbox.hand rect" ] Always Flow_key
      ~sample:
        {|<svg width="30" height="18" viewBox="0 0 30 18"><g class="fbox hand"><rect x="1" y="1" width="28" height="16" rx="3"/></g></svg>|}
      ~says:"written for the page, and held to the code by tests";
    hint "flow.held" Flow_mark [ "fdot"; "held" ] [ ".fdot.held" ] Always Flow_key
      ~sample:
        {|<svg width="14" height="14" viewBox="0 0 14 14"><circle class="fdot held" cx="7" cy="7" r="4.5"/></svg>|}
      ~says:"held by tests — hover a dot for which; it links to §0.4";
    hint "flow.unheld" Flow_mark [ "unheld" ] [ ".fdot.unheld" ] Always Flow_key
      ~sample:
        {|<svg width="14" height="14" viewBox="0 0 14 14"><circle class="fdot unheld" cx="7" cy="7" r="4.5"/></svg>|}
      ~says:"held by no test";
    hint "flow.agents" Flow_mark [ "fagent" ] [ ".fagent text"; ".fagent path" ] Always Flow_key
      ~sample:
        {|<svg width="22" height="14" viewBox="0 0 22 14"><g class="fagent"><text x="4" y="11">AI</text><path d="M2 10L19 2"/></g></svg>|}
      ~says:"agents do not read it whole — hover for what they query" ]

(** One key, rendered from the vocabulary: a sample and its words per
    hint, in the list's order. *)
let key_html (k : vh_key) : string =
  String.concat ~sep:"\n"
    (List.filter_map visual_hints ~f:(fun h ->
         if Poly.equal h.vh_key k then
           Some (Printf.sprintf "<span>%s %s</span>" h.vh_sample (esc h.vh_says))
         else None))
