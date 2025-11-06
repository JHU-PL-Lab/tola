open Base
open Tola_std
(*
  How many stores should a pkgm have?
  Here we should think about the store visibility and activeness.
*)

open Ppx_yojson_conv_lib.Yojson_conv.Primitives

type store_kind = Directory | Git_repo
and store_position = Local | Remote

and store_spec = {
  name : string;
  kind : store_kind;
  position : store_position;
  root : string;
}
[@@deriving yojson]

type pkg_spec = { meta_file : string } [@@deriving yojson]
type pm_spec = { versioning : string } [@@deriving yojson]

type ext_spec = {
  (* TODO: should be regex *)
  src_import_regex : string option;
  src_pid_regex : string option;
}
[@@deriving yojson]

type config = {
  pkgm_id : string;
  lang_id : string;
  pkg_spec : pkg_spec;
  pm_spec : pm_spec;
  ext_spec : ext_spec;
  cypher : string;
  root : string;
  cache_path : string;
  local_store : store_spec;
  remote_stores : store_spec list;
}
[@@deriving yojson]
(* `lang` is used to find the _including_ syntax
     `pkgm` is used to find the correct pkgm root path *)

(* TODO:
include is a 2nd-class value that we just expand the text
at_rounded should be extented to 1nd-class value
*)

(*
  include(foo)
  include(\\([^)]*\\))

  #include foo\n
  #include \\([^)]*\\)\n
*)

let inclusion_alist =
  let at_rounded = "@@\\([^@ \t\r\n]+\\)@@" in
  let include_spaced = "; ?include(\\([^)]*\\))" in
  [ ("lt", at_rounded); ("z3", include_spaced) ]

let local_dir_store name root =
  { name; kind = Directory; position = Local; root }

let remote_dir_store name root =
  { name; kind = Directory; position = Remote; root }

let git_store name root = { name; kind = Git_repo; position = Remote; root }

let mk_config ?(root = "_pm/root") ?(cache_path = "_pm/cache")
    ?(cypher = "tola") lang_id pkgm_id meta_file =
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
  let pkg_spec = { meta_file } in

  (* TODO: I shall use version to init a pkgm, not the other way around *)
  let pm_spec = { versioning = "semver" } in
  let ext_spec =
    {
      (* regex *)
      src_import_regex =
        List.Assoc.find ~equal:String.equal inclusion_alist lang_id;
      src_pid_regex = None;
    }
  in
  {
    pkgm_id;
    lang_id;
    pkg_spec;
    pm_spec;
    ext_spec;
    cypher;
    root;
    cache_path;
    local_store;
    remote_stores;
  }
