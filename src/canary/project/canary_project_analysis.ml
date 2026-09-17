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
    spec and hands on a richer value, and the branch folds into it. *)

open Base

type t = {
  an_project : string;
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
  an_carries : (Canary_lang.lang * string list) list;
      (** and the POSITIVE form, which is what selection wants: the
          agreements whose methods this project can carry, per language.
          Derived from the same question so the two cannot disagree *)
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
    answer, computed once. *)
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

(** THE PASS. Pure: it reads declarations and the registry, and touches
    no world, no workspace and no disk. *)
let of_project_run (pr : Canary_project_run.project_run) : t =
  let declared = declared_api_of pr in
  let langs = langs_of pr in
  let mechanisms = List.map langs ~f:(fun l -> (l, mechanism_of pr l)) in
  let unsuited =
    List.concat_map mechanisms ~f:(fun (lang, mechanism) ->
        Canary_agreement.unsuited_here ~mechanism ~lang ~declared)
    |> List.dedup_and_sort ~compare:Poly.compare
  in
  let carries =
    List.map mechanisms ~f:(fun (lang, mechanism) ->
        ( lang,
          List.filter_map Canary_agreement.agreement_registry ~f:(fun r ->
              (* the same two filters the result table's columns use:
                 a method with no evaluator reports not_implemented
                 forever, and one this project cannot carry reports
                 not_applicable forever — neither is coverage *)
              let usable =
                List.exists
                  r.Canary_agreement.ag.Canary_agreement_common.ag_methods
                  ~f:(fun m ->
                    Option.is_some m.Canary_agreement_common.m_eval
                    && Canary_agreement.suits_here ~mechanism ~lang ~declared m)
              in
              if usable && r.Canary_agreement.ag_enabled then
                Some r.Canary_agreement.ag_slug
              else None) ))
  in
  { an_project = pr.Canary_project_run.pr_name;
    an_declared = declared;
    an_mechanisms = mechanisms;
    an_unsuited = unsuited;
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
