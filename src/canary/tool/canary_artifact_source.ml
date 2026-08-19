open Base

(* Source artifact ops.
   Models how to obtain source code. A source_repo is the package-like
   struct: it pairs a remote (where to fetch from) with locals (cached
   checkouts per distro), plus version metadata.

   Distro base directories factor out the per-machine prefix so local
   paths can be expressed as base / relative. *)

type repo_remote =
  | Git of string   (* git url — the MAJORITY; clone/fetch + worktrees *)
  | Hg of string    (* mercurial url — hg clone/pull/update (no worktrees) *)
  | Tar of string   (* archive url (tar/zip) — curl + unpack; the ref IS the file *)

(* The source-vcs abstraction (2026-08-16, user): canary is not hardcoded
   to git — each variant has its corresponding fetch action + tool. *)

type local_path = {
  distro : Canary_store.distro;
  path : string;        (* source checkout root *)
  build_path : string;  (* associated build dir — source of truth for this checkout *)
}

type source_repo = {
  name : string;                         (* e.g., "z3" *)
  remote : repo_remote option;
      (** [None] = a LOCAL-ONLY repo (2026-08-15, user): a local fork
          without a remote is FINE — spec-check reports it as a WARNING,
          not an error (we may or may not find a bug worth pushing; a
          remote on the personal account per project is not required).
          Official projects distributed as archives / via a PM source
          (no git at all) are a LATER refinement — all current projects
          have remotes. *)
  locals : local_path list;
  version : Canary_basic.version;        (* {channel=Dev|Stable; id="4.13.4"|"19"|""} *)
  ref_ : string;                         (* "HEAD", "z3-4.13.4" *)
  official : bool;
  build_sys_deps : string list;          (* apt packages required to build from source *)
  api_source : Canary_artifact.t option; (* hand-written API/binding spec; None = not yet declared *)
  label : string option;
      (** the FREE LABEL (2026-08-15, design/repo_model.md Q1): [None] =
          the official repo identity; [Some l] = a repo VARIANT, e.g. our
          fork ([Some "arbipher"]). [ref_]/[official]/stable-latest
          markers are repo PROPERTIES; WHICH repos a run enumerates is
          the algorithm/config's choice, not this field's. *)
  artifacts : Canary_artifact.artifact_id list;
      (** WHAT ARTIFACTS the repo's tree builds (2026-08-16, the
          multi-repo principle — design/repo_model.md): the modeling
          direction is repo → artifacts; on-tree-ness derives from it.
          The SOURCE itself is implicit (it IS the tree, not built from
          it). Generalizes the old per-source [has_build_lib]/
          [has_build_binding] booleans. *)
}

(* Generate local_path entries for all distros from a relative path.
   e.g., mk_locals "contrib/z3-all/z3" = [
     { distro = Wsl; path = "/home/red/code/contrib/z3-all/z3" };
     { distro = MacOS_local; path = "/Users/ex/code/contrib/z3-all/z3" };
   ]

   TODO (build-path convention, 2026-07-23) — source layout:
     source : ~/code/contrib/<project>-all/<project>          (checkout)
     build  : ~/code/contrib/<project>-all/build/<tag>        (per-tag build result)
   The [build_dir] default "../build" yields the *un-tagged*
   ~/code/contrib/<project>-all/build (what z3/llvm use today, one build
   tree shared across variants). When we start source-building variants,
   [build_dir] should incorporate the version/variant tag ("../build/<tag>")
   so each variant's compile output is isolated. Only matters for
   source-built projects (z3/llvm); Pattern-A projects (sqlite/ssl/cairo/…)
   use opam binaries and never build a native lib. *)
let mk_locals ?(build_dir = "../build") rel_path =
  List.map Canary_store.all_distros ~f:(fun distro ->
      let path = Canary_store.distro_base distro ^ "/" ^ rel_path in
      let build_path = path ^ "/" ^ build_dir in
      { distro; path; build_path })

(* Find the local checkout for a distro, if any *)
let local_for distro (repo : source_repo) =
  List.find repo.locals ~f:(fun l ->
      Poly.equal l.distro distro)

(* ── WORKTREE-based source checkouts (2026-08-15, design/repo_model.md) ──
   One repository (shared objects) + a [git worktree] per tracked ref —
   versions coexist without in-place [git checkout <ref>] churn; the
   stable/latest markers are descriptive and can update, so every run
   REFRESHES on demand (fetch in the main checkout, then re-pin the
   worktree to the ref). The fetch step IS the prepare (the project's
   realize style; prepare as a dynamically dispatched action is future
   work). The naming scheme: <contrib_root>/<project>-all/<repo-name>
   for the main checkout, -<ref-slug> per worktree (the OFFICIAL repo
   name drives the dir; the slug is the fallback naming for variants). *)

let repo_main_path ~(project : string) ~(repo : source_repo) :
    Canary_store.distro -> string =
  fun distro ->
    Printf.sprintf "%s/%s-all/%s"
      (Canary_store.contrib_root distro) project repo.name

let repo_worktree_path ~(project : string) ~(repo : source_repo) ~(ref_ : string) :
    Canary_store.distro -> string =
  fun distro ->
    let slug =
      String.map ref_ ~f:(function '/' | '\\' | ':' -> '-' | c -> c)
    in
    Printf.sprintf "%s-%s" (repo_main_path ~project ~repo distro) slug

let worktree_ensure_cmd ?(marker = "source.ok") ~project ~(repo : source_repo)
    ~(ref_ : string) ~output_dir ~variant_key () : string =
  let distro = Canary_basic.detect_distro () in
  let main = repo_main_path ~project ~repo distro in
  let wt = repo_worktree_path ~project ~repo ~ref_ distro in
  (* the marker must be the one the ACTION's postcondition looks for
     ({!Canary_step_builder.marker_of_action}): [source.ok] for
     [Fetch Source], [binding_source.ok] for [Fetch (Binding_source l)].
     Hardcoding "source.ok" made the first off-tree binding-source fetch
     run fine and then fail its postcondition. *)
  let ok = Canary_basic.variant_file ~variant_key marker in
  match repo.remote with
  | Some (Git url) ->
      (* the worktree shape: clone once, worktree-add once, then refresh
         on demand (fetch the ref into the shared repo; re-pin the
         worktree to it). NOTE: a worktree's .git is a FILE (gitdir
         pointer), so existence is tested on the directory, not on .git. *)
      [%string
        {|if [ ! -d %{main}/.git ]; then git clone %{url} %{main}; fi && \
git -C %{main} fetch -q origin %{ref_} && \
if [ ! -d %{wt} ]; then git -C %{main} worktree add -f %{wt} %{ref_}; fi && \
git -C %{wt} checkout -q -f %{ref_} && \
echo '%{wt}' > %{output_dir}/%{ok}|}]
  | Some (Hg url) ->
      (* mercurial: one checkout, refreshed in place (hg has no
         worktrees; per-ref checkouts via `hg share` are future work).
         The refresh re-pulls + updates — the stable/latest markers can
         move. *)
      [%string
        {|if [ ! -d %{main}/.hg ]; then hg clone %{url} %{main}; fi && \
hg -R %{main} pull -q && \
hg -R %{main} update -q %{ref_} && \
echo '%{main}' > %{output_dir}/%{ok}|}]
  | Some (Tar url) ->
      (* archive: download + unpack once (the ref IS the archive file);
         refresh = re-download when missing. *)
      [%string
        {|if [ ! -d %{main} ]; then mkdir -p %{main} && %{Canary_build_cmd.curl_unzip_cmd ~url ~dest:main ()}; fi && \
echo '%{main}' > %{output_dir}/%{ok}|}]
  | None ->
      (* LOCAL-ONLY repo (a fork without a remote — the user's model:
         warning-grade): the main checkout IS the local fork; it must
         pre-exist — no clone, no fetch. Loud, not silent. *)
      [%string
        {|test -d %{main}/.git || { echo 'local-only repo %{main} missing — prepare the fork first' >&2; exit 1; } && \
echo '%{main}' > %{output_dir}/%{ok}|}]

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
  let ok = Canary_basic.variant_file ~variant_key "source.ok" in
  match local_for distro repo with
  | Some l ->
      [%string "test -d %{l.path} && echo '%{l.path}' > %{output_dir}/%{ok}"]
  | None -> (
      match repo.remote with
      | None ->
          (* LOCAL-ONLY repo (a fork without a remote — warning-grade per
             design/repo_model.md) with no [locals] entry: nothing to
             fetch. Loud, not silent. *)
          [%string
            "echo 'local-only repo %{repo.name} has no remote and no local checkout' >&2; exit 1"]
      | Some (Git url) ->
          let ref_ = repo.ref_ in
          (* Clone into a stable path derived from version+ref, not
             output_dir, so build_lib etc. can find it via
             root_of_source *)
          let ver_str = Canary_basic.string_of_version repo.version in
          let clone_dir =
            [%string "_out/canary/projects/%{repo.name}/%{ver_str}_%{ref_}/src"]
          in
          [%string
            "if [ -d %{clone_dir}/.git ]; then cd %{clone_dir} && git fetch && git checkout %{ref_}; else git clone %{url} %{clone_dir} && cd %{clone_dir} && git checkout %{ref_}; fi && echo '%{clone_dir}' > %{output_dir}/%{ok}"]
      | Some (Hg url) ->
          let ref_ = repo.ref_ in
          let ver_str = Canary_basic.string_of_version repo.version in
          let clone_dir =
            [%string "_out/canary/projects/%{repo.name}/%{ver_str}_%{ref_}/src"]
          in
          [%string
            "if [ -d %{clone_dir}/.hg ]; then cd %{clone_dir} && hg pull -q && hg update -q %{ref_}; else hg clone %{url} %{clone_dir} && cd %{clone_dir} && hg update -q %{ref_}; fi && echo '%{clone_dir}' > %{output_dir}/%{ok}"]
      | Some (Tar url) ->
          (* an archive source: curl + unpack into the stable cache path *)
          let ver_str = Canary_basic.string_of_version repo.version in
          let dest =
            [%string "_out/canary/projects/%{repo.name}/%{ver_str}_archive/src"]
          in
          [%string
            "if [ ! -d %{dest} ]; then mkdir -p %{dest} && %{Canary_build_cmd.curl_unzip_cmd ~url ~dest ()}; fi && echo '%{dest}' > %{output_dir}/%{ok}"])

(* Compute a cache-path tag for a source repo.
   For HEAD-tracking repos, appends the short commit hash so the cache
   path is content-addressed and doesn't collide across checkouts.
   e.g., version="dev", HEAD=abc123 → "dev_abc123"
   Falls back to repo.version if the repo has no local checkout or git fails. *)
let version_cache_tag distro (repo : source_repo) =
  let ver_str = Canary_basic.string_of_version repo.version in
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
               [%string "%{ver_str}_%{h}"]
           | _ -> ver_str)
      | None -> ver_str
    end
  | _ -> ver_str

(* check_post for fetch_source: read source.ok (variant-keyed) and verify the path exists *)
let source_check_post ~output_dir ~variant_key =
  let ok_name = Canary_basic.variant_file ~variant_key "source.ok" in
  let ok_file = output_dir ^ "/" ^ ok_name in
  if Stdlib.Sys.file_exists ok_file then
    let ic = Stdlib.open_in ok_file in
    let path = Stdlib.input_line ic in
    Stdlib.close_in ic;
    Stdlib.Sys.file_exists path
  else false

(* Human-readable origin string for a source_repo: "local:<path>" or
   "<kind>:<url>" *)
let source_desc distro (repo : source_repo) =
  match local_for distro repo with
  | Some l -> "local:" ^ l.path
  | None -> (
      match repo.remote with
      | Some (Git url) -> "git:" ^ url
      | Some (Hg url) -> "hg:" ^ url
      | Some (Tar url) -> "tar:" ^ url
      | None -> "(no remote)")

(* Shell command that verifies api_source claims against the fetched source tree.
   Headers component: checks dir exists and each listed file exists.
   binding_api.source_dir (in-tree): checks dir exists.
   Runtime_lib / Link_lib / Pc_file are post-build or PM-installed — not checked here.
   Writes scan.ok to output_dir on success.

   Moved here from surface/canary_artifact_api.ml on 2026-06-02 (Phase
   11c) — it's a CHECK shell command, not a fact-type definition; lives
   next to the other source-side helpers. *)
let scan_source_cmd ~source_root (api : Canary_artifact.t)
    ~output_dir ~variant_key =
  let ok = Canary_basic.variant_file ~variant_key "scan.ok" in
  let header_checks =
    match api.native_api.headers with
    | None -> []
    | Some { dir; files } ->
        let abs_dir = [%string "%{source_root}/%{dir}"] in
        [%string "test -d %{abs_dir}"]
        :: List.map files ~f:(fun f -> [%string "test -f %{abs_dir}/%{f}"])
  in
  let binding_checks =
    List.filter_map api.binding_apis ~f:(fun b ->
      Option.map b.source_dir ~f:(fun sd ->
        [%string "test -d %{source_root}/%{sd}"]))
  in
  String.concat ~sep:"\n"
    (header_checks @ binding_checks
     @ [[%string "echo 'scan ok' > %{output_dir}/%{ok}"]])
