open Base

(* First-class API source layer.
   Captures the native API surface a library exposes and the language
   bindings that consume it. Hand-written per project; scan/summary reads
   this at post-build time to confirm each claim against the built artifacts.

   Provider side (native_api): declares which components an artifact exposes
   and carries path details for components known at fetch time.
   Consumer side (binding_api): describes the binding artifact and which
   canary actions apply (Build when source_dir is set; Pack when can_pack).
   Action dep requirements (headers + link_lib for build; runtime_lib for probe)
   are derivable from action type — not declared on binding_api.
   See doc/canary/design/api_surface.md §4 for the design rationale. *)

(* [lang] lives in [Canary_lang] (base/). Earlier this file had a
   transparent re-export so [open Canary_artifact] users saw the
   constructors; the shim was dropped on 2026-06-02 (Phase 11a) — the
   3 affected callers now [open Canary_lang] directly. *)

type native_api_kind =
  | C
  | Cpp_api
[@@deriving show]

(** Component kinds — declared by the provider ([native_api.components]).
    No path payload here; paths live in the provider's detail fields
    ([headers] etc.). [Link_lib] is the unversioned [.so] symlink (shared)
    or [.a] (static) used at link time; [Runtime_lib] is the versioned
    [.so]/[.dylib] loaded at runtime (absent for static linking).

    Cross-reference to the surface-theory vocabulary in
    [doc/canary/research/surface_theory.md] §2.1:

    - [Headers]     ↔ {i s1 native_header} — syntactic native surface.
                      In tiny: [n3 header_native.h] = [c/include/tiny.h].
    - [Runtime_lib] ↔ {i s2 native_lib} (semantic). The {i runtime} carrier;
                      ELF/dyld resolves this. In tiny: [n4 lib_native.so]
                      = [c/build/libtiny.so.1].
    - [Link_lib]    ↔ {i s2 native_lib} via the link-time symlink (shared)
                      or archive (static). Same s2 role; different access
                      time. In tiny: [c/build/libtiny.so] (symlink to [n4]).
    - [Pc_file]     ↔ no s* role — packaging metadata that {i drives} where
                      [Headers]/[Link_lib]/[Runtime_lib] live, but isn't
                      itself a surface canary checks. *)
type api_component =
  | Headers      (** C/C++ public headers ↔ s1 native_header *)
  | Runtime_lib  (** versioned .so/.dylib ↔ s2 native_lib (runtime carrier) *)
  | Link_lib     (** .so symlink or .a ↔ s2 native_lib (link-time carrier) *)
  | Pc_file      (** pkg-config file — packaging metadata, no s* role *)
[@@deriving show]

(* Path detail for Header components — only present on the provider side *)
type headers_spec = {
  dir   : string;        (** path to header dir; source-relative or absolute *)
  files : string list;   (** public header file names relative to dir *)
}
[@@deriving show]

type native_api = {
  kind            : native_api_kind;
  components      : api_component list;  (** what this source/package exposes *)
  headers         : headers_spec option; (** path detail when Headers ∈ components *)
  symbol_prefixes : string list;
  stable_symbols  : string list;         (** L1a: must be exported *)
  (* L1b: symbols expected to carry @@ version annotations (e.g. malloc@@GLIBC_2.31).
     Placeholder — inspect not yet wired. *)
  versioned_symbols : string list;
  (* L4: ABI/runtime properties.  Placeholder — inspect not yet wired. *)
  soname    : string option;             (** expected SONAME (e.g. "libz3.so.4.15") *)
  c_runtime : string option;             (** expected C runtime ("glibc", "musl") *)
  cxx_abi   : string option;             (** expected C++ ABI ("itanium", "msvc") *)
}
[@@deriving show]

type binding_api = {
  lang             : Canary_lang.lang;               (** explicit language tag — Binding is always lang-keyed *)
  source_dir       : string option;      (** Some _ ↔ Build_binding applicable; headers here or in -dev pkg *)
  module_watchlist : string list;        (** L3: dotted paths ok: "Llvm.Opcode.UncondBr" *)
  (* L2: type/function signatures to inspect (.cmi digests, C prototypes).
     Placeholder — inspect not yet wired. *)
  type_watchlist   : string list;
}
[@@deriving show]

(* The per-language probe specs [ocaml_binding] and [python_binding]
   moved to [tool/canary_toolchain.ml] on 2026-06-02 (Phase 11b) —
   they describe how to compile/probe a binding (operational), not
   what the binding exposes (theoretical). *)

type t = {
  native_api   : native_api;
  binding_apis : binding_api list;
}
[@@deriving show]

let _ = Canary_lang.show_lang
let _ = show

(* Watchlist accessors — used by summary closures in project specs *)

let native_watchlist (api : t) = api.native_api.stable_symbols

let binding_watchlist_exn (api : t) (lang : Canary_lang.lang) =
  match List.find api.binding_apis ~f:(fun b -> Poly.equal b.lang lang) with
  | Some b -> b.module_watchlist
  | None ->
      failwith
        [%string "canary_artifact_api: no binding for lang %{Canary_lang.show_lang lang}"]

(* Shell warning prefix for a summary command when a stable (fetch-only)
   source reuses the dev api_source spec. *)
let stable_reuse_warning ~source_name ~source_version =
  [%string
    "echo 'NOTE: api_source is the dev spec reused for stable source \
     %{source_name}/%{source_version}; watchlist may drift'"]

(* [scan_source_cmd] moved to tool/canary_artifact_source.ml on
   2026-06-02 (Phase 11c) — it's a check shell command, not a fact
   type. *)

(* =================================================================
   Artifact identity & project declaration (2026-08-07).
   Merged from [Canary_project_spec] — the base layer owns artifact
   identity types; the action layer wires them into enumeration rows.
   ================================================================= *)

(* ── base vocabulary (re-exported from Canary_store / Canary_basic) ── *)

type provision = Canary_store.provision =
  | Absent | Fetched | Built | Installed | Vendored
[@@deriving show, eq]

type artifact = Canary_basic.artifact_kind =
  | Source | Headers | Lib | Binding of Canary_lang.lang
  | Binding_source of Canary_lang.lang | App
[@@deriving show, eq]

let string_of_provision = Canary_store.string_of_provision

(** Concise artifact label for display (coarse kind only). *)
let string_of_artifact = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding l -> "binding-" ^ Canary_lang.string_of_lang l
  | Binding_source l -> "binding_source-" ^ Canary_lang.string_of_lang l
  | App -> "app"

(* ── precise artifact identity (ssot §4.2.3) ──
   The coarse [artifact] (= Canary_basic.artifact_kind) can't tell two
   bindings of one lib apart (cext vs ctypes) or two apps apart (direct vs
   via-helper). So the enumeration has its OWN identity type, which carries
   whatever refines a kind: a binding's mechanism, an app's wiring. *)

(** How an app consumes the library (decision 2, ssot §4.2.3). *)
type app_wiring = Direct | Via_helper [@@deriving show, eq]

let string_of_app_wiring = function Direct -> "direct" | Via_helper -> "via_helper"

(** The enumeration's precise artifact identity.

    A SUM since 2026-08-24 (user: the identity carries a payload, so the
    record was lying). It used to be [{ kind : artifact; ext :
    artifact_ext }] — two fields where the second refines the first, with
    the pairing rule held only by convention. That let
    [{ kind = Lib; ext = Ext_mechanism Cstubs }] and
    [{ kind = Binding OCaml; ext = Ext_none }] typecheck, both nonsense.

    Why the payload did NOT move into {!Canary_basic.artifact_kind}
    instead — the other obvious absorption, and the more expensive one:
    the coarse kind has ~116 mention sites and genuinely
    mechanism-INDEPENDENT consumers ([kind_order] for the matrix column
    order, [consumes_of_action]/[produces_of_action] — a [Build_binding l]
    consumes [Lib] whatever the mechanism — [string_of_artifact_kind],
    [scenario_dir_of]'s naming). Putting the mechanism there turns every
    one of those into [Binding (l, _)]: the coarse view stops being a type
    and becomes a wildcard convention. Keeping it as a PROJECTION
    ({!kind_of}) gives both.

    {1 Why some constructors carry nothing}

    [A_source] and [A_headers] have no payload, and that is the correct
    shape rather than an unfinished one: this type is pure IDENTITY, and
    everything that VARIES about an artifact lives in the structures that
    use it —

    - {!placement} = [{ provision; version }] — how a scenario obtains it
      and at which version;
    - {!artifact_axes} = [{ ax_universe; ax_runtime; ax_follows; ax_pins }]
      — what the project declares about it;
    - {!assignment} = [(artifact_info * placement) list] — the pairing.

    So a lib's provision, version, provider and pins are all present; none
    of them belongs to its identity.

    What a payload-free constructor DOES mean is "one per project". A
    project has one source and one header set — which is why there is
    nothing to tell two of them apart. [A_binding] carries lang ×
    mechanism because a project has several bindings; [A_binding_source]
    carries lang; [A_app] carries wiring. When a constructor here gains a
    payload, it is because the thing it names stopped being unique.

    {1 Why [A_lib] carries [string option] and not [string]}

    A lib is the one artifact whose uniqueness is a fact about today's
    projects rather than about the model: sqlite has one, mpfr needs two
    (it requires gmp), bytesrw needs five optional backends. So [A_lib]
    carries a name — but an OPTIONAL one, and the option is load-bearing.

    [None] is not a placeholder. It says "this project has one lib, and
    naming it would be redundant" — a true statement about all nine
    projects that exist, and the reason {!string_of_id} still prints
    plain [lib] for them (ids feed scenario dirs, dedup keys and
    run-cache markers, so they must not churn). [Some n] says the project
    declares more than one and this is which.

    A plain [string] would have forced a distinguished empty value —
    every project writing [A_lib ""] — which is the payload rule
    inverted: a sentinel standing in for "no payload needed here". The
    option types that distinction instead of encoding it in a magic
    value. Contrast [ext], deleted 2026-08-24, which was exactly such a
    stand-in.

    Naming the lib is step 1 of three in
    [doc/canary/design/enumeration/multi_lib.md] §3a. Steps 2 ([rp_build]
    beside [rp_run], so [rp_deploy] is derived rather than declared) and
    3 (a role per consumed slot in the action catalogue, so an action can
    link one lib and load another) still await a project that declares
    two — neither is expressible while every lib placement is the same
    placement. Until then every construction site passes [None] via
    {!a_lib} and nothing observable changes.

    Constructors carry an [A_] prefix because this module re-exports
    [artifact_kind]'s constructors unqualified and they would shadow.
    Almost nothing needs them: construction goes through the smart
    constructors below (~268 call sites), and reads go through {!kind_of}
    / {!mechanism_of} / {!wiring_of}. *)
type artifact_info =
  | A_source
  | A_headers
  | A_lib of string option
  | A_binding of Canary_lang.lang * Canary_mechanism.mechanism
  | A_binding_source of Canary_lang.lang
  | A_app of app_wiring
[@@deriving show, eq]

(** The coarse role, projected out. An artifact HAS a kind; several
    consumers want only that. *)
let kind_of : artifact_info -> artifact = function
  | A_source -> Source
  | A_headers -> Headers
  | A_lib _ -> Lib
  | A_binding (l, _) -> Binding l
  | A_binding_source l -> Binding_source l
  | A_app _ -> App

(** The refinement, where the kind has one. [None] for source / headers,
    which are one-per-project by construction, and for a lib — whose own
    refinement is a name, read by {!lib_name_of}. *)
let mechanism_of : artifact_info -> Canary_mechanism.mechanism option = function
  | A_binding (_, m) -> Some m
  | A_source | A_headers | A_lib _ | A_binding_source _ | A_app _ -> None

let wiring_of : artifact_info -> app_wiring option = function
  | A_app w -> Some w
  | A_source | A_headers | A_lib _ | A_binding _ | A_binding_source _ -> None

(** The lib's declared name. [Some None] = "a lib, unnamed" (the project
    has one); [Some (Some n)] = "the lib called [n]"; [None] = not a lib
    at all. The doubled option is deliberate — collapsing it would lose
    the difference between "not a lib" and "the project's only lib". *)
let lib_name_of : artifact_info -> string option option = function
  | A_lib n -> Some n
  | A_source | A_headers | A_binding _ | A_binding_source _ | A_app _ -> None

(* [artifact_ext] and [ext_of] lived here from the record era until
   2026-08-24. The view existed because consumers wanted "whatever
   refines this kind" without caring which flavour — and once the
   identity became a sum, every one of them turned out to want something
   narrower: four wanted only the mechanism ({!mechanism_of}), and the
   fifth was a node field that was never read. Keeping a projection
   nobody needed would have left the record's shape behind in a type
   that no longer had it. *)

(* smart constructors — THE construction API *)
let a_source : artifact_info = A_source
let a_headers : artifact_info = A_headers
(** THE lib of a single-lib project — every project today. A project that
    declares two uses {!a_lib_named} for both, never this. *)
let a_lib : artifact_info = A_lib None

(** A named lib, for a project declaring more than one (mpfr + gmp). The
    name reaches ids as [lib-<n>], so it must be born-safe: '-' not ':',
    no path separators. *)
let a_lib_named (n : string) : artifact_info = A_lib (Some n)
let a_binding_source (lang : Canary_lang.lang) : artifact_info =
  A_binding_source lang

let a_binding (lang : Canary_lang.lang) (m : Canary_mechanism.mechanism) :
    artifact_info =
  A_binding (lang, m)

let a_app (w : app_wiring) : artifact_info = A_app w

(** Canonical born-safe id string: '-' refinement delimiter, safe for
    filesystem paths and ':'-separated env vars. *)
let string_of_id (id : artifact_info) : string =
  let base = string_of_artifact (kind_of id) in
  match id with
  | A_binding (_, m) -> base ^ "-" ^ Canary_mechanism.string_of_mechanism m
  | A_app w -> base ^ "-" ^ string_of_app_wiring w
  | A_lib (Some n) -> base ^ "-" ^ n
  (* [A_lib None] prints plain [lib]: an unnamed lib has no refinement to
     add, which is what keeps every existing id byte-identical. *)
  | A_source | A_headers | A_lib None | A_binding_source _ -> base

(* DISPLAY-ONLY pretty form: ':' delimiter. Never use for keys/paths. *)
let pretty_artifact = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding l -> "binding:" ^ Canary_lang.string_of_lang l
  | Binding_source l -> "binding_source:" ^ Canary_lang.string_of_lang l
  | App -> "app"

let pretty_id (id : artifact_info) : string =
  let base = pretty_artifact (kind_of id) in
  match id with
  | A_binding (_, m) -> base ^ ":" ^ Canary_mechanism.string_of_mechanism m
  | A_app w -> base ^ ":" ^ string_of_app_wiring w
  | A_lib (Some n) -> base ^ ":" ^ n
  | A_source | A_headers | A_lib None | A_binding_source _ -> base

(* ── project declaration (stage 1 / ssot §4.2) ── *)

(** A declared artifact's AXES — the per-ARTIFACT record the spec row
    carries: the provision×version universe + optional runtime-edge mode
    + optional follows constraint + optional STORE PINS (2026-08-12). *)
type artifact_axes = {
  ax_universe : (provision * Canary_basic.channel list) list;
  ax_runtime : Canary_store.dep_mode option;
  ax_follows : artifact_info option;
  ax_pins : Canary_basic.build_id list;
      (** pinned concrete versions for the Fetched provision, PROJECTED
          from the artifact's provider (never hand-declared): a pinned
          placement carries the version [id] in its build_id and is
          identity-bearing, where an unpinned Fetched stays
          version-ambient. *)
}
[@@deriving show]

(** Row constructor: [axes u] = universe only; [axes ~runtime:m u] also
    declares the runtime-edge mode; [axes ~pins:ps u] the store pins. *)
let axes ?runtime ?follows ?(pins = [])
    (u : (provision * Canary_basic.channel list) list) : artifact_axes =
  { ax_universe = u; ax_runtime = runtime; ax_follows = follows; ax_pins = pins }

(** STAGE 1 — a project's static declaration: WHAT the project is. Its
    artifacts, each artifact's provision universe (A1), and each artifact's
    version universe. These are *project facts*. *)
type project_spec = {
  ps_universe : (artifact_info * artifact_axes) list;
}
[@@deriving show]

(** From a raw [(artifact_info * artifact_axes) list]. *)
let project_spec_of_universe
    (u : (artifact_info * artifact_axes) list) : project_spec =
  { ps_universe = u }

let ps_artifacts (s : project_spec) : artifact_info list =
  List.map s.ps_universe ~f:fst

let ps_axes_of (s : project_spec) (id : artifact_info) : artifact_axes option =
  List.Assoc.find s.ps_universe id ~equal:equal_artifact_info

let ps_provisions_of (s : project_spec) (id : artifact_info) : provision list =
  match ps_axes_of s id with
  | Some ax -> List.map ax.ax_universe ~f:fst
  | None -> []

let ax_versions_of (ax : artifact_axes) (pv : provision) :
    Canary_basic.build_id list =
  (* STORE PINS (2026-08-12): a Fetched artifact with pinned versions
     ranges over the pins (identity-bearing build_ids) instead of the
     channel list. Unpinned artifacts keep the ambient rule. *)
  if equal_provision pv Fetched && not (List.is_empty ax.ax_pins) then
    ax.ax_pins
  else
    match List.Assoc.find ax.ax_universe pv ~equal:equal_provision with
    | Some cs -> List.map cs ~f:Canary_basic.good
    | None -> []

let ps_versions_of (s : project_spec) (id : artifact_info) (pv : provision) :
    Canary_basic.build_id list =
  match ps_axes_of s id with
  | None -> []
  | Some ax -> ax_versions_of ax pv

(** Every (provision, version) point the artifact may occupy — the
    axes read the way pass 2 ranges over them, with [Absent] dropped (it
    is the artifact NOT being there, not a version of it).

    Exists for the pair audit (`spec-check`'s [lib_pair] / [binding_pair],
    2026-08-25): "does this artifact have a channel pair" is a question
    about POINTS, and the two mechanisms that make a point look nothing
    alike — a second universe cell (apt + a prebuilt) and a second store
    pin (opam 0.6.0 + 0.7.0, ONE cell on one channel). Counting universe
    cells or distinct channels gets ssl and sqlite's binding pairs wrong;
    counting what [ax_versions_of] yields gets them right. *)
let ax_points (ax : artifact_axes) : (provision * Canary_basic.build_id) list =
  List.concat_map ax.ax_universe ~f:(fun (pv, _) ->
      if equal_provision pv Absent then []
      else List.map (ax_versions_of ax pv) ~f:(fun v -> (pv, v)))
  |> List.dedup_and_sort ~compare:(fun (p1, v1) (p2, v2) ->
         String.compare
           (Canary_store.string_of_provision p1
           ^ ":" ^ Canary_basic.string_of_build_id v1)
           (Canary_store.string_of_provision p2
           ^ ":" ^ Canary_basic.string_of_build_id v2))

(* ── placement & assignment (2026-08-08) ──
   Moved from Canary_enumerate — base vocabulary for the scenario IR. *)

type placement = { provision : provision; version : Canary_basic.build_id }
[@@deriving show]

type assignment = (artifact_info * placement) list [@@deriving show]
