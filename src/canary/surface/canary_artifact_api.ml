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

type lang =
  | Cpp
  | OCaml
  | Python
  | Rust
  | CSharp
  | Java
[@@deriving show]

let string_of_lang = function
  | Cpp -> "cpp" | OCaml -> "ocaml"
  | Python -> "python" | Rust -> "rust" | CSharp -> "csharp" | Java -> "java"

let display_of_lang = function
  | Cpp -> "C++" | OCaml -> "OCaml"
  | Python -> "Python" | Rust -> "Rust" | CSharp -> "C#" | Java -> "Java"

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
  lang             : lang;               (** explicit language tag — Binding is always lang-keyed *)
  source_dir       : string option;      (** Some _ ↔ Build_binding applicable; headers here or in -dev pkg *)
  module_watchlist : string list;        (** L3: dotted paths ok: "Llvm.Opcode.UncondBr" *)
  (* L2: type/function signatures to inspect (.cmi digests, C prototypes).
     Placeholder — inspect not yet wired. *)
  type_watchlist   : string list;
}
[@@deriving show]

(* ── Binding probe specs — how to compile/run the probe for each language ── *)

type ocaml_binding = {
  example_target   : string;
  example_name     : string;
  example_file     : string;
  binding_lib_name : string;
  build_api_path   : string option;
}

type python_binding = {
  probe_snippet : string;
  pip_package   : string option;
}

type t = {
  native_api   : native_api;
  binding_apis : binding_api list;
}
[@@deriving show]

let _ = show_lang
let _ = show

(* Watchlist accessors — used by summary closures in project specs *)

let native_watchlist (api : t) = api.native_api.stable_symbols

let binding_watchlist_exn (api : t) (lang : lang) =
  match List.find api.binding_apis ~f:(fun b -> Poly.equal b.lang lang) with
  | Some b -> b.module_watchlist
  | None ->
      failwith
        [%string "canary_artifact_api: no binding for lang %{show_lang lang}"]

(* Shell warning prefix for a summary command when a stable (fetch-only)
   source reuses the dev api_source spec. *)
let stable_reuse_warning ~source_name ~source_version =
  [%string
    "echo 'NOTE: api_source is the dev spec reused for stable source \
     %{source_name}/%{source_version}; watchlist may drift'"]

(* Shell command that verifies api_source claims against the fetched source tree.
   Headers component: checks dir exists and each listed file exists.
   binding_api.source_dir (in-tree): checks dir exists.
   Runtime_lib / Link_lib / Pc_file are post-build or PM-installed — not checked here.
   Writes scan.ok to output_dir on success. *)
let scan_source_cmd ~source_root (api : t) ~output_dir ~variant_key =
  let ok = Canary_output_path.variant_file ~variant_key "scan.ok" in
  let header_checks =
    match api.native_api.headers with
    | None -> []
    | Some { dir; files } ->
        let abs_dir = [%string "%{source_root}/%{dir}"] in
        [%string "test -d %{abs_dir}"]
        :: List.map files ~f:(fun f -> [%string "test -f %{abs_dir}/%{f}"])
  in
  let binding_checks =
    List.filter_map api.binding_apis ~f:(fun b ->
      Option.map b.source_dir ~f:(fun sd ->
        [%string "test -d %{source_root}/%{sd}"]))
  in
  String.concat ~sep:"\n"
    (header_checks @ binding_checks
     @ [[%string "echo 'scan ok' > %{output_dir}/%{ok}"]])
