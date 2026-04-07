(* PM ops for opam (lang PM, isolated stores via switches).
   Each switch is an independent store with its own repo-url list.
   Packages can be installed directly, via local repo-url, or from
   a local switch (.opam file).

   Uniform PM ops:
   - install, remove, verify, query_version  (package ops)
   - check_available, list_depexts           (remote query)
   - current_switch, list_switches, switch   (store switching)
   - list_repos, add_repo, set_repo_url      (source management)

   Parallelism: each switch is independent, so tests on different
   switches can run in parallel. Tests within one switch are sequential
   (stateful). This connects to TODO #10 (unified build cache). *)

let install_cmd ~pkg =
  [%string "eval $(opam env) && opam install %{pkg} -y --assume-depexts"]

let remove_cmd ~pkg =
  [%string "eval $(opam env) && opam remove -y %{pkg}"]

let verify_installed_cmd ~pkg =
  [%string "eval $(opam env) && test -n \"$(opam list %{pkg} --installed --short 2>/dev/null)\""]

let query_version_cmd ~pkg =
  [%string "eval $(opam env) && opam show %{pkg} --field=version 2>/dev/null"]

let check_available_cmd ~pkg =
  [%string "eval $(opam env) && opam show %{pkg} >/dev/null 2>&1"]

let list_depexts_cmd ~pkg =
  [%string "eval $(opam env) && opam show %{pkg} --field=depexts 2>/dev/null"]

(* Store switching *)
let current_switch_cmd =
  "opam switch show"

let list_switches_cmd =
  "opam switch list --short"

let switch_cmd ~name =
  [%string "opam switch %{name} && eval $(opam env)"]

(* Source management: repo-url list per switch *)
let list_repos_cmd =
  "eval $(opam env) && opam repo list --short"

let add_repo_cmd ~name ~url =
  [%string "eval $(opam env) && opam repo add %{name} \"%{url}\" --rank=1"]

let set_repo_url_cmd ~name ~url =
  [%string "eval $(opam env) && opam repo set-url %{name} \"%{url}\""]

let update_repo_cmd ~name =
  [%string "eval $(opam env) && opam update %{name}"]
