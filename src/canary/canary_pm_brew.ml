(* PM ops for brew (system PM, stateful global store).
   No isolated stores. Keg-only packages need explicit linking.

   Uniform PM ops:
   - install, remove, verify, query_version  (package ops)
   - check_available, prefix                  (remote query + locate)
   - link, unlink                             (version switching for keg-only) *)

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
