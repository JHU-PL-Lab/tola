open Base
open Canary_basic

let render_stage_guard = function
  | Guard_runner_os Ubuntu -> "runner.os == 'Linux'"
  | Guard_runner_os MacOS -> "runner.os == 'macOS'"

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

let render_step (stage : string step) =
      let base = [ "      - name: " ^ stage.name ] in
      let if_lines =
        match stage.guard with
        | Some guard -> [ "        if: " ^ render_stage_guard guard ]
        | None -> []
      in
      let shell_lines =
        match stage.shell with Some s -> [ "        shell: " ^ s ] | None -> []
      in
      let env_lines =
        if List.is_empty stage.env_fields then []
        else
          [ "        env:" ]
          @ List.map stage.env_fields ~f:(fun (k, v) -> "          " ^ k ^ ": " ^ v)
      in
      let run = stage.action in
      let run_lines =
        if multiline run then [ "        run: |"; indent_block 10 run ]
        else [ "        run: " ^ run ]
      in
      String.concat ~sep:"\n"
        (base @ if_lines @ shell_lines @ env_lines @ run_lines)

let render_job (job : string job) =
  let header =
    [
      "  " ^ job.id ^ ":";
      (if job.if_disabled then "    if: false" else "");
      "    name: " ^ job.name;
      "    runs-on: " ^ job.runs_on;
    ]
    |> List.filter ~f:(fun s -> not (String.is_empty s))
  in
  let strategy_lines =
    match job.strategy_yaml with
    | None -> []
    | Some s -> String.split_lines s |> List.map ~f:(fun l -> "    " ^ l)
  in
  let step_lines =
    [ "    steps:" ]
    @ List.map job.preamble ~f:render_preamble_action
    @ List.map job.steps ~f:render_step
  in
  String.concat ~sep:"\n" (header @ strategy_lines @ step_lines)

let render_workflow ~workflow_name (jobs : string job list) =
  let jobs_yaml = List.map jobs ~f:render_job |> String.concat ~sep:"\n\n" in
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
