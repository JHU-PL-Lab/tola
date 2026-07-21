open Base
open Canary

(* ── GH Actions YAML backend ──
   Renders step lists as GH Actions workflow YAML.
   Design: one GH job per project variant; each step → one GH step.
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
  let base = "$GITHUB_WORKSPACE/_out/canary/projects/" in
  let project_name = match String.rsplit2 project ~on:'/' with
    | Some (name, _) -> name
    | None -> project
  in
  let step_dir = Canary_basic.step_dir_of_tag tag in
  base ^ project_name ^ "/" ^ step_dir

(* Render one step as one or two GH step blocks.
   Expect_failure yields two steps: run (continue-on-error) + verify. *)
let render_gh_step ~project (step : step) =
  (* Use output_tag (not tag) so summary steps share the parent's directory. *)
  let out = output_dir_of ~project ~tag:step.output_tag in
  let raw_cmd = step.cmd ~output_dir:out ~variant_key:step.variant_id in
  let full_cmd = [%string "mkdir -p \"%{out}\"\n%{raw_cmd}"] in
  let run_block body = [%string "        run: |\n%{indent 10 body}\n"] in
  let sym_check_step =
    match step.symbol_check with
    | None -> []
    | Some sc ->
        let checks =
          List.map sc.required ~f:(fun e ->
              let pat =
                match e.sym_version with
                | None -> e.sym_name
                | Some v -> [%string "%{e.sym_name}@@%{v}"]
              in
              [%string
                {|nm -D '%{sc.provided_lib}' 2>/dev/null | grep -qF '%{pat}' || { echo "FAIL: required symbol missing: %{pat}"; exit 1; }|}])
          @ List.map sc.missing ~f:(fun e ->
              let pat =
                match e.sym_version with
                | None -> e.sym_name
                | Some v -> [%string "%{e.sym_name}@@%{v}"]
              in
              [%string
                {|nm -D '%{sc.provided_lib}' 2>/dev/null | grep -qF '%{pat}' && { echo "FAIL: symbol present but should be missing: %{pat}"; exit 1; } || true|}])
        in
        let body =
          String.concat ~sep:"\n" checks
          ^ [%string "\necho 'symbol check passed: %{sc.provided_lib}'"]
        in
        [ [%string {|      - name: %{step.tag} (symbols)
%{run_block body}|}] ]
  in
  let render_failure_check ~contains_any =
    let id = sanitize_id step.tag in
    let grep_check =
      List.map contains_any ~f:(fun pat ->
          [%string {|grep -qF '%{pat}' "%{out}/probe.log" 2>/dev/null|}])
      |> String.concat ~sep:" \\\n          || "
    in
    let verify_body =
      if List.is_empty contains_any then
        [%string
          {|if [ "${{ steps.%{id}.outcome }}" = "success" ]; then
  echo "FAIL: expected failure but step succeeded"
  exit 1
fi
echo "PASS: expected failure confirmed (no specific predicted strings)"|}]
      else
        [%string
          {|if [ "${{ steps.%{id}.outcome }}" = "success" ]; then
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
    [
      [%string
        {|      - name: %{step.tag}
        id: %{id}
        continue-on-error: true
%{run_block full_cmd}|}];
      [%string
        {|      - name: %{step.tag} (verify)
%{run_block verify_body}|}];
    ]
  in
  match step.expectation with
  | Expect_success ->
      [ [%string {|      - name: %{step.tag}
%{run_block full_cmd}|}] ]
      @ sym_check_step
  | Expect_compat_failure { inputs; version_info = _ } ->
      (* Resolve predictions at YAML-generation time using locally-cached
         summaries. When cache is empty (fresh CI runner), the fallback in
         render_failure_check accepts any failure with non-empty probe.log.
         Path format: "step_tag/file.json". v3 layout: no variant subdir —
         variant_id is encoded as a filename suffix (e.g. summary_19.json). *)
      let project_dir = step.project_dir in
      let resolve rel =
        match String.lsplit2 rel ~on:'/' with
        | Some (step_tag, file) ->
            let step_d = Canary_basic.step_dir_of_tag step_tag in
            let vk_file = Canary_basic.variant_file
                ~variant_key:step.variant_id file in
            project_dir ^ "/" ^ step_d ^ "/" ^ vk_file
        | None ->
            let vk_rel = Canary_basic.variant_file
                ~variant_key:step.variant_id rel in
            project_dir ^ "/" ^ vk_rel
      in
      let derived =
        Canary_compat_run.predicted_contains_any_v2
          ~disabled:step.disabled_contracts ~resolve inputs
      in
      render_failure_check ~contains_any:derived
  | Expect_failure { contains_any; version_info = _ } ->
      render_failure_check ~contains_any

let render_job ~job_id ~job_name ~runner_os ~ocaml_version ~project ~sys_deps
    ~preamble_steps (steps : step list) =
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
  let preamble =
    if List.is_empty preamble_steps then ""
    else String.concat ~sep:"\n" preamble_steps ^ "\n"
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
%{preamble}%{sys_deps_step}%{opam_repo_setup}
%{gh_steps}
|}]

type job_spec = {
  id : string;
  name : string;
  project : string;
  sys_deps : string list; (* apt packages to install before action steps *)
  preamble_steps : string list; (* raw yaml steps inserted after setup-ocaml *)
  steps : step list;
}

let render_workflow ?(runner_os = "ubuntu-latest") ?(ocaml_version = "5.2")
    ?(triggers = "on:\n  push:\n  pull_request:") ~workflow_name
    (jobs : job_spec list) =
  let jobs_yaml =
    List.map jobs ~f:(fun j ->
        render_job ~job_id:j.id ~job_name:j.name ~runner_os ~ocaml_version
          ~project:j.project ~sys_deps:j.sys_deps
          ~preamble_steps:j.preamble_steps j.steps)
    |> String.concat ~sep:"\n"
  in
  [%string {|name: %{workflow_name}

%{triggers}

jobs:
%{jobs_yaml}|}]
