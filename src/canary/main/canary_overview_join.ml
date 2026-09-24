(** [Canary_overview_join] — §1'S CHOICES, AS DATA (2026-09-24, status.md
    §2.7; user: "can we also make the pm itself as the choice? … all are
    shown as buttons in one place. If we click a binding mechanism, the
    dependent pms are also shown as clicked. if we click a concrete package
    case, the pms and binding-mechanism it uses are also shown as
    clicked").

    The overview's §1 draws ONE chain on the generic layout, and five
    choices draw it: the native side's package manager, the language
    side's, the binding mechanism (the artifact band), the cooperation (the
    package band) — or one CONCRETE chain canary runs, which fixes the
    other four and names the nodes. This module computes what every choice
    draws, and the page's script only keeps the state and looks the
    answers up.

    A concrete chain is a row of §5.4 — ONE list, which that table renders
    too — named from its project's DECLARATIONS, never from a run: §1 is
    what can exist and what canary runs; a recorded world is §2.1's. *)

open Base
module T = Canary_topology

(* ── the package managers, per side ─────────────────────────────────── *)

(** The two package-manager nodes of the diagram. *)
type side = Native | Language

(** The package managers the panel offers on one side: the PM-solo table's
    rows, split by the drivers' own scope — a SYSTEM package manager
    supplies a native side, a language one a language side
    ([Canary_topology.is_system_pm]). *)
let pms (s : side) : Canary_store.package_manager list =
  List.filter_map Canary_pm_solo.table ~f:(fun r ->
      let pm = r.Canary_pm_solo.ps_pm in
      match s with
      | Native -> if T.is_system_pm pm then Some pm else None
      | Language -> if T.is_system_pm pm then None else Some pm)

(* ── the order the panel lists things in ─────────────────────────────── *)

(** Grouped by LANGUAGE, in order of first appearance, otherwise in the
    given order (user, 2026-09-24: "sort them first from the language
    side, then two ocaml ones (cstubs and dynlink) can be together"). *)
let by_language (lang_of : 'a -> Canary_lang.lang) (xs : 'a list) : 'a list =
  let langs =
    List.fold xs ~init:[] ~f:(fun acc x ->
        if List.mem acc (lang_of x) ~equal:Poly.equal then acc else acc @ [ lang_of x ])
  in
  List.concat_map langs ~f:(fun l -> List.filter xs ~f:(fun x -> Poly.equal (lang_of x) l))

(** The artifact bands, one per mechanism, grouped by language. *)
let variants () : T.artifact_variant list =
  by_language (fun (v : T.artifact_variant) -> v.T.av_lang) (T.artifact_variants ())

(* ── the concrete chains ────────────────────────────────────────────── *)

(** One concrete chain: the worlds of one project that bind one language
    with the same two sides. *)
type case = {
  cs_id : string;  (** project, language, the two sides — URL-safe *)
  cs_project : string;
  cs_lang : Canary_lang.lang;
  cs_mechanism : Canary_mechanism.mechanism;
  cs_topology : T.t;
  cs_band : T.coop_band;  (** its own band, over its own worlds *)
  cs_bridges : string list;
      (** the kinds of bridge it joins through, as terms — what its
          "bridge package" node says when no name is declared *)
  cs_names : (string * string) list;
      (** node id → what its project DECLARES the node is, in the chain's
          first world — the name drawn under the generic label *)
  cs_name_sources : (string * Canary_overview_runs.source) list;
      (** node id → the declaration each name was read from, and the code
          that read it ([Canary_overview_runs.declared_names]) *)
}

(** The key §5.4 sorts by, so the table and the buttons share one order. *)
let sort_key (c : case) =
  ( c.cs_project,
    Canary_lang.string_of_lang c.cs_lang,
    Canary_mechanism.string_of_mechanism c.cs_mechanism,
    T.string_of_supplier c.cs_topology.T.tp_lang,
    T.string_of_supplier c.cs_topology.T.tp_sys,
    T.character c.cs_topology )

(** Every concrete chain the worlds realize. The two sides decide the
    topology — its join is the declared gate only where a package manager
    supplies the binding — so project, language and the two sides are the
    key, and the id is spelled from them. *)
let cases_of (is : T.band_instance list) : case list =
  let key (i : T.band_instance) =
    T.chain_id_of ~project:i.T.bi_project ~lang:i.T.bi_lang i.T.bi_topology
  in
  List.map is ~f:key
  |> List.dedup_and_sort ~compare:String.compare
  |> List.filter_map ~f:(fun id ->
         match List.filter is ~f:(fun i -> String.equal (key i) id) with
         | [] -> None
         | first :: _ as mine ->
             Option.map
               (T.band_over mine (T.coop_of first.T.bi_topology))
               ~f:(fun band ->
                 let declared =
                   Canary_overview_runs.declared_names first.T.bi_pr first.T.bi_world
                     first.T.bi_lang ~publishes:first.T.bi_publishes
                 in
                 { cs_id = id;
                   cs_project = first.T.bi_project;
                   cs_lang = first.T.bi_lang;
                   cs_mechanism = first.T.bi_mechanism;
                   cs_topology = first.T.bi_topology;
                   cs_band = band;
                   cs_bridges = T.bridge_terms mine;
                   cs_names = List.map declared ~f:(fun (n, (l, _)) -> (n, l));
                   cs_name_sources = List.map declared ~f:(fun (n, (_, s)) -> (n, s)) }))
  |> List.sort ~compare:(fun a b -> Poly.compare (sort_key a) (sort_key b))

(** The package managers a concrete chain lights: its system PM, if one
    supplies its native side, and its language side's. *)
let case_pms (c : case) =
  (T.native_pm_of c.cs_topology, T.lang_pm_of c.cs_topology)

(* ── what a mechanism depends on ────────────────────────────────────── *)

(** THE PACKAGE MANAGERS A MECHANISM DEPENDS ON: those that ship its
    LANGUAGE's bindings in the chains canary runs — opam for OCaml, pip
    for Python. Read per language rather than per mechanism, so a
    mechanism no project binds through yet (cffi, dynlink) still names
    where its bindings would come from. The native side does not depend on
    the mechanism — any mechanism binds apt's library — so it is not one
    of them. *)
let dependent_pms (cs : case list) (m : Canary_mechanism.mechanism) :
    Canary_store.package_manager list =
  let lang = (Canary_mechanism.info_of_mechanism m).Canary_mechanism.mi_lang in
  List.filter_map cs ~f:(fun c ->
      if Poly.equal c.cs_lang lang then T.lang_pm_of c.cs_topology else None)
  |> List.dedup_and_sort ~compare:Poly.compare

(* ── everything the panel draws ─────────────────────────────────────── *)

(** A choice's key: the cooperation, then each package manager or ["*"]
    for a side left open — ["conf|apt|opam"], ["absorbed|*|pip"]. *)
let band_key (k : T.coop) (native : Canary_store.package_manager option)
    (lang : Canary_store.package_manager option) : string =
  let pm = function None -> "*" | Some p -> Canary_store.string_of_pm p in
  String.concat ~sep:"|" [ T.code_of_coop k; pm native; pm lang ]

(** What a mechanism, a cooperation and the two package managers pick out
    among the concrete chains — the "canary runs this chain" line. *)
let runs_key m k native lang =
  Canary_mechanism.string_of_mechanism m ^ "|" ^ band_key k native lang

type t = {
  jn_instances : T.band_instance list;
  jn_cases : case list;
  jn_kinds : T.coop_band list;
      (** the drawable cooperation kinds some world realizes, each with its
          band over ALL its chains — the cooperation bar *)
  jn_bands : (string * T.coop_band) list;
      (** every choice of package managers some chain has, per kind *)
  jn_bridges : (string * string list) list;
      (** per such choice, the kinds of bridge its chains join through, as
          terms — what the "bridge package" node says under it *)
  jn_runs : (string * string list) list;  (** runs key → case ids *)
}

let of_projects (projects : (string * Canary_project_run.project_run) list) : t =
  let is = T.band_instances projects in
  let cs = cases_of is in
  let kinds =
    List.filter_map T.coop_catalogue ~f:(fun info ->
        if T.has_band info.T.co_kind then T.band_over is info.T.co_kind else None)
  in
  let opt_pms f k =
    None
    :: (List.filter_map is ~f:(fun i ->
            if Poly.equal (T.coop_of i.T.bi_topology) k then f i.T.bi_topology else None)
       |> List.dedup_and_sort ~compare:Poly.compare
       |> List.map ~f:Option.some)
  in
  let bands_with_bridges =
    List.concat_map kinds ~f:(fun b ->
        let k = b.T.cb_kind in
        List.concat_map (opt_pms T.native_pm_of k) ~f:(fun native ->
            List.filter_map (opt_pms T.lang_pm_of k) ~f:(fun lang ->
                Option.map (T.band_over ?native ?lang is k) ~f:(fun band ->
                    ( band_key k native lang,
                      band,
                      T.bridge_terms (T.instances_over ?native ?lang is k) )))))
  in
  let bands = List.map bands_with_bridges ~f:(fun (key, band, _) -> (key, band)) in
  let runs =
    List.concat_map cs ~f:(fun c ->
        let native, lang = case_pms c in
        let k = T.coop_of c.cs_topology in
        List.concat_map [ None; native ] ~f:(fun n ->
            List.map [ None; lang ] ~f:(fun l -> (runs_key c.cs_mechanism k n l, c.cs_id))))
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let run_keys = List.map runs ~f:fst |> List.dedup_and_sort ~compare:String.compare in
  { jn_instances = is;
    jn_cases = cs;
    jn_kinds = kinds;
    jn_bands = bands;
    jn_bridges = List.map bands_with_bridges ~f:(fun (key, _, terms) -> (key, terms));
    jn_runs =
      List.map run_keys ~f:(fun key ->
          (key, List.filter_map runs ~f:(fun (k, id) -> if String.equal k key then Some id else None)))
  }

(** A COOPERATION'S PACKAGE MANAGERS, as its button's subtitle (user,
    2026-09-24: "for the cooperation, can you also label the pm?"): the
    pairs its chains take, [language ↔ native], then any package manager
    a chain has on one side only and no pair names; ["no PM"] where no
    chain has one. *)
let pm_label (j : t) (k : T.coop) : string =
  let uniq l =
    List.fold l ~init:[] ~f:(fun acc x -> if List.mem acc x ~equal:Poly.equal then acc else acc @ [ x ])
  in
  let pairs =
    List.filter_map j.jn_instances ~f:(fun i ->
        if Poly.equal (T.coop_of i.T.bi_topology) k then
          Some (T.lang_pm_of i.T.bi_topology, T.native_pm_of i.T.bi_topology)
        else None)
    |> uniq
  in
  let both = List.filter_map pairs ~f:(function Some l, Some n -> Some (l, n) | _ -> None) in
  let named = List.concat_map both ~f:(fun (l, n) -> [ l; n ]) in
  let singles =
    List.filter_map pairs ~f:(function Some p, None | None, Some p -> Some p | _ -> None)
    |> List.filter ~f:(fun p -> not (List.mem named p ~equal:Poly.equal))
    |> uniq
  in
  let pm = Canary_store.string_of_pm in
  match List.map both ~f:(fun (l, n) -> pm l ^ " ↔ " ^ pm n) @ List.map singles ~f:pm with
  | [] -> "no PM"
  | parts -> String.concat ~sep:" · " parts

(** THE PACKAGE NODES A CHOICE IS ABOUT, highlighted when its button is
    clicked (user, 2026-09-24: "lightly highlight the related package
    nodes … to show those packages are related"):
    - a native-side package manager ships the NATIVE package;
    - a language-side one ships the BINDING package, and the BRIDGE package
      too where it defines bridges ([Canary_bridge.kinds_of_pm]: a conf
      package is an opam package);
    - a binding mechanism ships in the binding package;
    - a cooperation joins the package nodes its band keeps.
    Keyed [group|value], the way the panel's buttons are. *)
let package_nodes = [ "pkg_sys"; "bridge"; "pkg_lang" ]

let related (j : t) : (string * string list) list =
  let pm = Canary_store.string_of_pm in
  List.map (pms Native) ~f:(fun p -> ("ps|" ^ pm p, [ "pkg_sys" ]))
  @ List.map (pms Language) ~f:(fun p ->
        ( "pl|" ^ pm p,
          "pkg_lang"
          :: (if List.is_empty (Canary_bridge.kinds_of_pm p) then [] else [ "bridge" ]) ))
  @ List.map (variants ()) ~f:(fun v ->
        ("m|" ^ Canary_mechanism.string_of_mechanism v.T.av_mechanism, [ "pkg_lang" ]))
  @ List.map j.jn_kinds ~f:(fun b ->
        ( "k|" ^ T.code_of_coop b.T.cb_kind,
          List.filter package_nodes ~f:(fun n ->
              not (List.mem b.T.cb_hidden n ~equal:String.equal)) ))

(** The state the panel opens in: the first mechanism, with the package
    manager it depends on, and the first cooperation. *)
let default_choice (j : t) : string * string * string option =
  let m =
    match variants () with
    | v :: _ -> v.T.av_mechanism
    | [] -> Canary_mechanism.Cstubs
  in
  let k = match j.jn_kinds with b :: _ -> T.code_of_coop b.T.cb_kind | [] -> "" in
  let pl =
    match dependent_pms j.jn_cases m with
    | [ p ] -> Some (Canary_store.string_of_pm p)
    | _ -> None
  in
  (Canary_mechanism.string_of_mechanism m, k, pl)

(** What the default choice leaves out and greys — drawn into the page, so
    it opens right before any script runs. *)
let default_drawing (j : t) : string list * string list =
  let m, k, pl = default_choice j in
  let m_gone =
    List.find_map (variants ()) ~f:(fun v ->
        if String.equal (Canary_mechanism.string_of_mechanism v.T.av_mechanism) m then
          Some (T.with_edges v.T.av_hidden)
        else None)
    |> Option.value ~default:[]
  in
  let band =
    List.Assoc.find j.jn_bands (k ^ "|*|" ^ Option.value pl ~default:"*") ~equal:String.equal
  in
  match band with
  | None -> (m_gone, [])
  | Some b -> (m_gone @ T.with_edges b.T.cb_hidden, b.T.cb_dead)

let json (j : t) : Yojson.Basic.t =
  let strs l = `List (List.map l ~f:(fun s -> `String s)) in
  let pm_json = function
    | None -> `Null
    | Some p -> `String (Canary_store.string_of_pm p)
  in
  let m, k, pl = default_choice j in
  `Assoc
    [ ( "default",
        `Assoc
          [ ("m", `String m); ("k", `String k);
            ("pl", match pl with None -> `Null | Some p -> `String p) ] );
      ( "mechanisms",
        `Assoc
          (List.map (variants ()) ~f:(fun v ->
               ( Canary_mechanism.string_of_mechanism v.T.av_mechanism,
                 `Assoc
                   [ ("gone", strs (T.with_edges v.T.av_hidden));
                     ( "pms",
                       strs
                         (List.map (dependent_pms j.jn_cases v.T.av_mechanism)
                            ~f:Canary_store.string_of_pm) ) ] ))) );
      ( "kinds",
        `Assoc
          (List.map T.coop_catalogue ~f:(fun i ->
               ( T.code_of_coop i.T.co_kind,
                 `Assoc
                   [ ("name", `String i.T.co_name);
                     ("label", `String i.T.co_label);
                     ( "unbanded",
                       match T.no_band_because i.T.co_kind with
                       | None -> `Null
                       | Some why -> `String why ) ] ))) );
      ( "bands",
        `Assoc
          (List.map j.jn_bands ~f:(fun (key, b) ->
               ( key,
                 `Assoc
                   [ ("gone", strs (T.with_edges b.T.cb_hidden));
                     ("dead", strs b.T.cb_dead);
                     ("n", `Int b.T.cb_worlds);
                     ( "bridge",
                       strs
                         (Option.value ~default:[]
                            (List.Assoc.find j.jn_bridges key ~equal:String.equal)) ) ] )))
      );
      (* THE PACKAGE MANAGERS' TERMS for the package layer's two
         in-between nodes (user, 2026-09-24): the capability file a
         manager's package ships, from the PM-solo table, and the bridge
         kinds it defines, from [Canary_bridge] *)
      ( "pm_terms",
        `Assoc
          (List.map Canary_pm_solo.table ~f:(fun r ->
               let pm = r.Canary_pm_solo.ps_pm in
               ( Canary_store.string_of_pm pm,
                 `Assoc
                   [ ("cap", `String r.Canary_pm_solo.ps_capability);
                     ("bridges", strs (List.map (Canary_bridge.kinds_defined pm) ~f:fst)) ] )))
      );
      (* whose capability file the native side shows while no system
         package manager is chosen: this platform's *)
      ( "sys_pm",
        `String
          (Canary_store.string_of_pm
             (Canary_store.system_pm_of_platform (Canary_store.platform ()))) );
      ( "cases",
        `List
          (List.map j.jn_cases ~f:(fun c ->
               let native, lang = case_pms c in
               `Assoc
                 [ ("id", `String c.cs_id);
                   ("project", `String c.cs_project);
                   ("lang", `String (Canary_lang.string_of_lang c.cs_lang));
                   ("m", `String (Canary_mechanism.string_of_mechanism c.cs_mechanism));
                   ("k", `String (T.code_of_coop (T.coop_of c.cs_topology)));
                   ("ps", pm_json native);
                   ("pl", pm_json lang);
                   ("gone", strs (T.with_edges c.cs_band.T.cb_hidden));
                   ("dead", strs c.cs_band.T.cb_dead);
                   ("bridge", strs c.cs_bridges);
                   ( "names",
                     `Assoc (List.map c.cs_names ~f:(fun (n, l) -> (n, `String l))) );
                   ( "names_src",
                     `Assoc
                       (List.map c.cs_name_sources ~f:(fun (n, s) ->
                            (n, Canary_overview_runs.json_of_source s))) ) ])) );
      (* WHERE THE GENERIC CHOICES' LINES COME FROM (2026-09-24) — every
         value the script writes under a node while no package is chosen.
         A chosen package's names carry their own ([names_src]), and a
         recorded run's theirs ([name_sources], [place_sources]) *)
      ( "sources",
        let src what at = Canary_overview_runs.(json_of_source (from_code what at)) in
        `Assoc
          [ ( "pm_choice",
              src "the package manager chosen, by a click or by the page's default: one of those canary has a driver for, on the side its scope puts it"
                "Canary_overview_join.pms; the default, default_choice" );
            ( "cap_term",
              src "what the native side's package manager calls its capability file (this platform's, while none is chosen)"
                "Canary_pm_solo.table (ps_capability)" );
            ( "bridge_term",
              src "the kinds of bridge the gates of the chains drawn name"
                "Canary_topology.bridge_terms → Canary_bridge.kind_term" );
            ( "bridge_term_pm",
              src "the kinds of bridge the language side's package manager defines"
                "Canary_bridge.kinds_defined" ) ] );
      ("runs", `Assoc (List.map j.jn_runs ~f:(fun (key, ids) -> (key, strs ids))));
      ("related", `Assoc (List.map (related j) ~f:(fun (key, ns) -> (key, strs ns)))) ]
