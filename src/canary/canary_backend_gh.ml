open Base

(* ── GH Actions YAML backend ──
   Renders action_step lists as GH Actions workflow YAML.
   Design: one GH job per project variant; each action_step → one GH step.
   Steps share a runner filesystem so no artifact passing is needed. *)

let indent n s =
  let pad = String.make n ' ' in
  String.split_lines s
  |> List.map ~f:(fun line -> if String.is_empty line then "" else pad ^ line)
  |> String.concat ~sep:"\n"

let sanitize_id s =
  String.map s ~f:(fun c ->
      if Char.is_alphanum c || Char.equal c '-' || Char.equal c '_' then c
      else '_')

let output_dir_of ~project ~tag =
  "$GITHUB_WORKSPACE/_out/canary/" ^ project ^ "/" ^ tag

(* Render one action_step as one or two GH step blocks.
   Expect_failure yields two steps: run (continue-on-error) + verify. *)
let render_gh_step ~project (step : Canary_action.action_step) =
  let out = output_dir_of ~project ~tag:step.tag in
  let raw_cmd = step.cmd ~output_dir:out in
  let full_cmd = [%string "mkdir -p \"%{out}\"\n%{raw_cmd}"] in
  let run_block body =
    [%string "        run: |\n%{indent 10 body}\n"]
  in
  match step.expectation with
  | Expect_success | Expect_symbols _ ->
    [ [%string {|      - name: %{step.tag}
%{run_block full_cmd}|}] ]
  | Expect_failure { contains_any } ->
    let id = sanitize_id step.tag in
    let grep_check =
      List.map contains_any ~f:(fun pat ->
          [%string {|grep -qF '%{pat}' "%{out}/probe.log" 2>/dev/null|}])
      |> String.concat ~sep:" \\\n          || "
    in
    let verify_body =
      [%string {|if [ "${{ steps.%{id}.outcome }}" = "success" ]; then
  echo "FAIL: expected failure but step succeeded"
  exit 1
fi
if %{grep_check}; then
  echo "PASS: expected failure confirmed"
else
  echo "FAIL: expected message not found in probe.log"
  cat "%{out}/probe.log" || true
  exit 1
fi|}]
    in
    [ [%string {|      - name: %{step.tag}
        id: %{id}
        continue-on-error: true
%{run_block full_cmd}|}];
      [%string {|      - name: %{step.tag} (verify)
%{run_block verify_body}|}] ]

let render_job ~job_id ~job_name ~runner_os ~ocaml_version ~project ~sys_deps
    (steps : Canary_action.action_step list) =
  let gh_steps =
    List.concat_map steps ~f:(render_gh_step ~project)
    |> String.concat ~sep:"\n"
  in
  let sys_deps_step =
    if List.is_empty sys_deps then ""
    else
      let pkgs = String.concat ~sep:" " sys_deps in
      [%string
        {|      - name: Install system build dependencies
        run: sudo apt-get install -y --no-install-recommends %{pkgs}
|}]
  in
  let opam_repo_setup =
    [%string
      {|      - name: Add canary opam repo
        run: |
          eval $(opam env)
          opam repo add canary-local \
            "file://$GITHUB_WORKSPACE/canary/templates/opam-local-repo" \
            --rank=1 2>/dev/null \
            || opam repo set-url canary-local \
            "file://$GITHUB_WORKSPACE/canary/templates/opam-local-repo"
          opam update canary-local
|}]
  in
  [%string
    {|  %{job_id}:
    name: %{job_name}
    runs-on: %{runner_os}
    steps:
      - uses: actions/checkout@v6
      - uses: ocaml/setup-ocaml@v3
        with:
          ocaml-compiler: "%{ocaml_version}"
%{sys_deps_step}%{opam_repo_setup}
%{gh_steps}
|}]

type job_spec = {
  id : string;
  name : string;
  project : string;
  sys_deps : string list;   (* apt packages to install before action steps *)
  steps : Canary_action.action_step list;
}

let render_workflow ?(runner_os = "ubuntu-latest") ?(ocaml_version = "5.2")
    ~workflow_name (jobs : job_spec list) =
  let jobs_yaml =
    List.map jobs ~f:(fun j ->
        render_job ~job_id:j.id ~job_name:j.name ~runner_os ~ocaml_version
          ~project:j.project ~sys_deps:j.sys_deps j.steps)
    |> String.concat ~sep:"\n"
  in
  [%string
    {|name: %{workflow_name}

on:
  push:
  pull_request:

jobs:
%{jobs_yaml}|}]
