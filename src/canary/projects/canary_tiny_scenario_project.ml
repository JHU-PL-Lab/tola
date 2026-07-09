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
    [doc/canary/design/tiny.md] §"Two orthogonal axes:
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
    join. See [doc/canary/design/tiny.md]
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

(** Does the scenario's perturbation produce a probe-observable
    manifestation? [Unknown_gap] means no — the derived
    expectation returns [Expect_success] everywhere (canary
    runs to completion; nothing is asserted).

    Cases with no manifestation:
    - positive coverage (Pc entries): [perturbation = None]
    - detection gap Bs entries (Bs.6 c8-dormant,
      Bs.13 c7-static-only): [manifest = Unknown_gap] *)
let has_probe_manifestation (scenario : Canary_scenario.scenario) : bool =
  match scenario.perturbation with
  | None -> false
  | Some { manifest = Unknown_gap; _ } -> false
  | Some _ -> true

(** Derive an [expectation] function from the entry's
    [recipe.violates], languages, and manifest.

    Uniform: entries with no probe manifestation
    ([has_probe_manifestation = false]) return
    [Expect_success] for every rule — same behaviour as calling
    [make_base_script_spec] with no override. Otherwise, per
    rule:

    - At [Build_binding lang] scoped to [scenario_langs], fire
      c6 if violated.
    - At [Probe (Binding lang)] scoped to [scenario_langs],
      try compat contracts first (first match wins); else
      [Expect_failure { contains_any = ["FAIL "] }] if any
      behavioural contract is violated; else [Expect_success].

    Compat-before-behavioural priority matters when a recipe
    mixes both (e.g., type_wrong = c6+c3); once c6 is derived,
    the compat side wins. *)
let expectation_of_entry (entry : Canary_tiny_scenario.entry)
  : Canary_basic.rule -> Canary_store.location option ->
    Canary_step_model.step_expectation
  =
  let open Base in
  let module CC = Canary_compat in
  let scenario_langs = langs_of_scenario entry.scenario in
  let violates = entry.recipe.violates in
  let has_manifest = has_probe_manifestation entry.scenario in
  let expect_failure_shape =
    List.exists violates ~f:is_expect_failure_contract in
  let violates_c6 =
    List.mem violates CC.C6 ~equal:Poly.equal in
  fun rule _loc ->
    (* No probe manifestation → nothing to assert; every rule
       returns Expect_success. Same behaviour as calling
       make_base_script_spec without an expectation override. *)
    if not has_manifest then Expect_success
    else match rule with
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

(** Build the script_spec for a scenario. Uniform code path:
    base spec with expectation derived from the entry.
    Entries without a probe manifestation get
    [Expect_success] uniformly (see [has_probe_manifestation]
    inside [expectation_of_entry]) — equivalent to no
    override at all. *)
let script_spec_of_entry
    ~(perturbed_stores : Canary_project_tiny.tiny_stores)
    (entry : Canary_tiny_scenario.entry)
  : Canary_step_builder.script_spec
  =
  let stores = stores_of_entry ~stores:perturbed_stores entry in
  { (Canary_project_tiny.make_base_script_spec ~stores ()) with
    expectation = expectation_of_entry entry;
  }

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
