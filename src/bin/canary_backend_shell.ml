open Base
open Canary_basic

let guard_matches ~runner_os = function
  | On_runner_os os -> Poly.( = ) os runner_os

let render_step ~runner_os (step : string step) =
  if Option.value_map step.guard ~default:true ~f:(guard_matches ~runner_os)
  then
    let body = step.action in
    let header = [%string "# Step: %{step.name}"] in
    Some
      (String.concat ~sep:"\n"
         [
           header;
           "if [ -f \"$GITHUB_ENV\" ]; then";
           "  set -a";
           "  . \"$GITHUB_ENV\"";
           "  set +a";
           "fi";
           body;
         ])
  else None

let render_job ~runner_os (job : string job) =
  let lines =
    [ [%string "# Job: %{job.id} (%{job.name})"] ]
    @ List.filter_map job.steps ~f:(render_step ~runner_os)
  in
  String.concat ~sep:"\n\n" lines

let render_script ?(preamble_lines = []) ~runner_os (jobs : string job list) =
  let jobs_str =
    List.map jobs ~f:(render_job ~runner_os) |> String.concat ~sep:"\n\n"
  in
  String.concat ~sep:"\n"
    ([ "#!/usr/bin/env bash"; "set -euo pipefail" ]
    @ [
        "if [ -z \"${GITHUB_ENV:-}\" ]; then";
        "  GITHUB_ENV=\"${TMPDIR:-/tmp}/canary_github_env.$$\"";
        "  export GITHUB_ENV";
        "fi";
        ": > \"$GITHUB_ENV\"";
      ]
    @ preamble_lines @ [ ""; jobs_str; "" ])
