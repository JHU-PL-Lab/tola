open Tola_std
open Canary_basic

let shell_preamble_lines =
  [
    "SCRIPT_DIR=\"$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)\"";
    "CANARY_ROOT=\"$(cd \"${SCRIPT_DIR}/..\" && pwd)\"";
  ]

let render_project ~canary ~workflow_name ~name jobs =
  let yaml_path = project_yaml_path canary name in
  let shell_path = project_shell_path canary name in
  let yaml_jobs = List.map (resolve_job_scripts ~scripts:canary.yaml_scripts) jobs in
  let shell_jobs = List.map (resolve_job_scripts ~scripts:canary.shell_scripts) jobs in
  write_file yaml_path
    (Canary_backend_yaml.render_workflow ~workflow_name yaml_jobs);
  write_file shell_path
    (Canary_backend_shell.render_script ~preamble_lines:shell_preamble_lines
       ~runner_os:Ubuntu shell_jobs);
  (yaml_path, shell_path)

let run_local distro =
  let z3_config = Canary_project_z3.config distro in
  let canary = z3_config.canary in
  check_file_exists_exn canary.root;
  run_cmd_exn
    (Fmt.str "mkdir -p %s %s" canary.out_root canary.backend_shell_root);
  let _z3_yaml, z3_shell =
    render_project ~canary ~workflow_name:z3_config.workflow_name
      ~name:"z3" (Canary_project_z3.jobs distro)
  in
  let _sqlite_yaml, sqlite_shell =
    render_project ~canary
      ~workflow_name:(Canary_project_sqlite.config distro).workflow_name
      ~name:"sqlite" (Canary_project_sqlite.jobs distro)
  in
  check_file_exists_exn z3_shell;
  check_file_exists_exn sqlite_shell;
  run_cmd ~strict:false (Fmt.str "chmod +x %s %s" z3_shell sqlite_shell)

let run (distro : Canary_basic.distro) =
  let z3_config = Canary_project_z3.config distro in
  let canary = z3_config.canary in
  let z3_dev_instance = Canary_project_z3.z3_dev_instance_of_distro distro in
  Fmt.pr "------------------YAML for OCaml CI------------------@.";
  let sqlite_yaml_output =
    z3_dev_instance.canary_gh_abs $/ "workflows/canary_sqlite.yml"
  in
  run_cmd_exn
    (Fmt.str
       "rm -rf %s && mkdir -p %s && cp -a %s/examples %s/ && cp -a %s/scripts \
        %s/ && cp -a %s/templates %s/ && mkdir -p %s %s"
       canary.out_root canary.out_root canary.root canary.out_root canary.root
       canary.out_root canary.root canary.out_root canary.backend_yaml_root
       canary.backend_shell_root);
  Canary_project_z3.render_opam_templates
    [ ("%{BUILD_Z3_IN_OPAM}%", Canary_project_z3.build_z3_in_opam) ]
    [
      (canary.opam_tpl_template, canary.opam_generated);
      (canary.opam_tpl_template, canary.opam_in_generated);
    ];
  let z3_yaml, z3_shell =
    render_project ~canary ~workflow_name:z3_config.workflow_name
      ~name:"z3" (Canary_project_z3.jobs distro)
  in
  let sqlite_yaml, sqlite_shell =
    render_project ~canary
      ~workflow_name:(Canary_project_sqlite.config distro).workflow_name
      ~name:"sqlite" (Canary_project_sqlite.jobs distro)
  in
  run_cmd_exn
    (Fmt.str "python3 -c \"import yaml,sys; yaml.safe_load(open('%s'))\""
       z3_yaml);
  run_cmd_exn
    (Fmt.str "python3 -c \"import yaml,sys; yaml.safe_load(open('%s'))\""
       sqlite_yaml);
  run_cmd ~strict:false
    (Fmt.str "rm -rf %s && mkdir -p %s && cp -a %s/. %s/"
       z3_dev_instance.canary_contrib_abs z3_dev_instance.canary_contrib_abs
       canary.out_root z3_dev_instance.canary_contrib_abs);
  check_file_exists_exn z3_yaml;
  check_file_exists_exn z3_shell;
  check_file_exists_exn sqlite_yaml;
  check_file_exists_exn sqlite_shell;
  check_file_exists_exn canary.opam_generated;
  check_file_exists_exn canary.opam_in_generated;
  run_cmd ~strict:false (Fmt.str "chmod +x %s %s" z3_shell sqlite_shell);
  run_cmd ~strict:false
    (Fmt.str "mkdir -p %s/workflows && cp -f %s %s"
       z3_dev_instance.canary_gh_abs z3_yaml z3_dev_instance.canary_yaml_output);
  run_cmd ~strict:false
    (Fmt.str "mkdir -p %s/workflows && cp -f %s %s"
       z3_dev_instance.canary_gh_abs sqlite_yaml sqlite_yaml_output)
