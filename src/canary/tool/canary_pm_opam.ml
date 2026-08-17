(* PM ops for opam (lang PM, isolated stores via switches).
   Each switch is an independent store with its own repo-url list.
   Tests on different switches can run in parallel.
   Tests within one switch are sequential (stateful).

   NOTE: `eval $(opam env)` prefix activates the current/default switch.
   To target a specific switch, this should be replaced with
   `eval $(opam env --switch=<name>)`. Left as-is for now. *)

let properties : Canary_store.pm_properties = {
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

(* The version the switch currently HOLDS for [pkg] (installed-version
   query, not the repo's available version). The store-pin check (2026-08-12):
   shell half of [Canary_step_builder.pin_check_post] — the check_post
   compares this against the pin. The OPAM package version is the store's
   OWN record (robust across packages whose findlib META version differs
   from the opam version — e.g. z3.dev's META carries the source version
   while opam reports "dev"). *)
let version_of_cmd ~pkg =
  [%string "eval $(opam env) && opam list %{pkg} --installed --short --columns=version 2>/dev/null"]

(* A shell test: the switch holds exactly [pin] for [pkg]. *)
let holds_pin_cmd ~pkg ~pin =
  [%string "test \"$(%{version_of_cmd ~pkg})\" = \"%{pin}\""]

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

(* The generalized wrapper-package Publish primitive (2026-08-17, active
   plan 2 — generalizes [Canary_toolchain.opam_pack_cmd]): subst the
   wrapper's [opam.in] (the .in convention — opam indexes only [opam]
   files, so the env-interpolated source var is subst'd with the
   OPAMVAR_ prefix), register the canary-local repo idempotently, drop
   the conflicting store packages (the same-findlib names — the
   pin-switch's first half), install the wrapper over the scenario's
   source (ABSOLUTE — the opam-sandbox gotcha: the package script runs
   from the sandbox build dir where relative _out paths don't exist),
   and write the pack marker. The pin-check postcondition
   ([Canary_step_builder.pin_check_post]) verifies the store provably
   holds the published state. *)
let pack_wrapper_cmd ~repo_name ~repo_abs ~pkg ~pkg_dir ~src_var ~src_path
    ?(conflicts = []) ~output_dir ~variant_key () =
  let pack_ok = Canary_basic.variant_file ~variant_key "pack.ok" in
  let abs p =
    if String.starts_with ~prefix:"/" p then p else "$(pwd)/" ^ p
  in
  let removes =
    String.concat "\n"
      (List.map (fun c -> [%string "opam remove -y %{c} || true"]) conflicts)
  in
  (* the subst input: the wrapper's opam.in — [pkg] is the INSTALLABLE
     name, [pkg_dir] the repo dir (<name>.<version>, the z3.dev
     convention); the OPAMVAR_ prefix feeds opam's %{VAR}%
     interpolation. NOTE: [opam config subst] appends ".in" itself —
     the target is the BASE name (opam.in → opam; the CLAUDE.md
     gotcha). *)
  let subst =
    Printf.sprintf
      "OPAMVAR_%s=\"%s\" opam config subst %s/packages/%s/opam"
      src_var (abs src_path) repo_abs pkg_dir
  in
  [%string
    {|eval $(opam env)
printf 'opam-version: "2.0"\n' > "%{abs repo_abs}/repo"
%{subst}
opam repo remove %{repo_name} 2>/dev/null || true
opam repo add %{repo_name} "file://%{abs repo_abs}" --rank=1
opam update %{repo_name}
%{removes}
opam install -y %{pkg} --verbose --keep-build-dir --assume-depexts \
  && echo 'ok' > %{output_dir}/%{pack_ok}|}]
