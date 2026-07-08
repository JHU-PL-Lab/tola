(** A2-with-factory prototype (Task 1.6, P1 path).

    Given a {!Canary_tiny_scenario.entry} and its perturbed
    stores, produce a {!Canary_step_builder.script_spec} that
    canary can run as its own project — one scenario, one
    project spec, no multi-variant fanning.

    Now attempting structural derivation: the [expectation]
    field is computed from [recipe.violates] instead of
    dispatched from a hand-coded helper. Base spec still
    comes from {!Canary_project_tiny.make_base_script_spec};
    only the expectation gets replaced.

    Coverage today (structural):
    - c1 (Contract 1, cmp_symbol): Probe (Binding lang) fires
      [Expect_compat_failure] with C_stub + Native_lib inputs.

    Falls back to hand-coded helper for scenarios whose
    contracts aren't derived yet (currently: everything
    except c1-only recipes). Grows one contract at a time.

    Not yet doing:
    - baseline store synthesis (relies on [tiny-scenarios
      prepare] outputs, as today).
*)

(** Language set a scenario's contracts should fire at.

    Derived from [scenario.belongs_to] — the Good scenarios
    the entry attributes to. Suffix rule:
    - [Sc.N] (no suffix) = shared → both OCaml and Python
    - [Sc.N.OCaml] → OCaml only
    - [Sc.N.Python] → Python only

    Union over multiple [belongs_to] entries. Rationale in
    [doc/canary/design/derivation.md] §"Two orthogonal axes:
    contract × language." *)
let langs_of_scenario (scenario : Canary_scenario.scenario)
  : Canary_lang.lang list =
  let open Base in
  let lang_of_id id =
    if String.is_suffix id ~suffix:".OCaml" then [ Canary_lang.OCaml ]
    else if String.is_suffix id ~suffix:".Python" then [ Canary_lang.Python ]
    else [ Canary_lang.OCaml; Canary_lang.Python ]
  in
  scenario.belongs_to
  |> List.concat_map ~f:lang_of_id
  |> List.dedup_and_sort ~compare:Poly.compare

(** Per-contract inputs for [Expect_compat_failure], scoped
    to a language. Returns [None] if the contract has no
    coverage for that language (e.g. c2 is lang-specific).

    Contracts covered today: c1, c2. Grow as new scenarios
    join. See [doc/canary/design/derivation.md]
    §"Per-contract inputs" for the full table. *)
let compat_inputs_of_contract ~(lang : Canary_lang.lang)
  : Canary_compat.contract_id -> Canary_compat.inspect_input list option
  =
  let module CC = Canary_compat in
  function
  | CC.C1 ->
    let lang_dir = Canary_lang.string_of_lang lang in
    Some CC.[
      C_stub
        [ Printf.sprintf "build_binding_%s/inspect.json" lang_dir ];
      Native_lib [ "build_lib/inspect.json" ];
    ]
  | CC.C2 ->
    (match lang with
     | Canary_lang.OCaml ->
       Some CC.[ Ocaml_mli
                   [ "build_binding_ocaml/inspect_mli.json" ] ]
     | Canary_lang.Python ->
       Some CC.[ Python_attrs
                   [ "build_binding_python/inspect_attrs.json" ] ]
     | _ -> None)
  | CC.C4 ->
    (* Tiny store convention: only Python cext is cached from
       baseline; OCaml binding rebuilds fresh each run and picks
       up the new SONAME. Only Python probe sees c4 fire. *)
    (match lang with
     | Canary_lang.Python ->
       Some CC.[
         Native_lib  [ "build_lib/inspect.json" ];
         Abi_surface [ "build_binding_python/inspect.json" ];
       ]
     | _ -> None)
  | CC.C5 ->
    (* Same lang scope as c4 (same rebuild convention). Cached
       Python cext carries stale @VER references. *)
    (match lang with
     | Canary_lang.Python ->
       Some CC.[
         Versioned_exports [ "build_lib/inspect.json" ];
         Versioned_req     [ "build_binding_python/inspect.json" ];
       ]
     | _ -> None)
  | CC.C6 ->
    (* Only OCaml binding rebuilds against the perturbed header;
       cstub compile fails. Python cext cached — didn't see the
       header change. c6 fires at Build (Binding OCaml) primarily
       and cascades to Probe when dune rebuilds the same cstub. *)
    (match lang with
     | Canary_lang.OCaml ->
       Some CC.[
         Typed_header
           [ "scan_sources/inspect_typed_header.json" ];
         Typed_binding_stub
           [ "scan_sources/inspect_typed_binding_stub_ocaml.json" ];
       ]
     | _ -> None)
  | _ -> None

(** Is this contract detected by a probe assertion (behavioral
    shape) rather than a static comparator?

    c3 cmp_behavior and c7 cmp_api_repack fire when the probe
    exits with a "FAIL …" line. No inputs — the probe binary's
    own assertion is the check. Distinguished from
    [compat_inputs_of_contract] which returns inputs for
    static comparators (c1, c2, c4, c5, c6). *)
let is_expect_failure_contract = function
  | Canary_compat.C3 | Canary_compat.C7 -> true
  | _ -> false

(** Derive an [expectation] function from the entry's
    [recipe.violates] contract list, scoped by the scenario's
    languages.

    Structure (following user 2026-07-08: outer=scenario,
    inner=contract):
    - At every [Probe (Binding lang)] step whose [lang] is in
      the scenario's language set,
    - try compat contracts first: first violated contract in
      the list whose static comparator yields inputs for
      [lang] wins;
    - else if any violated contract is behavioural (c3/c7),
      emit [Expect_failure { contains_any = ["FAIL "] }];
    - else fall through to [Expect_success].

    Compat before behavioural: compat inputs give a specific
    predicted substring, more precise than the generic
    "FAIL " match. Only matters when a recipe mixes both
    kinds (e.g., type_wrong violates c6+c3); once c6 is
    derived, the compat side wins. *)
let expectation_of_entry (entry : Canary_tiny_scenario.entry)
  : Canary_basic.rule -> Canary_store.location option ->
    Canary_step_model.step_expectation
  =
  let open Base in
  let module CC = Canary_compat in
  let scenario_langs = langs_of_scenario entry.scenario in
  let violates = entry.recipe.violates in
  let expect_failure_shape =
    List.exists violates ~f:is_expect_failure_contract in
  let violates_c6 =
    List.mem violates CC.C6 ~equal:Poly.equal in
  fun rule _loc ->
    match rule with
    | Canary_basic.Build_binding lang
      when violates_c6
        && List.mem scenario_langs lang ~equal:Poly.equal ->
      (* c6 uniquely fires at Build (cstub compile fails
         against perturbed header) in addition to Probe.
         Other contracts don't fire at Build. *)
      (match compat_inputs_of_contract ~lang CC.C6 with
       | Some inputs ->
         Expect_compat_failure { inputs; version_info = None }
       | None -> Expect_success)
    | Canary_basic.Probe (Binding lang)
      when List.mem scenario_langs lang ~equal:Poly.equal ->
      (match
         List.find_map violates
           ~f:(fun c -> compat_inputs_of_contract ~lang c)
       with
       | Some inputs ->
         Expect_compat_failure { inputs; version_info = None }
       | None when expect_failure_shape ->
         Expect_failure {
           contains_any = [ "FAIL " ];
           version_info = None;
         }
       | None -> Expect_success)
    | _ -> Expect_success

(** Is a recipe covered by the structural derivation today?

    Returns [true] when every contract in [recipe.violates]
    has a case in {!expectation_of_recipe}. Used by
    {!script_spec_of_entry} to decide whether to derive or
    fall back to the hand-coded helper. *)
(** How is this entry routed through the factory?
    - [`Derived]   : goes through {!expectation_of_entry}
    - [`Dispatched]: falls back to a hand-coded helper
    - [`Base]      : no expectation override (positive /
                     detection-gap entries). *)
type route = [ `Derived | `Dispatched | `Base ]

let string_of_route = function
  | `Derived -> "derived"
  | `Dispatched -> "dispatched"
  | `Base -> "base"

(** Which contracts have a derivation case today. Grows as
    coverage lands. *)
let is_derivable_contract = function
  | Canary_compat.C1
  | Canary_compat.C2
  | Canary_compat.C4
  | Canary_compat.C5
  | Canary_compat.C6 -> true                     (* compat *)
  | Canary_compat.C3 | Canary_compat.C7 -> true  (* expect_failure *)
  | _ -> false

(** Does the scenario's perturbation produce a probe-observable
    manifestation? [Unknown_gap] means no — the derived
    expectation would misfire (canary would expect a FAIL that
    never comes). Base spec runs to completion. *)
let has_probe_manifestation (scenario : Canary_scenario.scenario) : bool =
  match scenario.perturbation with
  | None -> false  (* positive coverage: no perturbation *)
  | Some { manifest = Unknown_gap; _ } -> false
  | Some _ -> true

let route_of_entry (entry : Canary_tiny_scenario.entry) : route =
  let violates_derivable =
    Base.List.exists entry.recipe.violates ~f:is_derivable_contract
  in
  match has_probe_manifestation entry.scenario, violates_derivable with
  | true, true -> `Derived
  | false, _ -> `Base       (* Pc.* or Unknown_gap Bs.* *)
  | true, false -> `Dispatched

(* [recipe_is_derivable] retained for backwards compat with
   [script_spec_of_entry]; superseded by [route_of_entry].
   TODO: drop once all callers switch to [route_of_entry]. *)
let recipe_is_derivable (recipe : Canary_tiny_scenario.tiny_recipe) : bool =
  Base.List.exists recipe.violates ~f:is_derivable_contract

(** Derive tiny_stores adjustments from the recipe's concrete
    perturbation. Today only Soname_bump needs it: prepare
    renames the .so to a new SONAME (e.g. [libtiny.so.2.0]),
    and the runtime symlink canary probes is the MAJOR name
    ([libtiny.so.2]). Strip trailing ".<minor>" digits when
    both the last two dotted segments are numeric. *)
let stores_of_entry
    ~(stores : Canary_project_tiny.tiny_stores)
    (entry : Canary_tiny_scenario.entry)
  : Canary_project_tiny.tiny_stores
  =
  let open Base in
  let is_all_digits s =
    (not (String.is_empty s))
    && String.for_all s ~f:Char.is_digit
  in
  let strip_trailing_minor s =
    match List.rev (String.split ~on:'.' s) with
    | last :: (second :: _ as rest_rev)
      when is_all_digits last && is_all_digits second ->
      String.concat ~sep:"." (List.rev rest_rev)
    | _ -> s
  in
  match entry.recipe.perturbation with
  | Some (Canary_tiny_scenario.Soname_bump { to_so; _ }) ->
    { stores with lib_filename = strip_trailing_minor to_so }
  | _ -> stores

let script_spec_of_entry
    ~(perturbed_stores : Canary_project_tiny.tiny_stores)
    (entry : Canary_tiny_scenario.entry)
  : Canary_step_builder.script_spec
  =
  let stores = stores_of_entry ~stores:perturbed_stores entry in
  match route_of_entry entry with
  | `Derived ->
    { (Canary_project_tiny.make_base_script_spec
         ~stores ())
      with
      expectation = expectation_of_entry entry;
    }
  | `Base ->
    (* Positive coverage (Pc entries) or detection-gap
       scenarios (Bs.6 c8-dormant, Bs.13 c7-static-only).
       All step outcomes are Ok / Pass — no expectation
       override needed. Base spec runs to completion. *)
    Canary_project_tiny.make_base_script_spec
      ~stores:perturbed_stores ()
  | `Dispatched ->
    (* No dispatch fallbacks left today — all covered
       contracts have derivation cases. If a new scenario
       lands with an unfamiliar violates set, arrive here
       for a clear error. Once every contract is derivable
       this branch becomes unreachable and can be dropped
       along with the [`Dispatched] tag on {!route}. *)
    Stdlib.failwith
      (Printf.sprintf
         "Canary_tiny_scenario_project: %S needs a dispatch \
          fallback, but the dispatch table is empty. Grow \
          compat_inputs_of_contract or the Expect_failure \
          branch instead."
         entry.scenario.name)

(** Convenience: look up the entry by scenario name and build
    the spec. Raises via [name_of_string] on unknown names. *)
let script_spec_of_name
    ~(perturbed_stores : Canary_project_tiny.tiny_stores)
    (name : string)
  : Canary_step_builder.script_spec
  =
  let name = Canary_tiny_scenario.name_of_string name in
  match Canary_tiny_scenario.find_by_name name with
  | Some entry -> script_spec_of_entry ~perturbed_stores entry
  | None ->
    Stdlib.failwith
      (Printf.sprintf
         "Canary_tiny_scenario_project: no entry with name %S" name)
