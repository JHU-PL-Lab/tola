(** [Canary_enumerate] — the shared abstract enumeration core (ssot §4.2).

    **One** enumeration algorithm over (provision assignment) × (mutation),
    product-then-filter. tiny and every general project are two orthogonal
    *projections* of the same product:

    - **tiny** = fix provision = all [Built], walk the mutation axis
      (§5's `Bs.N`).
    - **a general project** = fix mutation = none, walk the provision axis
      (its variants; ssl `sys` = all [Fetched], ssl `src` = all [Built]).

    This module is the enumeration algorithm. [run_config] instantiates it
    with a [config] — one [level] (`Free`/`Subset`/`Full`) per axis (ssot
    §4.2); [tiny_slice] and [general_slice] are the two canonical configs.
    Backing tiny's designed 22 and each project's variants
    out to *be* projections of this enumeration algorithm (replacing the two hand-written
    enumerations in `canary_scenario.ml` / the per-project variant lists) is
    the convergence named in §4.2 — a later round. For now the enumeration algorithm stands
    alongside them, with tests pinning each projection's shape.

    Separate file only while it stands alongside the hand-written
    enumerations: once the convergence lands (this enumeration algorithm backing both),
    **fold this into `canary_scenario.ml` (or a scenario util)** — it is the
    scenario-enumeration core and belongs beside the scenario types.

    The enumeration algorithm is **polymorphic in the mutation** (['m]): it is pure
    combinatorics — which artifacts are provided and from where, and which
    provided artifact is mutated — agnostic to what a mutation *means*. tiny
    supplies real mutations; a general project supplies none. *)

open Base

(* [provision] and [slot] are base vocabulary — defined in
   [Canary_store] / [Canary_basic] and re-exported here (constructor
   re-export keeps existing [Canary_enumerate.Built] / [.Slot_source]
   references working). See those base modules for the docs. *)
type provision = Canary_store.provision =
  | Absent | Fetched | Built | Vendored
[@@deriving show, eq]

type slot = Canary_basic.slot =
  | Slot_source | Slot_lib | Slot_binding of Canary_lang.lang
[@@deriving show, eq]

let string_of_slot = Canary_basic.string_of_slot

(** A provision assignment: one provision per slot. *)
type assignment = (slot * provision) list

(** One point of the scenario space: a provision assignment plus an optional
    mutation on one *provided* slot ([None] = the positive scenario). *)
type 'm point = { assignment : assignment; mutation : (slot * 'm) option }

let provision_of (a : assignment) (s : slot) : provision =
  List.Assoc.find a s ~equal:equal_slot |> Option.value ~default:Absent

let provided (a : assignment) (s : slot) : bool =
  not (equal_provision (provision_of a s) Absent)

(** Dependency filter (product-then-filter, §4.2): a lib [Built] from source
    needs the source present; any provided binding needs the lib present. *)
let assignment_ok (a : assignment) : bool =
  let lib = provision_of a Slot_lib in
  (not (equal_provision lib Built) || provided a Slot_source)
  && List.for_all a ~f:(fun (s, pv) ->
         match s with
         | Slot_binding _ -> equal_provision pv Absent || provided a Slot_lib
         | _ -> true)

(* The product of provision assignments over [slots] × [provisions]. *)
let rec assignments_of (slots : slot list) (provisions : provision list) :
    assignment list =
  match slots with
  | [] -> [ [] ]
  | s :: rest ->
      let tails = assignments_of rest provisions in
      List.concat_map provisions ~f:(fun pv ->
          List.map tails ~f:(fun t -> (s, pv) :: t))

(** The full enumeration algorithm: the product of *valid* provision assignments ×
    (positive + each applicable mutation). A mutation is applicable to an
    assignment only when its target slot is provided (§4.2: "a mutation
    applies only to a provided artifact"). *)
let enumerate ~(slots : slot list) ~(provisions : provision list)
    ~(mutations : (slot * 'm) list) : 'm point list =
  assignments_of slots provisions
  |> List.filter ~f:assignment_ok
  |> List.concat_map ~f:(fun a ->
         let positive = { assignment = a; mutation = None } in
         let muts =
           List.filter_map mutations ~f:(fun (s, m) ->
               if provided a s then Some { assignment = a; mutation = Some (s, m) }
               else None)
         in
         positive :: muts)

(** How much of an axis a config expands (ssot §4.2): [Free] collapses to
    one representative; [Subset] is a curated list; [Full] is every value. *)
type 'a level = Free | Subset of 'a list | Full

(** A config assigns one [level] per axis. Instantiating the algorithm with
    a config yields a project's concrete scenarios (ssot §4.2 — "every use
    is one config"). Today the ranged axes are provision and mutation;
    version / mechanism / app-wiring are axes still to add, each becoming a
    field here. *)
type 'm config = {
  provision : provision level;
  mutation : (slot * 'm) level;
}

(** Instantiate the algorithm with a config, given each axis's universe (its
    full value set). Provision [Free] = one representative (the head of
    [all_provisions] — a project orders its universe so the representative
    is first); mutation [Free] = the [None] baseline, i.e. no injected fault
    (the positive point is always present), so it resolves to no placements. *)
let run_config ~(slots : slot list) ~(all_provisions : provision list)
    ~(all_mutations : (slot * 'm) list) (cfg : 'm config) : 'm point list =
  let provisions =
    match cfg.provision with
    | Free -> ( match all_provisions with x :: _ -> [ x ] | [] -> [] )
    | Subset vs -> vs
    | Full -> all_provisions
  in
  let mutations =
    match cfg.mutation with
    | Free -> []  (* the None baseline — positive point only *)
    | Subset vs -> vs
    | Full -> all_mutations
  in
  enumerate ~slots ~provisions ~mutations

(** tiny's config: provision [Free] (collapse to one representative,
    [Built] — the whole pipeline built locally), mutation [Full] (walk every
    defect). Source-[Built] here just means "present locally" — the source
    is the pipeline root, its provision degenerate. *)
let tiny_slice ~(slots : slot list) ~(mutations : (slot * 'm) list) :
    'm point list =
  run_config ~slots ~all_provisions:[ Built ] ~all_mutations:mutations
    { provision = Free; mutation = Full }

(** A general project's config: provision [Full] (walk the provision axis
    over the project's universe), mutation [Free] (positive only). Yields
    one positive point per valid provision assignment (ssl `sys` = all
    [Fetched], ssl `src` = all [Built], … among them). *)
let general_slice ~(slots : slot list) ~(provisions : provision list) :
    'm point list =
  run_config ~slots ~all_provisions:provisions ~all_mutations:[]
    { provision = Full; mutation = Free }

let string_of_provision = Canary_store.string_of_provision

(** Read a slot's provision off a concrete action set (which action-graph
    verbs a variant runs): [Build_*] ⇒ [Built], [Fetch _] ⇒ [Fetched], else
    [Absent]. This is the inverse of §6.5's "provision decides which actions
    run" — recovering the provision coordinate from a variant's steps, so a
    general project's hand-written variants can be rendered as enumeration algorithm
    assignments. *)
let provision_of_actions (acts : Canary_basic.action list) (s : slot) :
    provision =
  let has a = List.mem acts a ~equal:Poly.equal in
  match s with
  | Slot_source -> if has (Canary_basic.Fetch Canary_basic.Source) then Fetched else Absent
  | Slot_lib ->
      if has Canary_basic.Build_lib then Built
      else if has (Canary_basic.Fetch Canary_basic.Lib) then Fetched
      else Absent
  | Slot_binding l ->
      if has (Canary_basic.Build_binding l) then Built
      else if has (Canary_basic.Fetch (Canary_basic.Binding l)) then Fetched
      else Absent

(** The provision assignment a variant's action set implies (one provision
    per slot, via [provision_of_actions]). *)
let assignment_of_actions ~(slots : slot list)
    (acts : Canary_basic.action list) : assignment =
  List.map slots ~f:(fun s -> (s, provision_of_actions acts s))

(** Pretty an assignment as "source=fetched lib=built binding:ocaml=built". *)
let string_of_assignment (a : assignment) : string =
  String.concat ~sep:" "
    (List.map a ~f:(fun (s, pv) ->
         string_of_slot s ^ "=" ^ string_of_provision pv))
