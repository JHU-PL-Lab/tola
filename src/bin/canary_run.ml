open Base
open Tola_std
open Canary_basic
open Canary

let project_configs distro =
  [
    Canary_project_z3.config distro;
    Canary_project_sqlite.config distro;
  ]

let jobs_of_config cfg = List.map cfg.job_specs ~f:(Canary.make_job cfg)

let shell_preamble_lines =
  [
    "SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"";
    "CANARY_ROOT=\"$(cd \"${SCRIPT_DIR}/..\" && pwd)\"";
  ]

let render_project ~canary ~workflow_name ~name jobs =
  let yaml_path = project_yaml_path canary name in
  let shell_path = project_shell_path canary name in
  let yaml_jobs =
    List.map jobs ~f:(resolve_job_scripts ~scripts:canary.backends.yaml_scripts)
  in
  let shell_jobs =
    List.map jobs ~f:(resolve_job_scripts ~scripts:canary.backends.shell_scripts)
  in
  write_file yaml_path
    (Canary_backend_yaml.render_workflow ~workflow_name yaml_jobs);
  write_file shell_path
    (Canary_backend_shell.render_script ~preamble_lines:shell_preamble_lines
       ~runner_os:Ubuntu shell_jobs);
  (yaml_path, shell_path)

let render_config ~canary (cfg : project_config) =
  render_project ~canary ~workflow_name:cfg.workflow_name ~name:cfg.name
    (jobs_of_config cfg)

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

let dump distro =
  let configs = project_configs distro in
  List.iter configs ~f:(fun cfg ->
      Fmt.pr "=== %s ===@.@." cfg.name;
      let jobs = jobs_of_config cfg in
      List.iter jobs ~f:dump_job)

let run_local distro =
  let configs = project_configs distro in
  let canary = (List.hd_exn configs).canary in
  check_file_exists_exn canary.paths.root;
  run_cmd_exn
    (Fmt.str "mkdir -p %s %s" canary.paths.out_root canary.backends.shell_root);
  let results = List.map configs ~f:(render_config ~canary) in
  List.iter results ~f:(fun (_, shell) -> check_file_exists_exn shell);
  let shells = List.map results ~f:snd |> String.concat ~sep:" " in
  run_cmd ~strict:false (Fmt.str "chmod +x %s" shells)

let run (distro : Canary_basic.distro) =
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
  let results = List.map configs ~f:(render_config ~canary) in
  (* validate yamls *)
  List.iter results ~f:(fun (yaml, _) ->
      run_cmd_exn
        (Fmt.str "python3 -c \"import yaml,sys; yaml.safe_load(open('%s'))\"" yaml));
  (* deploy: copy canary output + yamls to target repos *)
  let deploy = List.find_map configs ~f:(fun c -> c.deploy) in
  Option.iter deploy ~f:(fun d ->
      run_cmd ~strict:false
        (Fmt.str "rm -rf %s && mkdir -p %s && cp -a %s/. %s/" d.contrib_abs
           d.contrib_abs canary.paths.out_root d.contrib_abs);
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
