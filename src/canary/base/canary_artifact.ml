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
  | Absent | Fetched | Built | Vendored
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
   via-helper). The enumeration's identity is the pair (artifact, artifact_ext)
   — the coarse kind + an [ext] that refines a binding by its mechanism and an
   app by its wiring. *)

(** How an app consumes the library (decision 2, ssot §4.2.3). *)
type app_wiring = Direct | Via_helper [@@deriving show, eq]

let string_of_app_wiring = function Direct -> "direct" | Via_helper -> "via_helper"

(** Per-kind extension distinguishing several artifacts of the same coarse
    kind: a binding by its mechanism, an app by its wiring. *)
type artifact_ext =
  | Ext_none  (** source / headers / lib *)
  | Ext_mechanism of Canary_mechanism.mechanism  (** a binding *)
  | Ext_wiring of app_wiring  (** an app *)
[@@deriving show, eq]

(** The enumeration's precise artifact identity — the coarse [kind] plus its
    [ext] (≡ the (artifact, artifact_ext) pair). [kind_of] projects back to
    the coarse [Canary_basic.artifact_kind]. *)
type artifact_id = { kind : artifact; ext : artifact_ext } [@@deriving show, eq]

let kind_of (id : artifact_id) : artifact = id.kind
let ext_of (id : artifact_id) : artifact_ext = id.ext

(* smart constructors *)
let a_source : artifact_id = { kind = Source; ext = Ext_none }
let a_headers : artifact_id = { kind = Headers; ext = Ext_none }
let a_lib : artifact_id = { kind = Lib; ext = Ext_none }

let a_binding_source (lang : Canary_lang.lang) : artifact_id =
  { kind = Binding_source lang; ext = Ext_none }

let a_binding (lang : Canary_lang.lang) (m : Canary_mechanism.mechanism) :
    artifact_id =
  { kind = Binding lang; ext = Ext_mechanism m }

let a_app (w : app_wiring) : artifact_id = { kind = App; ext = Ext_wiring w }

(** Canonical born-safe id string: '-' ext delimiter, filesystem/env-var safe. *)
let string_of_id (id : artifact_id) : string =
  let base = string_of_artifact id.kind in
  match id.ext with
  | Ext_none -> base
  | Ext_mechanism m -> base ^ "-" ^ Canary_mechanism.string_of_mechanism m
  | Ext_wiring w -> base ^ "-" ^ string_of_app_wiring w

(* DISPLAY-ONLY pretty form: ':' delimiter. Never use for keys/paths. *)
let pretty_artifact = function
  | Source -> "source"
  | Headers -> "headers"
  | Lib -> "lib"
  | Binding l -> "binding:" ^ Canary_lang.string_of_lang l
  | Binding_source l -> "binding_source:" ^ Canary_lang.string_of_lang l
  | App -> "app"

let pretty_id (id : artifact_id) : string =
  let base = pretty_artifact id.kind in
  match id.ext with
  | Ext_none -> base
  | Ext_mechanism m -> base ^ ":" ^ Canary_mechanism.string_of_mechanism m
  | Ext_wiring w -> base ^ ":" ^ string_of_app_wiring w

(* ── project declaration (stage 1 / ssot §4.2) ── *)

(** A declared artifact's AXES — the per-ARTIFACT record the spec row
    carries: the provision×version universe + optional runtime-edge mode
    + optional follows constraint + optional STORE PINS (2026-08-12). *)
type artifact_axes = {
  ax_universe : (provision * Canary_basic.channel list) list;
  ax_runtime : Canary_store.dep_mode option;
  ax_follows : artifact_id option;
  ax_pins : Canary_basic.build_id list;
      (** pinned concrete versions for the Fetched provision, PROJECTED
          from the artifact's provider (never hand-declared): a pinned
          placement carries the version [id] in its build_id and is
          identity-bearing, where an unpinned Fetched stays
          version-ambient. *)
}

(** Row constructor: [axes u] = universe only; [axes ~runtime:m u] also
    declares the runtime-edge mode; [axes ~pins:ps u] the store pins. *)
let axes ?runtime ?follows ?(pins = [])
    (u : (provision * Canary_basic.channel list) list) : artifact_axes =
  { ax_universe = u; ax_runtime = runtime; ax_follows = follows; ax_pins = pins }

(** STAGE 1 — a project's static declaration: WHAT the project is. Its
    artifacts, each artifact's provision universe (A1), and each artifact's
    version universe. These are *project facts*. *)
type project_spec = {
  ps_universe : (artifact_id * artifact_axes) list;
}

(** From a raw [(artifact_id * artifact_axes) list]. *)
let project_spec_of_universe
    (u : (artifact_id * artifact_axes) list) : project_spec =
  { ps_universe = u }

let ps_artifacts (s : project_spec) : artifact_id list =
  List.map s.ps_universe ~f:fst

let ps_axes_of (s : project_spec) (id : artifact_id) : artifact_axes option =
  List.Assoc.find s.ps_universe id ~equal:equal_artifact_id

let ps_provisions_of (s : project_spec) (id : artifact_id) : provision list =
  match ps_axes_of s id with
  | Some ax -> List.map ax.ax_universe ~f:fst
  | None -> []

let ps_versions_of (s : project_spec) (id : artifact_id) (pv : provision) :
    Canary_basic.build_id list =
  match ps_axes_of s id with
  | None -> []
  | Some ax -> (
      (* STORE PINS (2026-08-12): a Fetched artifact with pinned versions
         ranges over the pins (identity-bearing build_ids) instead of the
         channel list. Unpinned artifacts keep the ambient rule. *)
      if equal_provision pv Fetched && not (List.is_empty ax.ax_pins) then
        ax.ax_pins
      else
        match List.Assoc.find ax.ax_universe pv ~equal:equal_provision with
        | Some cs -> List.map cs ~f:Canary_basic.good
        | None -> [])

(* ── placement & assignment (2026-08-08) ──
   Moved from Canary_enumerate — base vocabulary for the scenario IR. *)

type placement = { provision : provision; version : Canary_basic.build_id }

type assignment = (artifact_id * placement) list
