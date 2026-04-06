open Base

(* ── Package managers and locations ──
   A store is any place artifacts can be fetched from or published to.
   Location identifies where an artifact physically resides. *)

type package_manager = Apt | Brew | Opam | Unsupported
type store_behavior = Stateless | Stateful_global | Isolated_store of string

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
  | Unsupported -> Stateless

let mk_system_package_spec ?version_tag ?locator_hint
    ?(behavior = Stateful_global) ~linux_pkg ~macos_pkg () =
  { linux_pkg; macos_pkg; version_tag; locator_hint; behavior }

let system_pkg_for_pm spec pm =
  match pm with
  | Brew -> spec.macos_pkg
  | Apt | Opam | Unsupported -> spec.linux_pkg

let pm_install_cmd pm ~pkg =
  match pm with
  | Brew -> Canary_basic_brew.install_cmd ~pkg
  | Apt -> Canary_basic_apt.install_cmd ~pkg
  | Opam -> [%string "eval $(opam env) && opam install %{pkg} -y --assume-depexts"]
  | Unsupported -> [%string "echo 'no package manager for %{pkg}' && false"]

let system_install_cmd pm (spec : system_package_spec) =
  pm_install_cmd pm ~pkg:(system_pkg_for_pm spec pm)

let verify_system_install_cmd pm (spec : system_package_spec) =
  let pkg = system_pkg_for_pm spec pm in
  match pm with
  | Apt -> Canary_basic_apt.verify_installed_cmd ~pkg
  | Brew -> Canary_basic_brew.verify_installed_cmd ~pkg
  | Opam | Unsupported ->
      [%string "echo 'no verify command for %{pkg}' && false"]

(* ── Source store ──
   Models how to obtain source code. A source_repo is the package-like
   struct: it pairs a remote (where to fetch from) with locals (cached
   checkouts per distro), plus version metadata.

   Distro base directories factor out the per-machine prefix so local
   paths can be expressed as base / relative. *)

type distro = Wsl | MacOS_local

let distro_base : distro -> string = function
  | Wsl -> "/home/red/code"
  | MacOS_local -> "/Users/ex/code"

type git_remote = Git_remote of string   (* url *)

type local_path = {
  distro : distro;
  path : string;
}

type source_repo = {
  name : string;                         (* e.g., "z3" *)
  remote : git_remote;
  locals : local_path list;
  version : string;                      (* "dev", "4.13.4" *)
  ref_ : string;                         (* "HEAD", "z3-4.13.4" *)
  official : bool;
}

(* Generate local_path entries for all distros from a relative path.
   e.g., mk_locals "contrib/z3-all/z3" = [
     { distro = Wsl; path = "/home/red/code/contrib/z3-all/z3" };
     { distro = MacOS_local; path = "/Users/ex/code/contrib/z3-all/z3" };
   ] *)
let all_distros = [ Wsl; MacOS_local ]

let mk_locals rel_path =
  List.map all_distros ~f:(fun distro ->
      { distro; path = distro_base distro ^ "/" ^ rel_path })

(* Find the local checkout for a distro, if any *)
let local_for distro (repo : source_repo) =
  List.find repo.locals ~f:(fun l ->
      match l.distro, distro with
      | Wsl, Wsl -> true
      | MacOS_local, MacOS_local -> true
      | _ -> false)

(* Resolve the source root path: local checkout if available,
   otherwise will need to clone *)
let source_root distro (repo : source_repo) =
  match local_for distro repo with
  | Some l -> Some l.path
  | None -> None

(* Generate the fetch_source shell command.
   If a local checkout exists, verify it. Otherwise clone from remote
   into the canary local cache. For arbitrary refs (commit SHAs), we
   clone then checkout in two steps since --branch only works for
   tags and branch names. *)
let source_fetch_cmd distro (repo : source_repo) ~output_dir =
  match local_for distro repo with
  | Some l ->
      [%string "test -d %{l.path} && echo '%{l.path}' > %{output_dir}/source.ok"]
  | None ->
      let (Git_remote url) = repo.remote in
      let ref_ = repo.ref_ in
      (* Clone into a stable path derived from version+ref, not output_dir,
         so build_lib etc. can find it via root_of_source *)
      let clone_dir = [%string "_out/canary/_local/%{repo.name}/%{repo.version}_%{ref_}/src"] in
      [%string "if [ -d %{clone_dir}/.git ]; then cd %{clone_dir} && git fetch && git checkout %{ref_}; else git clone %{url} %{clone_dir} && cd %{clone_dir} && git checkout %{ref_}; fi && echo '%{clone_dir}' > %{output_dir}/source.ok"]

(* check_post for fetch_source: read source.ok and verify the path exists *)
let source_check_post ~output_dir =
  let ok_file = output_dir ^ "/source.ok" in
  if Stdlib.Sys.file_exists ok_file then
    let ic = Stdlib.open_in ok_file in
    let path = Stdlib.input_line ic in
    Stdlib.close_in ic;
    Stdlib.Sys.file_exists path
  else false
