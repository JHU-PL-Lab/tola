(** §1's panel: the choices that draw one chain on the diagram — the two
    package managers, the binding mechanism, the cooperation, or a package
    in canary, which fixes the other four — with the notes each choice
    shows, the recorded run's key and lists, the layout's rules, and the
    node legend. Every set a choice draws is {!Canary_overview_join}'s
    data, embedded as JSON; the page's script keeps the state and applies
    it. The page opens drawn in the default choice. *)

open Base
module T = Canary_topology
module D = Canary_overview_diagram
module L = Canary_overview_looks
module C = Canary_overview_cases

let esc = Canary_overview_assets.esc

(** The catalogue's action families with no edge on the diagram, counted
    from the catalogue. *)
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

(** §1.1: what each node is. *)
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
  (* the concrete chains, grouped by project in §3.4's order *)
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
  (* the hand-drawn case a cooperation is illustrated by: its prose, and
     what it says about single nodes *)
  let hand_note k =
    match List.find C.hand_cases ~f:(fun c -> Poly.equal c.C.ca_coop k) with
    | None -> ""
    | Some c ->
        Printf.sprintf {|<br><b>%s.</b> %s%s|} (esc c.C.ca_title) c.C.ca_blurb
          (String.concat
             (List.map c.C.ca_subs ~f:(fun (n, s) ->
                  Printf.sprintf " <i>%s</i>: %s."
                    (esc
                       (Option.value_map (T.node_by_id n) ~default:n ~f:(fun nd ->
                            nd.T.nd_label)))
                    (esc s))))
  in
  (* a cooperation's note shows whether or not a package is chosen; its
     band's note only while none is *)
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
        "<strong>Canary runs this chain:</strong> " ^ esc (runs_label j ids) ^ " (§3.4)."
  in
  (* the covered cooperations with no band of their own, said rather than
     dropped: their chains are among the concrete ones *)
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
    (D.diagram ~classes ~case_slots:true ~ph_slots:true
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
           {|<p class="mechnote">No cooperation button: %s. Their packages are among the concrete ones, drawn with what canary cannot read left in (§3.3).</p>|}
           (esc (String.concat ~sep:"; " us)))
    (* the layout's rules, as a redraw must keep them *)
    (Printf.sprintf
       {|<details class="jprov" id="jrules"><summary>How this diagram is laid out — %d rules a redraw in any framework must keep</summary><ol class="lrules">%s</ol><p class="mechnote">Each is held against these places by <code>overview.layout_rules_hold</code>, or by the pin it names; the looks are the keys'.</p></details>|}
       (List.length L.layout_rules)
       (String.concat
          (List.map L.layout_rules ~f:(fun r ->
               Printf.sprintf "<li><strong>%s</strong> <span class=\"lwhy\">%s</span></li>"
                 (esc r.L.lr_says) (esc r.L.lr_why)))))
    (* the recorded run's key, from the vocabulary *)
    (L.key_html L.Run_key)
    data
