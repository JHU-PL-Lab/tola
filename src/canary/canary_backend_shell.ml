open Base
open Canary_basic

let guard_matches ~runner_os = function
  | On_runner_os os -> Poly.( = ) os runner_os

let render_step ~runner_os (step : step) =
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

let render_job ~runner_os (job : job) =
  let header =
    if String.is_empty job.description then
      [ [%string "# Job: %{job.id} (%{job.name})"] ]
    else
      [ [%string "# Job: %{job.id} (%{job.name})"];
        [%string "# %{job.description}"] ]
  in
  let lines =
    header @ List.filter_map job.steps ~f:(render_step ~runner_os)
  in
  String.concat ~sep:"\n\n" lines

let render_script ?(preamble_lines = []) ~runner_os (jobs : job list) =
  let active_jobs = List.filter jobs ~f:(fun j -> not j.if_disabled) in
  let jobs_str =
    List.map active_jobs ~f:(render_job ~runner_os) |> String.concat ~sep:"\n\n"
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
