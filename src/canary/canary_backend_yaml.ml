open Base
open Canary_basic

let render_step_guard = function
  | On_runner_os Ubuntu -> "runner.os == 'Linux'"
  | On_runner_os MacOS -> "runner.os == 'macOS'"

let render_preamble_action { name; uses; with_fields } =
  let name_lines =
    match name with
    | Some n -> [ "      - name: " ^ n ]
    | None -> [ "      - uses: " ^ uses ]
  in
  let uses_line =
    if Option.is_some name then [ "        uses: " ^ uses ] else []
  in
  let with_lines =
    if List.is_empty with_fields then []
    else
      [ "        with:" ]
      @ List.map with_fields ~f:(fun (k, v) -> "          " ^ k ^ ": " ^ v)
  in
  String.concat ~sep:"\n" (name_lines @ uses_line @ with_lines)

let render_step (step : step) =
      let base = [ "      - name: " ^ step.name ] in
      let if_lines =
        match step.guard with
        | Some guard -> [ "        if: " ^ render_step_guard guard ]
        | None -> []
      in
      let shell_lines =
        match step.shell with Some s -> [ "        shell: " ^ s ] | None -> []
      in
      let env_lines =
        if List.is_empty step.env_fields then []
        else
          [ "        env:" ]
          @ List.map step.env_fields ~f:(fun (k, v) -> "          " ^ k ^ ": " ^ v)
      in
      let run = step.action in
      let run_lines =
        if multiline run then [ "        run: |"; indent_block 10 run ]
        else [ "        run: " ^ run ]
      in
      String.concat ~sep:"\n"
        (base @ if_lines @ shell_lines @ env_lines @ run_lines)

let strategy_anchor_yaml =
  {|strategy: &strategy_vars
  fail-fast: false
  matrix:
    os: [ubuntu-latest, macos-latest]
    ocaml-version: ["5.4.0"]|}

let strategy_ref_yaml = "strategy: *strategy_vars"

let render_job ~strategy_yaml (job : job) =
  let header =
    [
      "  " ^ job.id ^ ":";
      (if job.if_disabled then "    if: false" else "");
      "    name: " ^ job.name;
      (if String.is_empty job.description then ""
       else "    description: " ^ job.description);
      "    runs-on: " ^ job.runs_on;
    ]
    |> List.filter ~f:(fun s -> not (String.is_empty s))
  in
  let strategy_lines =
    String.split_lines strategy_yaml |> List.map ~f:(fun l -> "    " ^ l)
  in
  let step_lines =
    [ "    steps:" ]
    @ List.map job.preamble ~f:render_preamble_action
    @ List.map job.steps ~f:render_step
  in
  String.concat ~sep:"\n" (header @ strategy_lines @ step_lines)

let render_workflow ~workflow_name (jobs : job list) =
  let jobs_yaml =
    List.mapi jobs ~f:(fun i job ->
        let strategy_yaml =
          if i = 0 then strategy_anchor_yaml else strategy_ref_yaml
        in
        render_job ~strategy_yaml job)
    |> String.concat ~sep:"\n\n"
  in
  [%string
    {|name: %{workflow_name}

on:
  push:
    branches: ["**"]
  pull_request:
    branches: ["**"]

jobs:
%{jobs_yaml}
|}]
