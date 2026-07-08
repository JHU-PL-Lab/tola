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
  | _ -> None

(** Derive an [expectation] function from the entry's
    [recipe.violates] contract list, scoped by the scenario's
    languages.

    Structure (following user 2026-07-08: outer=scenario,
    inner=contract):
    - At every [Probe (Binding lang)] step whose [lang] is in
      the scenario's language set,
    - find the first contract in [recipe.violates] that
      yields inputs for [lang] via
      [compat_inputs_of_contract], and
    - emit [Expect_compat_failure] with those inputs.

    Contracts without coverage or probes in other languages
    fall through to [Expect_success]. *)
let expectation_of_entry (entry : Canary_tiny_scenario.entry)
  : Canary_basic.rule -> Canary_store.location option ->
    Canary_step_model.step_expectation
  =
  let open Base in
  let scenario_langs = langs_of_scenario entry.scenario in
  let violates = entry.recipe.violates in
  fun rule _loc ->
    match rule with
    | Canary_basic.Probe (Binding lang)
      when List.mem scenario_langs lang ~equal:Poly.equal ->
      (match
         List.find_map violates
           ~f:(fun c -> compat_inputs_of_contract ~lang c)
       with
       | Some inputs ->
         Expect_compat_failure { inputs; version_info = None }
       | None -> Expect_success)
    | _ -> Expect_success

(** Is a recipe covered by the structural derivation today?

    Returns [true] when every contract in [recipe.violates]
    has a case in {!expectation_of_recipe}. Used by
    {!script_spec_of_entry} to decide whether to derive or
    fall back to the hand-coded helper. *)
let recipe_is_derivable (recipe : Canary_tiny_scenario.tiny_recipe) : bool =
  let module CC = Canary_compat in
  let covered = function CC.C1 | CC.C2 -> true | _ -> false in
  (not (Base.List.is_empty recipe.violates))
  && Base.List.for_all recipe.violates ~f:covered

let script_spec_of_entry
    ~(perturbed_stores : Canary_project_tiny.tiny_stores)
    (entry : Canary_tiny_scenario.entry)
  : Canary_step_builder.script_spec
  =
  if recipe_is_derivable entry.recipe then
    { (Canary_project_tiny.make_base_script_spec
         ~stores:perturbed_stores ())
      with
      expectation = expectation_of_entry entry;
    }
  else
    (* Fall back to hand-coded helpers by scenario name for
       contracts not yet derivable (c3..c8). Each case here
       is a candidate for future derivation; the list shrinks
       as [compat_inputs_of_contract] grows and as
       Expect_failure-shape derivation lands. *)
    let stores = perturbed_stores in
    let module CPT = Canary_project_tiny in
    match entry.scenario.name with
    | "abi_soname_bump" ->
      (* c4: soname mismatch. Perturbation renamed
         libtiny.so.1 -> libtiny.so.2.0 during prepare, so
         the workspace holds libtiny.so.2 — override the
         default lib_filename. *)
      let stores = { stores with lib_filename = "libtiny.so.2" } in
      CPT.make_lib_soname_bumped_script_spec ~stores
    | "behavior_silent" ->
      (* c3: behaviour diff surfaces at probe assertion. *)
      CPT.make_lib_behavior_broken_script_spec ~stores
    | "symbol_version_floor" ->
      (* c5: versioned symbol requirements. *)
      CPT.make_lib_symbol_version_broken_script_spec ~stores
    | "header_arity_bump" ->
      (* c6: header arity change; catches at Build via
         typed-signature scan. *)
      CPT.make_binding_type_broken_script_spec ~stores
    | "type_wrong" ->
      (* violates c6+c3. Same-arity float-vs-int type diff
         isn't caught by the current c6 comparator (arity-
         only). Route through the c3 probe assertion — same
         Expect_failure shape as behavior_silent — since
         wrong-type calls produce wrong runtime output. *)
      CPT.make_lib_behavior_broken_script_spec ~stores
    | "api_repack" ->
      (* c7 OCaml: probe assertion catches the intra-binding
         argument-reversal. *)
      CPT.make_binding_repack_broken_script_spec ~stores
    | "api_repack_python" ->
      (* c7 Python: parallel to api_repack, on the cext /
         ctypes __init__.py side. *)
      CPT.make_binding_python_repack_broken_script_spec ~stores
    | "api_faithful"
    | "api_repack_stub_orphan"
    | "app_over_binding_ocaml"
    | "app_over_helper_ocaml" ->
      (* Positive coverage (Pc entries) or detection-gap
         scenarios (Bs.6 c8-dormant, Bs.13 c7-static-only).
         All step outcomes are Ok / Pass — no expectation
         override needed. Base spec runs to completion. *)
      CPT.make_base_script_spec ~stores ()
    | other ->
      Stdlib.failwith
        (Printf.sprintf
           "Canary_tiny_scenario_project: no dispatch for \
            scenario %S (dispatch table exhausted)"
           other)

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
