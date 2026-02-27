open Base
open Tola_std

type t = {
  prefix_name : string;
  prefix_var : string;
  prefix_envar : string;
  libdir_name : string;
  libdir_var : string;
  local_repo_name : string;
  package_name : string;
  package_version : string;
  canary_src_var : string;
}

let default =
  {
    prefix_name = "Z3_PREFIX";
    prefix_var = "$Z3_PREFIX";
    prefix_envar = "${Z3_PREFIX}";
    libdir_name = "Z3_LIB_DIR";
    libdir_var = "$Z3_LIB_DIR";
    local_repo_name = "local-z3-dev";
    package_name = "z3";
    package_version = "dev";
    canary_src_var = "CANARY_Z3_SRC";
  }

let pkg_full t = [%string "%{t.package_name}.%{t.package_version}"]

let install_and_prefix_cmds t (os : Canary_helper.runner_os) pkg =
  let install_cmd, prefix_cmd =
    match os with
    | Ubuntu ->
        ( [%string "sudo apt install -y %{pkg}"],
          [%string "pkg-config --variable=prefix %{pkg}"] )
    | MacOS ->
        ([%string "brew install %{pkg}"], [%string "brew --prefix %{pkg}"])
  in
  let libdir_cmd =
    match os with
    | Ubuntu -> [%string "pkg-config --variable=libdir %{pkg}"]
    | MacOS -> [%string "echo \"$(%{prefix_cmd})/lib\""]
  in
  [
    install_cmd;
    prefix_cmd;
    [%string "echo \"%{t.prefix_name}=$(%{prefix_cmd})\" >> \"$GITHUB_ENV\""];
    [%string "echo \"%{t.libdir_name}=$(%{libdir_cmd})\" >> \"$GITHUB_ENV\""];
    [%string "echo \"Detected %{t.prefix_name}=%{t.prefix_var}\""];
    [%string "echo \"Detected %{t.libdir_name}=%{t.libdir_var}\""];
  ]
  |> String.concat ~sep:"\n"

let install_local_cmd t ~canary_contrib_rel =
  let pkg_full = pkg_full t in
  let repo_rel = canary_contrib_rel $/ "opam-local-repo" in
  let opam_rel =
    [%string "%{repo_rel}/packages/%{t.package_name}/%{pkg_full}/opam"]
  in
  [%string
    {|eval $(opam env)
OPAMVAR_%{t.canary_src_var}="git+file://$PWD" opam config subst %{opam_rel}
opam repo add %{t.local_repo_name} "file://$PWD/%{repo_rel}" --rank=1 || opam repo set-url %{t.local_repo_name} "file://$PWD/%{repo_rel}"
opam update %{t.local_repo_name}
opam remove -y %{pkg_full} || true
opam install -y %{pkg_full} --verbose|}]

(* 
# This is a two-step tests, though we should test them separately
#   - package z3.dev works
#   - package z3.dev under opam works

opam repository remove local-repo --yes --all || true

#   SRC_DIR="$OPAM_SWITCH_PREFIX/.opam-switch/sources/z3.dev"
#   cp "$SRC_DIR/examples/ml/ml_example.ml" .
*)
