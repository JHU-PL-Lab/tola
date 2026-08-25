(** [Canary_store_config] — provenance the store owns, one field per
    artifact's store (project-definition redesign, seam S3 —
    [doc/canary/design/ssot.md] §6.1). Absorbs the
    provenance half of [api_source] (components / headers / source_dir);
    the checking half is {!Canary_surface}.

    Reuses {!Canary_store} for store identity: a [location] carries
    [pm_info] ([Sys_pm] / [Lang_pm { lang; pm }]), so "which store, which
    PM" is {b data}, not a set of PM-specific type fields. A binding
    therefore has exactly one source (its [location]'s [pm]) — the old
    "opam OR pip, both optional" shape was unrepresentable-nonsense and
    is gone.

    Lives in [tool/] because {!Canary_artifact_source.source_repo} does;
    everything else it references is [base/]. *)

(* ── Unified per-artifact provider — "where an artifact comes from" ──
   The typed detail behind an artifact's [Canary_store.provision] axis value
   (ssot §4.2): a vendored/cached PATH, a [source_repo] to build from, or a PM +
   package. [source_repo] is used AS-IS (its [remote] | [locals] already models
   "make it local to use"). The coarse [provision] is DERIVED
   ([provision_of_provider]) so the axis and the detail can't drift. [Cached] ≈
   [Vendored] on the axis (both are pre-existing local copies canary just probes).

   This is the ONE store shape the old five (lib_store / binding_store /
   source_repo / tiny_stores / the pr_provenance string) converge onto: it now
   backs [lib_store] and [binding_store] directly (was [location] + [system_pkg]
   / [pkg_name]) and drives [command_of_step]'s Derived fetch. *)
(** A STORE PIN (2026-08-12) — one installable version of a lang-PM
    package, declared as project data; the enumeration ranges over the
    pins and the runner enforces them (identity + pin-checked fetch +
    world assertions). The default install form is the standard
    "<package>.<pin_version>"; [install_name] is the escape for packages
    whose install target doesn't follow the convention. *)
type opam_pin = {
  pin_version : string;
      (** the OPAM package version — the store's own record ([holds_pin]
          verifies against `opam list --columns=version`), and the
          scenario identity. E.g. "0.6.0", "dev". *)
  install_name : string option;
      (** the `opam install` target; [None] = the standard
          "<package>.<pin_version>" (ssl.0.6.0, z3.dev). Custom for
          irregular names (e.g. an opam package literally named
          "llvm.19-shared" whose version isn't "19-shared"). *)
}

type provider =
  | Absent
  | Vendored of string
  | Cached of string
  | Repo of Canary_artifact_source.source_repo
      (** ANY artifact provided from a repo (2026-08-15, the unification —
          design/enumeration/stage1_declare_spec.md): the AXES' provision says WHAT the repo
          provides — [Fetched] = the repo ships/fetches the artifact (or
          the project source, for a Source row); [Built] = the artifact is
          BUILT from the repo's source. The old [Source_repo]/[Built_from]
          pair split the same record by exactly that provision, which the
          axes already declare ([Built_from] had zero live uses). *)
  | Repo_axes of Canary_artifact_source.source_repo list
      (** a repo FAMILY covering the channels of one artifact (C1,
          2026-08-16, design/enumeration/stage1_declare_spec.md Roadmap C): the per-channel
          repos — official stable + official dev (+ a labeled fork when one
          exists). Each repo's [version] record declares its channel and
          id; [versions_of_provider] projects them into the axes' store
          pins, so a repo with a concrete id is identity-bearing and one
          with [id = ""] stays version-ambient. Same provision semantics
          as [Repo]; the stable repo is listed first. *)
  | Sys_pkg of Canary_store.system_package_spec
  | Lang_pkg of {
      lang : Canary_lang.lang;
      pm : Canary_store.package_manager;
      package : string;
      self_contained : bool;
          (** the package bundles its own native lib (co-provider, backlog #45).
              [Ambient] runtime edge is derivable from this flag. *)
      versions : opam_pin list option;
          (** STORE PINS: the concrete installable versions, when the
              artifact's Fetched provision ranges over more than "whatever
              the PM picks" (opam has no multi-version co-installation — a
              pinned version is store status, not content; see
              doc/canary/project/opam_exclusive_store_issue.md). [None] =
              version-ambient as before. Opam-first; pip pins
              (`pip install pkg==1.2.3`) are the natural future use. *)
    }

(** ONE declaration per admissible provision (2026-08-25).

    {1 What it replaces, and why}

    A row used to declare a coarse universe AND, separately, one
    [provider] for the whole artifact — and the two only lined up for one
    of the provisions. sqlite's lib is the specimen: [Sys_pkg
    libsqlite3-dev] beside a universe of {Fetched, Built, Installed},
    where the package explains only the Fetched case. The Built one comes
    from source and the Installed one from the Built one, and neither has
    anything to do with apt. That forced a special rule — "the provider's
    provision is a BASELINE, not the whole truth" — plus a pin per
    project to stop the two declarations drifting.

    Here each admissible provision states its own origin, so there is
    nothing to keep in step and no baseline to explain.

    {1 The axis it actually encodes}

    Not external-vs-internal (user, 2026-08-25 — [Vendored] is external
    too: [canary prebuilt] downloads conda-forge tarballs before the
    run). The question each constructor answers is {b which action in
    THIS run produces the artifact}:

    {v
    Absent      — nothing
    Vendored    — nothing; it pre-exists the run
    Fetched     — Fetch
    Built_from  — Build_*
    Installed   — Install_lib
    v}

    Which is exactly what {!producing_action_of} computes, and why a
    [Vendored] artifact has no producing action: the arrow starts outside
    the run. Where its bytes came from is a PREPARATION concern, which is
    why [canary prebuilt] is a separate command.

    {1 Payloads}

    Each branch carries what its action needs, and nothing else — the
    same rule the artifact identity follows ([Canary_artifact], "a
    constructor gains a payload when the thing it names stops being
    unique"):

    - [Installed] carries nothing: it is always the staged face of THIS
      artifact's own [Built_from], so there is no second possibility to
      name.
    - [Built_from] carries the artifact it builds FROM. That deletes a
      hardcode: [build_deps_of] used to read
      [if id = a_lib && declared a_source then [a_source]], and zarith
      (whose binding builds from [a_binding_source OCaml], not the lib's
      source) needed a per-project escape. Now the row says it. *)
type provision_spec =
  | Absent
  | Fetched of provider
      (** the PM, repo or repo family a fetch asks. [provider]'s
          [Vendored]/[Cached]/[Absent] constructors are not reachable
          here — they are other provisions — but the type is shared
          rather than split so the 12 existing readers keep working. *)
  | Built_from of Canary_artifact.artifact_info
      (** the artifact this one is compiled from *)
  | Installed
      (** the staged face of this artifact's own [Built_from] *)
  | Vendored_at of string  (** a local path that pre-exists the run *)

let provision_of_spec : provision_spec -> Canary_store.provision = function
  | Absent -> Canary_store.Absent
  | Fetched _ -> Canary_store.Fetched
  | Built_from _ -> Canary_store.Built
  | Installed -> Canary_store.Installed
  | Vendored_at _ -> Canary_store.Vendored

(** The fetch origin, when this provision has one. [None] for the three
    that are produced here or pre-exist — and that [None] is the honest
    answer, where the old model had to invent a provider for them. *)
let fetch_provider_of : provision_spec -> provider option = function
  | Fetched p -> Some p
  | Absent | Built_from _ | Installed | Vendored_at _ -> None

(** The arrow, read off the SPEC (2026-08-25): origin → action →
    artifact. [None] where no action in this run produces it — [Absent],
    and [Vendored_at], whose arrow starts outside the run.

    This is [providing_action_of] without the [~provision] parameter,
    because the spec already carries it. The old signature needed the
    provision passed IN precisely because the provider could not say
    which one it explained. *)
let producing_action_of (k : Canary_basic.artifact_kind) :
    provision_spec -> Canary_basic.action option = function
  | Absent | Vendored_at _ -> None
  | Fetched _ -> Some (Canary_basic.Fetch k)
  | Built_from _ -> (
      match k with
      | Canary_basic.Lib -> Some Canary_basic.Build_lib
      | Canary_basic.Binding l -> Some (Canary_basic.Build_binding l)
      | Canary_basic.Headers -> Some Canary_basic.Build_headers
      | Canary_basic.Source | Canary_basic.Binding_source _
      | Canary_basic.App ->
          None)
  | Installed -> (
      match k with
      | Canary_basic.Lib -> Some Canary_basic.Install_lib
      | Canary_basic.Source | Canary_basic.Headers | Canary_basic.Binding _
      | Canary_basic.Binding_source _ | Canary_basic.App ->
          None)

let provision_of_provider : provider -> Canary_store.provision = function
  | Absent -> Canary_store.Absent
  | Vendored _ | Cached _ -> Canary_store.Vendored
  | Repo _ | Repo_axes _ -> Canary_store.Fetched
      (* the baseline-display value: a repo enters at the FETCH boundary.
         A [Repo] row whose axes carry [Built] is the built-from-source
         case — the display drift check flags it and the arrow (below)
         reads the axes. *)
  | Sys_pkg _ | Lang_pkg _ -> Canary_store.Fetched

(** The ARROW unification (user, 2026-08-06): an artifact COMES FROM its
    provider via an ACTION — [provider → action → artifact] — and fetching
    is the SAME SHAPE as building. Building is the case where the provider
    is itself an enumerated artifact (a [Built_from] repo whose checkout is
    the Source artifact the Build action consumes); fetching is the case
    where the provider (a PM package, a repo to clone) sits at the
    enumeration's BOUNDARY. [None] = a supplied local copy
    ([Vendored]/[Cached]): no canary action produces it — the arrow starts
    outside the run entirely (an initial node in the graph view).

    Dual of [Canary_enumerate.provision_of_actions] (which reads the
    provision back off a variant's action set); the projects-test pins the
    two consistent through [provision_of_provider] so they cannot drift. *)
let providing_action_of ~(provision : Canary_store.provision)
    (k : Canary_basic.artifact_kind) (p : provider) : Canary_basic.action option =
  match p with
  | Absent | Vendored _ | Cached _ -> None
  | Sys_pkg _ | Lang_pkg _ -> Some (Canary_basic.Fetch k)
  | Repo _ | Repo_axes _ -> (
      (* what the repo provides IS the axes' provision (the unification) *)
      match provision with
      | Canary_store.Fetched -> Some (Canary_basic.Fetch k)
      | Canary_store.Built -> (
          match k with
          | Canary_basic.Lib -> Some Canary_basic.Build_lib
          | Canary_basic.Binding l -> Some (Canary_basic.Build_binding l)
          | Canary_basic.Headers -> Some Canary_basic.Build_headers
          | Canary_basic.Source | Canary_basic.Binding_source _
          | Canary_basic.App -> None)
      | Canary_store.Installed -> (
          (* the maker step of an Installed artifact (2026-08-18, the
             provider-exclusive-rows model) *)
          match k with
          | Canary_basic.Lib -> Some Canary_basic.Install_lib
          | Canary_basic.Source | Canary_basic.Headers
          | Canary_basic.Binding _ | Canary_basic.Binding_source _
          | Canary_basic.App -> None)
      | Canary_store.Absent | Canary_store.Vendored -> None)

(** [dep_mode_of_provider p] returns the runtime-edge mode implied by the
    provider's self-contained declaration: [Some (Ambient s)] for a
    self-contained lang-PM package, [None] otherwise. A [None] result means
    the [ax_runtime] stays undeclared or is set by the project. *)
let dep_mode_of_provider (p : provider) : Canary_store.dep_mode option =
  match p with
  | Lang_pkg { self_contained = true; package; _ } ->
      Some (Canary_store.Ambient ([%string "bundled lib (%{package})"]))
  | _ -> None

(** [versions_of_provider p] — the store pins declared on the provider
    (2026-08-12; widened 2026-08-16): [Some vs] as [version] records
    ([channel; id]) for a lang-PM package whose installable versions the
    project declares (lang-PM pins carry no channel → [Stable]) or for a
    [Repo_axes] family (each repo's own [version] record, channel
    PRESERVED — the pins are identity-bearing and the thin policy's
    [Subset [Stable]] drops the dev repos); [None] = version-ambient.
    Projected into the artifact's axes by [artifact_row]; the enforcement
    lives in the enumeration (identity) + runner (pin-checked fetch +
    world assertion). *)
let versions_of_provider (p : provider) : Canary_basic.version list option =
  match p with
  | Lang_pkg { versions = Some vs; _ } ->
      Some
        (List.map
           (fun v ->
             { Canary_basic.channel = Canary_basic.Stable; id = v.pin_version })
           vs)
  | Lang_pkg { versions = None; _ } -> None
  | Repo_axes rs ->
      Some
        (List.map (fun r -> r.Canary_artifact_source.version) rs)
  | Absent | Vendored _ | Cached _ | Repo _ | Sys_pkg _ -> None

(** The opam install target for a pin: the declared [install_name], or
    the standard "<package>.<pin_version>". *)
let install_name_of_pin ~(package : string) (p : opam_pin) : string =
  match p.install_name with
  | Some n -> n
  | None -> package ^ "." ^ p.pin_version

let string_of_source_repo (repo : Canary_artifact_source.source_repo) : string =
  let url =
    match repo.Canary_artifact_source.remote with
    | Some (Canary_artifact_source.Git u) -> u
    | Some (Canary_artifact_source.Hg u) -> u
    | Some (Canary_artifact_source.Tar u) -> "archive: " ^ u
    | None -> "(no remote)"
  in
  let label =
    match repo.Canary_artifact_source.label with
    | Some l -> Printf.sprintf " (fork: %s)" l
    | None -> ""
  in
  Printf.sprintf "%s @%s (ref %s) %s%s" repo.Canary_artifact_source.name
    (Canary_basic.string_of_version repo.Canary_artifact_source.version)
    repo.Canary_artifact_source.ref_ url label

let string_of_provider : provider -> string = function
  | Absent -> "absent"
  | Vendored p -> "vendored: " ^ p
  | Cached p -> "cached: " ^ p
  | Repo repo -> "repo: " ^ string_of_source_repo repo
  | Repo_axes rs ->
      "repo: "
      ^ String.concat ", "
          (List.map
             (fun r ->
               Printf.sprintf "%s@%s (%s)"
                 r.Canary_artifact_source.name
                 (Canary_basic.string_of_version r.Canary_artifact_source.version)
                 (Canary_basic.string_of_channel r.Canary_artifact_source.version.Canary_basic.channel))
             rs)
  | Sys_pkg spec ->
      Printf.sprintf "sys-pm linux:%s macos:%s" spec.Canary_store.linux_pkg
        spec.Canary_store.macos_pkg
  | Lang_pkg { pm; package; _ } ->
      Printf.sprintf "%s:%s" (Canary_store.string_of_pm pm) package

type binding_store = {
  provider : provider;
      (** where the binding comes from: [Lang_pkg {pm; package}] (opam/pip) or
          [Vendored]/[Built_from] (built from source). Drives the [Derived] fetch;
          the coarse provision is [provision_of_provider]. *)
  source_dir : string option;
      (** moved off [binding_api]: gates [Build_binding] + the scan check.
          Metadata (how it's built), not provenance. *)
}

type lib_store = {
  provider : provider;
      (** where the lib comes from: [Sys_pkg spec] (apt/brew) | [Built_from repo]
          | [Vendored]/[Cached] path. Drives [Derived] fetch_lib. *)
  components : Canary_artifact.api_component list;
      (** moved off [native_api]: Headers / Link_lib / Runtime_lib / Pc_file.
          Metadata (what it exposes), not provenance. *)
  headers : Canary_artifact.headers_spec option;
      (** moved off [native_api]: header dir + files. Metadata. *)
}

type store_config = {
  source : Canary_artifact_source.source_repo option; (* Source store *)
  lib : lib_store option; (* Lib store *)
  bindings : (Canary_lang.lang * binding_store) list; (* Binding store, per lang *)
}

let empty_store_config = { source = None; lib = None; bindings = [] }

(** The package manager of a binding's store, if it lives in a lang PM
    (rather than being built from source). *)
let binding_pm (b : binding_store) : Canary_store.package_manager option =
  match b.provider with Lang_pkg { pm; _ } -> Some pm | _ -> None
