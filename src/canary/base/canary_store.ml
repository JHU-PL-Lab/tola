open Base

(* ── Package managers and locations ──
   A store is any place artifacts can be fetched from or published to.
   Location identifies where an artifact physically resides. *)

(* PM-related types (inlined from canary_pm_types.ml on 2026-06-01,
   Phase 10a). The separate file existed only because canary_store and
   the per-PM drivers needed shared types without a circular dep —
   now that the dispatchers (pm_install_cmd etc.) live in
   tool/canary_pm.ml (Phase 9a), no cycle remains. *)

type package_manager = Apt | Brew | Opam | Pip | Unsupported
type store_behavior = Stateless | Stateful_global | Isolated_store of string
type pm_scope = System | Lang

type pm_properties = {
  pm : package_manager;
  scope : pm_scope;
  behavior : store_behavior;
  switching : string;
  parallel_safe : bool;
}

type system_package_spec = {
  linux_pkg : string;
  macos_pkg : string;
  version_tag : string option;
  locator_hint : string option;
  behavior : store_behavior;
}

(* pm_info: what kind of package manager location.
   Sys_pm: system PM (apt/brew) — native C lib; pm distinguishes linux vs macOS.
   Lang_pm: language PM (opam/pip) — binding artifact; carries lang + pm.
   Future variants: Virtual_pm, Project_pm, Multi_lingua_pm, … *)
type pm_info =
  | Sys_pm of { pm : package_manager }
  | Lang_pm of { lang : Canary_lang.lang; pm : package_manager }

(* Location: objective "where does this artifact live right now".
   Build_tree: raw build output. Staged: cmake --install'd (TODO #25).
   Pm: in a package manager — see pm_info for the sub-kind. *)
type location =
  | Build_tree
  | Staged  (** cmake --install'd into a prefix — see TODO #25 *)
  | Pm of pm_info

(* Artifact status — the lifecycle state of an artifact (explicit
   complement to location). Renamed from [stage] on 2026-07-21 per
   SSOT §6.2 so [stage] is free for pipeline-phase meaning (Sc.N
   is-a stage). Derivable from location for now (Build_tree→Built,
   Staged→Installed, Pm→Packed or Fetched). Will become a field on
   a first-class artifact type. *)
type artifact_status = Built | Installed | Packed | Fetched

let string_of_pm = function
  | Apt -> "apt"
  | Brew -> "brew"
  | Opam -> "opam"
  | Pip -> "pip"
  | Unsupported -> "unsupported"

let string_of_store_behavior = function
  | Stateless -> "stateless"
  | Stateful_global -> "stateful-global"
  | Isolated_store name -> [%string "isolated(%{name})"]

let string_of_location = function
  | Build_tree -> "build_tree"
  | Staged -> "staged"
  | Pm (Sys_pm { pm }) -> [%string "sys_pm:%{string_of_pm pm}"]
  | Pm (Lang_pm { lang; pm }) ->
      [%string "%{Canary_lang.string_of_lang lang}:%{string_of_pm pm}"]

let is_source_location = function
  | Build_tree | Staged -> true
  | Pm _ -> false

(* Placeholder location for universal action-action enumeration (canary paths). *)
let store = Pm (Sys_pm { pm = Apt })

(* ── System package manager detection and commands ── *)

let detect_pm () =
  if Stdlib.Sys.command "which brew > /dev/null 2>&1" = 0 then Brew
  else if Stdlib.Sys.command "which apt-get > /dev/null 2>&1" = 0 then Apt
  else Unsupported

let store_behavior_of_pm = function
  | Apt | Brew -> Stateful_global
  | Opam -> Isolated_store "switch"
  | Pip -> Isolated_store "venv"
  | Unsupported -> Stateless

let mk_system_package_spec ?version_tag ?locator_hint
    ?(behavior = Stateful_global) ~linux_pkg ~macos_pkg () =
  { linux_pkg; macos_pkg; version_tag; locator_hint; behavior }

let system_pkg_for_pm spec pm =
  match pm with
  | Brew -> spec.macos_pkg
  | Apt | Opam | Pip | Unsupported -> spec.linux_pkg

(* The PM dispatchers (pm_install_cmd, system_install_cmd,
   verify_system_install_cmd) moved to tool/canary_pm.ml on 2026-06-01
   (Phase 9a) to fix the base→tool layer reversal. The per-PM drivers
   live in tool/canary_pm_{apt,brew,opam,pip}.ml; their dispatcher
   belongs next to them, not here. base/canary_store keeps only types
   and pure helpers. *)

(* ── Distro ──
   Cross-cutting: affects both source local-path lookup and system PM
   (apt on Linux, brew on macOS). Kept here since it's used by both
   the PM dispatch above and the source artifact module. *)

type distro = Wsl | MacOS_local

let distro_base : distro -> string = function
  | Wsl -> "/home/red/code"
  | MacOS_local -> "/Users/ex/code"

let all_distros = [ Wsl; MacOS_local ]

(* Source repo and its operations moved to canary_artifact_source.ml *)
