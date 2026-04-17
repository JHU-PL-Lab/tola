(* PM ops for opam (lang PM, isolated stores via switches).
   Each switch is an independent store with its own repo-url list.
   Tests on different switches can run in parallel.
   Tests within one switch are sequential (stateful).

   NOTE: `eval $(opam env)` prefix activates the current/default switch.
   To target a specific switch, this should be replaced with
   `eval $(opam env --switch=<name>)`. Left as-is for now. *)

let properties : Canary_pm_types.pm_properties = {
  pm = Opam;
  scope = Lang;
  behavior = Isolated_store "switch";
  switching = "opam switch (full environment isolation)";
  parallel_safe = true;  (* across switches; not within one *)
}

let install_cmd ~pkg =
  [%string "eval $(opam env) && opam install %{pkg} -y --assume-depexts"]

let remove_cmd ~pkg =
  [%string "eval $(opam env) && opam remove -y %{pkg}"]

let verify_installed_cmd ~pkg =
  [%string "eval $(opam env) && test -n \"$(opam list %{pkg} --installed --short 2>/dev/null)\""]

let is_installed ~pkg =
  Stdlib.Sys.command (verify_installed_cmd ~pkg) = 0

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
