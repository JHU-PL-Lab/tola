(* PM ops for brew (system PM, stateful global store).
   Keg-only packages need explicit linking. *)

let properties : Canary_pm_types.pm_properties = {
  pm = Brew;
  scope = System;
  behavior = Stateful_global;
  switching = "link/unlink for keg-only; brew switch (deprecated)";
  parallel_safe = false;
}

let install_cmd ~pkg = [%string "brew install %{pkg}"]

let remove_cmd ~pkg = [%string "brew uninstall %{pkg}"]

let verify_installed_cmd ~pkg = [%string "brew list %{pkg}"]

let query_version_cmd ~pkg =
  [%string "brew info --json=v2 %{pkg} 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['formulae'][0]['versions']['stable'])\""]

let check_available_cmd ~pkg =
  [%string "brew info %{pkg} >/dev/null 2>&1"]

let prefix_cmd ~pkg =
  [%string "brew --prefix %{pkg}"]

(* Version switching: link/unlink for keg-only packages *)
let link_cmd ~pkg = [%string "brew link %{pkg}"]

let unlink_cmd ~pkg = [%string "brew unlink %{pkg}"]
