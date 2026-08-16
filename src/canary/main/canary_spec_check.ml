(* ── Static spec-maturity audit (2026-08-13, `canary spec-check`) ──

   Audits a registry project's DECLARED spec against the three-version-report
   readiness checklist. PURELY STATIC: reads only [project_run.pr_artifacts]
   (rows: identity, axes, providers) + [pr_wrapper_pkgs]. No enumeration, no
   realization, no filesystem, no shell — runtime facts (a package renamed,
   a remote moved, actual probe results) belong to run status, not here.

   Non-uniformities that remain (recorded in
   doc/canary/project/status_project.md §2), reported as-is, NOT
   special-cased in code:
   - z3/llvm source rows carry the STABLE repo's provider; per-channel (dev)
     source providers are the not-yet-wired provenance refinement.
   - tiny-full declares its api_source on [project_run.pr_api_source]
     (its source row is Vendored, not repo-carried) and is exempt from the
     reporting-oriented checks (in-tree witness).
   (The 2026-08-13 fulfillment round closed the others: pattern-A gained
   typed rows via [Canary_pattern_a.artifacts]; sqlite wired a source row +
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
    (id : Canary_artifact.artifact_id) :
    Canary_project_spec.artifact_row option =
  List.find pr.pr_artifacts ~f:(fun d ->
      Canary_artifact.equal_artifact_id d.Canary_project_spec.ar_artifact id)

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
   [Repo] provider (2026-08-15 unification — the axes' provision says
   what the repo provides). Per-channel sources are the not-yet-wired
   provenance refinement, so any one repo satisfies the static checks
   (same shape as z3's stable-repo-on-row). *)
let source_repo_of (pr : Canary_project_run.project_run) :
    Canary_artifact_source.source_repo option =
  List.find_map pr.pr_artifacts ~f:(fun d ->
      match d.Canary_project_spec.ar_provider with
      | Some (Canary_store_config.Repo r) -> Some r
      | _ -> None)

(* ── the eight checks (checklist order) ── *)

let check_dev_source (pr : Canary_project_run.project_run) : item =
  let label = "dev source" in
  match row_of pr Canary_artifact.a_source with
  | Some d ->
      let detail =
        match d.Canary_project_spec.ar_provider with
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
      match d.Canary_project_spec.ar_provider with
      | Some
          (Canary_store_config.Sys_pkg _ | Canary_store_config.Vendored _
          | Canary_store_config.Cached _) as p ->
          { item_id = "stable_lib"; label; severity = Ok;
            detail = Option.value_map p ~default:"" ~f:Canary_store_config.string_of_provider }
      | _ ->
          { item_id = "stable_lib"; label; severity = Warn;
            detail =
              "no stable lib source declared (system pkg or vendored/cached archive)" })

let check_opam_package (pr : Canary_project_run.project_run) : item =
  let label = "opam package" in
  if is_in_tree_witness pr then
    { item_id = "opam_package"; label; severity = Na;
      detail = "n/a (in-tree witness)" }
  else
    let ocaml_rows = binding_rows pr Canary_lang.OCaml in
    let typed =
      List.find_map ocaml_rows ~f:(fun d ->
          match d.Canary_project_spec.ar_provider with
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
            match Canary_artifact.ext_of d.Canary_project_spec.ar_artifact with
            | Canary_artifact.Ext_mechanism m ->
                Some (Canary_mechanism.string_of_mechanism m)
            | _ -> None)
        |> List.dedup_and_sort ~compare:String.compare
      in
      { item_id = "python_binding"; label; severity = Ok;
        detail =
          Printf.sprintf "%d python binding(s) (%s)" (List.length rows)
            (String.concat ~sep:", " mechs) }

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

(* The repo-contents invariant (2026-08-16, design/repo_model.md): a
   NON-source artifact whose provider is [Repo r] must appear in
   [r.artifacts] (the source itself is implicit — it IS the tree, not
   something built from it). Returns (artifact, repo-name) violations. *)
let repo_contents_violations (pr : Canary_project_run.project_run) :
    (string * string) list =
  List.filter_map pr.pr_artifacts ~f:(fun d ->
      match d.Canary_project_spec.ar_provider with
      | Some (Canary_store_config.Repo r)
        when not
               (Canary_artifact.equal_artifact_id
                  d.Canary_project_spec.ar_artifact Canary_artifact.a_source) ->
          if
            List.exists r.Canary_artifact_source.artifacts
              ~f:(Canary_artifact.equal_artifact_id
                    d.Canary_project_spec.ar_artifact)
          then None
          else
            Some
              ( Canary_artifact.string_of_id d.Canary_project_spec.ar_artifact,
                r.Canary_artifact_source.name )
      | _ -> None)

let check (pr : Canary_project_run.project_run) : report =
  { project = pr.pr_name;
    items =
      [ check_dev_source pr;
        check_c_api pr;
        check_github_remote pr;
        check_stable_lib pr;
        check_opam_package pr;
        check_dev_wrapper_package pr;
        check_python_binding pr;
        check_binding_dev_source pr ] }

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
