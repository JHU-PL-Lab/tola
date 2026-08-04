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
type provider =
  | Absent
  | Vendored of string
  | Cached of string
  | Source_repo of Canary_artifact_source.source_repo
      (** the SOURCE artifact itself, obtained from a repo (git clone / local
          checkout) — Fetched on the axis. Sibling of [Built_from] (a lib/binding
          BUILT from that source, which is Built). *)
  | Built_from of Canary_artifact_source.source_repo
  | Sys_pkg of Canary_store.system_package_spec
  | Lang_pkg of {
      lang : Canary_lang.lang;
      pm : Canary_store.package_manager;
      package : string;
    }

let provision_of_provider : provider -> Canary_store.provision = function
  | Absent -> Canary_store.Absent
  | Vendored _ | Cached _ -> Canary_store.Vendored
  | Source_repo _ -> Canary_store.Fetched
  | Built_from _ -> Canary_store.Built
  | Sys_pkg _ | Lang_pkg _ -> Canary_store.Fetched

let string_of_source_repo (repo : Canary_artifact_source.source_repo) : string =
  let (Canary_artifact_source.Git_remote url) = repo.Canary_artifact_source.remote in
  Printf.sprintf "%s @%s (ref %s) %s" repo.Canary_artifact_source.name
    repo.Canary_artifact_source.version repo.Canary_artifact_source.ref_ url

let string_of_provider : provider -> string = function
  | Absent -> "absent"
  | Vendored p -> "vendored: " ^ p
  | Cached p -> "cached: " ^ p
  | Source_repo repo -> "source repo: " ^ string_of_source_repo repo
  | Built_from repo ->
      let (Canary_artifact_source.Git_remote url) =
        repo.Canary_artifact_source.remote
      in
      Printf.sprintf "built from source: %s @%s (%s)"
        repo.Canary_artifact_source.name repo.Canary_artifact_source.version url
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
  components : Canary_artifact_api.api_component list;
      (** moved off [native_api]: Headers / Link_lib / Runtime_lib / Pc_file.
          Metadata (what it exposes), not provenance. *)
  headers : Canary_artifact_api.headers_spec option;
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
