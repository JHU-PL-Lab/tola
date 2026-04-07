let install_cmd ~pkg = [%string "brew install %{pkg}"]

let verify_installed_cmd ~pkg = [%string "brew list %{pkg}"]

let query_version_cmd ~pkg =
  [%string "brew info --json=v2 %{pkg} 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['formulae'][0]['versions']['stable'])\""]

let check_available_cmd ~pkg =
  [%string "brew info %{pkg} >/dev/null 2>&1"]

let prefix_cmd ~pkg =
  [%string "brew --prefix %{pkg}"]
