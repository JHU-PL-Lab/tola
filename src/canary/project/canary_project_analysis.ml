(** Pass 2 — ANALYSE: what canary understands about a project, as a
    value (2026-09-16, user).

    A project author writes a [project_run]: artifact rows, binding
    declarations, an api_source, command templates. That is the RAW
    spec, and it is deliberately flexible. What canary actually reasons
    with is a set of DERIVED facts over it — which claims this project
    can carry, what it declares it ships, which mechanism each language
    binds through. Until now those facts had no home: six functions
    computed one each, on demand, several of them per scenario.

    THE COST OF HAVING NO NAME FOR IT, measured. Two views of "which
    checks apply to this project" — [Canary_matrix]'s result columns and
    [Canary_check_index] — each derived the answer separately, and on
    2026-09-15 they DISAGREED: the index asked applicability with the
    project's first declared binding for every action, so sqlite's
    Python probe reported that nothing fires there while the result
    table carried five Python check columns and the run log had decided
    [api_names_present] on that step twelve times. Three views of one
    project, two answers. A pin now stops that instance. One value stops
    the class, which is what this is for.

    WHAT BELONGS HERE, and the rule is sharp: a fact that needs no
    WORLD. Applicability is [mechanism -> lang -> declared -> _] with no
    assignment, so it is knowable from the spec alone and belongs here.
    FIRING is [mechanism -> lang -> world -> _] and cannot be, so it
    stays at realize where a world exists. Putting firing here would
    mean inventing a world, which is the enumeration's job.

    NOT A SIBLING (2026-09-16, user: "can we do them in linear, so …
    every IR is clean"). The pass table already carried one unnumbered
    branch — [chain_applicable], "a real spec-only derivation that is
    neither a pass nor a dump" — and the enumeration README lists it
    among the accidents it wants redesigned away. Adding a second branch
    would have reproduced exactly that. This is a PASS: it takes the
    spec and hands on a richer value, and the branch folds into it —
    [an_chains] IS that branch, now a field of a numbered pass. *)

open Base

(** What ONE action touches, spelled in the project's own artifact
    identities rather than in coarse kinds.

    Two lists and not one, because the two are asked by different
    questions. A HOOK at `<action>_post` asks what the action just
    PRODUCED — that is the artifact there is now something new to say
    about. A precondition asks what it CONSUMES. The flat
    `artifacts_of_action` concatenates them, which is right for the
    diagram and wrong for a hook. *)
type touch = {
  tc_consumes : Canary_artifact.artifact_info list;
  tc_produces : Canary_artifact.artifact_info list;
}

type t = {
  an_project : string;
  an_spec : Canary_artifact.project_spec;
      (** pass 1's output, carried rather than recomputed. The pipeline
          is LINEAR: every pass hands the next everything it needs, so
          pass 3 reads the spec from here instead of asking the
          [project_run] again *)
  an_chains : Canary_basic.action_sig list list;
      (** the universal chains this spec admits — [chain_applicable]
          over the 38. Was the pass table's unnumbered *(branch)* row.
          `canary paths` prints the unfiltered 38 and nothing printed
          the per-project survivors; `canary emit <p> --stage analyse`
          now does *)
  an_declared : Canary_artifact.t option;
      (** what the project says it ships — the reference half of every
          declaration comparison. Was [Canary_pipeline.declared_api_of],
          read from the source repo's record with the project's own
          [pr_api_source] as fallback *)
  an_mechanisms : (Canary_lang.lang * Canary_mechanism.mechanism) list;
      (** one entry per language this project binds, from
          [pr_binding_decls]. A LIST, not a lookup function, because the
          consumers that got this wrong were the ones asking for a
          single answer and getting the first binding's *)
  an_unsuited : Canary_agreement.unsuited list;
      (** claims this project cannot carry, per language, with the
          reason. The negative form is what reports print *)
  an_touches : (Canary_basic.action * touch) list;
      (** THE JOIN: `artifacts_of_action` × the artifact declarations.
          For each action canary knows, which of THIS project's declared
          artifacts it consumes and produces. An action touching nothing
          declared is absent — it is not in this project's vocabulary.

          It is the missing half of the action model (2026-09-16, user).
          `consumes_of_action` answers in coarse KINDS (`Lib`,
          `Binding OCaml`); a project declares refined IDENTITIES
          (`A_lib (Some "crypto")`, `A_binding (OCaml, Cstubs)`). Nothing
          joined the two, so anything wanting "what did this action just
          make, and what do we know about it" had to guess — and the
          existing guess is `find_artifact_of_kind`, which takes the
          FIRST declared artifact of a kind and is already wrong for the
          multi-lib case `A_lib of string option` was landed for. *)
  an_carries : (Canary_lang.lang * string list) list;
      (** and the POSITIVE form, which is what selection wants: the
          agreements whose methods this project can carry, per language.
          Derived from the same question so the two cannot disagree.

          Keyed over the MODELLED languages, not the declared ones, and
          the two lists differ on purpose. [an_unsuited] is a report
          about this project — asking a one-binding project what its
          absent Python side cannot carry is the bug pass 2 fixed. This
          is a lookup table for consumers that ask about a language the
          CHAIN mentions, which the result table does for every project
          whose spec declares no binding at all. A language with no
          declared binding is answered with its default mechanism,
          which is what both consumers already did. *)
}

(** The languages a project binds, in declaration order. Falls back to
    the registry-wide pair when a project declares no binding at all —
    the same fallback [Canary_pipeline.langs] has always used, kept so
    that an undeclared project analyses rather than vanishing. *)
let langs_of (pr : Canary_project_run.project_run) : Canary_lang.lang list =
  match
    List.map pr.Canary_project_run.pr_binding_decls
      ~f:(fun (d : Canary_binding_decl.binding_decl) ->
        (Canary_mechanism.info_of_mechanism d.Canary_binding_decl.mechanism)
          .Canary_mechanism.mi_lang)
    |> List.dedup_and_sort ~compare:Poly.compare
  with
  | [] -> Canary_lang.[ OCaml; Python ]
  | ls -> ls

(** The mechanism a project binds a language through, or that language's
    default. Moved from [Canary_pipeline.mechanism_of_project] — same
    answer, computed once.

    ⚠ IT READS ONE OF TWO DECLARATIONS (found 2026-09-16, recorded in
    `project/issues.md` §2). A project may state its mechanism on
    [pr_binding_decls] — which this reads — or on the artifact table's
    [a_binding lang mech] row, which [Canary_opam_binding] fills from its
    own [binding_mechanism] while leaving [pr_binding_decls] EMPTY. So
    cairo, libffi, zlib and zstd declare a mechanism nothing here sees,
    and this answers with the language default: libffi declares [Ctypes]
    and is reported as [Cstubs].

    NOT fixed in place, deliberately. Reading the artifact table would
    flip four GREEN cells on libffi's result table to [not_applicable],
    because Ctypes carries none of the stub-reading claims — and whether
    that is a correction depends on whether `ctypes-foreign` (which DOES
    ship a compiled stub archive, unlike Python's ctypes) is a [Ctypes]
    binding by the catalogue's own predicates. That is a question about
    the mechanism catalogue, not about this function. *)
let mechanism_of (pr : Canary_project_run.project_run)
    (l : Canary_lang.lang) : Canary_mechanism.mechanism =
  match
    List.find pr.Canary_project_run.pr_binding_decls
      ~f:(fun (d : Canary_binding_decl.binding_decl) ->
        Poly.equal
          (Canary_mechanism.info_of_mechanism d.Canary_binding_decl.mechanism)
            .Canary_mechanism.mi_lang
          l)
  with
  | Some d -> d.Canary_binding_decl.mechanism
  | None -> Canary_mechanism.mechanism_of_lang_exn l

(** What the project declares it ships. The source repo's [api_source]
    wins over the project's own field, because a project with a source
    repo states it there and the fallback exists for the ones without. *)
let declared_api_of (pr : Canary_project_run.project_run) :
    Canary_artifact.t option =
  let from_source =
    List.find_map pr.Canary_project_run.pr_artifacts ~f:(fun d ->
        match Canary_project_spec.provider_of_row d with
        | Some (Canary_store_config.Repo r)
        | Some (Canary_store_config.Repo_axes (r :: _)) ->
            r.Canary_artifact_source.api_source
        | _ -> None)
  in
  match from_source with
  | Some _ -> from_source
  | None -> pr.Canary_project_run.pr_api_source

(** The languages canary MODELS a binding mechanism for. Not the
    languages a project declares ([an_mechanisms] is that): the
    consumers of [an_carries] ask about whichever language an ACTION
    names, and four registry projects declare no binding at all while
    their chains still carry OCaml actions. *)
let modelled_langs : Canary_lang.lang list =
  List.filter Canary_lang.[ Cpp; OCaml; Python; Rust; CSharp; Java ]
    ~f:(fun l ->
      Option.is_some (Canary_mechanism.default_mechanism_of_lang l))

(** THE APPLICABILITY QUESTION, asked once — can this project carry this
    METHOD, in this language? Every other applicability derivation in
    the tree is this function with different plumbing, and when two of
    them disagreed (2026-09-15, Python) it was because each had built
    its own [mechanism]/[declared] pair on the way in. *)
let suits_for ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(declared : Canary_artifact.t option)
    (m : Canary_agreement_common.checking_method) : bool =
  Canary_agreement.suits_here ~mechanism ~lang ~declared m

(** …and the agreement-level form the result table's columns want: the
    two filters that say a cell could never speak. A method with no
    evaluator reports [not_implemented] forever, one this project cannot
    carry reports [not_applicable] forever, and neither is coverage. *)
let carried_slugs ~(mechanism : Canary_mechanism.mechanism)
    ~(lang : Canary_lang.lang) ~(declared : Canary_artifact.t option) :
    string list =
  List.filter_map Canary_agreement.agreement_registry ~f:(fun r ->
      let usable =
        List.exists r.Canary_agreement.ag.Canary_agreement_common.ag_methods
          ~f:(fun m ->
            Option.is_some m.Canary_agreement_common.m_eval
            && suits_for ~mechanism ~lang ~declared m)
      in
      if usable && r.Canary_agreement.ag_enabled then
        Some r.Canary_agreement.ag_slug
      else None)

(** Every artifact this project declares of a coarse kind — a LIST,
    because a kind may name several identities.

    `Canary_enumerate.find_artifact_of_kind` is the existing answer and
    it returns the FIRST. That was a fair simplification while every
    project had one lib and one binding per language; `A_lib of string
    option` (2026-08-25, multi_lib step 1) is the declaration that
    breaks it, and this is the shape that will not have to change when
    a second lib lands. *)
let declared_of_kind (s : Canary_artifact.project_spec)
    (k : Canary_basic.artifact_kind) : Canary_artifact.artifact_info list =
  List.filter (Canary_artifact.ps_artifacts s) ~f:(fun i ->
      Poly.equal (Canary_artifact.kind_of i) k)

(** THE JOIN. For every action in the catalogue over [langs], what this
    project's DECLARATIONS say it touches.

    An action with nothing declared on either side is dropped: it is not
    in this project's vocabulary, and saying so by ABSENCE rather than
    by an empty record is what lets a consumer iterate the list instead
    of filtering it. Note an action can legitimately have an empty
    [tc_produces] and still belong — every `Probe_*` does, because a
    probe verifies and creates nothing. *)
let touches_of (s : Canary_artifact.project_spec)
    (langs : Canary_lang.lang list) :
    (Canary_basic.action * touch) list =
  List.filter_map (Canary_basic.store_actions ~langs) ~f:(fun a ->
      let of_kinds ks = List.concat_map ks ~f:(declared_of_kind s) in
      let tc_consumes = of_kinds (Canary_action.consumes_of_action a) in
      let tc_produces = of_kinds (Canary_action.produces_of_action a) in
      if List.is_empty tc_consumes && List.is_empty tc_produces then None
      else Some (a, { tc_consumes; tc_produces }))

(** THE PASS. Pure: it reads declarations and the registry, and touches
    no world, no workspace and no disk. *)
let of_project_run (pr : Canary_project_run.project_run) : t =
  let declared = declared_api_of pr in
  let spec =
    Canary_project_spec.project_spec_of_rows
      pr.Canary_project_run.pr_artifacts
  in
  let langs = langs_of pr in
  let mechanisms = List.map langs ~f:(fun l -> (l, mechanism_of pr l)) in
  let unsuited =
    List.concat_map mechanisms ~f:(fun (lang, mechanism) ->
        Canary_agreement.unsuited_here ~mechanism ~lang ~declared)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let carries =
    List.map modelled_langs ~f:(fun lang ->
        (lang, carried_slugs ~mechanism:(mechanism_of pr lang) ~lang ~declared))
  in
  { an_project = pr.Canary_project_run.pr_name;
    an_spec = spec;
    an_chains = Canary_enumerate.applicable_chains spec;
    an_declared = declared;
    an_mechanisms = mechanisms;
    an_unsuited = unsuited;
    (* over the MODELLED languages, like [an_carries] and for the same
       reason: an action names a language whether or not this project
       declared a binding for it, and a consumer asking about
       `probe_binding_python` wants an answer rather than a hole *)
    an_touches = touches_of spec modelled_langs;
    an_carries = carries }

(* ── asking the analysed spec things ── *)

(** Can this project carry this agreement, in this language? THE
    question both views were answering separately. *)
let carries (t : t) ~(lang : Canary_lang.lang) (slug : string) : bool =
  match List.Assoc.find t.an_carries lang ~equal:Poly.equal with
  | None -> false
  | Some slugs -> List.mem slugs slug ~equal:String.equal

(** …in ANY language it binds. The result table asks this for a
    lib-side column, which no language owns. *)
let carries_anywhere (t : t) (slug : string) : bool =
  List.exists t.an_carries ~f:(fun (_, slugs) ->
      List.mem slugs slug ~equal:String.equal)

let mechanism_for (t : t) (l : Canary_lang.lang) : Canary_mechanism.mechanism =
  match List.Assoc.find t.an_mechanisms l ~equal:Poly.equal with
  | Some m -> m
  | None -> Canary_mechanism.mechanism_of_lang_exn l

(** Can this project carry this METHOD, in this language? The finer
    question behind {!carries}, for the consumer that counts methods
    rather than rows — an agreement can reach an action through one
    method and not another.

    Asking it HERE is the point: the mechanism and the declaration come
    off the analysed spec, so a caller cannot supply its own pair. That
    is precisely how [Canary_matrix] came to ask z3's Python probe with
    [Cext] (the language default) while [Canary_check_index] asked it
    with [Ctypes] (what z3 declares). *)
let suits (t : t) ~(lang : Canary_lang.lang)
    (m : Canary_agreement_common.checking_method) : bool =
  suits_for ~mechanism:(mechanism_for t lang) ~lang ~declared:t.an_declared m

(** The languages this project DECLARES a binding for, in declaration
    order. *)
let langs (t : t) : Canary_lang.lang list = List.map t.an_mechanisms ~f:fst

(** What this action touches here, or [None] if it touches nothing this
    project declares — which is the same as saying the action is not
    part of this project. *)
let touches (t : t) (a : Canary_basic.action) : touch option =
  List.Assoc.find t.an_touches a ~equal:Poly.equal

(** The artifacts an action PRODUCES here. THE HOOK'S QUESTION
    (2026-09-16, user): `<action>_post` is a trigger MOMENT, not a
    specification of what runs at it, and what should run is derived
    from what the action just made. A lib inspection is the same
    inspection whether the lib arrived via `build_lib`, `fetch_lib` or a
    package that happens to contain one; what differs is only where it
    is. Asking this from the INVOKING side is what makes that one
    answer instead of three hand-placed ones.

    Empty for every `Probe_*` — they produce nothing — which is the
    typed statement of why a probe cannot be the place an artifact's
    evidence is first recorded. *)
let produced_at (t : t) (a : Canary_basic.action) :
    Canary_artifact.artifact_info list =
  match touches t a with None -> [] | Some tc -> tc.tc_produces

(** The actions that PRODUCE this artifact here — the hook question read
    backwards, and the one a check asks: "where could my evidence come
    from?" More than one is normal and is the point: a lib is produced
    by `build_lib` in a Built world, `fetch_lib` in a Fetched one and
    `install_lib` in an Installed one, and a check that needs the lib
    should be able to attach at whichever of them this world runs. *)
let producers_of (t : t) (id : Canary_artifact.artifact_info) :
    Canary_basic.action list =
  List.filter_map t.an_touches ~f:(fun (a, tc) ->
      if
        List.exists tc.tc_produces ~f:(fun i ->
            String.equal
              (Canary_artifact.string_of_id i)
              (Canary_artifact.string_of_id id))
      then Some a
      else None)
