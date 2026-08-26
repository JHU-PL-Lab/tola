(* PM ops for brew (system PM, stateful global store).
   Keg-only packages need explicit linking. *)

let properties : Canary_store.pm_properties = {
  pm = Brew;
  scope = System;
  behavior = Stateful_global;
  switching = "link/unlink for keg-only; brew switch (deprecated)";
  parallel_safe = false;
}

let install_cmd ~pkg = [%string "brew install %{pkg}"]

let remove_cmd ~pkg = [%string "brew uninstall %{pkg}"]

let verify_installed_cmd ~pkg = [%string "brew list %{pkg}"]

let is_installed ~pkg =
  Stdlib.Sys.command ([%string "%{verify_installed_cmd ~pkg} >/dev/null 2>&1"]) = 0

(* TWO DIFFERENT QUESTIONS, and they were one name (2026-08-26). This was
   [query_version_cmd], the sibling of apt's — but apt's asks [dpkg -s],
   "what version is INSTALLED", while this asked brew info, "what version
   is AVAILABLE". A caller reaching for the pair got the installed
   version on Linux and the latest published version on macOS, which is
   the sort of divergence a shared name hides rather than reveals: same
   signature, same call site, different fact. Split, and named for the
   fact each returns. *)

(** The newest version the tap KNOWS about — installed or not. *)
let available_version_cmd ~pkg =
  [%string "brew info --json=v2 %{pkg} 2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['formulae'][0]['versions']['stable'])\""]

(** The version actually INSTALLED (apt's [dpkg -s] counterpart). [brew
    list --versions] prints "<formula> <version>"; an uninstalled formula
    prints nothing, which is the same empty answer dpkg gives. *)
let installed_version_cmd ~pkg =
  [%string "brew list --versions %{pkg} 2>/dev/null | head -1 | awk '{print $NF}'"]

(* The old name, kept pointing at the AVAILABLE question because that is
   what its one caller (pm-test) has always asserted on. *)
let query_version_cmd = available_version_cmd

let check_available_cmd ~pkg =
  [%string "brew info %{pkg} >/dev/null 2>&1"]

let prefix_cmd ~pkg =
  [%string "brew --prefix %{pkg}"]

(* Version switching: link/unlink for keg-only packages *)
let link_cmd ~pkg = [%string "brew link %{pkg}"]

let unlink_cmd ~pkg = [%string "brew unlink %{pkg}"]
