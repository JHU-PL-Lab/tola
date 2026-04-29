open Base

(* First-class API source layer.
   Captures the native API surface a library exposes and the language
   bindings that consume it. Hand-written per project; scan/summary reads
   this at post-build time to confirm each claim against the built artifacts.

   Provider side (native_api): declares which components an artifact exposes
   and carries path details for components known at fetch time.
   Consumer side (binding_api.deps): which components a binding needs,
   using the same api_component type.
   See doc/canary/design/interface.md §4 for the design rationale. *)

type lang =
  | OCaml
  | Python
  | Rust
  | Cpp
  | CSharp
  | Java
[@@deriving show]

type native_api_kind =
  | C
  | Cpp_api
[@@deriving show]

(* Component kinds — pure enum shared by provider (native_api.components)
   and consumer (binding_api.deps). No path payload here; paths live in
   the provider's detail fields (headers, etc.). *)
type api_component =
  | Headers      (** C/C++ public headers *)
  | Runtime_lib  (** versioned .so/.dylib — loaded at runtime *)
  | Link_stub    (** unversioned .so symlink — for -l at build time *)
  | Pc_file      (** pkg-config file — build-system metadata *)
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
  stable_symbols  : string list;
}
[@@deriving show]

type binding_api = {
  lang             : lang;
  source_dir       : string option;      (** relative to source root; None = out-of-tree *)
  deps             : api_component list; (** which components from native_api this binding needs *)
  module_watchlist : string list;        (** dotted paths ok: "Llvm.Opcode.UncondBr" *)
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

(* Canonical deps lists for common binding patterns *)
let deps_all          = [ Headers; Link_stub; Runtime_lib ]
let deps_runtime_only = [ Runtime_lib ]

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
   Runtime_lib / Link_stub / Pc_file are post-build or PM-installed — not checked here.
   Writes scan.ok to output_dir on success. *)
let scan_source_cmd ~source_root (api : t) ~output_dir =
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
     @ [[%string "echo 'scan ok' > %{output_dir}/scan.ok"]])
