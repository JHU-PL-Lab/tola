open Base

(* ── Package managers and locations ──
   A store is any place artifacts can be fetched from or published to.
   Location identifies where an artifact physically resides. *)

include Canary_pm_types

type system_package_spec = {
  linux_pkg : string;
  macos_pkg : string;
  version_tag : string option;
  locator_hint : string option;
  behavior : store_behavior;
}

type location = Build_tree | System_pm | Lang_pm | Wild of string

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
  | Build_tree -> "build tree"
  | System_pm -> "system PM"
  | Lang_pm -> "lang PM"
  | Wild s -> s

let is_source_location = function
  | Build_tree -> true
  | System_pm | Lang_pm | Wild _ -> false

(* Abstract unified store for action rule enumeration *)
let store = Wild "store"

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

let pm_install_cmd pm ~pkg =
  match pm with
  | Brew -> Canary_pm_brew.install_cmd ~pkg
  | Apt -> Canary_pm_apt.install_cmd ~pkg
  | Opam -> [%string "eval $(opam env) && opam install %{pkg} -y --assume-depexts"]
  | Pip -> Canary_pm_pip.install_cmd ~pkg
  | Unsupported -> [%string "echo 'no package manager for %{pkg}' && false"]

let system_install_cmd pm (spec : system_package_spec) =
  pm_install_cmd pm ~pkg:(system_pkg_for_pm spec pm)

let verify_system_install_cmd pm (spec : system_package_spec) =
  let pkg = system_pkg_for_pm spec pm in
  match pm with
  | Apt -> Canary_pm_apt.verify_installed_cmd ~pkg
  | Brew -> Canary_pm_brew.verify_installed_cmd ~pkg
  | Pip -> Canary_pm_pip.verify_installed_cmd ~pkg
  | Opam | Unsupported ->
      [%string "echo 'no verify command for %{pkg}' && false"]

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
