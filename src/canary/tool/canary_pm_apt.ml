(* PM ops for apt (system PM, stateful global store).
   No isolated stores. Version switching via update-alternatives. *)

let properties : Canary_store.pm_properties = {
  pm = Apt;
  scope = System;
  behavior = Stateful_global;
  switching = "update-alternatives (per-command, not per-store)";
  parallel_safe = false;
}

let install_cmd ~pkg = [%string "sudo apt-get install -y %{pkg}"]

let remove_cmd ~pkg = [%string "sudo apt-get remove -y %{pkg}"]

let verify_installed_cmd ~pkg = [%string "dpkg -s %{pkg}"]

let is_installed ~pkg =
  Stdlib.Sys.command ([%string "%{verify_installed_cmd ~pkg} >/dev/null 2>&1"]) = 0

let query_version_cmd ~pkg =
  [%string "dpkg -s %{pkg} 2>/dev/null | grep '^Version:' | cut -d' ' -f2"]

let check_available_cmd ~pkg =
  [%string "apt-cache show %{pkg} >/dev/null 2>&1"]

let list_available_versions_cmd ~pkg =
  [%string "apt-cache madison %{pkg} 2>/dev/null | awk '{print $3}'"]

(* Version switching: update-alternatives (per-command, not per-store).
   e.g., llvm-config-19 vs llvm-config-18 *)
let active_alternative_cmd ~name =
  [%string "update-alternatives --display %{name} 2>/dev/null | head -2"]

let set_alternative_cmd ~name ~path =
  [%string "sudo update-alternatives --set %{name} %{path}"]
