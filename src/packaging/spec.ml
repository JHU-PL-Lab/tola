open Base
open Tola_std.Std.File_infix
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
  root : string;
  cache_path : string;
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

let config_of root cache_path lang_id pkgm_id meta_file local_store
    remote_stores =
  { root; cache_path; lang_id; pkgm_id; meta_file; local_store; remote_stores }

let mk_config root cache_path lang_id pkgm_id meta_file =
  let local_root = Unix.getcwd () $/ root $/ pkgm_id $/ "local" in
  let local_store = local_dir_store "local0" local_root in
  let remote_stores =
    let remote_root = Unix.getcwd () $/ root $/ pkgm_id $/ "remote" in
    (* let remote_root2 = Sys.getcwd () $/ demo_root $/ pkgm_id ^ "_remote2" in *)
    [
      remote_dir_store "remote1" remote_root;
      (* remote_dir_store "remote2" remote_root2; *)
      git_store "arbipher/multiverse" "https://github.com/arbipher/multiverse";
    ]
  in
  config_of root cache_path lang_id pkgm_id meta_file local_store remote_stores
