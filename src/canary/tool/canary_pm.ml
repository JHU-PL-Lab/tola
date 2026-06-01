(** [Canary_pm] — PM dispatcher.

    Routes a [package_manager] enum value to the per-PM install / verify
    command in {!Canary_pm_apt}, {!Canary_pm_brew}, {!Canary_pm_opam},
    {!Canary_pm_pip}. Extracted from {!Canary_store} on 2026-06-01
    (Phase 9a) to fix the base→tool layer reversal: the dispatchers
    reach into [tool/], so they belong in [tool/], not next to the
    type definitions in [base/]. The [package_manager] enum,
    [system_package_spec] record, and the pure [system_pkg_for_pm]
    helper stay in {!Canary_store}.

    A reader looking for "what shell command installs a package" should
    land here. *)

open Canary_store

(** Generate the install command for a single package on the given PM.
    Opam and Unsupported get inline strings; the rest delegate to the
    per-PM driver. *)
let install_cmd pm ~pkg =
  match pm with
  | Brew -> Canary_pm_brew.install_cmd ~pkg
  | Apt -> Canary_pm_apt.install_cmd ~pkg
  | Opam -> [%string "eval $(opam env) && opam install %{pkg} -y --assume-depexts"]
  | Pip -> Canary_pm_pip.install_cmd ~pkg
  | Unsupported -> [%string "echo 'no package manager for %{pkg}' && false"]

(** Install the OS-appropriate package from a {!system_package_spec}. *)
let system_install_cmd pm (spec : system_package_spec) =
  install_cmd pm ~pkg:(system_pkg_for_pm spec pm)

(** Verify a system-installed package is present (for post-install
    sanity checks in test/canary_pm_test.ml and tool/canary_toolchain.ml). *)
let verify_system_install_cmd pm (spec : system_package_spec) =
  let pkg = system_pkg_for_pm spec pm in
  match pm with
  | Apt -> Canary_pm_apt.verify_installed_cmd ~pkg
  | Brew -> Canary_pm_brew.verify_installed_cmd ~pkg
  | Pip -> Canary_pm_pip.verify_installed_cmd ~pkg
  | Opam | Unsupported ->
      [%string "echo 'no verify command for %{pkg}' && false"]
