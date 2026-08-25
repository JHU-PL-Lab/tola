(* ── Static spec-maturity audit (2026-08-13, `canary spec-check`) ──

   Audits a registry project's DECLARED spec against the mismatch-matrix
   readiness checklist (the term was "three-version report" until
   2026-08-19; the axis is a per-artifact CHANNEL PAIR — stable + latest —
   and the fork is a fix vehicle, not a third version. See
   design/enumeration/stage1_declare_spec.md). PURELY STATIC: reads only [project_run.pr_artifacts]
   (rows: identity, axes, providers) + [pr_wrapper_pkgs]. No enumeration, no
   realization, no filesystem, no shell — runtime facts (a package renamed,
   a remote moved, actual probe results) belong to run status, not here.

   Non-uniformities that remain (recorded in
   doc/canary/project/issues.md §2), reported as-is, NOT
   special-cased in code:
   - z3/llvm source rows carry the STABLE repo's provider; per-channel (dev)
     source providers are the not-yet-wired provenance refinement.
   - tiny-full declares its api_source on [project_run.pr_api_source]
     (its source row is Vendored, not repo-carried) and is exempt from the
     reporting-oriented checks (in-tree witness).
   (The 2026-08-13 fulfillment round closed the others: pattern-A gained
   typed rows via [Canary_opam_binding.artifacts]; sqlite wired a source row +
   api_source; ssl declared the openssl repo.)

   Severity: Error = severe (blocks the report workflow — cannot run many
   tests / cannot fix / cannot report); Warn = nice-to-have missing. *)

open Base

type severity =
  | Error
  | Warn
  | Ok
  | Na

let string_of_severity = function
  | Error -> "error"
  | Warn -> "warn"
  | Ok -> "ok"
  | Na -> "n/a"

type item = {
  item_id : string;  (* stable ratchet key *)
  label : string;
  severity : severity;
  detail : string;
}

type report = { project : string; items : item list }

let errors_of (r : report) : item list =
  List.filter r.items ~f:(fun i -> Poly.equal i.severity Error)

let warns_of (r : report) : item list =
  List.filter r.items ~f:(fun i -> Poly.equal i.severity Warn)

let summary (r : report) : string =
  Printf.sprintf "%d error(s), %d warning(s)" (List.length (errors_of r))
    (List.length (warns_of r))

(* tiny-full: the in-tree witness — exempt from the reporting-oriented
   checks (github remote, opam package). Name-based: a provider-shape
   heuristic would wrongly exempt pattern-A projects (no providers at all). *)
let is_in_tree_witness (pr : Canary_project_run.project_run) : bool =
  String.equal pr.pr_name "tiny-full"

let row_of (pr : Canary_project_run.project_run)
    (id : Canary_artifact.artifact_info) :
    Canary_project_spec.artifact_row option =
  List.find pr.pr_artifacts ~f:(fun d ->
      Canary_artifact.equal_artifact_info d.Canary_project_spec.ar_artifact id)

let binding_rows (pr : Canary_project_run.project_run)
    (lang : Canary_lang.lang) : Canary_project_spec.artifact_row list =
  List.filter pr.pr_artifacts ~f:(fun d ->
      match Canary_artifact.kind_of d.Canary_project_spec.ar_artifact with
      | Canary_basic.Binding l -> Poly.equal l lang
      | _ -> false)

let has_built_axis (d : Canary_project_spec.artifact_row) : bool =
  List.exists
    d.Canary_project_spec.ar_axes.Canary_artifact.ax_universe
    ~f:(fun (provision, _) -> Poly.equal provision Canary_artifact.Built)

(* The declared source repo, wherever it is carried: ANY artifact row's
   [Repo]/[Repo_axes] provider (2026-08-15 unification — the axes'
   provision says what the repo provides). A [Repo_axes] family reports
   its STABLE repo (listed first) — the reporting-oriented checks
   (forge, api_source) read the official channel; z3/llvm/sqlite/ssl
   still carry a single [Repo] (their per-channel dispatch lives in the
   table rows — the C2 migration). *)
let source_repo_of (pr : Canary_project_run.project_run) :
    Canary_artifact_source.source_repo option =
  List.find_map pr.pr_artifacts ~f:(fun d ->
      match Canary_project_spec.provider_of_row d with
      | Some (Canary_store_config.Repo r) -> Some r
      | Some (Canary_store_config.Repo_axes (r :: _)) -> Some r
      | _ -> None)

(* ── the eight checks (checklist order) ── *)

let check_dev_source (pr : Canary_project_run.project_run) : item =
  let label = "dev source" in
  match row_of pr Canary_artifact.a_source with
  | Some d ->
      let detail =
        match Canary_project_spec.provider_of_row d with
        | Some p -> Canary_store_config.string_of_provider p
        | None -> "source row (no provider declared)"
      in
      { item_id = "dev_source"; label; severity = Ok; detail }
  | None -> (
      match source_repo_of pr with
      | Some r ->
          { item_id = "dev_source"; label; severity = Ok;
            detail =
              Printf.sprintf "built from source repo: %s (%s)"
                r.Canary_artifact_source.name
                (match r.Canary_artifact_source.remote with
                | Some (Canary_artifact_source.Git u) -> u
                | Some (Canary_artifact_source.Hg u) -> u
                | Some (Canary_artifact_source.Tar u) -> "archive: " ^ u
                | None -> "(no remote)")
          }
      | None ->
          { item_id = "dev_source"; label; severity = Error;
            detail = "no source row — cannot fix" })

let check_c_api (pr : Canary_project_run.project_run) : item =
  let label = "C API" in
  let api =
    match source_repo_of pr with
    | Some r -> r.Canary_artifact_source.api_source
    | None -> pr.pr_api_source
  in
  match api with
  | Some _ ->
      { item_id = "c_api"; label; severity = Ok;
        detail = "api_source declared (headers + watchlists)" }
  | None ->
      { item_id = "c_api"; label; severity = Error;
        detail = "api_source not declared — cannot run many tests" }

let check_github_remote (pr : Canary_project_run.project_run) : item =
  (* PUBLIC forge (2026-08-13, user): github.com OR gitlab.* — cairo's
     canonical host is gitlab.freedesktop.org (no official github mirror),
     and MRs are the report workflow there. Anything else (self-hosted
     tar-only projects like GMP) is still an error — no report path. *)
  let label = "public remote" in
  if is_in_tree_witness pr then
    { item_id = "github_remote"; label; severity = Na;
      detail = "n/a (in-tree witness)" }
  else
    let url =
      match source_repo_of pr with
      | Some r -> (
          match r.Canary_artifact_source.remote with
          | Some (Canary_artifact_source.Git u) -> Some u
          | Some (Canary_artifact_source.Hg u) -> Some u
          (* an archive source: declared, but no forge PR workflow — a
             warning-grade origin, like the local-only fork *)
          | Some (Canary_artifact_source.Tar _) -> None
          | None -> None)
      | None -> None
    in
    let is_archive =
      match source_repo_of pr with
      | Some r -> (
          match r.Canary_artifact_source.remote with
          | Some (Canary_artifact_source.Tar _) -> true
          | _ -> false)
      | None -> false
    in
    match url with
    | Some u
      when String.is_substring u ~substring:"github.com"
           || String.is_substring u ~substring:"gitlab." ->
        { item_id = "github_remote"; label; severity = Ok; detail = u }
    | Some u ->
        { item_id = "github_remote"; label; severity = Error;
          detail =
            Printf.sprintf "remote %s is not a public forge — cannot report" u }
    | None when is_archive ->
        (* an archive source (Tar): declared, but no forge PR workflow —
           report via the upstream's preferred channel. *)
        { item_id = "github_remote"; label; severity = Warn;
          detail = "archive source — no forge PR workflow" }
    | None -> (
        (* the user's fork rule (2026-08-15): a LOCAL-ONLY fork (a label
           but no remote) is a WARNING, not an error — we may or may not
           find a bug worth pushing; a per-project remote on the personal
           account is not required. An official repo without a remote
           stays an error for now (the archive case above is the
           declared form). *)
        match source_repo_of pr with
        | Some r when Option.is_some r.Canary_artifact_source.label ->
            { item_id = "github_remote"; label; severity = Warn;
              detail = "local fork — no remote (reportable only if pushed)" }
        | _ ->
            { item_id = "github_remote"; label; severity = Error;
              detail = "no source repo declared — cannot report" })

let check_stable_lib (pr : Canary_project_run.project_run) : item =
  let label = "stable lib" in
  match row_of pr Canary_artifact.a_lib with
  | None ->
      { item_id = "stable_lib"; label; severity = Warn;
        detail = "no lib row — cannot baseline" }
  | Some d -> (
      (* Reads the row's UNIVERSE since 2026-08-25, not a provider. The
         old form asked whether the lib's provider was
         [Sys_pkg | Vendored | Cached] — but [Vendored]/[Cached] were
         never fetch origins, they were provisions wearing a provider's
         type, which is the mismatch the spec model removed. The question
         it means to ask is about admissible provisions: does this lib
         have a stable point that does not require building it here? *)
      let stable_point =
        List.find_map d.Canary_project_spec.ar_universe ~f:(fun (spec, _) ->
            match spec with
            | Canary_store_config.Fetched (Canary_store_config.Sys_pkg _ as p)
              ->
                Some (Canary_store_config.string_of_provider p)
            | Canary_store_config.Vendored_at at -> Some ("vendored: " ^ at)
            | Canary_store_config.Fetched _ | Canary_store_config.Absent
            | Canary_store_config.Built_from _ | Canary_store_config.Installed
              ->
                None)
      in
      match stable_point with
      | Some detail -> { item_id = "stable_lib"; label; severity = Ok; detail }
      | None ->
          { item_id = "stable_lib"; label; severity = Warn;
            detail =
              "no stable lib source declared (system pkg or vendored/cached archive)" })

(* ── the PAIR checks (2026-08-25, status_project §2 item 0) ──

   [check_stable_lib] above asks whether a stable point EXISTS; every
   other check in this file is likewise a PRESENCE audit. None of them
   multiplies anything, so no combination of them can notice that the
   declared rows collectively generate one world — `spec-check tiny-full`
   reported 0 errors while tiny-full enumerated a single scenario
   (issues.md §1). But the stated bar for a landing is the 2×2 minimum
   (user, 2026-08-19: "the minimum meaningful requirement for any
   project, like a lower bound"), and a 2×2 needs a PAIR on each axis.
   These two checks are that question, one per axis.

   THE COUNT IS OVER POINTS. Measured before writing (`emit <p> --stage
   declare --json` over the registry): ssl's and sqlite's OCaml binding
   pairs are two store PINS inside ONE `Fetched@stable` cell, so both
   "≥ 2 universe cells" and "both channels present" call them unpaired
   and would have shipped a check that warns on the two projects whose
   pairs are the cheapest to declare. [points_of_row] expands pins the
   way pass 2 does; nothing else gets this right.

   WARN, NOT ERROR. zarith's lib axis has one point because GMP's newest
   release is three years old and apt already ships it (landing.md §3) —
   a fact about the world, not an omission. The row's [ar_rationale] is
   where that distinction is declared, so a warn prints it: the reader
   sees whether the thin axis is explained. Making it an Error would
   flip `spec-check @all` to exit 1 on a project that is as complete as
   it can be. *)

let pp_points (pts : (Canary_artifact.provision * Canary_basic.build_id) list) :
    string =
  String.concat ~sep:", "
    (List.map pts ~f:(fun (pv, v) ->
         Printf.sprintf "%s@%s"
           (Canary_store.string_of_provision pv)
           (Canary_basic.string_of_build_id v)))

(* the row's declared WHY, appended to a warn — the field exists to tell
   "the world is like this" from "we did not declare it" *)
let with_rationale (d : Canary_project_spec.artifact_row) (s : string) : string =
  match d.Canary_project_spec.ar_rationale with
  | Some r -> s ^ " — " ^ r
  | None -> s

let rows_of_kind (pr : Canary_project_run.project_run)
    (k : Canary_basic.artifact_kind) : Canary_project_spec.artifact_row list =
  List.filter pr.pr_artifacts ~f:(fun d ->
      Poly.equal (Canary_artifact.kind_of d.Canary_project_spec.ar_artifact) k)

(* EVERY declared lib must be paired. A project's libs are the
   dependencies under test — each one's version axis is a question the
   project exists to ask — so with several libs (D4) this stays a
   conjunction rather than becoming "at least one". *)
let check_lib_pair (pr : Canary_project_run.project_run) : item =
  let label = "lib pair" in
  let id = "lib_pair" in
  match rows_of_kind pr Canary_basic.Lib with
  | [] ->
      { item_id = id; label; severity = Warn;
        detail = "no lib row — no axis to pair" }
  | rows ->
      let described =
        List.map rows ~f:(fun d ->
            let pts = Canary_project_spec.points_of_row d in
            (d, pts,
             Printf.sprintf "%s: %d point(s) [%s]"
               (Canary_artifact.string_of_id d.Canary_project_spec.ar_artifact)
               (List.length pts) (pp_points pts)))
      in
      let thin =
        List.filter described ~f:(fun (_, pts, _) -> List.length pts < 2)
      in
      if List.is_empty thin then
        { item_id = id; label; severity = Ok;
          detail =
            String.concat ~sep:"; "
              (List.map described ~f:(fun (_, _, s) -> s)) }
      else
        { item_id = id; label; severity = Warn;
          detail =
            String.concat ~sep:"; "
              (List.map thin ~f:(fun (d, _, s) ->
                   with_rationale d (s ^ " — no channel pair"))) }

(* AT LEAST ONE binding must be paired. The 2×2's consumer axis is
   realized by one paired consumer; a second binding in another language
   is additive coverage, not a second requirement (sqlite/z3/llvm each
   pair their OCaml binding and carry a single-point Python one, and
   §1 E of status_project counts them complete). The per-row counts stay
   in the detail so the unpaired ones are still visible. *)
let check_binding_pair (pr : Canary_project_run.project_run) : item =
  let label = "binding pair" in
  let id = "binding_pair" in
  let rows =
    List.filter pr.pr_artifacts ~f:(fun d ->
        match Canary_artifact.kind_of d.Canary_project_spec.ar_artifact with
        | Canary_basic.Binding _ -> true
        | _ -> false)
  in
  match rows with
  | [] ->
      { item_id = id; label; severity = Warn;
        detail = "no binding row — no consumer axis to pair" }
  | rows ->
      let described =
        List.map rows ~f:(fun d ->
            let pts = Canary_project_spec.points_of_row d in
            (d, pts,
             Printf.sprintf "%s: %d [%s]"
               (Canary_artifact.string_of_id d.Canary_project_spec.ar_artifact)
               (List.length pts) (pp_points pts)))
      in
      let detail =
        String.concat ~sep:"; " (List.map described ~f:(fun (_, _, s) -> s))
      in
      if List.exists described ~f:(fun (_, pts, _) -> List.length pts >= 2) then
        { item_id = id; label; severity = Ok; detail }
      else
        (* one rationale to print: the thinnest row is the whole story
           when no row is paired *)
        let d, _, _ = List.hd_exn described in
        { item_id = id; label; severity = Warn;
          detail = with_rationale d (detail ^ " — no consumer channel pair") }

let check_opam_package (pr : Canary_project_run.project_run) : item =
  let label = "opam package" in
  if is_in_tree_witness pr then
    { item_id = "opam_package"; label; severity = Na;
      detail = "n/a (in-tree witness)" }
  else
    let ocaml_rows = binding_rows pr Canary_lang.OCaml in
    let typed =
      List.find_map ocaml_rows ~f:(fun d ->
          match Canary_project_spec.provider_of_row d with
          | Some
              (Canary_store_config.Lang_pkg
                { pm = Canary_store.Opam; package; versions; _ }) ->
              Some (package, versions)
          | _ -> None)
    in
    match typed with
    | Some (package, versions) ->
        let pin_detail =
          match versions with
          | None -> "not pinned"
          | Some pins ->
              Printf.sprintf "pinned %s"
                (String.concat ~sep:", "
                   (List.map pins ~f:(fun p -> p.pin_version)))
        in
        { item_id = "opam_package"; label; severity = Ok;
          detail = Printf.sprintf "opam %s (%s)" package pin_detail }
    | None when List.is_empty ocaml_rows ->
        { item_id = "opam_package"; label; severity = Warn;
          detail = "no OCaml binding row" }
    | None ->
        { item_id = "opam_package"; label; severity = Warn;
          detail =
            "opam package not declared on the artifact table (provider absent)" }

let check_dev_wrapper_package (pr : Canary_project_run.project_run) : item =
  let label = "dev wrapper package" in
  match pr.pr_wrapper_pkgs with
  | [] ->
      { item_id = "dev_wrapper_package"; label; severity = Warn;
        detail = "no wrapper package declared for the dev source (Publish)" }
  | pkgs ->
      { item_id = "dev_wrapper_package"; label; severity = Ok;
        detail =
          String.concat ~sep:", "
            (List.map pkgs ~f:(fun (lang, pkg) ->
                 Printf.sprintf "%s %s" (Canary_lang.string_of_lang lang) pkg)) }

let check_python_binding (pr : Canary_project_run.project_run) : item =
  let label = "python binding(s)" in
  let py_rows = binding_rows pr Canary_lang.Python in
  match py_rows with
  | [] ->
      { item_id = "python_binding"; label; severity = Warn;
        detail = "no python binding" }
  | rows ->
      let mechs =
        List.filter_map rows ~f:(fun d ->
            Option.map
              (Canary_artifact.mechanism_of d.Canary_project_spec.ar_artifact)
              ~f:Canary_mechanism.string_of_mechanism)
        |> List.dedup_and_sort ~compare:String.compare
      in
      { item_id = "python_binding"; label; severity = Ok;
        detail =
          Printf.sprintf "%d python binding(s) (%s)" (List.length rows)
            (String.concat ~sep:", " mechs) }

(* M2 step 4 (2026-08-16): the binding declarations — one flat typed
   record per binding (mechanism + payload), what checker/contract
   selection reads. Every BINDING artifact the table declares must have
   its decl (a Warn while external projects fill in); projects without
   bindings are n/a. *)
let check_binding_declarations (pr : Canary_project_run.project_run) : item =
  let label = "binding declarations" in
  let bindings =
    List.filter_map pr.pr_artifacts ~f:(fun d ->
        match Canary_artifact.kind_of d.Canary_project_spec.ar_artifact with
        | Canary_basic.Binding _ -> Some d.Canary_project_spec.ar_artifact
        | _ -> None)
  in
  match bindings with
  | [] ->
      { item_id = "binding_decls"; label; severity = Na;
        detail = "no binding artifacts declared" }
  | _ ->
      let declared =
        List.filter bindings ~f:(fun id ->
            Option.is_some (Canary_project_run.binding_decl_of pr id))
      in
      let missing =
        List.filter bindings ~f:(fun id ->
            Option.is_none (Canary_project_run.binding_decl_of pr id))
      in
      let detail =
        Printf.sprintf "%d/%d declared" (List.length declared)
          (List.length bindings)
      in
      if List.is_empty missing then
        { item_id = "binding_decls"; label; severity = Ok; detail }
      else
        { item_id = "binding_decls"; label; severity = Warn;
          detail =
            Printf.sprintf "%s — missing: %s" detail
              (String.concat ~sep:", " (List.map missing ~f:Canary_artifact.string_of_id)) }

(* M2 step 5 (2026-08-17): raw build overrides — for every binding with
   a Built axis, the mechanism model derives a recipe; when a template
   exists (Dune_targets / Verify_product) but the project declares it
   builds raw, that divergence is FLAGGED (visible, consciously
   judged). Raw recipe (Dlopen) = nothing overridden. *)
let check_raw_build_overrides (pr : Canary_project_run.project_run) : item =
  let label = "raw build overrides" in
  let built_bindings =
    List.filter pr.pr_artifacts ~f:(fun d ->
        has_built_axis d
        &&
        match Canary_artifact.kind_of d.Canary_project_spec.ar_artifact with
        | Canary_basic.Binding _ -> true
        | _ -> false)
  in
  match built_bindings with
  | [] ->
      { item_id = "raw_build_overrides"; label; severity = Na;
        detail = "no Built axis on a binding" }
  | _ ->
      let overridden =
        List.filter built_bindings ~f:(fun d ->
            let id = d.Canary_project_spec.ar_artifact in
            match id with
            | Canary_artifact.A_binding (lang, mech) ->
                let templated =
                  match Canary_project_run.binding_decl_of pr id with
                  | Some decl -> (
                      match Canary_binding_templates.recipe_of_decl decl with
                      | Canary_binding_templates.Raw -> false
                      | Canary_binding_templates.Dune_targets _
                      | Canary_binding_templates.Verify_product -> true)
                  | None -> false
                in
                templated
                && List.exists pr.pr_raw_build_overrides
                     ~f:(fun (l, m) ->
                       Poly.equal l lang
                       && Poly.equal m mech)
            | _ -> false)
      in
      let detail =
        Printf.sprintf "%d raw override(s)"
          (List.length overridden)
      in
      if List.is_empty overridden then
        { item_id = "raw_build_overrides"; label; severity = Ok; detail }
      else
        { item_id = "raw_build_overrides"; label; severity = Warn;
          detail =
            Printf.sprintf "%s — %s" detail
              (String.concat ~sep:", "
                 (List.map overridden ~f:(fun d ->
                      Canary_artifact.string_of_id
                        d.Canary_project_spec.ar_artifact))) }

let check_binding_dev_source (pr : Canary_project_run.project_run) : item =
  let label = "binding dev source" in
  let all_binding_rows =
    List.filter pr.pr_artifacts ~f:(fun d ->
        match Canary_artifact.kind_of d.Canary_project_spec.ar_artifact with
        | Canary_basic.Binding _ -> true
        | _ -> false)
  in
  match List.find all_binding_rows ~f:has_built_axis with
  | Some d ->
      { item_id = "binding_dev_source"; label; severity = Ok;
        detail =
          Printf.sprintf "Built axis on %s"
            (Canary_artifact.string_of_id d.Canary_project_spec.ar_artifact) }
  | None ->
      { item_id = "binding_dev_source"; label; severity = Warn;
        detail = "no Built axis on a binding" }

(* The repo-contents invariant (2026-08-16, design/enumeration/stage1_declare_spec.md): a
   NON-source artifact whose provider is [Repo r] must appear in
   [r.artifacts] (the source itself is implicit — it IS the tree, not
   something built from it). A [Repo_axes] family provides the artifact
   per channel, so EVERY repo's tree must contain it (strict form;
   only a_source rows use [Repo_axes] today and are exempt, so no live
   violations — the strict rule is the honest one when a family provides
   a lib/binding). Returns (artifact, repo-name) violations. *)
let repo_contents_violations (pr : Canary_project_run.project_run) :
    (string * string) list =
  List.filter_map pr.pr_artifacts ~f:(fun d ->
      (* A repo's [artifacts] records the CONSUMABLE artifacts it can
         provide (lib, binding). A SOURCE row's provider being that repo
         is tautological — the repo IS the source — so source-kind rows
         are exempt. Extended 2026-08-19 from [a_source] alone to any
         source kind, when an off-tree BINDING source became a declared
         artifact (zarith's repo provides the binding; demanding it also
         list "binding_source-ocaml" among its contents asks it to
         declare itself). *)
      let not_source =
        match
          Canary_artifact.kind_of d.Canary_project_spec.ar_artifact
        with
        | Canary_basic.Source | Canary_basic.Binding_source _ -> false
        | _ -> true
      in
      match Canary_project_spec.provider_of_row d with
      | Some (Canary_store_config.Repo r) when not_source ->
          if
            List.exists r.Canary_artifact_source.artifacts
              ~f:(Canary_artifact.equal_artifact_info
                    d.Canary_project_spec.ar_artifact)
          then None
          else
            Some
              ( Canary_artifact.string_of_id d.Canary_project_spec.ar_artifact,
                r.Canary_artifact_source.name )
      | Some (Canary_store_config.Repo_axes rs) when not_source -> (
          match
            List.find rs ~f:(fun r ->
                not
                  (List.exists r.Canary_artifact_source.artifacts
                     ~f:(Canary_artifact.equal_artifact_info
                           d.Canary_project_spec.ar_artifact)))
          with
          | Some r ->
              Some
                ( Canary_artifact.string_of_id d.Canary_project_spec.ar_artifact,
                  r.Canary_artifact_source.name )
          | None -> None)
      | _ -> None)

let check (pr : Canary_project_run.project_run) : report =
  { project = pr.pr_name;
    items =
      [ check_dev_source pr;
        check_c_api pr;
        check_github_remote pr;
        check_stable_lib pr;
        check_lib_pair pr;
        check_binding_pair pr;
        check_opam_package pr;
        check_dev_wrapper_package pr;
        check_python_binding pr;
        check_binding_dev_source pr;
        check_binding_declarations pr;
        check_raw_build_overrides pr ] }

(* ── rendering (CLI text + web json) ── *)

let mark_of (s : severity) : string =
  match s with
  | Ok -> "✓"
  | Error -> "✗"
  | Warn -> "⚠"
  | Na -> "n/a"

(* all four marks are exactly 3 bytes wide (✓/✗/⚠ are one UTF-8 char,
   "n/a" is 3 ASCII) — a literal separator aligns, same idiom as
   [Canary_scenario_coverage.pp_rows]. *)
let pp_item (i : item) : string =
  Printf.sprintf "  %s  %-22s  %s" (mark_of i.severity) i.label i.detail

let pp_report (r : report) : string =
  String.concat ~sep:"\n"
    (Printf.sprintf "spec-check: %s" r.project :: List.map r.items ~f:pp_item
   @ [ "  " ^ summary r ])

let legend = "  ✓ ok   ✗ error (severe)   ⚠ warn (missing)   n/a (in-tree witness)"

let item_to_json (i : item) : Yojson.Safe.t =
  `Assoc
    [ ("id", `String i.item_id);
      ("label", `String i.label);
      ("severity", `String (string_of_severity i.severity));
      ("detail", `String i.detail) ]

let report_to_json (r : report) : Yojson.Safe.t =
  `Assoc
    [ ("project", `String r.project);
      ("items", `List (List.map r.items ~f:item_to_json)) ]
