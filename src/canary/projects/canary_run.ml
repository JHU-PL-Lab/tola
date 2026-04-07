open Base
open Tola_std
open Canary_store
open Canary_basic
open Canary

let project_configs distro =
  [
    Canary_project_z3.config distro;
    Canary_project_sqlite.config distro;
    Canary_project_llvm.config distro;
  ]

let jobs_of_config cfg =
  List.map cfg.job_specs
    ~f:(make_job ~steps_of_phase:Canary.steps_of_phase ~config:cfg)

let shell_preamble_lines =
  [
    "SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"";
    "CANARY_ROOT=\"$(cd \"${SCRIPT_DIR}/..\" && pwd)\"";
  ]

let runner_os_of_distro = function MacOS_local -> MacOS | Wsl -> Ubuntu

let render_project ~runner_os ~canary ~workflow_name ~name jobs =
  let yaml_path = project_yaml_path canary name in
  let shell_path = project_shell_path canary name in
  let yaml_jobs =
    List.map jobs ~f:(resolve_job_scripts ~scripts:canary.backends.yaml_scripts)
  in
  let shell_jobs =
    List.map jobs
      ~f:(resolve_job_scripts ~scripts:canary.backends.shell_scripts)
  in
  write_file yaml_path
    (Canary_backend_yaml.render_workflow ~workflow_name yaml_jobs);
  write_file shell_path
    (Canary_backend_shell.render_script ~preamble_lines:shell_preamble_lines
       ~runner_os shell_jobs);
  (yaml_path, shell_path)

let render_config ~runner_os ~canary (cfg : project_config) =
  render_project ~runner_os ~canary ~workflow_name:cfg.workflow_name
    ~name:cfg.name (jobs_of_config cfg)

let render_opam_templates ~(canary : canary_config) bindings =
  let files =
    [
      (canary.opam.tpl_template, canary.opam.generated);
      (canary.opam.tpl_template, canary.opam.in_generated);
    ]
  in
  List.iter files ~f:(fun (src, dst) ->
      let rendered =
        List.fold bindings ~init:(read_file src) ~f:(fun acc (k, v) ->
            String.substr_replace_all acc ~pattern:k ~with_:v)
      in
      let parent = Stdlib.Filename.dirname dst in
      ignore (Stdlib.Sys.command (Fmt.str "mkdir -p %s" parent));
      write_file dst rendered)

let yaml_output_of_deploy deploy name =
  deploy.gh_abs $/ "workflows" $/ [%string "canary_%{name}.yml"]

let dump_config_to_string (cfg : project_config) =
  let buf = Buffer.create 1024 in
  let ppf = Fmt.with_buffer buf in
  Fmt.pf ppf "=== %s ===@.@." cfg.name;
  let jobs = jobs_of_config cfg in
  List.iter jobs ~f:(pp_job ppf);
  Fmt.flush ppf ();
  Buffer.contents buf

let shell_of_config (cfg : project_config) =
  let jobs = jobs_of_config cfg in
  let shell_jobs =
    List.map jobs
      ~f:(resolve_job_scripts ~scripts:cfg.canary.backends.shell_scripts)
  in
  Canary_backend_shell.render_script ~preamble_lines:shell_preamble_lines
    ~runner_os:Ubuntu shell_jobs

let dump distro =
  let configs = project_configs distro in
  List.iter configs ~f:(fun cfg ->
      Stdlib.print_string (dump_config_to_string cfg))

let dump_graph _distro =
  let graph_dir = "_out/canary/graph" in
  ignore (Stdlib.Sys.command [%string "mkdir -p %{graph_dir}"]);
  let configs = project_configs _distro in
  (* Derived graphs from job specs *)
  List.iter configs ~f:(fun cfg ->
      let g = graph_of_job_specs cfg.job_specs in
      let path = [%string "%{graph_dir}/%{cfg.name}.mmd"] in
      write_file path (mermaid_of_graph g);
      Fmt.pr "Wrote %s@." path);
  (* Hardcoded reference graphs *)
  let hardcoded =
    [
      ("z3", build_graph ~name:"z3" ~system_pm:Brew ~lang:OCaml);
      ("sqlite3", build_graph ~name:"sqlite3" ~system_pm:Brew ~lang:OCaml);
    ]
  in
  List.iter hardcoded ~f:(fun (name, g) ->
      let path = [%string "%{graph_dir}/%{name}_reference.mmd"] in
      write_file path (mermaid_of_graph g);
      Fmt.pr "Wrote %s@." path);
  (* Action rule schema diagram *)
  let path = [%string "%{graph_dir}/action_rule.mmd"] in
  write_file path
    (mermaid_of_action_rule_schema store_rules);
  Fmt.pr "Wrote %s@." path

let dump_job_paths_with ~pp =
  Fmt.pr "=== Action Pattern Table ===@.@.";
  Fmt.pr "Each row is a structural action pattern. The `versions` column shows@.";
  Fmt.pr "how many version combinations instantiate that pattern (with 2 versions).@.";
  Fmt.pr "Every artifact can be probed (probe = action_path → probe_<kind>, d+1).@.@.";
  let ar =
    make_action_rule ~rules:store_rules ~versions:two_versions ~name:"pkg"
      ~source:store ()
  in
  let paths = job_paths_of_action_rule ar in
  pp Fmt.stdout paths;
  Fmt.pr "@.%d structural patterns, %d total artifacts@."
    (List.length (pattern_rows_of_paths paths))
    (List.length paths)

let dump_job_paths () = dump_job_paths_with ~pp:pp_job_path_table
let dump_job_paths_md () = dump_job_paths_with ~pp:pp_job_path_table_md

(* ── Action runner ── *)

let run_action_demo () =
  let root = "_out" in
  let distro = Canary_basic.detect_distro () in
  Canary_action.run_project ~root ~project:"sqlite"
    (Canary_project_sqlite.action_steps ~root ~project:"sqlite");
  Canary_action.run_project ~root ~project:"llvm"
    (Canary_project_llvm.action_steps ~root ~project:"llvm" distro);
  Canary_action.run_project ~root ~project:"z3"
    (Canary_project_z3.action_steps ~root ~project:"z3" distro)

let run_local ?(exec = false) ?project distro =
  let runner_os = runner_os_of_distro distro in
  let configs = project_configs distro in
  let configs =
    match project with
    | None -> configs
    | Some p -> List.filter configs ~f:(fun cfg -> String.equal cfg.name p)
  in
  let canary = (List.hd_exn (project_configs distro)).canary in
  check_file_exists_exn canary.paths.root;
  run_cmd_exn
    (Fmt.str "mkdir -p %s %s" canary.paths.out_root canary.backends.shell_root);
  let results = List.map configs ~f:(render_config ~runner_os ~canary) in
  List.iter results ~f:(fun (_, shell) -> check_file_exists_exn shell);
  let shells = List.map results ~f:snd in
  List.iter shells ~f:(fun shell ->
      run_cmd ~strict:false (Fmt.str "chmod +x %s" shell));
  if exec then
    List.iter shells ~f:(fun shell ->
        Fmt.pr "@.--- Running %s ---@." shell;
        run_cmd_exn (Fmt.str "bash %s" shell))

let run (distro : Canary_store.distro) =
  let runner_os = runner_os_of_distro distro in
  let configs = project_configs distro in
  let canary = (List.hd_exn configs).canary in
  Fmt.pr "------------------YAML for OCaml CI------------------@.";
  run_cmd_exn
    (Fmt.str
       "rm -rf %s && mkdir -p %s && cp -a %s/examples %s/ && cp -a %s/scripts \
        %s/ && cp -a %s/templates %s/ && mkdir -p %s %s"
       canary.paths.out_root canary.paths.out_root canary.paths.root
       canary.paths.out_root canary.paths.root canary.paths.out_root
       canary.paths.root canary.paths.out_root canary.backends.yaml_root
       canary.backends.shell_root);
  (* render opam templates for projects that have bindings *)
  List.iter configs ~f:(fun cfg ->
      if not (List.is_empty cfg.opam_template_bindings) then
        render_opam_templates ~canary cfg.opam_template_bindings);
  (* render all projects *)
  let results = List.map configs ~f:(render_config ~runner_os ~canary) in
  (* validate yamls *)
  List.iter results ~f:(fun (yaml, _) ->
      run_cmd_exn
        (Fmt.str "python3 -c \"import yaml,sys; yaml.safe_load(open('%s'))\""
           yaml));
  (* deploy: copy canary output + yamls to target repos *)
  let deploy = List.find_map configs ~f:(fun c -> c.deploy) in
  Option.iter deploy ~f:(fun d ->
      run_cmd ~strict:false
        (Fmt.str "rm -rf %s && mkdir -p %s && rsync -a --exclude '_local' %s/ %s/"
           d.contrib_abs d.contrib_abs canary.paths.out_root d.contrib_abs);
      List.iter (List.zip_exn configs results) ~f:(fun (cfg, (yaml, _)) ->
          let yaml_dst = yaml_output_of_deploy d cfg.name in
          run_cmd ~strict:false
            (Fmt.str "mkdir -p %s/workflows && cp -f %s %s" d.gh_abs yaml
               yaml_dst)));
  (* check generated files exist *)
  List.iter results ~f:(fun (yaml, shell) ->
      check_file_exists_exn yaml;
      check_file_exists_exn shell);
  check_file_exists_exn canary.opam.generated;
  check_file_exists_exn canary.opam.in_generated;
  let shells = List.map results ~f:snd |> String.concat ~sep:" " in
  run_cmd ~strict:false (Fmt.str "chmod +x %s" shells)
