open Std.File_infix
(*
  How many stores should a pkgm have?
  Here we should think about the store visibility and activeness.
*)

type store_kind = Directory | Git_repo
type store_position = Local | Remote

type store_spec = {
  name : string;
  kind : store_kind;
  position : store_position;
  root : string;
}

type config = {
  lang_id : string;
  pkgm_id : string;
  meta_file : string;
  local_store : store_spec;
  remote_stores : store_spec list;
}

let local_dir_store name root =
  { name; kind = Directory; position = Local; root }

let remote_dir_store name root =
  { name; kind = Directory; position = Remote; root }

let git_store name root = { name; kind = Git_repo; position = Remote; root }

let mk_config lang_id pkgm_id meta_file local_store remote_stores =
  { lang_id; pkgm_id; meta_file; local_store; remote_stores }

let mk_demo_config ?(demo_root = "_pm_root") lang_id pkgm_id meta_file =
  let local_root = Sys.getcwd () $/ demo_root $/ pkgm_id ^ "_local" in
  let local_store = local_dir_store "local0" local_root in
  let remote_stores =
    let remote_root = Sys.getcwd () $/ demo_root $/ pkgm_id ^ "_remote" in
    let remote_root2 = Sys.getcwd () $/ demo_root $/ pkgm_id ^ "_remote2" in
    [
      remote_dir_store "remote" remote_root;
      remote_dir_store "remote2" remote_root2;
      git_store "arbipher/multiverse" "https://github.com/arbipher/multiverse";
    ]
  in
  mk_config lang_id pkgm_id meta_file local_store remote_stores
