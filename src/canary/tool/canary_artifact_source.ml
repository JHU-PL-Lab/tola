open Base

(* Source artifact ops.
   Models how to obtain source code. A source_repo is the package-like
   struct: it pairs a remote (where to fetch from) with locals (cached
   checkouts per distro), plus version metadata.

   Distro base directories factor out the per-machine prefix so local
   paths can be expressed as base / relative. *)

type git_remote = Git_remote of string   (* url *)

type local_path = {
  distro : Canary_store.distro;
  path : string;        (* source checkout root *)
  build_path : string;  (* associated build dir — source of truth for this checkout *)
}

type source_repo = {
  name : string;                         (* e.g., "z3" *)
  remote : git_remote;
  locals : local_path list;
  version : string;                      (* "dev", "4.13.4" *)
  ref_ : string;                         (* "HEAD", "z3-4.13.4" *)
  official : bool;
  has_build_lib : bool;                  (* build the native lib from this source? *)
  has_build_binding : bool;              (* build language bindings from this source? *)
  build_sys_deps : string list;          (* apt packages required to build from source *)
  api_source : Canary_artifact_api.t option; (* hand-written API/binding spec; None = not yet declared *)
}

(* Generate local_path entries for all distros from a relative path.
   e.g., mk_locals "contrib/z3-all/z3" = [
     { distro = Wsl; path = "/home/red/code/contrib/z3-all/z3" };
     { distro = MacOS_local; path = "/Users/ex/code/contrib/z3-all/z3" };
   ] *)
let mk_locals ?(build_dir = "../build") rel_path =
  List.map Canary_store.all_distros ~f:(fun distro ->
      let path = Canary_store.distro_base distro ^ "/" ^ rel_path in
      let build_path = path ^ "/" ^ build_dir in
      { distro; path; build_path })

(* Find the local checkout for a distro, if any *)
let local_for distro (repo : source_repo) =
  List.find repo.locals ~f:(fun l ->
      Poly.equal l.distro distro)

(* Resolve the source root path: local checkout if available,
   otherwise will need to clone *)
let source_root distro (repo : source_repo) =
  match local_for distro repo with
  | Some l -> Some l.path
  | None -> None

(* Generate the fetch_source shell command.
   If a local checkout exists, verify it. Otherwise clone from remote
   into the canary local cache. For arbitrary refs (commit SHAs), we
   clone then checkout in two steps since --branch only works for
   tags and branch names. *)
let source_fetch_cmd distro (repo : source_repo) ~output_dir ~variant_key =
  let ok = Canary_output_path.variant_file ~variant_key "source.ok" in
  match local_for distro repo with
  | Some l ->
      [%string "test -d %{l.path} && echo '%{l.path}' > %{output_dir}/%{ok}"]
  | None ->
      let (Git_remote url) = repo.remote in
      let ref_ = repo.ref_ in
      (* Clone into a stable path derived from version+ref, not output_dir,
         so build_lib etc. can find it via root_of_source *)
      let clone_dir = [%string "_out/canary/projects/%{repo.name}/%{repo.version}_%{ref_}/src"] in
      [%string "if [ -d %{clone_dir}/.git ]; then cd %{clone_dir} && git fetch && git checkout %{ref_}; else git clone %{url} %{clone_dir} && cd %{clone_dir} && git checkout %{ref_}; fi && echo '%{clone_dir}' > %{output_dir}/%{ok}"]

(* Compute a cache-path tag for a source repo.
   For HEAD-tracking repos, appends the short commit hash so the cache
   path is content-addressed and doesn't collide across checkouts.
   e.g., version="dev", HEAD=abc123 → "dev_abc123"
   Falls back to repo.version if the repo has no local checkout or git fails. *)
let version_cache_tag distro (repo : source_repo) =
  match repo.ref_ with
  | "HEAD" -> begin
      match local_for distro repo with
      | Some l ->
          let ic =
            Unix.open_process_in
              [%string "git -C %{l.path} rev-parse --short=6 HEAD 2>/dev/null"]
          in
          let result =
            try Some (String.strip (Stdlib.input_line ic)) with End_of_file -> None
          in
          ignore (Unix.close_process_in ic);
          (match result with
           | Some h when not (String.is_empty h) ->
               [%string "%{repo.version}_%{h}"]
           | _ -> repo.version)
      | None -> repo.version
    end
  | _ -> repo.version

(* check_post for fetch_source: read source.ok (variant-keyed) and verify the path exists *)
let source_check_post ~output_dir ~variant_key =
  let ok_name = Canary_output_path.variant_file ~variant_key "source.ok" in
  let ok_file = output_dir ^ "/" ^ ok_name in
  if Stdlib.Sys.file_exists ok_file then
    let ic = Stdlib.open_in ok_file in
    let path = Stdlib.input_line ic in
    Stdlib.close_in ic;
    Stdlib.Sys.file_exists path
  else false

(* Human-readable origin string for a source_repo: "local:<path>" or "git:<url>" *)
let source_desc distro (repo : source_repo) =
  match local_for distro repo with
  | Some l -> "local:" ^ l.path
  | None ->
      let (Git_remote url) = repo.remote in
      "git:" ^ url
