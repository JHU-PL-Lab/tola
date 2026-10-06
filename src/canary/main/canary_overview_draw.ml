(** §1's diagram for one choice — the four buttons, or a package and one
    of its recorded worlds: what each edge and node shows, and the lines
    under the node labels with their sources (the lines table). The page
    opens drawn by it and the export draws any choice by it; the page's
    script applies the same answers, looked up in the join data and the
    recorded views. *)

open Base
module T = Canary_topology
module J = Canary_overview_join
module R = Canary_overview_runs

let esc = Canary_overview_assets.esc

(** What the buttons choose: a mechanism, a cooperation and the two
    package managers — or a package, which sets those four, and one of
    its recorded worlds. *)
type choice = {
  ch_mechanism : string;
  ch_coop : string;
  ch_native : string option;
  ch_lang : string option;
  ch_package : string option;
  ch_world : string option;  (** a recorded view's key, [<id>@<machine>] *)
}

(** The choice the page opens in. *)
let opening (j : J.t) : choice =
  let m, k, pl = J.default_choice j in
  { ch_mechanism = m; ch_coop = k; ch_native = None; ch_lang = pl; ch_package = None;
    ch_world = None }

(** This machine's recorded views, by the key the page's world selector
    uses. *)
let keyed_views (vs : R.view list) : (string * R.view) list =
  let machine = Canary_store.string_of_platform (Canary_store.platform ()) in
  List.map vs ~f:(fun v -> (v.R.vw_id ^ "@" ^ machine, v))

(** A choice as the buttons make it: a package sets the other four and
    its first recorded world; a mechanism chooses the package manager it
    depends on, unless one is named. [None] leaves a button as the page
    opens it; ["none"] clears a package manager or the world. *)
let choose (j : J.t) ~(views : (string * R.view) list) ?package ?world ?mechanism ?coop ?native
    ?lang () : (choice, string) Result.t =
  let open0 = opening j in
  let one_of what xs x =
    if List.mem xs x ~equal:String.equal then Ok x
    else Error (Printf.sprintf "unknown %s %s; one of: %s" what x (String.concat ~sep:", " xs))
  in
  let pm_of side what = function
    | None -> Ok None
    | Some "none" -> Ok (Some None)
    | Some p ->
        Result.map
          (one_of what (List.map (J.pms side) ~f:Canary_store.string_of_pm) p)
          ~f:(fun p -> Some (Some p))
  in
  let case_ids = List.map j.J.jn_cases ~f:(fun c -> c.J.cs_id) in
  let world_of_key = function
    | None -> Ok None
    | Some "none" -> Ok (Some None)
    | Some w -> (
        match
          List.find views ~f:(fun (k, v) -> String.equal k w || String.equal v.R.vw_id w)
        with
        | Some (k, v) -> Ok (Some (Some (k, v)))
        | None ->
            Error
              (Printf.sprintf "no recorded world %s on this machine; one of: %s" w
                 (String.concat ~sep:", " (List.map views ~f:fst))))
  in
  (* a package: the other four from it, and its first recorded world *)
  let of_package p world =
    Result.bind (one_of "package" case_ids p) ~f:(fun p ->
        let c = List.find_exn j.J.jn_cases ~f:(fun c -> String.equal c.J.cs_id p) in
        let native, lang = J.case_pms c in
        let pm = Option.map ~f:Canary_store.string_of_pm in
        Result.map
          (match world with
           | Some (Some (k, v)) ->
               if String.equal v.R.vw_case p then Ok (Some k)
               else Error (Printf.sprintf "world %s realizes package %s, not %s" k v.R.vw_case p)
           | Some None -> Ok None
           | None ->
               Ok
                 (List.find_map views ~f:(fun (k, v) ->
                      if String.equal v.R.vw_case p then Some k else None)))
          ~f:(fun w ->
            { ch_mechanism = Canary_mechanism.string_of_mechanism c.J.cs_mechanism;
              ch_coop = T.code_of_coop (T.coop_of c.J.cs_topology);
              ch_native = pm native;
              ch_lang = pm lang;
              ch_package = Some p;
              ch_world = w }))
  in
  (* the four buttons, from the page's opening state *)
  let of_buttons () =
    let m =
      match mechanism with
      | None -> Ok open0.ch_mechanism
      | Some m ->
          one_of "mechanism"
            (List.map (J.variants ()) ~f:(fun v ->
                 Canary_mechanism.string_of_mechanism v.T.av_mechanism))
            m
    in
    let k =
      match coop with
      | None -> Ok open0.ch_coop
      | Some k ->
          one_of "cooperation" (List.map j.J.jn_kinds ~f:(fun b -> T.code_of_coop b.T.cb_kind)) k
    in
    match
      ( m,
        k,
        pm_of J.Native "native-side package manager" native,
        pm_of J.Language "language-side package manager" lang )
    with
    | Error e, _, _, _ | _, Error e, _, _ | _, _, Error e, _ | _, _, _, Error e -> Error e
    | Ok m, Ok k, Ok native, Ok lang ->
        let lang =
          match (lang, mechanism) with
          | Some l, _ -> l
          | None, Some _ ->
              Option.first_some
                (Option.bind (J.variant_named m) ~f:(fun v -> J.mechanism_pm j v.T.av_mechanism))
                open0.ch_lang
          | None, None -> open0.ch_lang
        in
        Ok
          { ch_mechanism = m;
            ch_coop = k;
            ch_native = Option.join native;
            ch_lang = lang;
            ch_package = None;
            ch_world = None }
  in
  Result.bind (world_of_key world) ~f:(fun world ->
      match (package, world) with
      | Some p, _ -> of_package p world
      | None, Some (Some (_, v)) -> of_package v.R.vw_case world
      | None, _ -> of_buttons ())

(** A choice in words, for a command's report. *)
let describe (c : choice) : string =
  match c.ch_package with
  | Some p ->
      "package " ^ p
      ^ Option.value_map c.ch_world ~default:" (declared, no recorded world)" ~f:(fun w ->
            ", recorded world " ^ w)
  | None ->
      String.concat ~sep:" · "
        [ c.ch_mechanism; c.ch_coop; Option.value c.ch_native ~default:"no native PM";
          Option.value c.ch_lang ~default:"no language PM" ]

(** What a choice draws. *)
type drawing = {
  dr_view : R.view option;  (** the recorded world drawn, if one is *)
  dr_gone : string list;  (** nodes and edges not drawn *)
  dr_dead : string list;  (** edges greyed *)
  dr_claims : (string * (string * T.claim_state) list) list;
      (** per edge, the agreements its badges count *)
  dr_lines : (string * R.line) list;  (** node → the line under its label *)
  dr_places : (string * (string * R.source option)) list;
      (** node → a recorded run's placement, with its source *)
}

let drawing (j : J.t) ~(views : (string * R.view) list) (c : choice) : drawing =
  let package =
    Option.bind c.ch_package ~f:(fun id ->
        List.find j.J.jn_cases ~f:(fun x -> String.equal x.J.cs_id id))
  in
  let view =
    Option.bind package ~f:(fun _ ->
        Option.bind c.ch_world ~f:(List.Assoc.find views ~equal:String.equal))
  in
  (* a chosen package draws with its own mechanism *)
  let variant =
    J.variant_named
      (match package with
       | Some p -> Canary_mechanism.string_of_mechanism p.J.cs_mechanism
       | None -> c.ch_mechanism)
  in
  let band, lines =
    match package with
    | Some p -> (Some p.J.cs_band, J.case_lines p)
    | None ->
        let r = J.resolve j ~k:c.ch_coop ~native:c.ch_native ~lang:c.ch_lang in
        ( Option.bind r.J.rv_band ~f:(List.Assoc.find j.J.jn_bands ~equal:String.equal),
          r.J.rv_lines )
  in
  match view with
  | Some v ->
      { dr_view = Some v;
        dr_gone = v.R.vw_gone;
        dr_dead = [];
        dr_claims = v.R.vw_edge_claims;
        (* a recorded name first, then what the package declares *)
        dr_lines = J.named_then_terms (R.view_lines v) lines;
        dr_places =
          List.map v.R.vw_nodes ~f:(fun (n, p) ->
              (n, (p, List.Assoc.find v.R.vw_place_sources n ~equal:String.equal))) }
  | None ->
      { dr_view = None;
        dr_gone =
          Option.value_map variant ~default:[] ~f:(fun v -> T.with_edges v.T.av_hidden)
          @ Option.value_map band ~default:[] ~f:(fun b -> T.with_edges b.T.cb_hidden);
        dr_dead = Option.value_map band ~default:[] ~f:(fun b -> b.T.cb_dead);
        dr_claims = Option.value_map variant ~default:[] ~f:J.mechanism_claims;
        dr_lines = lines;
        dr_places = [] }

let is_edge id = List.exists T.edges ~f:(fun e -> String.equal e.T.eg_id id)
let find l id = List.Assoc.find l id ~equal:String.equal

(** An element's classes: not drawn, greyed, and a recorded run's state
    and badge colour on an edge or its dimming on a node. *)
let classes (d : drawing) (id : string) : string list =
  let has l = List.mem l id ~equal:String.equal in
  (if has d.dr_gone then [ "gone" ] else [])
  @ (if has d.dr_dead then [ "jdead" ] else [])
  @
  match d.dr_view with
  | Some v when is_edge id ->
      ("st-" ^ Option.value (find v.R.vw_edges id) ~default:"absent")
      :: Option.value_map (find v.R.vw_badges id) ~default:[] ~f:(fun b -> [ "cl-" ^ b ])
  | Some v when List.mem v.R.vw_dim id ~equal:String.equal -> [ "dim" ]
  | _ -> []

(** The drawing's SVG, carrying the components' boxes for the panel's
    button to show. *)
let svg (d : drawing) : string =
  Canary_overview_diagram.diagram ~boxes:true ~case_slots:true ~ph_slots:true ~classes:(classes d)
    ~counts:(fun e -> R.badge_counts (Option.value (find d.dr_claims e) ~default:[]))
    ~lines:(fun n ->
      Option.map (find d.dr_lines n) ~f:(fun l ->
          ( l.R.ln_text,
            (if l.R.ln_recorded then [ "rec-name" ] else []) @ if l.R.ln_term then [ "term" ] else []
          )))
    ~places:(fun n -> Option.map (find d.dr_places n) ~f:fst)
    ~markers:(fun e ->
      Option.bind d.dr_view ~f:(fun v ->
          Option.map (find v.R.vw_placeholders e) ~f:(fun xs ->
              ( ("on"
                :: (if List.exists xs ~f:(fun (u, _) -> String.equal u "not_yet") then
                      [ "not_yet" ]
                    else [])),
                String.concat ~sep:"\n" (List.map xs ~f:snd) ))))
    ()

(* ── the lines table ── *)

let lines_head =
  {|<thead><tr><th>node</th><th>line</th><th>shown</th><th>source — and the code that read it</th></tr></thead>|}

let source_cell = function
  | None -> {|<span class="src render">no source</span>|}
  | Some (s : R.source) ->
      let k = R.string_of_source_kind s.R.src_kind in
      Printf.sprintf {|<span class="src %s">%s</span> %s — <code>%s</code>|} k k
        (if String.equal k "run" then "<code>" ^ esc s.R.src_what ^ "</code>" else esc s.R.src_what)
        (esc s.R.src_at)

(** Every line written under a node label, then a recorded run's
    placement, each with its source, in the diagram's node order. *)
let lines_rows (d : drawing) : string =
  String.concat
    (List.concat_map T.nodes ~f:(fun n ->
         let row kind text src =
           Printf.sprintf "<tr><td>%s</td><td>%s</td><td><code>%s</code></td><td>%s</td></tr>"
             (esc n.T.nd_label) kind (esc text) (source_cell src)
         in
         List.filter_opt
           [ Option.bind (find d.dr_lines n.T.nd_id) ~f:(fun l ->
                 Option.some_if (not (String.is_empty l.R.ln_text))
                   (row (if l.R.ln_term then "term" else "name") l.R.ln_text l.R.ln_src));
             Option.bind (find d.dr_places n.T.nd_id) ~f:(fun (p, s) ->
                 Option.some_if (not (String.is_empty p)) (row "placement" p s)) ]))

(** The lines table, captioned; the page's script refills its body. *)
let lines_table (d : drawing) : string =
  Canary_overview_exhibits.table ~cls:"cmp" "tab-lines"
  ^ lines_head ^ "\n" ^ {|<tbody id="jprovbody">|} ^ lines_rows d ^ "</tbody></table>"
