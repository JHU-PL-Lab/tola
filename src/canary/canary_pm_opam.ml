let install_cmd ~pkg =
  [%string "eval $(opam env) && opam install %{pkg} -y --assume-depexts"]

let verify_installed_cmd ~pkg =
  [%string "eval $(opam env) && test -n \"$(opam list --installed-roots %{pkg} --short 2>/dev/null)\""]

let query_version_cmd ~pkg =
  [%string "eval $(opam env) && opam show %{pkg} --field=version 2>/dev/null"]

let check_available_cmd ~pkg =
  [%string "eval $(opam env) && opam show %{pkg} >/dev/null 2>&1"]

let list_depexts_cmd ~pkg =
  [%string "eval $(opam env) && opam show %{pkg} --field=depexts 2>/dev/null"]

let current_switch_cmd =
  "opam switch show"

let list_switches_cmd =
  "opam switch list --short"
